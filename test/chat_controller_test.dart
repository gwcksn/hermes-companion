import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/avatar/avatar_controller.dart';
import 'package:hermes_companion/avatar/avatar_state.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/gateway/chat_controller.dart';
import 'package:hermes_companion/data/hermes_client.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/pet/pet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_gateway.dart';
import 'fakes/fake_hermes.dart';

const _url = 'https://bash.example.ts.net';

class _Rig {
  _Rig(this.prefs, {this.profile = 'default'});

  final SharedPreferences prefs;
  final String profile;
  final store = MemoryCredentialStore();
  final server = FakeHermes();
  final gateway = FakeGateway();
  late ProviderContainer c;

  Future<void> start() async {
    await prefs.setString('settings.serverUrl', _url);
    await prefs.setString('settings.profile', profile);
    await prefs.setBool('settings.setupComplete', true);
    await store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        credentialStoreProvider.overrideWithValue(store),
        hermesClientFactoryProvider.overrideWithValue((url) => fakeClient(url, store, server)),
        gatewayConnectorProvider.overrideWithValue(gateway.connect),
      ],
    );
    c.listen(chatProvider, (_, _) {});
    await settle();
  }

  ChatState get chat => c.read(chatProvider);
  ChatController get ctl => c.read(chatProvider.notifier);
  AvatarState get avatar => c.read(avatarProvider);

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('connects with a fresh ticket, advertises server requests, creates and stores a session', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);

    expect(r.chat.phase, ChatPhase.ready);
    expect(r.gateway.uris.single.toString(), 'wss://bash.example.ts.net/api/ws?ticket=ticket-1');
    final conn = r.gateway.last;
    expect(conn.methods.take(2), ['client.capabilities', 'session.create']);
    expect(conn.request('client.capabilities')['params'], {'server_requests': true});
    expect(
      (conn.request('session.create')['params'] as Map).containsKey('profile'),
      isFalse,
      reason: 'default omits profile',
    );
    expect(prefs.getString('chat.session.$_url|default'), 'stored-1');
  });

  test('a restart resumes the stored session and shows its history', () async {
    final first = _Rig(prefs);
    await first.start();
    first.gateway.stored['stored-1'] = [
      {'role': 'user', 'text': 'hi'},
      {'role': 'assistant', 'text': 'Hello Gilang!'},
      {'role': 'tool', 'text': 'ignored'},
    ];
    final gateway = first.gateway;
    first.c.dispose();

    final second = _Rig(prefs)..gateway.stored.addAll(gateway.stored);
    await second.start();
    addTearDown(second.c.dispose);
    final resume = second.gateway.last.request('session.resume')['params'] as Map;
    expect(resume['session_id'], 'stored-1');
    expect(second.chat.messages.map((m) => (m.role, m.text)), [
      (ChatRole.user, 'hi'),
      (ChatRole.hermes, 'Hello Gilang!'),
    ]);
  });

  test('named profile is sent and gets its own stored session', () async {
    final r = _Rig(prefs, profile: 'crawly');
    await r.start();
    addTearDown(r.c.dispose);
    expect((r.gateway.last.request('session.create')['params'] as Map)['profile'], 'crawly');
    expect(prefs.getString('chat.session.$_url|crawly'), 'stored-1');
  });

  test('a full turn streams into one bubble and drives the avatar', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    final conn = r.gateway.last;

    await r.ctl.send('weather tomorrow?');
    expect(conn.request('prompt.submit')['params'], {'session_id': 'live-1', 'text': 'weather tomorrow?'});
    expect(r.chat.busy, isTrue);
    expect(r.avatar, AvatarState.thinking);
    expect(r.chat.messages.last.streaming, isTrue);
    expect(r.chat.messages.last.text, isEmpty);

    conn.event('message.start', 'live-1');
    conn.event('tool.start', 'live-1', {'tool_id': 't1', 'name': 'web_search'});
    await r.settle();
    expect(r.avatar, AvatarState.searching);
    expect(r.chat.activity, 'Looking it up…');
    expect(r.chat.messages.last.text, isEmpty);

    conn.event('tool.complete', 'live-1', {'tool_id': 't1', 'name': 'web_search', 'result': 'ok'});
    conn.event('tool.start', 'live-1', {'tool_id': 't2', 'name': 'terminal'});
    await r.settle();
    expect(r.avatar, AvatarState.working);
    expect(r.chat.activity, 'Working on it…');

    conn.event('message.delta', 'live-1', {'text': 'Rain '});
    conn.event('message.delta', 'live-1', {'text': 'likely.'});
    await r.settle();
    expect(r.avatar, AvatarState.speaking);
    expect(r.chat.messages.last.text, 'Rain likely.');
    expect(r.chat.messages.last.streaming, isTrue);

    conn.event('message.delta', 'other-session', {'text': 'NOT MINE'});
    conn.event('message.complete', 'live-1', {'text': 'Rain likely tomorrow.', 'status': 'complete'});
    await r.settle();
    expect(r.chat.messages.map((m) => (m.role, m.text)), [
      (ChatRole.user, 'weather tomorrow?'),
      (ChatRole.hermes, 'Rain likely tomorrow.'),
    ]);
    expect(r.chat.busy, isFalse);
    expect(r.avatar, AvatarState.done);
  });

  test('a thank-you message ends the turn happy instead of done', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    await r.ctl.send('thanks, that was great!');
    r.gateway.last.event('message.complete', 'live-1', {'text': 'Anytime!', 'status': 'complete'});
    await r.settle();
    expect(r.avatar, AvatarState.happy);

    await r.ctl.send('what is the weather?');
    r.gateway.last.event('message.complete', 'live-1', {'text': 'Sunny.', 'status': 'complete'});
    await r.settle();
    expect(r.avatar, AvatarState.done);
  });

  test('chat turns feed the pet', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    final start = r.c.read(petProvider);
    await r.ctl.send('thanks, that was great!');
    expect(r.c.read(petProvider).mood, closeTo(start.mood + 4, 0.01));
    expect(r.c.read(petProvider).curiosity, closeTo(start.curiosity + 5, 0.01));
    r.gateway.last.event('message.complete', 'live-1', {
      'text': 'Anytime!',
      'status': 'complete',
    });
    await r.settle();
    expect(r.c.read(petProvider).mood, closeTo(start.mood + 4 + 2 + 10, 0.01));
  });

  test('turn errors show a note and the oops avatar', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    await r.ctl.send('hi');
    r.gateway.last.event('message.complete', 'live-1', {
      'text': '',
      'status': 'error',
      'warning': 'Provider quota exceeded',
    });
    await r.settle();
    expect(r.chat.messages.last.text, 'Provider quota exceeded');
    expect(r.chat.messages.last.error, isTrue);
    expect(r.avatar, AvatarState.oops);
  });

  test('stop interrupts the running turn', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    await r.ctl.send('long task');
    await r.ctl.stop();
    expect(r.gateway.last.request('session.interrupt')['params'], {'session_id': 'live-1'});
  });

  test('approval: card appears, Allow once answers the server request', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    final conn = r.gateway.last;
    conn.serverRequest('req-9', 'approval', {
      'session_id': 'live-1',
      'request_id': 'a1',
      'command': 'rm -rf ~/tmp/cache',
      'description': 'delete cache',
      'choices': ['once', 'session', 'always', 'deny'],
    });
    await r.settle();
    expect(r.chat.approval?.command, 'rm -rf ~/tmp/cache');
    expect(r.avatar, AvatarState.alarm);

    r.ctl.answerApproval('once');
    expect(conn.replies.single, {
      'jsonrpc': '2.0',
      'id': 'req-9',
      'result': {'choice': 'once'},
    });
    expect(r.chat.approval, isNull);
  });

  test('approval withdrawn by the server clears the card', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    final conn = r.gateway.last;
    conn.serverRequest('req-1', 'approval', {'session_id': 'live-1', 'request_id': 'a1', 'command': 'ls'});
    conn.event('request.cancel', 'live-1', {'id': 'req-1', 'method': 'approval', 'reason': 'interrupt'});
    await r.settle();
    expect(r.chat.approval, isNull);
    expect(conn.replies, isEmpty);
  });

  test('clarify: choices and typed answers fill the set, then reply once', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    final conn = r.gateway.last;
    conn.serverRequest('req-2', 'clarify', {
      'session_id': 'live-1',
      'questions': [
        {
          'qid': 'q1',
          'question': 'Which city?',
          'choices': ['Yogyakarta', 'Jakarta'],
        },
        {'qid': 'q2', 'question': 'Any time?'},
      ],
    });
    await r.settle();
    expect(r.chat.clarify?.current?.question, 'Which city?');

    await r.ctl.answerClarify('Yogyakarta');
    expect(r.chat.clarify?.current?.question, 'Any time?');
    await r.ctl.send('after 5pm'); // typed text answers the open question
    expect(conn.replies.single['result'], {
      'answers': {'q1': 'Yogyakarta', 'q2': 'after 5pm'},
    });
    expect(conn.methods, isNot(contains('prompt.submit')));
    expect(r.chat.clarify, isNull);
  });

  test('requests the companion cannot handle are declined with -32601', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    r.gateway.last.serverRequest('req-3', 'sudo', {'session_id': 'live-1', 'command': 'apt upgrade'});
    await r.settle();
    expect((r.gateway.last.replies.single['error'] as Map)['code'], -32601);
  });

  test('a dropped socket goes offline and reconnects with a new ticket', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    r.gateway.last.drop();
    await r.settle();
    expect(r.chat.phase, ChatPhase.offline);

    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100)); // first backoff step
    await r.settle();
    expect(r.chat.phase, ChatPhase.ready);
    expect(r.gateway.uris.last.queryParameters['ticket'], 'ticket-2');
    expect(r.gateway.last.request('session.resume')['params']['session_id'], 'stored-1');
  });

  test('/new starts a fresh session without prompting the server', () async {
    final r = _Rig(prefs);
    await r.start();
    addTearDown(r.c.dispose);
    final conn = r.gateway.last;
    final firstStored = prefs.getString(
      'chat.session.$_url|default',
    );

    await r.ctl.send('hello');
    expect(r.chat.messages, isNotEmpty);
    await r.ctl.send('/new');
    await r.settle();

    expect(r.chat.messages, isEmpty);
    expect(conn.methods.where((m) => m == 'prompt.submit').length, 1);
    expect(conn.methods, containsAllInOrder(['session.close', 'session.create']));
    final fresh = prefs.getString('chat.session.$_url|default');
    expect(fresh, isNotNull);
    expect(fresh, isNot(firstStored));
  });
}
