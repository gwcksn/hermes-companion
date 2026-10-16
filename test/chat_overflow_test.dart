// Regression: the soft keyboard covers ~65% of the 360dp design canvas on the S8,
// which used to overflow the chat page's composer ("BOTTOM OVERFLOWED BY 17 PIXELS").
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/app.dart';
import 'package:hermes_companion/data/auth/credential_store.dart';
import 'package:hermes_companion/data/gateway/chat_controller.dart';
import 'package:hermes_companion/data/hermes_client.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/data/location.dart';
import 'package:hermes_companion/data/weather_provider.dart';
import 'package:hermes_companion/screens/home_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_gateway.dart';
import 'fakes/fake_hermes.dart';
import 'fixtures/open_meteo.dart';

const _url = 'https://bash.example.ts.net';

class _FixtureWeather extends WeatherClient {
  @override
  Future<Map<String, dynamic>> fetch(Place place) async => openMeteoFixture();
}

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

void main() {
  setUpAll(_loadFonts);

  testWidgets('chat composer still fits when the soft keyboard covers the canvas', (tester) async {
    // S8 landscape: 2960x1440 physical, 4 px per design dp (740 x 360 design canvas).
    tester.view.physicalSize = const Size(2960, 1440);
    tester.view.devicePixelRatio = 4.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    SharedPreferences.setMockInitialValues(const {
      'settings.serverUrl': _url,
      'settings.profile': 'default',
      'settings.setupComplete': true,
    });
    final prefs = await SharedPreferences.getInstance();

    final store = MemoryCredentialStore();
    await store.save(const Credentials(server: _url, username: 'admin', password: 'secret'));
    final server = FakeHermes();
    final gateway = FakeGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          credentialStoreProvider.overrideWithValue(store),
          hermesClientFactoryProvider.overrideWithValue((url) => fakeClient(url, store, server)),
          weatherClientProvider.overrideWithValue(_FixtureWeather()),
          gatewayConnectorProvider.overrideWithValue(gateway.connect),
        ],
        child: const HermesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);

    // The S8 IME covers 916 physical px = 229 design dp of the 360 dp canvas. The app reads
    // viewInsets (it zeroes padding), and the Scaffold shrinks the panel by them.
    tester.view.viewInsets = const FakeViewPadding(bottom: 916);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'chat page must not overflow with the keyboard up');
    expect(find.byType(TextField), findsOneWidget, reason: 'the composer stays on screen while typing');
  });
}