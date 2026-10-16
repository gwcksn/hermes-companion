import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'google_auth.dart';

/// Thrown when there is no usable Google session; the page shows the Connect state.
class GoogleSignedOut implements Exception {
  const GoogleSignedOut();
}

/// Calendar + Tasks REST calls. Returns raw JSON item lists so they can be cached as-is.
class GoogleWorkspaceClient {
  GoogleWorkspaceClient(this._auth, [Dio? dio])
    : _dio =
          dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));

  final GoogleAuth _auth;
  final Dio _dio;

  Future<List<Map<String, dynamic>>> events(DateTime timeMin, DateTime timeMax) =>
      _items('https://www.googleapis.com/calendar/v3/calendars/primary/events', {
        'singleEvents': true,
        'orderBy': 'startTime',
        'maxResults': 100,
        'timeMin': timeMin.toUtc().toIso8601String(),
        'timeMax': timeMax.toUtc().toIso8601String(),
      });

  Future<List<Map<String, dynamic>>> tasks() => _items('https://tasks.googleapis.com/tasks/v1/lists/@default/tasks', {
    'showCompleted': false,
    'showHidden': false,
    'maxResults': 100,
  });

  Future<void> completeTask(String id) =>
      _send('PATCH', 'https://tasks.googleapis.com/tasks/v1/lists/@default/tasks/$id', data: {'status': 'completed'});

  Future<List<Map<String, dynamic>>> _items(String url, Map<String, dynamic> query) async {
    final res = await _send('GET', url, query: query);
    return ((res.data?['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// Authorized request with one token refresh + retry on 401/403.
  Future<Response<Map<String, dynamic>>> _send(
    String method,
    String url, {
    Map<String, dynamic>? query,
    Object? data,
  }) async {
    var token = await _auth.accessToken();
    if (token == null) throw const GoogleSignedOut();
    for (var attempt = 0; ; attempt++) {
      try {
        return await _dio.request<Map<String, dynamic>>(
          url,
          data: data,
          queryParameters: query,
          options: Options(method: method, headers: {'Authorization': 'Bearer $token'}),
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if ((status == 401 || status == 403) && attempt == 0) {
          token = await _auth.accessToken(forceRefresh: true);
          if (token == null) throw const GoogleSignedOut();
          continue;
        }
        rethrow;
      }
    }
  }
}

final googleClientProvider = Provider<GoogleWorkspaceClient>(
  (ref) => GoogleWorkspaceClient(ref.watch(googleAuthProvider)),
);
