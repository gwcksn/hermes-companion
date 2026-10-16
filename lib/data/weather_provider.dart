import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'location.dart';
import 'weather.dart';

const _refreshEvery = Duration(minutes: 30);
const _cacheKey = 'weather.openMeteo.v2';

/// Fetches Open-Meteo for a [Place]. Returns the raw JSON so it can be cached as-is.
class WeatherClient {
  WeatherClient([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.open-meteo.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  Future<Map<String, dynamic>> fetch(Place place) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/forecast',
      queryParameters: {
        'latitude': place.latitude,
        'longitude': place.longitude,
        'current': 'temperature_2m,weather_code,is_day',
        'hourly':
            'temperature_2m,weather_code,precipitation_probability,is_day',
        'timezone': 'auto',
        'forecast_hours': 24,
      },
    );
    return res.data!;
  }
}

final weatherClientProvider = Provider<WeatherClient>((ref) => WeatherClient());

/// Weather for the Weather page: shows the cached forecast immediately, refreshes every 30 min,
/// and keeps the last good forecast if a refresh fails.
class WeatherNotifier extends AsyncNotifier<Weather> {
  Timer? _timer;
  late Place _place;

  @override
  Future<Weather> build() async {
    // A new place (moved, or first GPS fix) rebuilds this and refetches.
    _place = ref.watch(placeProvider);
    _timer?.cancel();
    _timer = Timer.periodic(_refreshEvery, (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    final cached = await _readCache();
    if (cached != null) {
      if (DateTime.now().difference(cached.fetchedAt) > _refreshEvery) {
        // Stale: show it now, refresh in the background.
        Future.microtask(refresh);
      }
      return cached;
    }
    return _fetchAndCache();
  }

  /// Re-fetch; on failure keep showing the previous forecast if there is one.
  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) state = const AsyncLoading();
    try {
      state = AsyncData(await _fetchAndCache());
    } catch (e, st) {
      state = previous != null ? AsyncData(previous) : AsyncError(e, st);
    }
  }

  Future<Weather> _fetchAndCache() async {
    final json = await ref.read(weatherClientProvider).fetch(_place);
    final now = DateTime.now();
    final weather = Weather.fromOpenMeteo(json, fetchedAt: now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'at': now.toIso8601String(),
          'place': _place.key,
          'data': json,
        }),
      );
    } catch (_) {
      // Caching is best-effort.
    }
    return weather;
  }

  Future<Weather?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['place'] != _place.key) return null;
      return Weather.fromOpenMeteo(
        m['data'] as Map<String, dynamic>,
        fetchedAt: DateTime.parse(m['at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

// Retries are ours (tap to retry, 30-min refresh), not Riverpod's automatic backoff.
final weatherProvider = AsyncNotifierProvider<WeatherNotifier, Weather>(
  WeatherNotifier.new,
  retry: (_, _) => null,
);
