import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';
import 'pet_controller.dart';
import 'pet_rules.dart';

const statsPeekFor = Duration(seconds: 4);

/// True for a few seconds after the avatar is tapped, so the stats strip shows briefly.
class StatsPeek extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  void peek() {
    state = true;
    _timer?.cancel();
    _timer = Timer(statsPeekFor, () => state = false);
  }
}

final statsPeekProvider = NotifierProvider<StatsPeek, bool>(StatsPeek.new);

/// Debug builds keep the strip visible with numbers to check the wiring; tests turn it off.
final petStatsDebugProvider = Provider<bool>((ref) => kDebugMode);

/// The strip shows after a tap or while a need is low; never in quiet mode.
final statsVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(settingsProvider.select((s) => s.quietPet))) return false;
  return ref.watch(statsPeekProvider) || hasLowNeed(ref.watch(petProvider));
});
