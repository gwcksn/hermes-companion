import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_controller.dart';
import '../avatar/avatar_state.dart';
import '../avatar/scenes.dart' show cleaningFor, poopingFor, hungryFor;
import '../data/gateway/chat_controller.dart';
import '../data/settings_store.dart';
import '../pet/pet_controller.dart';
import '../pet/pet_events.dart';
import '../pet/pet_rules.dart';
import '../pet/pet_state.dart' show maxPoops;
import '../pet/pet_ui.dart';
import '../screens/clock_page.dart' show nowWib;

const _shiftEvery = Duration(minutes: 3);
const _nightCheckEvery = Duration(minutes: 1);
const activityStartAfter = Duration(minutes: 3);
const activityEvery = Duration(minutes: 1);
const sleepAfter = Duration(minutes: 10);
const happyFor = Duration(seconds: 3);

/// What Hermes does while nobody is around. From [activityStartAfter] until [sleepAfter] it plays a
/// random one (never the same twice in a row), switching every [activityEvery].
/// At night only calm ones ([AvatarState.nightOk]) are picked. Add an entry here for each new idle activity.
const idleActivities = [
  AvatarState.singing,
  AvatarState.coffee,
  AvatarState.reading,
  AvatarState.stargazing,
  AvatarState.meditating,
  AvatarState.gaming,
  AvatarState.doodling,
  AvatarState.stretching,
  AvatarState.daydreaming,
  AvatarState.clockpeek,
];

/// Idle activities plus the need hints: calm states we set ourselves, ended by any touch.
final _activityStates = {
  ...idleActivities,
  AvatarState.hungry,
  AvatarState.curious,
  AvatarState.bored,
  AvatarState.sulky,
};

/// Scene that hints at [hint].
AvatarState _sceneForHint(NeedHint hint) => switch (hint) {
  NeedHint.hungry => AvatarState.hungry,
  NeedHint.messy => AvatarState.sulky,
  NeedHint.sleepy => AvatarState.stretching,
  NeedHint.bored => AvatarState.bored,
  NeedHint.curious => AvatarState.curious,
};

final _idleLike = {AvatarState.idle, ..._activityStates};

const nightDimOpacity = 0.55;
const sleepDimOpacity = 0.75;

/// Night is 22:00 to 06:00 in WIB; [wibNow] comes from `nowWib()`.
bool isNightWib(DateTime wibNow) => wibNow.hour >= 22 || wibNow.hour < 6;

const _shiftCycle = [
  Offset(0, 0),
  Offset(2, 0),
  Offset(2, 2),
  Offset(0, 2),
  Offset(-2, 2),
  Offset(-2, 0),
  Offset(-2, -2),
  Offset(0, -2),
  Offset(2, -2),
];

/// Slow walk of at most 2 design px around the origin, for AMOLED burn-in.
Offset pixelShiftFor(int step) => _shiftCycle[step % _shiftCycle.length];

class AmbientState {
  const AmbientState({this.shift = Offset.zero, this.night = false, this.asleep = false});

  final Offset shift;
  final bool night;
  final bool asleep;

  AmbientState copyWith({Offset? shift, bool? night, bool? asleep}) =>
      AmbientState(shift: shift ?? this.shift, night: night ?? this.night, asleep: asleep ?? this.asleep);
}

/// Pixel shift, night detection and idle-to-sleep for the bedside display.
class AmbientController extends Notifier<AmbientState> {
  var _step = 0;
  final _idleTimers = <Timer>[];
  Timer? _happyTimer;
  final _rng = Random();
  AvatarState? _lastActivity;
  DateTime? _lastTouchDay;
  final _careTimers = <Timer>[];
  var _careBusy = false;

  @override
  AmbientState build() {
    final shiftTimer = Timer.periodic(_shiftEvery, (_) {
      _step++;
      state = state.copyWith(shift: pixelShiftFor(_step));
    });
    final nightTimer = Timer.periodic(_nightCheckEvery, (_) {
      final night = isNightWib(nowWib());
      if (night != state.night) state = state.copyWith(night: night);
    });
    ref.onDispose(() {
      shiftTimer.cancel();
      nightTimer.cancel();
      _cancelIdle();
      _happyTimer?.cancel();
      for (final t in _careTimers) {
        t.cancel();
      }
    });

    // Chat or avatar activity counts as use; the calm states we set ourselves do not.
    ref.listen(chatProvider.select((c) => (c.messages.length, c.busy)), (_, _) => poke());
    ref.listen(avatarProvider, (_, next) {
      if (!_idleLike.contains(next) && next != AvatarState.sleeping && next != AvatarState.happy) poke();
    });

    _armIdle();
    return AmbientState(night: isNightWib(nowWib()));
  }

  /// Any sign of use: reset the idle clock and end singing or sleep. A [touch] gets a happy greeting.
  void poke({bool touch = false}) {
    if (touch) _firstTouchOfDay();
    final cur = ref.read(avatarProvider);
    final wasResting = state.asleep || _activityStates.contains(cur);
    if (state.asleep) state = state.copyWith(asleep: false);
    if (wasResting) {
      if (touch) {
        _happy();
      } else if (cur == AvatarState.sleeping || _activityStates.contains(cur)) {
        ref.read(avatarProvider.notifier).set(AvatarState.idle);
      }
    }
    _armIdle();
  }

  /// Tapping the avatar while it is idle makes it happy for a moment.
  void petAvatar() {
    ref.read(petProvider.notifier).onEvent(const AvatarTapped());
    ref.read(statsPeekProvider.notifier).peek();
    if (ref.read(avatarProvider) == AvatarState.idle) _happy();
  }

  /// Plays [scene] for [duration], then returns to idle if nothing else took over.
  void showScene(AvatarState scene, Duration duration) {
    _happyTimer?.cancel();
    ref.read(avatarProvider.notifier).set(scene);
    _happyTimer = Timer(duration, () {
      if (ref.read(avatarProvider) == scene) {
        ref.read(avatarProvider.notifier).set(AvatarState.idle);
      }
    });
  }

  /// Plays a care [scene] for [d], then runs [done] and returns to idle if nothing else took over.
  /// Its end is never cancelled by another scene, so a pile or a clean-up is always recorded.
  void _care(AvatarState scene, Duration d, void Function() done) {
    _careBusy = true;
    ref.read(avatarProvider.notifier).set(scene);
    late final Timer t;
    t = Timer(d, () {
      _careTimers.remove(t);
      _careBusy = false;
      done();
      if (ref.read(avatarProvider) == scene) {
        ref.read(avatarProvider.notifier).set(AvatarState.idle);
      }
    });
    _careTimers.add(t);
  }

  /// A task was finished: show the proud scene if nothing more important is on screen.
  void reactProud() {
    if (_careBusy || state.asleep || ref.read(settingsProvider).quietPet) return;
    if (!_idleLike.contains(ref.read(avatarProvider))) return;
    showScene(AvatarState.proud, hungryFor);
  }

  /// Runs [fn] after [d], cancelled with the controller. Used to let a care scene finish first.
  void later(Duration d, void Function() fn) {
    late final Timer t;
    t = Timer(d, () {
      _careTimers.remove(t);
      fn();
    });
    _careTimers.add(t);
  }

  /// A meal came due: play the pooping scene and add the pile. Waits while the pet is busy, asleep,
  /// at night or in Quiet pet; piles that are already at the cap are added without a scene.
  void playPoop() {
    if (_careBusy || state.asleep || state.night) return;
    if (ref.read(settingsProvider).quietPet) return;
    if (!_idleLike.contains(ref.read(avatarProvider))) return;
    final pet = ref.read(petProvider);
    if (!poopIsDue(pet, ref.read(petClockProvider).now())) return;
    final notifier = ref.read(petProvider.notifier);
    if (pet.poops >= maxPoops) return notifier.onEvent(const PoopHappened());
    _care(AvatarState.pooping, poopingFor, () => notifier.onEvent(const PoopHappened()));
  }

  /// Sweeps away every pile with the cleaning scene.
  void cleanUp() {
    if (_careBusy || ref.read(petProvider).poops == 0) return;
    poke();
    final notifier = ref.read(petProvider.notifier);
    _care(AvatarState.cleaning, cleaningFor, () => notifier.onEvent(const CleanTapped()));
  }

  /// Tuck-in: sleep now instead of waiting out the idle ladder. Any touch wakes it.
  void sleepNow() {
    _cancelIdle();
    _happyTimer?.cancel();
    state = state.copyWith(asleep: true);
    ref.read(avatarProvider.notifier).set(AvatarState.sleeping);
  }

  void _firstTouchOfDay() {
    final now = nowWib();
    if (now.hour < 6) return;
    final day = DateTime(now.year, now.month, now.day);
    if (_lastTouchDay == day) return;
    _lastTouchDay = day;
    ref.read(petProvider.notifier).onEvent(const DailyFirstTouch());
  }

  void _happy() {
    ref.read(avatarProvider.notifier).set(AvatarState.happy);
    _happyTimer?.cancel();
    _happyTimer = Timer(happyFor, () {
      if (ref.read(avatarProvider) == AvatarState.happy) ref.read(avatarProvider.notifier).set(AvatarState.idle);
    });
  }

  void _cancelIdle() {
    for (final t in _idleTimers) {
      t.cancel();
    }
    _idleTimers.clear();
  }

  void _armIdle() {
    _cancelIdle();
    _lastActivity = null;
    _idleTimers.add(Timer(activityStartAfter, _nextActivity));
    _idleTimers.add(
      Timer(sleepAfterFor(ref.read(petProvider), sleepAfter), () {
        if (!_idleLike.contains(ref.read(avatarProvider))) return _armIdle();
        state = state.copyWith(asleep: true);
        ref.read(avatarProvider.notifier).set(AvatarState.sleeping);
      }),
    );
  }

  void _nextActivity() {
    // Never cut off thinking, alarms or errors.
    if (!_idleLike.contains(ref.read(avatarProvider))) return;
    if (!ref.read(settingsProvider).quietPet) {
      final hint = pickNeedHint(ref.read(petProvider), _rng);
      if (hint != null) {
        showScene(_sceneForHint(hint), hungryFor);
        _idleTimers.add(Timer(activityEvery, _nextActivity));
        return;
      }
    }
    final pick = pickActivity(
      ref.read(petProvider).copyWith(lastActivity: _lastActivity),
      idleActivities,
      night: isNightWib(nowWib()),
      rng: _rng,
    );
    if (pick == null) return;
    _lastActivity = pick;
    ref.read(avatarProvider.notifier).set(pick);
    _idleTimers.add(Timer(activityEvery, _nextActivity));
  }
}

final ambientProvider = NotifierProvider<AmbientController, AmbientState>(AmbientController.new);

/// Opacity of the black dim layer for the current state.
double dimOpacityFor({required bool dimEnabled, required bool night, required bool asleep}) {
  if (!dimEnabled) return 0;
  if (asleep) return sleepDimOpacity;
  return night ? nightDimOpacity : 0;
}

/// Touch wake-up plus the dim layer, placed above the whole app.
class AmbientOverlay extends ConsumerWidget {
  const AmbientOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(ambientProvider);
    final dimEnabled = ref.watch(settingsProvider.select((s) => s.dimAtNight));
    final opacity = dimOpacityFor(dimEnabled: dimEnabled, night: a.night, asleep: a.asleep);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(ambientProvider.notifier).poke(touch: true),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 600),
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
