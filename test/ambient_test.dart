import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/avatar/avatar_controller.dart';
import 'package:hermes_companion/avatar/avatar_state.dart';
import 'package:hermes_companion/avatar/reactions.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/gateway/chat_controller.dart';
import 'package:hermes_companion/data/hermes_client.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/layout/ambient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_gateway.dart';
import 'fakes/fake_hermes.dart';

ProviderContainer _container(SharedPreferences prefs) {
  final store = MemoryCredentialStore();
  final server = FakeHermes();
  final gateway = FakeGateway();
  return ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      credentialStoreProvider.overrideWithValue(store),
      hermesClientFactoryProvider.overrideWithValue((url) => fakeClient(url, store, server)),
      gatewayConnectorProvider.overrideWithValue(gateway.connect),
    ],
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('isNightWib covers 22:00 to 06:00', () {
    expect(isNightWib(DateTime(2026, 1, 1, 21, 59)), isFalse);
    expect(isNightWib(DateTime(2026, 1, 1, 22)), isTrue);
    expect(isNightWib(DateTime(2026, 1, 1, 5, 59)), isTrue);
    expect(isNightWib(DateTime(2026, 1, 1, 6)), isFalse);
    expect(isNightWib(DateTime(2026, 1, 1, 12)), isFalse);
  });

  test('pixelShiftFor stays within 2px and repeats', () {
    for (var i = 0; i < 40; i++) {
      final o = pixelShiftFor(i);
      expect(o.dx.abs(), lessThanOrEqualTo(2));
      expect(o.dy.abs(), lessThanOrEqualTo(2));
    }
    expect(pixelShiftFor(0), Offset.zero);
    expect(pixelShiftFor(9), pixelShiftFor(0));
  });

  test('dimOpacityFor respects the setting, night and sleep', () {
    expect(dimOpacityFor(dimEnabled: false, night: true, asleep: true), 0);
    expect(dimOpacityFor(dimEnabled: true, night: false, asleep: false), 0);
    expect(dimOpacityFor(dimEnabled: true, night: true, asleep: false), nightDimOpacity);
    expect(dimOpacityFor(dimEnabled: true, night: false, asleep: true), sleepDimOpacity);
  });

  test('sleeps after idle, wakes on poke, and advances the pixel shift', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      async.elapse(const Duration(minutes: 3));
      expect(c.read(ambientProvider).shift, pixelShiftFor(1));

      async.elapse(sleepAfter);
      expect(c.read(ambientProvider).asleep, isTrue);
      expect(c.read(avatarProvider), AvatarState.sleeping);

      c.read(ambientProvider.notifier).poke();
      expect(c.read(ambientProvider).asleep, isFalse);
      expect(c.read(avatarProvider), AvatarState.idle);
    });
  });

  test('does not sleep while the avatar is busy', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      c.read(avatarProvider.notifier).set(AvatarState.thinking);
      async.elapse(sleepAfter * 2);
      expect(c.read(ambientProvider).asleep, isFalse);
      expect(c.read(avatarProvider), AvatarState.thinking);
    });
  });

  test('isFriendlyMessage matches thanks and greetings only', () {
    for (final t in ['thanks!', 'Thank you so much', 'terima kasih', 'Makasih ya', 'good morning', 'Selamat pagi']) {
      expect(isFriendlyMessage(t), isTrue, reason: t);
    }
    for (final t in ['what is the weather', 'thankful', 'set a timer']) {
      expect(isFriendlyMessage(t), isFalse, reason: t);
    }
  });

  test('sings from 3 minutes idle, sleeps at 10', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      async.elapse(singAfter - const Duration(seconds: 1));
      expect(c.read(avatarProvider), AvatarState.idle);
      async.elapse(const Duration(seconds: 2));
      expect(c.read(avatarProvider), AvatarState.singing);
      expect(c.read(ambientProvider).asleep, isFalse);

      async.elapse(sleepAfter - singAfter);
      expect(c.read(avatarProvider), AvatarState.sleeping);
      expect(c.read(ambientProvider).asleep, isTrue);
    });
  });

  test('a touch while singing or asleep gives a happy greeting, then idle', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      async.elapse(singAfter + const Duration(seconds: 1));
      c.read(ambientProvider.notifier).poke(touch: true);
      expect(c.read(avatarProvider), AvatarState.happy);
      async.elapse(happyFor + const Duration(seconds: 1));
      expect(c.read(avatarProvider), AvatarState.idle);

      async.elapse(sleepAfter);
      expect(c.read(avatarProvider), AvatarState.sleeping);
      c.read(ambientProvider.notifier).poke(touch: true);
      expect(c.read(ambientProvider).asleep, isFalse);
      expect(c.read(avatarProvider), AvatarState.happy);
    });
  });

  test('touching a singing avatar restarts the idle clock', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      async.elapse(singAfter + const Duration(seconds: 1));
      c.read(ambientProvider.notifier).poke(touch: true);
      async.elapse(happyFor + singAfter - const Duration(seconds: 10));
      expect(c.read(avatarProvider), AvatarState.idle);
    });
  });

  test('petting an idle avatar makes it happy, but not a busy one', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      c.read(ambientProvider.notifier).petAvatar();
      expect(c.read(avatarProvider), AvatarState.happy);
      async.elapse(happyFor + const Duration(seconds: 1));
      expect(c.read(avatarProvider), AvatarState.idle);

      c.read(avatarProvider.notifier).set(AvatarState.thinking);
      c.read(ambientProvider.notifier).petAvatar();
      expect(c.read(avatarProvider), AvatarState.thinking);
    });
  });

  test('does not start singing while the avatar is busy', () {
    fakeAsync((async) {
      final c = _container(prefs);
      addTearDown(c.dispose);
      c.listen(ambientProvider, (_, _) {});
      async.flushMicrotasks();

      c.read(avatarProvider.notifier).set(AvatarState.working);
      async.elapse(singAfter * 2);
      expect(c.read(avatarProvider), AvatarState.working);
    });
  });
}
