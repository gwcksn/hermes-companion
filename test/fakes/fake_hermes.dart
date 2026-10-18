import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/hermes_client.dart';

/// In-memory stand-in for the Keystore-backed store.
class MemoryCredentialStore extends CredentialStore {
  Credentials? creds;
  Map<String, String> cookies = {};
  String? cookieServer;

  @override
  Future<Credentials?> read(String server) async => creds?.server == server ? creds : null;

  @override
  Future<void> save(Credentials c) async {
    creds = c;
    cookieServer = c.server;
  }

  @override
  Future<Map<String, String>> readCookies(String server) async => cookieServer == server ? {...cookies} : {};

  @override
  Future<void> saveCookies(Map<String, String> c) async => cookies = {...c};

  @override
  Future<void> clear() async {
    creds = null;
    cookies = {};
    cookieServer = null;
  }
}

/// A fake Hermes dashboard: public /api/status, password login with a session cookie,
/// and a cookie-protected /api/model/info. Change [sessionValue] to simulate expiry.
class FakeHermes implements HttpClientAdapter {
  FakeHermes({this.username = 'admin', this.password = 'secret', this.reachable = true});

  final String username;
  final String password;
  bool reachable;
  String sessionValue = 's1';
  final requests = <RequestOptions>[];
  int logins = 0;
  int tickets = 0;

  /// What /api/audio/transcribe answers with; `transcribeBodies` collects what the app sent.
  String transcript = 'what is on my calendar';
  final transcribeBodies = <Map>[];

  /// /api/audio/speak answers a base64 data URL; `speakBodies` collects the requests.
  final speakBodies = <Map>[];
  bool speakFails = false;

  static const status = {
    'version': '0.21.6',
    'gateway_running': true,
    'auth_required': true,
    'auth_providers': ['basic'],
    'auth_flows': ['cookie', 'native_pkce'],
    'profiles': ['default', 'work', 'personal'],
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    if (!reachable) throw DioException.connectionError(requestOptions: o, reason: 'offline');
    switch ((o.method, o.uri.path)) {
      case ('GET', '/api/status'):
        return _json(200, status);
      case ('POST', '/auth/password-login'):
        logins++;
        final b = o.data as Map;
        if (b['provider'] != 'basic' || b['username'] != username || b['password'] != password) {
          return _json(401, {'detail': 'Invalid credentials'});
        }
        return _json(
          200,
          {'ok': true},
          headers: {
            'set-cookie': ['hermes_session=$sessionValue; Path=/; HttpOnly; SameSite=Lax'],
          },
        );
      case ('POST', '/api/auth/ws-ticket'):
        if (o.headers['cookie'] != 'hermes_session=$sessionValue') return _json(401, {'detail': 'Not authenticated'});
        return _json(200, {'ticket': 'ticket-${++tickets}'});
      case ('GET', '/api/model/info'):
        if (o.headers['cookie'] != 'hermes_session=$sessionValue') return _json(401, {'detail': 'Not authenticated'});
        final profile = o.uri.queryParameters['profile'] ?? 'default';
        return _json(200, {'model': profile == 'default' ? 'hermes-pro' : '$profile-model', 'provider': 'custom'});
      case ('POST', '/api/audio/transcribe'):
        if (o.headers['cookie'] != 'hermes_session=$sessionValue') return _json(401, {'detail': 'Not authenticated'});
        transcribeBodies.add(o.data as Map);
        return _json(200, {'ok': true, 'transcript': transcript, 'provider': 'local'});
      case ('POST', '/api/audio/speak'):
        if (o.headers['cookie'] != 'hermes_session=$sessionValue') return _json(401, {'detail': 'Not authenticated'});
        speakBodies.add(o.data as Map);
        if (speakFails) return _json(500, {'detail': 'tts down'});
        return _json(200, {'ok': true, 'audio': 'data:audio/mpeg;base64,AQID'});
    }
    return _json(404, {'detail': 'Not Found'});
  }

  ResponseBody _json(int code, Object body, {Map<String, List<String>> headers = const {}}) => ResponseBody.fromString(
    jsonEncode(body),
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );

  @override
  void close({bool force = false}) {}
}

HermesClient fakeClient(String url, CredentialStore store, FakeHermes server) =>
    HermesClient(url, store, dio: Dio()..httpClientAdapter = server);
