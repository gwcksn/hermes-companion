// JSON-RPC 2.0 over the Hermes gateway WebSocket (/api/ws). See docs/hermes-protocol.md.
//
// Three inbound frame kinds:
//   - responses to our requests: int `id`, `result` | `error`
//   - events: `method: "event"`, `params: {type, session_id, payload}`
//   - server→client requests: string `id` + `method` (approval, clarify, …), answered with [reply]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal duplex text channel, so tests can stand in for a real socket.
abstract class GatewayTransport {
  Stream<String> get incoming;
  void send(String frame);
  Future<void> close();
}

class _IoTransport implements GatewayTransport {
  _IoTransport(this._ws);

  final WebSocket _ws;

  @override
  Stream<String> get incoming => _ws.where((m) => m is String).cast<String>();

  @override
  void send(String frame) => _ws.add(frame);

  @override
  Future<void> close() => _ws.close();
}

typedef GatewayConnector = Future<GatewayTransport> Function(Uri uri);

Future<GatewayTransport> connectIoGateway(Uri uri) async =>
    _IoTransport(await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 15)));

class RpcError implements Exception {
  const RpcError(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'RpcError($code, $message)';
}

class GatewayEvent {
  const GatewayEvent(this.type, this.sessionId, this.payload);

  final String type;
  final String sessionId;
  final Map<String, dynamic> payload;
}

class ServerRequest {
  const ServerRequest(this.id, this.method, this.params);

  final String id;
  final String method;
  final Map<String, dynamic> params;
}

class GatewaySocket {
  GatewaySocket._(this._transport) {
    _sub = _transport.incoming.listen(_onFrame, onDone: _onDone, onError: (_) => _onDone());
  }

  /// Opens the socket and waits for `gateway.ready`.
  static Future<GatewaySocket> open(Uri uri, {GatewayConnector connector = connectIoGateway}) async {
    final socket = GatewaySocket._(await connector(uri));
    try {
      await socket._ready.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      await socket.close();
      rethrow;
    }
    socket._startHeartbeat();
    return socket;
  }

  static const heartbeatEvery = Duration(seconds: 15);
  static const deadAfter = Duration(seconds: 45);
  static const requestTimeout = Duration(seconds: 30);

  final GatewayTransport _transport;
  late final StreamSubscription<String> _sub;
  final _ready = Completer<void>();
  final _pending = <int, Completer<Object?>>{};
  final _events = StreamController<GatewayEvent>.broadcast();
  final _requests = StreamController<ServerRequest>.broadcast();
  final _closed = Completer<void>();
  int _nextId = 1;
  Timer? _heartbeat;
  DateTime _lastInbound = DateTime.now();

  Stream<GatewayEvent> get events => _events.stream;
  Stream<ServerRequest> get serverRequests => _requests.stream;

  /// Completes when the socket closes for any reason.
  Future<void> get closed => _closed.future;
  bool get isOpen => !_closed.isCompleted;

  Future<Object?> rpc(String method, [Map<String, dynamic>? params, Duration timeout = requestTimeout]) {
    if (!isOpen) return Future.error(const RpcError(-1, 'not connected'));
    final id = _nextId++;
    final done = Completer<Object?>();
    _pending[id] = done;
    _transport.send(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': ?params}));
    return done.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw RpcError(-2, '$method timed out');
      },
    );
  }

  /// Answers a server→client request with a result, or with an error when [error] is set.
  void reply(String id, {Object? result, RpcError? error}) {
    if (!isOpen) return;
    _transport.send(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        if (error != null) 'error': {'code': error.code, 'message': error.message} else 'result': result ?? {},
      }),
    );
  }

  Future<void> close() async {
    _heartbeat?.cancel();
    await _sub.cancel();
    await _transport.close();
    _onDone();
  }

  void _startHeartbeat() {
    _heartbeat = Timer.periodic(heartbeatEvery, (_) {
      if (DateTime.now().difference(_lastInbound) > deadAfter) {
        close();
        return;
      }
      rpc('gateway.ping', null, deadAfter).ignore();
    });
  }

  void _onFrame(String raw) {
    _lastInbound = DateTime.now();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final id = decoded['id'];
    final method = decoded['method'];

    if (method == 'event') {
      final p = decoded['params'];
      if (p is! Map<String, dynamic>) return;
      final type = p['type'] as String? ?? '';
      if (type == 'gateway.ready' && !_ready.isCompleted) _ready.complete();
      _events.add(
        GatewayEvent(type, p['session_id'] as String? ?? '', (p['payload'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
      return;
    }
    if (method is String && id is String) {
      _requests.add(ServerRequest(id, method, (decoded['params'] as Map?)?.cast<String, dynamic>() ?? {}));
      return;
    }
    if (id is int) {
      final done = _pending.remove(id);
      if (done == null) return;
      final err = decoded['error'];
      if (err is Map) {
        done.completeError(RpcError((err['code'] as num?)?.toInt() ?? 0, err['message'] as String? ?? 'error'));
      } else {
        done.complete(decoded['result']);
      }
    }
  }

  void _onDone() {
    if (_closed.isCompleted) return;
    _heartbeat?.cancel();
    for (final p in _pending.values) {
      p.completeError(const RpcError(-1, 'connection closed'));
    }
    _pending.clear();
    if (!_ready.isCompleted) _ready.completeError(const RpcError(-1, 'closed before ready'));
    _closed.complete();
    _events.close();
    _requests.close();
  }
}
