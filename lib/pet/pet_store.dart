import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pet_state.dart';

/// Pet snapshot in SharedPreferences as versioned JSON. No credentials here.
class PetStore {
  PetStore(this._prefs);

  static const key = 'pet.state';

  final SharedPreferences _prefs;

  PetState? load(DateTime now) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map<String, Object?> ? PetState.fromJson(j, now) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PetState s) => _prefs.setString(key, jsonEncode(s.toJson()));

  Future<void> clear() => _prefs.remove(key);
}
