// The device's current place, used by the Clock and Weather pages.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'settings_store.dart';

const _relocateEvery = Duration(minutes: 30);
const _cacheKey = 'place.v1';

class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.utcOffset,
  });

  /// Used until the first fix, and whenever location is denied or unavailable.
  static const fallback = Place(
    name: 'Yogyakarta',
    latitude: -7.80,
    longitude: 110.36,
    utcOffset: Duration(hours: 7),
  );

  final String name;
  final double latitude;
  final double longitude;
  final Duration utcOffset;

  /// "WIB" / "WITA" / "WIT" for Indonesia, otherwise "UTC+5:30".
  String get zoneLabel => switch (utcOffset.inMinutes) {
    420 => 'WIB',
    480 => 'WITA',
    540 => 'WIT',
    final m =>
      'UTC${m < 0 ? '-' : '+'}${m.abs() ~/ 60}${m.abs() % 60 == 0 ? '' : ':${(m.abs() % 60).toString().padLeft(2, '0')}'}',
  };

  DateTime now() => DateTime.now().toUtc().add(utcOffset);

  /// Stable key for the cache: ~1 km grid.
  String get key =>
      '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': latitude,
    'lon': longitude,
    'offset': utcOffset.inMinutes,
  };

  static Place? fromJson(Map<String, dynamic> j) {
    try {
      return Place(
        name: j['name'] as String,
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lon'] as num).toDouble(),
        utcOffset: Duration(minutes: (j['offset'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.key == key &&
      other.name == name &&
      other.utcOffset == utcOffset;

  @override
  int get hashCode => Object.hash(key, name, utcOffset);
}

/// Finds where the device is. Returns null when permission/services/network don't allow it.
class PlaceLocator {
  Future<Place?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return null;

      // A fresh fix first; last-known can be days old.
      final pos = await _currentOrLastKnown();
      if (pos == null) return null;
      return Place(
        name: await _nameFor(pos.latitude, pos.longitude) ?? 'Current location',
        latitude: pos.latitude,
        longitude: pos.longitude,
        utcOffset: DateTime.now().timeZoneOffset,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _currentOrLastKnown() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Neighbourhood-level name from the platform geocoder (what Android's own widgets show).
  Future<String?> _nameFor(double lat, double lon) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lon);
      for (final m in marks) {
        for (final v in [m.subLocality, m.locality, m.subAdministrativeArea, m.administrativeArea]) {
          if (v != null && v.trim().isNotEmpty) return v.trim();
        }
      }
    } catch (_) {}
    return null;
  }
}

final placeLocatorProvider = Provider<PlaceLocator>((ref) => PlaceLocator());

/// The current [Place]: last known (cached) immediately, re-located at launch and every 30 min.
class PlaceNotifier extends Notifier<Place> {
  @override
  Place build() {
    final timer = Timer.periodic(_relocateEvery, (_) => relocate());
    ref.onDispose(timer.cancel);
    Future.microtask(relocate);
    return _readCache() ?? Place.fallback;
  }

  Future<void> relocate() async {
    final place = await ref.read(placeLocatorProvider).locate();
    if (place == null || place == state) return;
    state = place;
    try {
      await ref
          .read(sharedPrefsProvider)
          .setString(_cacheKey, jsonEncode(place.toJson()));
    } catch (_) {}
  }

  Place? _readCache() {
    try {
      final raw = ref.read(sharedPrefsProvider).getString(_cacheKey);
      return raw == null
          ? null
          : Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

final placeProvider = NotifierProvider<PlaceNotifier, Place>(PlaceNotifier.new);
