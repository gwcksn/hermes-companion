import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather.dart';

const _refreshEvery = Duration(minutes: 30);
const _cacheKey = 'weather.openMeteo.v1';

/// Fetches Open-Meteo for [WeatherPlace]. Returns the raw JSON so it can be cached as-is.
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

  Future<Map<String, dynamic>> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/forecast',
      queryParameters: {
        'latitude': WeatherPlace.latitude,
        'longitude': WeatherPlace.longitude,
        'current': 'temperature_2m,weather_code,is_day',
        'hourly': 'temperature_2m,weather_code,precipitation_probability,is_day',
        'timezone': WeatherPlace.timezone,
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

  @override
  Future<Weather> build() async {
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
    final json = await ref.read(weatherClientProvider).fetch();
    final now = DateTime.now();
    final weather = Weather.fromOpenMeteo(json, fetchedAt: now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({'at': now.toIso8601String(), 'data': json}));
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
      return Weather.fromOpenMeteo(m['data'] as Map<String, dynamic>, fetchedAt: DateTime.parse(m['at'] as String));
    } catch (_) {
      return null;
    }
  }
}

// Retries are ours (tap to retry, 30-min refresh), not Riverpod's automatic backoff.
final weatherProvider = AsyncNotifierProvider<WeatherNotifier, Weather>(WeatherNotifier.new, retry: (_, _) => null);
