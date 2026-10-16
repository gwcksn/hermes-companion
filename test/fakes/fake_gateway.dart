import 'dart:async';
import 'dart:convert';

import 'package:hermes_companion/data/gateway/gateway_socket.dart';

/// A scripted Hermes gateway on the other end of /api/ws.
class FakeGateway {
  final connections = <FakeGatewayConnection>[];
  final uris = <Uri>[];

  /// Stored sessions by stored id → transcript rows.
  final stored = <String, List<Map<String, Object?>>>{};
  int _sessions = 0;

  FakeGatewayConnection get last => connections.last;

  Future<GatewayTransport> connect(Uri uri) async {
    uris.add(uri);
    final c = FakeGatewayConnection(this);
    connections.add(c);
    scheduleMicrotask(
      () => c.event('gateway.ready', '', {'skin': {}, 'change_events': true, 'replay_epoch': 'e1', 'heartbeat': true}),
    );
    return c;
  }

  Map<String, Object?> _newSession() {
    final n = ++_sessions;
    stored['stored-$n'] = [];
    return {'session_id': 'live-$n', 'stored_session_id': 'stored-$n', 'message_count': 0, 'messages': [], 'info': {}};
  }
}

class FakeGatewayConnection implements GatewayTransport {
  FakeGatewayConnection(this.gateway);

  final FakeGateway gateway;
  final _out = StreamController<String>();
  final requests = <Map<String, dynamic>>[];
  final replies = <Map<String, dynamic>>[];
  bool closed = false;

  Iterable<String> get methods => requests.map((r) => r['method'] as String);
  Map<String, dynamic> request(String method) => requests.lastWhere((r) => r['method'] == method);

  @override
  Stream<String> get incoming => _out.stream;

  @override
  void send(String frame) {
    final m = jsonDecode(frame) as Map<String, dynamic>;
    if (m.containsKey('method')) {
      requests.add(m);
      _answer(m);
    } else {
      replies.add(m);
    }
  }

  void _answer(Map<String, dynamic> m) {
    final id = m['id'];
    final p = (m['params'] as Map?)?.cast<String, dynamic>() ?? {};
    Object? result;
    Map<String, Object>? error;
    switch (m['method']) {
      case 'client.capabilities':
        result = {
          'server_requests': ['approval', 'clarify'],
          'declines_not_shown': false,
        };
      case 'gateway.ping':
        result = {'ok': true};
      case 'session.create':
        result = gateway._newSession();
      case 'session.resume':
        final rows = gateway.stored[p['session_id']];
        if (rows == null) {
          error = {'code': 4004, 'message': 'session not found'};
        } else {
          result = {'session_id': 'live-resumed', 'stored_session_id': p['session_id'], 'messages': rows};
        }
      case 'prompt.submit':
        result = {'status': 'streaming'};
      case 'session.interrupt':
        result = {'status': 'interrupted'};
      default:
        error = {'code': -32601, 'message': 'unknown'};
    }
    scheduleMicrotask(() {
      if (closed) return;
      _out.add(jsonEncode({'jsonrpc': '2.0', 'id': id, if (error != null) 'error': error else 'result': result}));
    });
  }

  void event(String type, String sessionId, [Map<String, Object?>? payload]) => _out.add(
    jsonEncode({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {'type': type, 'session_id': sessionId, 'payload': ?payload},
    }),
  );

  void serverRequest(String id, String method, Map<String, Object?> params) =>
      _out.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));

  /// Simulates the server dropping the socket.
  void drop() {
    closed = true;
    _out.close();
  }

  @override
  Future<void> close() async {
    if (!closed) drop();
  }
}
