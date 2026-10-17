import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/ambient.dart';
import 'pet_controller.dart';
import 'pet_events.dart';
import 'pet_rules.dart';

/// Publishes events from the other features to the pet. Watch it once from the home screen.
final petWiringProvider = Provider<void>((ref) {
  void emit(PetEvent e) => ref.read(petProvider.notifier).onEvent(e);

  // The 1-minute pet tick re-checks this, so a poop that had to wait (busy, asleep, night) lands later.
  ref.listen(petProvider, (_, next) {
    if (poopIsDue(next, ref.read(petClockProvider).now())) {
      ref.read(ambientProvider.notifier).playPoop();
    }
  });

  ref.listen(ambientProvider.select((a) => a.night), (prev, next) {
    emit(next ? const NightStarted() : const NightEnded());
  });

  ref.listen(ambientProvider.select((a) => a.asleep), (prev, next) {
    if (next && prev == false) emit(const TuckedIn());
    if (!next && prev == true) emit(const WokeUp());
  });
});
