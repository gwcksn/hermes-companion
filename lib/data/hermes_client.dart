// REST client for the Hermes dashboard (`hermes serve`, port 9119). See docs/hermes-protocol.md.
//
// Auth: POST /auth/password-login sets a session cookie. Cookies are kept in the
// CredentialStore and replayed on every call; a 401 triggers one silent re-login
// with the stored credentials, then the request is retried once.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/credential_store.dart';
import 'settings_store.dart';

enum HermesErrorKind { invalidUrl, unreachable, notHermes, badCredentials, rateLimited, signedOut, server }

class HermesError implements Exception {
  const HermesError(this.kind, [this.status]);

  final HermesErrorKind kind;
  final int? status;

  /// Short, user-facing text for status lines.
  String get message => switch (kind) {
    HermesErrorKind.invalidUrl => 'That address does not look right',
    HermesErrorKind.unreachable => 'Cannot reach it. Is Tailscale on?',
    HermesErrorKind.notHermes => 'Reachable, but that is not a Hermes dashboard',
    HermesErrorKind.badCredentials => 'Wrong username or password',
    HermesErrorKind.rateLimited => 'Too many attempts. Try again shortly',
    HermesErrorKind.signedOut => 'Signed out. Sign in again in Connection',
    HermesErrorKind.server => 'Hermes answered with an error${status == null ? '' : ' ($status)'}',
  };

  @override
  String toString() => 'HermesError($kind, $status)';
}

/// Public facts from GET /api/status.
class HermesStatus {
  const HermesStatus({
    required this.version,
    required this.gatewayRunning,
    required this.authRequired,
    required this.passwordLogin,
    required this.profiles,
  });

  final String version;
  final bool gatewayRunning;
  final bool authRequired;

  /// The `basic` provider is offered, so password login can work.
  final bool passwordLogin;
  final List<String> profiles;

  String get summary => 'Reachable. Hermes $version, gateway ${gatewayRunning ? 'running' : 'stopped'}';

  static HermesStatus? tryParse(Object? data) {
    if (data is! Map || data['version'] is! String) return null;
    final providers = (data['auth_providers'] as List?)?.cast<Object?>() ?? const [];
    return HermesStatus(
      version: data['version'] as String,
      gatewayRunning: data['gateway_running'] == true,
      authRequired: data['auth_required'] != false,
      passwordLogin: providers.contains('basic'),
      profiles: [
        for (final p in (data['profiles'] as List?) ?? const [])
          if (p is String) p,
      ],
    );
  }
}

/// Normalizes what the owner types: adds https://, drops trailing slashes. Null if unusable.
String? normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return null;
  return uri.replace(query: null, fragment: null).toString().replaceAll(RegExp(r'/+$'), '');
}

/// Adds `?profile=` except for `default`, matching hermes-conduit's DashboardPath.withProfile.
Map<String, dynamic> profileQuery(String profile, [Map<String, dynamic> extra = const {}]) => {
  ...extra,
  if (profile != 'default') 'profile': profile,
};

class HermesClient {
  HermesClient(this.baseUrl, this._store, {Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20))) {
    _dio.options
      ..baseUrl = baseUrl
      // Handle redirects and statuses ourselves: login may set its cookie on a 302.
      ..followRedirects = false
      ..validateStatus = (_) => true;
  }

  final String baseUrl;
  final CredentialStore _store;
  final Dio _dio;
  Map<String, String>? _cookies;

  /// Public: is this a Hermes dashboard, and what does it offer?
  Future<HermesStatus> status() async {
    final res = await _send(() => _dio.get<Object>('/api/status'));
    if (res.statusCode != 200) throw HermesError(HermesErrorKind.notHermes, res.statusCode);
    return HermesStatus.tryParse(res.data) ?? (throw const HermesError(HermesErrorKind.notHermes));
  }

  /// POST /auth/password-login. On success the session cookies are stored.
  Future<void> login(String username, String password) async {
    final res = await _send(
      () => _dio.post<Object>(
        '/auth/password-login',
        data: {'provider': 'basic', 'username': username, 'password': password},
        options: Options(contentType: Headers.jsonContentType),
      ),
    );
    final code = res.statusCode ?? 0;
    if (code == 401 || code == 403) throw HermesError(HermesErrorKind.badCredentials, code);
    if (code == 429) throw HermesError(HermesErrorKind.rateLimited, code);
    if (code >= 400) throw HermesError(HermesErrorKind.server, code);
    final cookies = parseSetCookies(res.headers[HttpHeaders.setCookieHeader] ?? const []);
    if (cookies.isEmpty) throw HermesError(HermesErrorKind.server, code);
    _cookies = cookies;
    await _store.saveCookies(cookies);
  }

  /// Authenticated GET returning decoded JSON. Re-logs in once on 401.
  Future<Object?> getJson(String path, {Map<String, dynamic>? query}) async {
    final res = await _authed(() => _dio.get<Object>(path, queryParameters: query, options: _cookieOptions()));
    return res.data;
  }

  /// Authenticated POST returning decoded JSON. Re-logs in once on 401.
  Future<Object?> postJson(String path, {Object? body, Duration? receiveTimeout}) async {
    final res = await _authed(
      () => _dio.post<Object>(
        path,
        data: body,
        options: _cookieOptions(contentType: Headers.jsonContentType)..receiveTimeout = receiveTimeout,
      ),
    );
    return res.data;
  }

  /// The profile's model name from GET /api/model/info, if the server reports one.
  Future<String?> modelName(String profile) async {
    final data = await getJson('/api/model/info', query: profileQuery(profile));
    if (data is Map) {
      for (final key in ['model', 'model_name', 'name', 'id']) {
        if (data[key] is String && (data[key] as String).isNotEmpty) return data[key] as String;
      }
    }
    return null;
  }

  /// One-use WebSocket ticket (30 s TTL) for /api/ws. Mint right before each connect.
  Future<String> mintWsTicket() async {
    final data = await postJson('/api/auth/ws-ticket');
    final ticket = data is Map ? data['ticket'] : null;
    if (ticket is! String || ticket.isEmpty) throw const HermesError(HermesErrorKind.server);
    return ticket;
  }

  /// wss:// (or ws://) URL for the gateway socket with [ticket].
  Uri gatewayUri(String ticket) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}/api/ws',
      queryParameters: {'ticket': ticket},
    );
  }

  Future<Response<Object>> _authed(Future<Response<Object>> Function() call) async {
    _cookies ??= await _store.readCookies(baseUrl);
    if (_cookies!.isEmpty) await _relogin();
    var res = await _send(call);
    if (res.statusCode == 401 || _isLoginRedirect(res)) {
      await _relogin();
      res = await _send(call);
    }
    final code = res.statusCode ?? 0;
    if (code == 401 || _isLoginRedirect(res)) throw HermesError(HermesErrorKind.signedOut, code);
    if (code >= 400) throw HermesError(HermesErrorKind.server, code);
    return res;
  }

  Future<void> _relogin() async {
    final creds = await _store.read(baseUrl);
    if (creds == null) throw const HermesError(HermesErrorKind.signedOut);
    try {
      await login(creds.username, creds.password);
    } on HermesError catch (e) {
      // Stored password no longer accepted: the owner must sign in again.
      if (e.kind == HermesErrorKind.badCredentials) throw HermesError(HermesErrorKind.signedOut, e.status);
      rethrow;
    }
  }

  bool _isLoginRedirect(Response<Object> res) {
    final code = res.statusCode ?? 0;
    if (code < 300 || code >= 400) return false;
    return (res.headers.value(HttpHeaders.locationHeader) ?? '').contains('/login');
  }

  Options _cookieOptions({String? contentType}) => Options(
    contentType: contentType,
    headers: {
      if (_cookies != null && _cookies!.isNotEmpty)
        HttpHeaders.cookieHeader: _cookies!.entries.map((e) => '${e.key}=${e.value}').join('; '),
    },
  );

  Future<Response<Object>> _send(Future<Response<Object>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw switch (e.type) {
        DioExceptionType.badResponse => HermesError(HermesErrorKind.server, e.response?.statusCode),
        _ => const HermesError(HermesErrorKind.unreachable),
      };
    }
  }
}

/// Extracts name=value pairs from Set-Cookie headers, skipping deletions.
Map<String, String> parseSetCookies(List<String> headers) {
  final out = <String, String>{};
  for (final h in headers) {
    final first = h.split(';').first.trim();
    final eq = first.indexOf('=');
    if (eq <= 0) continue;
    final name = first.substring(0, eq).trim();
    final value = first.substring(eq + 1).trim();
    final expired = RegExp(r'max-age=0\b', caseSensitive: false).hasMatch(h);
    if (value.isEmpty || expired) {
      out.remove(name);
    } else {
      out[name] = value;
    }
  }
  return out;
}

abstract final class HttpHeaders {
  static const setCookieHeader = 'set-cookie';
  static const cookieHeader = 'cookie';
  static const locationHeader = 'location';
}

/// Builds a client for a server URL (overridden in tests to inject a fake transport).
final hermesClientFactoryProvider = Provider<HermesClient Function(String url)>((ref) {
  final store = ref.watch(credentialStoreProvider);
  return (url) => HermesClient(url, store);
});

/// The client for the configured server, or null before setup has an address.
final hermesClientProvider = Provider<HermesClient?>((ref) {
  final url = ref.watch(settingsProvider.select((s) => s.serverUrl));
  if (url.isEmpty) return null;
  return ref.watch(hermesClientFactoryProvider)(url);
});
