import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_state.dart';
import '../data/settings_store.dart';
import 'pet_clock.dart';
import 'pet_events.dart';
import 'pet_rules.dart';
import 'pet_state.dart';
import 'pet_store.dart';

const petTickEvery = Duration(minutes: 1);
const _saveDebounce = Duration(seconds: 2);

final petClockProvider = Provider<PetClock>((ref) => const SystemPetClock());

final petStoreProvider = Provider<PetStore>((ref) => PetStore(ref.watch(sharedPrefsProvider)));

/// Loads the pet, applies catch-up decay, ticks while the app is open and takes events.
/// Purely cosmetic: nothing else waits on it.
class PetController extends Notifier<PetState> {
  Timer? _tick;
  Timer? _save;
  PetState? _latest;

  PetClock get _clock => ref.read(petClockProvider);

  @override
  PetState build() {
    final now = _clock.now();
    final loaded = ref.read(petStoreProvider).load(now);
    _tick = Timer.periodic(petTickEvery, (_) => _set(applyDecay(state, _clock.now())));
    final store = ref.read(petStoreProvider);
    ref.onDispose(() {
      _tick?.cancel();
      if (_save?.isActive ?? false) {
        _save!.cancel();
        final latest = _latest;
        if (latest != null) unawaited(store.save(latest));
      }
    });
    return applyPendingPoop(applyDecay(loaded ?? PetState.initial(now), now), now);
  }

  void onEvent(PetEvent e) => _set(applyEvent(state, e, _clock.now()));

  bool get canFeedNow => canFeed(state, _clock.now());

  Future<void> reset() async {
    _save?.cancel();
    state = PetState.initial(_clock.now());
    await ref.read(petStoreProvider).clear();
  }

  /// Records the idle activity that was just chosen, for the no-repeat rule.
  void noteActivity(AvatarState activity) => _set(state.copyWith(lastActivity: activity));

  void _set(PetState next) {
    state = next;
    _latest = next;
    _save?.cancel();
    _save = Timer(_saveDebounce, () => unawaited(ref.read(petStoreProvider).save(state)));
  }
}

final petProvider = NotifierProvider<PetController, PetState>(PetController.new);
