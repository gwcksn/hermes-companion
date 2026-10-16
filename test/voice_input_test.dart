import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/hermes_client.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/data/voice/recorder.dart';
import 'package:hermes_companion/data/voice/voice_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_hermes.dart';
import 'fakes/fake_recorder.dart';

const _url = 'https://bash.example.ts.net';

class _Rig {
  _Rig(SharedPreferences prefs) {
    c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        credentialStoreProvider.overrideWithValue(store),
        hermesClientFactoryProvider.overrideWithValue((url) => fakeClient(url, store, server)),
        recorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    c.listen(voiceInputProvider, (_, _) {});
  }

  final store = MemoryCredentialStore();
  final server = FakeHermes();
  final recorder = FakeRecorder();
  late final ProviderContainer c;

  VoiceState get state => c.read(voiceInputProvider);
  VoiceInput get ctl => c.read(voiceInputProvider.notifier);
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'settings.serverUrl': _url});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_Rig> signedIn() async {
    final r = _Rig(prefs);
    await r.store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    return r;
  }

  test('records, then returns the server transcript and sends base64 audio', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);

    await r.ctl.start();
    expect(r.state.phase, VoicePhase.recording);
    expect(r.recorder.started, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final text = await r.ctl.finish();
    expect(text, 'what is on my calendar');
    expect(r.server.transcribeBodies.single['mime_type'], 'audio/mp4');
    expect(r.server.transcribeBodies.single['data_url'], startsWith('data:audio/mp4;base64,'));
  });

  test('level events become waveform bars, capped at the bar count', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);
    await r.ctl.start();
    for (var i = 0; i < voiceBarCount + 5; i++) {
      r.recorder.emitLevel(1);
    }
    await _settle();
    expect(r.state.bars.length, voiceBarCount);
    expect(r.state.bars.last, 58);
  });

  test('a denied microphone ends in a clear error', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);
    r.recorder.permission = false;
    await r.ctl.start();
    expect(r.state.phase, VoicePhase.error);
    expect(r.state.error, contains('Microphone is blocked'));
    expect(r.recorder.started, isFalse);
  });

  test('a clip that is too short, or empty, is not sent', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);
    await r.ctl.start();
    expect(await r.ctl.finish(), isNull);
    expect(r.state.error, contains("didn't catch"));
    expect(r.server.transcribeBodies, isEmpty);
  });

  test('an empty transcript is reported, not sent as a message', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);
    r.server.transcript = '  ';
    await r.ctl.start();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(await r.ctl.finish(), isNull);
    expect(r.state.error, contains("didn't catch"));
  });

  test('server failure is mapped to a user-facing error', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);
    r.server.sessionValue = 's2'; // cookie no longer valid and re-login still works, so force offline instead
    r.server.reachable = false;
    await r.ctl.start();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(await r.ctl.finish(), isNull);
    expect(r.state.phase, VoicePhase.error);
    expect(r.state.error, isNotEmpty);
  });

  test('cancel discards the audio and returns to idle', () async {
    final r = await signedIn();
    addTearDown(r.c.dispose);
    await r.ctl.start();
    await r.ctl.cancel();
    expect(r.recorder.cancelled, isTrue);
    expect(r.state.phase, VoicePhase.idle);
    expect(r.server.transcribeBodies, isEmpty);
  });

  test('stops by itself at the maximum length', () {
    fakeAsync((async) {
      final r = _Rig(prefs);
      addTearDown(r.c.dispose);
      r.ctl.start();
      async.flushMicrotasks();
      expect(r.state.phase, VoicePhase.recording);
      async.elapse(voiceMaxLength + const Duration(seconds: 1));
      expect(r.state.phase, isNot(VoicePhase.recording));
    });
  });
}
