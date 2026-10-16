import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/avatar/avatar_controller.dart';
import 'package:hermes_companion/avatar/avatar_state.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/gateway/chat_controller.dart';
import 'package:hermes_companion/data/hermes_client.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/data/voice/player.dart';
import 'package:hermes_companion/data/voice/speak.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_audio_player.dart';
import 'fakes/fake_gateway.dart';
import 'fakes/fake_hermes.dart';

const _url = 'https://bash.example.ts.net';

class _Rig {
  _Rig(this.prefs);

  final SharedPreferences prefs;
  final store = MemoryCredentialStore();
  final server = FakeHermes();
  final gateway = FakeGateway();
  final player = FakeAudioPlayer();
  late ProviderContainer c;

  Future<void> start({bool readAloud = false}) async {
    await prefs.setString('settings.serverUrl', _url);
    await prefs.setBool('settings.setupComplete', true);
    await prefs.setBool('settings.readAloud', readAloud);
    await store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        credentialStoreProvider.overrideWithValue(store),
        hermesClientFactoryProvider.overrideWithValue((url) => fakeClient(url, store, server)),
        gatewayConnectorProvider.overrideWithValue(gateway.connect),
        audioPlayerProvider.overrideWithValue(player),
      ],
    );
    c.listen(chatProvider, (_, _) {});
    await settle();
  }

  AvatarState get avatar => c.read(avatarProvider);
  FakeGatewayConnection get conn => gateway.last;

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Real-time wait for async work the fakes finish on their own.
  Future<void> until(bool Function() ok, {String? why}) async {
    for (var i = 0; i < 300; i++) {
      if (ok()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('timed out waiting for ${why ?? 'condition'}');
  }

  void hermesReplies(String text) {
    conn.event('message.start', 'live-1');
    conn.event('message.delta', 'live-1', {'text': text});
    conn.event('message.complete', 'live-1', {'text': text, 'status': 'complete'});
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('speak response and speech text', () {
    test('a data URL, bare or inside a map, decodes to a clip', () {
      final bare = parseSpeakResponse('data:audio/mpeg;base64,AQID');
      expect(bare!.mimeType, 'audio/mpeg');
      expect(bare.bytes, [1, 2, 3]);
      expect(parseSpeakResponse({'ok': true, 'data_url': 'data:audio/wav;base64,AQID'})!.mimeType, 'audio/wav');
      expect(parseSpeakResponse({'audio': 'data:audio/ogg;codecs=opus;base64,AQID'})!.mimeType, 'audio/ogg');
    });

    test('anything else is rejected', () {
      expect(parseSpeakResponse(null), isNull);
      expect(parseSpeakResponse({'ok': false, 'audio': 'data:audio/mpeg;base64,AQID'}), isNull);
      expect(parseSpeakResponse('hello'), isNull);
      expect(parseSpeakResponse('data:audio/mpeg;base64,'), isNull);
    });

    test('markdown is reduced to plain speech', () {
      const md = '## Plan\n\n- **Rain** likely at [the lake](https://x.test/a) today\n\n```dart\nprint(1);\n```\nSee https://x.test now.';
      expect(speechText(md), 'Plan Rain likely at the lake today See now.');
    });

    test('long replies are cut at a sentence boundary', () {
      final long = List.filled(200, 'This is one sentence.').join(' ');
      final out = speechText(long);
      expect(out.length, lessThanOrEqualTo(1200));
      expect(out, endsWith('sentence.'));
    });
  });

  group('read aloud', () {
    test('off: a reply is not spoken', () async {
      final r = _Rig(prefs);
      await r.start();
      addTearDown(r.c.dispose);
      await r.c.read(chatProvider.notifier).send('hi');
      r.hermesReplies('Hello!');
      await r.settle();
      expect(r.server.speakBodies, isEmpty);
    });

    test('on: a reply is spoken and the avatar follows the audio', () async {
      final r = _Rig(prefs);
      await r.start(readAloud: true);
      addTearDown(r.c.dispose);
      await r.c.read(chatProvider.notifier).send('hi');
      r.conn.event('message.delta', 'live-1', {'text': 'Hello!'});
      await r.settle();
      expect(r.avatar, AvatarState.thinking);
      r.conn.event('message.complete', 'live-1', {'text': 'Hello!', 'status': 'complete'});
      await r.until(() => r.player.playing, why: 'playback');
      expect(r.server.speakBodies.single['text'], 'Hello!');
      expect(r.avatar, AvatarState.speaking);
      r.player.finish();
      await r.until(() => r.avatar != AvatarState.speaking, why: 'avatar settles');
    });

    test('a new reply cuts the one still playing', () async {
      final r = _Rig(prefs);
      await r.start(readAloud: true);
      addTearDown(r.c.dispose);
      await r.c.read(chatProvider.notifier).send('one');
      r.hermesReplies('First.');
      await r.until(() => r.player.played.length == 1, why: 'first clip');
      await r.c.read(chatProvider.notifier).send('two');
      r.hermesReplies('Second.');
      await r.until(() => r.player.played.length == 2, why: 'second clip');
      expect(r.server.speakBodies.map((b) => b['text']), ['First.', 'Second.']);
    });
  });
}
