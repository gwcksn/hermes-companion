// The companion's one ongoing conversation per profile, over the gateway WebSocket.
// Protocol: docs/hermes-protocol.md ("Realtime chat").
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/avatar_controller.dart';
import '../../avatar/avatar_state.dart';
import '../../avatar/reactions.dart';
import '../hermes_client.dart';
import '../settings_store.dart';
import '../voice/reply_speaker.dart';
import 'gateway_socket.dart';

enum ChatRole { user, hermes, note }

class ChatMessage {
  const ChatMessage(this.role, this.text, {this.streaming = false, this.error = false});

  final ChatRole role;
  final String text;
  final bool streaming;
  final bool error;

  ChatMessage copyWith({String? text, bool? streaming, bool? error}) =>
      ChatMessage(role, text ?? this.text, streaming: streaming ?? this.streaming, error: error ?? this.error);
}

class ApprovalPrompt {
  const ApprovalPrompt({required this.id, required this.command, required this.description, required this.choices});

  final String id;
  final String command;
  final String description;
  final List<String> choices;
}

class ClarifyQuestion {
  const ClarifyQuestion({required this.qid, required this.question, required this.choices});

  final String qid;
  final String question;
  final List<String> choices;
}

class ClarifyPrompt {
  const ClarifyPrompt({required this.id, required this.questions, this.answers = const {}});

  final String id;
  final List<ClarifyQuestion> questions;
  final Map<String, String?> answers;

  ClarifyQuestion? get current => questions.where((q) => !answers.containsKey(q.qid)).firstOrNull;
}

enum ChatPhase { idle, connecting, ready, offline }

class ChatState {
  const ChatState({
    this.phase = ChatPhase.idle,
    this.messages = const [],
    this.busy = false,
    this.activity,
    this.approval,
    this.clarify,
  });

  final ChatPhase phase;
  final List<ChatMessage> messages;

  /// A turn is running (send becomes stop).
  final bool busy;

  /// Short live status such as "Searching the web…".
  final String? activity;
  final ApprovalPrompt? approval;
  final ClarifyPrompt? clarify;

  ChatState copyWith({
    ChatPhase? phase,
    List<ChatMessage>? messages,
    bool? busy,
    String? Function()? activity,
    ApprovalPrompt? Function()? approval,
    ClarifyPrompt? Function()? clarify,
  }) => ChatState(
    phase: phase ?? this.phase,
    messages: messages ?? this.messages,
    busy: busy ?? this.busy,
    activity: activity != null ? activity() : this.activity,
    approval: approval != null ? approval() : this.approval,
    clarify: clarify != null ? clarify() : this.clarify,
  );
}

/// Tool names that read as "looking something up" get the searching avatar.
bool isSearchTool(String name) =>
    RegExp(r'search|web|browse|fetch|crawl|lookup|extract', caseSensitive: false).hasMatch(name);

const _historyLimit = 40;

class ChatController extends Notifier<ChatState> {
  GatewaySocket? _socket;
  String? _sessionId; // live runtime id
  String? _storedId; // durable id, persisted per server+profile
  Timer? _retry;
  Timer? _settle;
  int _attempt = 0;
  bool _disposed = false;
  int _generation = 0;

  HermesClient? get _client => ref.read(hermesClientProvider);
  String get _profile => ref.read(settingsProvider).profile;
  bool get _speakAloud => ref.read(settingsProvider).readAloud;

  String get _sessionKey => 'chat.session.${ref.read(settingsProvider).serverUrl}|$_profile';

  @override
  ChatState build() {
    ref.watch(hermesClientProvider);
    ref.watch(settingsProvider.select((s) => s.profile));
    final generation = ++_generation;
    _disposed = false;
    _storedId = null; // profile or server may have changed
    _attempt = 0;
    ref.onDispose(() {
      _disposed = true;
      _retry?.cancel();
      _settle?.cancel();
      _socket?.close();
      _socket = null;
      _sessionId = null;
    });
    if (_client == null) return const ChatState();
    Future.microtask(() {
      if (generation == _generation) connect();
    });
    return const ChatState(phase: ChatPhase.connecting);
  }

  // ── connection ────────────────────────────────────────────────────────────────

  Future<void> connect() async {
    final client = _client;
    if (client == null || _disposed) return;
    _retry?.cancel();
    final generation = _generation;
    state = state.copyWith(phase: ChatPhase.connecting);
    try {
      final ticket = await client.mintWsTicket();
      final socket = await GatewaySocket.open(client.gatewayUri(ticket), connector: ref.read(gatewayConnectorProvider));
      if (_disposed || generation != _generation) return await socket.close();
      _socket = socket;
      socket.events.listen(_onEvent);
      socket.serverRequests.listen(_onServerRequest);
      socket.closed.then((_) => _onSocketClosed(socket));
      // Without this, approvals/clarify for our session fail fast server-side.
      await socket.rpc('client.capabilities', {'server_requests': true}).catchError((_) => null);
      await _openSession(socket);
      _attempt = 0;
      state = state.copyWith(phase: ChatPhase.ready);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(phase: ChatPhase.offline, busy: false, activity: () => null);
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    final seconds = math.min(60, 2 << math.min(_attempt++, 5)); // 2, 4, 8 … 60 s
    _retry = Timer(Duration(seconds: seconds), connect);
  }

  void _onSocketClosed(GatewaySocket socket) {
    if (_disposed || socket != _socket) return;
    _socket = null;
    _sessionId = null;
    state = state.copyWith(
      phase: ChatPhase.offline,
      busy: false,
      activity: () => null,
      approval: () => null,
      clarify: () => null,
    );
    _avatar(AvatarState.idle);
    _scheduleRetry();
  }

  /// Resume the stored companion session for this profile, or create one.
  Future<void> _openSession(GatewaySocket socket) async {
    final prefs = ref.read(sharedPrefsProvider);
    _storedId ??= prefs.getString(_sessionKey);
    Map? result;
    if (_storedId != null) {
      try {
        result = await socket.rpc('session.resume', {
          'session_id': _storedId,
          ...profileQuery(_profile),
          'cols': 96,
          'source': 'desktop',
          'inline_images': false,
        }, const Duration(seconds: 60)) as Map?;
      } on RpcError {
        result = null; // deleted or unknown: start fresh
      }
    }
    result ??= await socket.rpc('session.create', {
      ...profileQuery(_profile),
      'cols': 96,
      'source': 'desktop',
      'title': 'Companion',
    }) as Map?;
    if (result == null) throw const RpcError(-3, 'no session');
    _sessionId = result['session_id'] as String?;
    final stored = result['stored_session_id'] as String?;
    if (stored != null && stored.isNotEmpty) {
      _storedId = stored;
      await prefs.setString(_sessionKey, stored);
    }
    final history = <ChatMessage>[];
    for (final m in (result['messages'] as List?) ?? const []) {
      if (m is! Map) continue;
      final text = (m['text'] ?? (m['content'] is String ? m['content'] : null)) as String?;
      if (text == null || text.trim().isEmpty || m['display_kind'] == 'hidden') continue;
      final role = switch (m['role']) {
        'user' => ChatRole.user,
        'assistant' => ChatRole.hermes,
        _ => null,
      };
      if (role != null) history.add(ChatMessage(role, text.trim()));
    }
    final kept = history.length > _historyLimit ? history.sublist(history.length - _historyLimit) : history;
    state = state.copyWith(messages: kept);
  }

  // ── user actions ──────────────────────────────────────────────────────────────

  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty) return;
    _friendlyTurn = isFriendlyMessage(text);

    // A pending clarify question takes typed text as its answer.
    if (state.clarify?.current != null) return answerClarify(text);

    final socket = _socket;
    _append(ChatMessage(ChatRole.user, text));
    if (socket == null || _sessionId == null) {
      _append(const ChatMessage(ChatRole.note, 'Not connected. Will reconnect shortly.', error: true));
      return;
    }
    state = state.copyWith(busy: true, activity: () => null);
    _ensureStreamingBubble();
    _avatar(AvatarState.thinking);
    try {
      await socket.rpc('prompt.submit', {'session_id': _sessionId, 'text': text}, const Duration(minutes: 3));
    } on RpcError catch (e) {
      state = state.copyWith(busy: false);
      _append(ChatMessage(ChatRole.note, 'Could not send: ${e.message}', error: true));
      _avatar(AvatarState.oops);
      _settleToIdle();
    }
  }

  Future<void> stop() async {
    final socket = _socket;
    if (socket == null || _sessionId == null) return;
    await socket.rpc('session.interrupt', {'session_id': _sessionId}).catchError((_) => null);
  }

  void answerApproval(String choice) {
    final a = state.approval;
    if (a == null) return;
    _socket?.reply(a.id, result: {'choice': choice});
    state = state.copyWith(approval: () => null);
    if (choice == 'deny') {
      _avatar(AvatarState.thinking);
    } else {
      state = state.copyWith(activity: () => 'Working on it…');
      _avatar(AvatarState.working);
    }
  }

  Future<void> answerClarify(String? answer) async {
    final c = state.clarify;
    final q = c?.current;
    if (c == null || q == null) return;
    if (answer != null) _append(ChatMessage(ChatRole.user, answer));
    final next = ClarifyPrompt(id: c.id, questions: c.questions, answers: {...c.answers, q.qid: answer});
    if (next.current == null) {
      _socket?.reply(c.id, result: {'answers': next.answers});
      state = state.copyWith(clarify: () => null);
    } else {
      state = state.copyWith(clarify: () => next);
    }
  }

  /// Skips all remaining clarify questions (a reply without answers is cancel-all).
  void skipClarify() {
    final c = state.clarify;
    if (c == null) return;
    _socket?.reply(c.id, result: {});
    state = state.copyWith(clarify: () => null);
  }

  // ── inbound ───────────────────────────────────────────────────────────────────

  void _onEvent(GatewayEvent e) {
    if (e.type == 'request.cancel') return _onRequestCancel(e.payload);
    if (e.type == 'session.reclaimed') {
      // The live session was reaped; reattach by stored id.
      final socket = _socket;
      _sessionId = null;
      if (socket != null) _openSession(socket).catchError((_) => socket.close());
      return;
    }
    if (_sessionId == null || e.sessionId != _sessionId) return;

    switch (e.type) {
      case 'message.start':
        _settle?.cancel();
        _ensureStreamingBubble();
        state = state.copyWith(busy: true);
        _avatar(AvatarState.thinking);
      case 'thinking.delta' || 'reasoning.delta' || 'reasoning.available':
        _avatar(AvatarState.thinking);
      case 'tool.start' || 'tool.generating':
        final name = e.payload['name'] as String? ?? '';
        final search = isSearchTool(name);
        state = state.copyWith(activity: () => search ? 'Looking it up…' : 'Working on it…');
        _avatar(search ? AvatarState.searching : AvatarState.working);
      case 'tool.complete':
        state = state.copyWith(activity: () => null);
        _avatar(AvatarState.thinking);
      case 'message.delta':
        final text = e.payload['text'] as String? ?? '';
        if (text.isEmpty) return;
        _ensureStreamingBubble();
        _updateLast((m) => m.copyWith(text: m.text + text));
        state = state.copyWith(activity: () => null);
        // With voice on, the avatar speaks when the audio does (ReplySpeaker), not as text streams.
        _avatar(_speakAloud ? AvatarState.thinking : AvatarState.speaking);
      case 'message.interim':
        final text = e.payload['text'] as String? ?? '';
        if (text.isEmpty || e.payload['already_streamed'] == true) return;
        _ensureStreamingBubble();
        _updateLast((m) => m.copyWith(text: m.text.isEmpty ? text : '${m.text}\n\n$text'));
      case 'message.complete':
        _finishTurn(e.payload);
      case 'error':
        _append(
          ChatMessage(ChatRole.note, e.payload['message'] as String? ?? 'Hermes reported an error.', error: true),
        );
        _endTurn(AvatarState.oops);
    }
  }

  void _finishTurn(Map<String, dynamic> p) {
    final text = p['text'];
    final status = p['status'] as String? ?? 'complete';
    final last = state.messages.lastOrNull;
    String? reply; // this turn's final text, for reading aloud
    if (last != null && last.role == ChatRole.hermes && last.streaming) {
      _updateLast(
        (m) =>
            m.copyWith(text: text is String && text.trim().isNotEmpty ? text.trim() : m.text.trim(), streaming: false),
      );
      final done = state.messages.last.text;
      if (done.isEmpty) {
        state = state.copyWith(messages: [...state.messages]..removeLast());
      } else {
        reply = done;
      }
    } else if (text is String && text.trim().isNotEmpty) {
      _append(ChatMessage(ChatRole.hermes, text.trim()));
      reply = text.trim();
    }
    if (status == 'complete' && reply != null && _speakAloud) {
      unawaited(ref.read(replySpeakerProvider.notifier).speak(reply));
    }
    switch (status) {
      case 'error':
        final warning = p['warning'] as String?;
        _append(ChatMessage(ChatRole.note, warning ?? 'The turn ended with an error.', error: true));
        _endTurn(AvatarState.oops);
      case 'interrupted':
        _endTurn(AvatarState.idle);
      default:
        _endTurn(_friendlyTurn ? AvatarState.happy : AvatarState.done);
    }
    _friendlyTurn = false;
  }

  void _endTurn(AvatarState avatar) {
    state = state.copyWith(busy: false, activity: () => null);
    _avatar(avatar);
    if (avatar != AvatarState.idle) _settleToIdle();
  }

  /// The user's last message was a greeting or thanks: finish the turn happy instead of just done.
  var _friendlyTurn = false;

  void _settleToIdle() {
    _settle?.cancel();
    _settle = Timer(const Duration(seconds: 3), () {
      if (_disposed || state.busy) return;
      // A reply being read aloud owns the avatar until its audio ends.
      if (ref.read(replySpeakerProvider) == SpeakerPhase.playing) return;
      _avatar(AvatarState.idle);
    });
  }

  void _onServerRequest(ServerRequest r) {
    switch (r.method) {
      case 'approval':
        final choices = [
          for (final c in (r.params['choices'] as List?) ?? const [])
            if (c is String) c,
        ];
        state = state.copyWith(
          approval: () => ApprovalPrompt(
            id: r.id,
            command: r.params['command'] as String? ?? '',
            description: r.params['description'] as String? ?? '',
            choices: choices.isEmpty ? const ['once', 'deny'] : choices,
          ),
        );
        _avatar(AvatarState.alarm);
      case 'clarify':
        final qs = [
          for (final q in (r.params['questions'] as List?) ?? const [])
            if (q is Map)
              ClarifyQuestion(
                qid: '${q['qid']}',
                question: q['question'] as String? ?? '',
                choices: [
                  for (final c in (q['choices'] as List?) ?? const [])
                    if (c is String) c,
                ],
              ),
        ];
        if (qs.isEmpty) return _socket?.reply(r.id, result: {});
        final replayed = (r.params['answers'] as Map?)?.cast<String, String?>() ?? const {};
        state = state.copyWith(
          clarify: () => ClarifyPrompt(id: r.id, questions: qs, answers: replayed),
        );
        _avatar(AvatarState.thinking);
      default:
        // sudo, secrets, vault, desktop bridges: not something a bedside screen should answer.
        _socket?.reply(r.id, error: const RpcError(-32601, 'not supported by the companion'));
    }
  }

  void _onRequestCancel(Map<String, dynamic> p) {
    final id = p['id'] as String?;
    if (id == null) return;
    if (state.approval?.id == id) state = state.copyWith(approval: () => null);
    if (state.clarify?.id == id) state = state.copyWith(clarify: () => null);
  }

  // ── helpers ───────────────────────────────────────────────────────────────────

  void _avatar(AvatarState s) {
    if (!_disposed) ref.read(avatarProvider.notifier).set(s);
  }

  void _append(ChatMessage m) => state = state.copyWith(messages: [...state.messages, m]);

  void _ensureStreamingBubble() {
    final last = state.messages.lastOrNull;
    if (last == null || last.role != ChatRole.hermes || !last.streaming) {
      _append(const ChatMessage(ChatRole.hermes, '', streaming: true));
    }
  }

  void _updateLast(ChatMessage Function(ChatMessage) f) {
    final list = [...state.messages];
    list[list.length - 1] = f(list.last);
    state = state.copyWith(messages: list);
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);

/// Test seam: the WebSocket connector used by [ChatController].
final gatewayConnectorProvider = Provider<GatewayConnector>((ref) => connectIoGateway);
