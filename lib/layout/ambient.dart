import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_controller.dart';
import '../avatar/avatar_state.dart';
import '../data/gateway/chat_controller.dart';
import '../data/settings_store.dart';
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

final _activityStates = {...idleActivities};
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
    if (ref.read(avatarProvider) == AvatarState.idle) _happy();
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
      Timer(sleepAfter, () {
        if (!_idleLike.contains(ref.read(avatarProvider))) return _armIdle();
        state = state.copyWith(asleep: true);
        ref.read(avatarProvider.notifier).set(AvatarState.sleeping);
      }),
    );
  }

  void _nextActivity() {
    // Never cut off thinking, alarms or errors.
    if (!_idleLike.contains(ref.read(avatarProvider))) return;
    final night = isNightWib(nowWib());
    final pool = night ? idleActivities.where((a) => a.nightOk).toList() : idleActivities;
    final options = pool.length > 1 ? pool.where((a) => a != _lastActivity).toList() : pool;
    final pick = options[_rng.nextInt(options.length)];
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
