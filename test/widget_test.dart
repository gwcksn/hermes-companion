import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/avatar/avatar_view.dart';
import 'package:hermes_companion/widgets/floating_avatar.dart';
import 'package:hermes_companion/app.dart';
import 'package:hermes_companion/avatar/avatar_state.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/gateway/chat_controller.dart';
import 'package:hermes_companion/data/hermes_client.dart';
import 'package:hermes_companion/data/notifications/notifications_provider.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/data/voice/recorder.dart';
import 'package:hermes_companion/data/location.dart';
import 'package:hermes_companion/data/weather_provider.dart';
import 'package:hermes_companion/screens/home_shell.dart';
import 'package:hermes_companion/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_gateway.dart';
import 'fakes/fake_hermes.dart';
import 'fakes/fake_notifications.dart';
import 'fakes/fake_recorder.dart';
import 'fixtures/open_meteo.dart';

const _url = 'https://bash.example.ts.net';

class _FixtureWeather extends WeatherClient {
  @override
  Future<Map<String, dynamic>> fetch(Place place) async => openMeteoFixture();
}

/// Load the bundled fonts so overflow checks use real glyph widths, not the test font's squares.
Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Fredoka', ['Fredoka-500', 'Fredoka-600']),
    ('Nunito', ['Nunito-600', 'Nunito-700']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await loader.load();
  }
}

class _Harness {
  _Harness({this.initialPrefs = const {}});

  final Map<String, Object> initialPrefs;
  final store = MemoryCredentialStore();
  final server = FakeHermes();
  final gateway = FakeGateway();
  final notifications = FakeNotificationsBridge();
  final recorder = FakeRecorder();
  late SharedPreferences prefs;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2960, 1440); // Galaxy S8 landscape
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    // The avatar animates forever; reduced motion freezes it so pumpAndSettle can settle.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues(initialPrefs);
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          credentialStoreProvider.overrideWithValue(store),
          hermesClientFactoryProvider.overrideWithValue((url) => fakeClient(url, store, server)),
          weatherClientProvider.overrideWithValue(_FixtureWeather()),
          gatewayConnectorProvider.overrideWithValue(gateway.connect),
          notificationsBridgeProvider.overrideWithValue(notifications),
          recorderFactoryProvider.overrideWithValue(() => recorder),
        ],
        child: const HermesApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// The TextField under a LabeledField's label.
Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextField),
);

void main() {
  setUpAll(_loadFonts);

  test('tokens match tokens.json', () {
    expect(HColors.bg, const Color(0xFF0B0A10));
    expect(HColors.peach, const Color(0xFFFFD6A5));
    expect(HSizes.designSize, const Size(740, 360));
    expect(HSizes.stage, 268);
    expect(AvatarState.values.map((s) => s.name), [
      'idle', 'listening', 'thinking', 'working', 'searching', 'speaking', //
      'done', 'oops', 'sleeping', 'happy', 'alarm', 'singing', 'coffee', 'reading', 'stargazing', 'meditating', //
      'gaming', 'doodling', 'stretching', 'daydreaming', 'clockpeek',
    ]);
  });

  testWidgets('first run: address, sign in, profile, then home; settings are saved', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.text('Find your Hermes'), findsOneWidget);

    await tester.enterText(_field('Hermes address'), 'bash.example.ts.net');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Username'), findsOneWidget);

    await tester.enterText(_field('Username'), 'admin');
    await tester.enterText(_field('Password'), 'wrong');
    await tester.tap(find.widgetWithText(InkWell, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong username or password'), findsOneWidget);
    expect(h.store.creds, isNull, reason: 'a rejected password is not kept');

    await tester.enterText(_field('Password'), 'secret');
    await tester.tap(find.widgetWithText(InkWell, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Connected. Talking to default, model bash-pro'), findsOneWidget);

    await tester.tap(find.text('crawly'));
    await tester.pumpAndSettle();
    expect(find.text('Connected. Talking to crawly, model crawly-model'), findsOneWidget);

    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);

    expect(h.store.creds?.username, 'admin');
    expect(h.store.cookies, {'hermes_session': 's1'});
    expect(h.prefs.getString('settings.serverUrl'), _url);
    expect(h.prefs.getString('settings.profile'), 'crawly');
    expect(h.prefs.getBool('settings.setupComplete'), isTrue);
  });

  testWidgets('configured app opens home; pages, mic and settings render', (tester) async {
    final h = _Harness(
      initialPrefs: {'settings.serverUrl': _url, 'settings.profile': 'default', 'settings.setupComplete': true},
    );
    await h.store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    await h.pump(tester);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clock page'));
    await tester.pumpAndSettle();
    expect(find.text('Yogyakarta · WIB'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Weather page'));
    await tester.pumpAndSettle();
    expect(find.text('Partly cloudy'), findsOneWidget);

    // Only 3 dots show, windowed around the current page, so Chat is reached by swiping back.
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();
    // A tap starts recording in the composer, not on a separate screen. It ticks a timer, so it
    // never settles: step frames by hand.
    await tester.tap(find.bySemanticsLabel('Talk to Hermes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.recorder.started, isTrue);
    expect(find.text('Tap to send'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cancel recording'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.recorder.cancelled, isTrue);
    expect(find.text('Tap to send'), findsNothing);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Connection settings'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as admin'), findsOneWidget);
    expect(find.text('Save and connect'), findsOneWidget);
  });

  testWidgets('server unreachable shows Offline and the oops avatar', (tester) async {
    final h = _Harness(initialPrefs: {'settings.serverUrl': _url, 'settings.setupComplete': true});
    h.server.reachable = false;
    await h.pump(tester);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Oops'), findsOneWidget);
  });

  testWidgets('chat page: streamed reply, approval card and clarify card fit and answer', (tester) async {
    final h = _Harness(initialPrefs: {'settings.serverUrl': _url, 'settings.setupComplete': true});
    await h.store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    await h.pump(tester);
    expect(find.text('Say something to Hermes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Is it going to rain?');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pumpAndSettle();
    final conn = h.gateway.last;
    conn.event('message.start', 'live-1');
    conn.event('message.delta', 'live-1', {'text': 'Probably this evening. '});
    await tester.pumpAndSettle();
    expect(find.text('Probably this evening.'), findsNothing); // still streaming, with trailing space
    expect(find.bySemanticsLabel('Stop Hermes'), findsOneWidget);
    conn.event('message.complete', 'live-1', {'text': 'Probably this evening, take a jacket.', 'status': 'complete'});
    await tester.pumpAndSettle();
    expect(find.text('Probably this evening, take a jacket.'), findsOneWidget);

    conn.serverRequest('req-1', 'approval', {
      'session_id': 'live-1',
      'request_id': 'a1',
      'command': 'curl wttr.in/Yogyakarta',
    });
    await tester.pumpAndSettle();
    expect(find.text('Hermes wants to run'), findsOneWidget);
    await tester.tap(find.text('Allow once'));
    await tester.pumpAndSettle();
    expect(conn.replies.single['result'], {'choice': 'once'});
    expect(find.text('Hermes wants to run'), findsNothing);

    conn.serverRequest('req-2', 'clarify', {
      'session_id': 'live-1',
      'questions': [
        {
          'qid': 'q1',
          'question': 'Morning or evening reminder?',
          'choices': ['Morning', 'Evening'],
        },
      ],
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();
    expect(conn.replies.last['result'], {
      'answers': {'q1': 'Evening'},
    });
  });

  testWidgets('typing bubble shows thinking/working status beside it in one row', (tester) async {
    final h = _Harness(initialPrefs: {'settings.serverUrl': _url, 'settings.setupComplete': true});
    await h.store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    await h.pump(tester);

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pumpAndSettle();
    final conn = h.gateway.last;
    // Thinking right after send: dots bubble + label, no separate activity line.
    expect(find.text('thinking on it'), findsOneWidget);
    expect(find.text('Working on it…'), findsNothing);

    conn.event('message.start', 'live-1');
    conn.event('tool.start', 'live-1', {'tool_id': 't1', 'name': 'terminal'});
    await tester.pumpAndSettle();
    expect(find.text('thinking on it'), findsNothing);
    expect(find.text('working on it'), findsOneWidget);
    expect(find.text('Working on it…'), findsNothing);

    conn.event('message.delta', 'live-1', {'text': 'Hello.'});
    await tester.pumpAndSettle();
    expect(find.text('working on it'), findsNothing);
    expect(find.text('Hello.'), findsOneWidget);
  });

  group('mic: hold to talk, tap to latch', () {
    Future<_Harness> chat(WidgetTester tester) async {
      final h = _Harness(initialPrefs: {'settings.serverUrl': _url, 'settings.setupComplete': true});
      await h.store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
      await h.pump(tester);
      return h;
    }

    Future<void> speak(WidgetTester tester, Duration length) async {
      // The recorder clock is a real-time-free periodic timer, so pumped time counts.
      await tester.pump(length);
    }

    Future<void> settleReal(WidgetTester tester) async {
      // transcribe runs through Dio on real async: give it event-loop turns, not fake time.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
    }

    testWidgets('hold, release: transcribes and sends the message', (tester) async {
      final h = await chat(tester);
      final mic = find.bySemanticsLabel('Talk to Hermes');
      final g = await tester.startGesture(tester.getCenter(mic));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.recorder.started, isTrue);
      expect(find.text('‹ Slide to cancel'), findsOneWidget);
      await speak(tester, const Duration(milliseconds: 1500));
      await g.up();
      await tester.pump();
      await settleReal(tester);
      await tester.pumpAndSettle();
      expect(h.server.transcribeBodies, hasLength(1));
      expect(find.text('what is on my calendar'), findsOneWidget);
      expect((h.gateway.last.request('prompt.submit')['params'] as Map)['text'], 'what is on my calendar');
      expect(find.text('Transcribing…'), findsNothing, reason: 'the composer returns to normal after sending');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('quick tap latches; stop sends', (tester) async {
      final h = await chat(tester);
      await tester.tap(find.bySemanticsLabel('Talk to Hermes'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tap to send'), findsOneWidget);
      expect(h.server.transcribeBodies, isEmpty);
      await speak(tester, const Duration(milliseconds: 1500));
      await tester.tap(find.bySemanticsLabel('Stop and send'));
      await tester.pump();
      await settleReal(tester);
      await tester.pumpAndSettle();
      expect(h.server.transcribeBodies, hasLength(1));
      expect(find.text('what is on my calendar'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // ...and the mic works again straight away.
      await tester.tap(find.bySemanticsLabel('Talk to Hermes'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tap to send'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cancel recording'));
      await tester.pumpAndSettle();
    });

    testWidgets('slide away and release cancels without sending', (tester) async {
      final h = await chat(tester);
      final mic = find.bySemanticsLabel('Talk to Hermes');
      final g = await tester.startGesture(tester.getCenter(mic));
      await tester.pump(const Duration(milliseconds: 500));
      await g.moveBy(const Offset(-400, 0));
      await tester.pump();
      expect(find.text('Release to cancel'), findsOneWidget);
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.recorder.cancelled, isTrue);
      expect(h.server.transcribeBodies, isEmpty);
      expect(find.text('Release to cancel'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Say something to Hermes'), findsOneWidget);
      expect(find.text('Yogyakarta · WIB'), findsNothing, reason: 'the slide must not swipe the pager');
    });

    testWidgets('a blocked microphone shows its message, then clears', (tester) async {
      final h = await chat(tester);
      h.recorder.permission = false;
      final g = await tester.startGesture(tester.getCenter(find.bySemanticsLabel('Talk to Hermes')));
      await tester.pump(const Duration(milliseconds: 100));
      await g.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Microphone is blocked'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.textContaining('Microphone is blocked'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  testWidgets('fullscreen panel: avatar floats and moves by long-press drag', (
    tester,
  ) async {
    final h = _Harness(
      initialPrefs: {
        'settings.serverUrl': _url,
        'settings.profile': 'default',
        'settings.setupComplete': true,
      },
    );
    await h.store.save(
      const Credentials(server: _url, username: 'admin', password: 'secret'),
    );
    await h.pump(tester);
    final pageW = tester.getSize(find.byType(PageView)).width;

    await tester.tap(find.bySemanticsLabel('Fullscreen panel'));
    await tester.pumpAndSettle();
    expect(h.prefs.getBool('settings.fullscreenPanel'), isTrue);
    expect(tester.getSize(find.byType(PageView)).width, greaterThan(pageW));
    expect(find.byType(FloatingAvatar), findsOneWidget);

    final before = tester.getTopLeft(find.byType(AvatarView));
    final g = await tester.startGesture(tester.getCenter(find.byType(AvatarView)));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(-200, 0));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(AvatarView)).dx, lessThan(before.dx - 100));
    expect(h.prefs.getDouble('settings.avatarPosX'), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
