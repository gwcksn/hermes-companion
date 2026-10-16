import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/data/location.dart';
import 'package:hermes_companion/data/weather.dart';
import 'package:hermes_companion/data/weather_provider.dart';
import 'package:hermes_companion/widgets/weather_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/open_meteo.dart';

class _FakeClient extends WeatherClient {
  _FakeClient(this.responses);

  final List<Object> responses; // Map = success, anything else = thrown
  int calls = 0;

  @override
  Future<Map<String, dynamic>> fetch(Place place) async {
    final r =
        responses[calls++ < responses.length
            ? calls - 1
            : responses.length - 1];
    if (r is Map<String, dynamic>) return r;
    throw r;
  }
}

void main() {
  group('parsing', () {
    test('current conditions and the next 4 hours', () {
      final w = Weather.fromOpenMeteo(
        openMeteoFixture(),
        fetchedAt: DateTime(2026, 10, 16, 17, 15),
      );
      expect(w.now.temp, 29.3);
      expect(w.condition, 'Partly cloudy');
      expect(w.now.kind, WeatherKind.partlyCloudy);
      expect(w.hours.map((h) => h.label), ['18:00', '19:00', '20:00', '21:00']);
      expect(w.hours.map((h) => h.temp.round()), [27, 26, 26, 25]);
      expect(w.hours[2].kind, WeatherKind.rain);
      expect(w.hours[1].isDay, isFalse);
    });

    test('rain hint names when rain becomes likely', () {
      final w = Weather.fromOpenMeteo(
        openMeteoFixture(),
        fetchedAt: DateTime(2026),
      );
      expect(w.hint, 'Rain likely this evening'); // 60% at 20:00
      final dry = Weather.fromOpenMeteo(
        openMeteoFixture(rain: [0, 0, 5, 10, 0, 0], codes: [1, 1, 1, 1, 0, 0]),
        fetchedAt: DateTime(2026),
      );
      expect(dry.hint, 'No rain expected');
      final storm = Weather.fromOpenMeteo(
        openMeteoFixture(rain: [0, 0, 30, 0, 0, 0], codes: [1, 1, 95, 1, 0, 0]),
        fetchedAt: DateTime(2026),
      );
      expect(storm.hint, 'Storms likely this evening');
    });
  });

  test('WMO codes map onto the 4 design glyphs', () {
    expect(kindFor(0), WeatherKind.clear);
    expect(kindFor(3), WeatherKind.cloudy);
    expect(kindFor(45), WeatherKind.cloudy);
    for (final c in [51, 61, 65, 80, 82, 95, 99]) {
      expect(kindFor(c), WeatherKind.rain, reason: 'code $c');
    }
    expect(conditionFor(63), 'Rain');
  });

  group('provider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'fetches, caches, and keeps the last forecast when a refresh fails',
      () async {
      final client = _FakeClient([openMeteoFixture(), Exception('offline')]);
        final c = ProviderContainer(
          overrides: [weatherClientProvider.overrideWithValue(client)],
        );
      addTearDown(c.dispose);

      final first = await c.read(weatherProvider.future);
      expect(first.now.temp, 29.3);

      await c.read(weatherProvider.notifier).refresh();
      expect(c.read(weatherProvider).value?.now.temp, 29.3);
      expect(c.read(weatherProvider).hasError, isFalse);

      // A fresh container reads the cache without touching the network.
      final offline = _FakeClient([Exception('offline')]);
        final c2 = ProviderContainer(
          overrides: [weatherClientProvider.overrideWithValue(offline)],
        );
      addTearDown(c2.dispose);
      expect((await c2.read(weatherProvider.future)).now.temp, 29.3);
      expect(offline.calls, 0);
      },
    );

    test('errors when there is no cache and the fetch fails', () async {
      final c = ProviderContainer(
        overrides: [
          weatherClientProvider.overrideWithValue(
            _FakeClient([Exception('offline')]),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(weatherProvider, (_, _) {});
      await expectLater(c.read(weatherProvider.future), throwsException);
    });
  });
}
