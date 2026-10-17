import 'dart:math';

import '../avatar/avatar_state.dart';
import 'pet_events.dart';
import 'pet_state.dart';

const maxCatchUp = Duration(hours: 12);
const feedCooldown = Duration(minutes: 30);

const poopDelay = Duration(minutes: 45);
const feedHunger = 35.0;

const _hungerDrainPerHour = 6.0;
const _hungerDrainAsleepPerHour = 1.5;
const _poopMoodDrainPerMin = 1 / 20; // per pile, on top of the normal drain
const _energyDrainPerHour = 4.0;
const _energyRefillPerHour = 10.0;
const _moodDrainPerMin = 1 / 20;
const _curiosityDrainPerMin = 1 / 15;

enum MoodLabel { joyful, content, bored, gloomy }

MoodLabel moodLabel(PetState s) {
  if (s.mood >= 80) return MoodLabel.joyful;
  if (s.mood >= 50) return MoodLabel.content;
  if (s.mood >= 30) return MoodLabel.bored;
  return MoodLabel.gloomy;
}

bool isSleepy(PetState s) => s.energy < 30;
bool isCurious(PetState s) => s.curiosity < 35;
bool isHungry(PetState s) => s.hunger < 35;
bool isFull(PetState s) => s.hunger >= 90;
bool isMessy(PetState s) => s.poops > 0;

/// A meal is ready to become a poop.
bool poopIsDue(PetState s, DateTime now) => s.poopDueAt != null && !now.isBefore(s.poopDueAt!);

/// Needs the avatar can hint at with a short scene, most pressing first.
enum NeedHint { hungry, messy, sleepy, bored, curious }

NeedHint? needHint(PetState s) {
  if (isHungry(s)) return NeedHint.hungry;
  if (isMessy(s)) return NeedHint.messy;
  if (isSleepy(s)) return NeedHint.sleepy;
  if (s.mood < 50) return NeedHint.bored;
  if (isCurious(s)) return NeedHint.curious;
  return null;
}

/// Picks a hint to play now, or null: nothing is needed, or the ~30% roll missed.
NeedHint? pickNeedHint(PetState s, Random rng, {double chance = 0.3}) => rng.nextDouble() < chance ? needHint(s) : null;

/// App resumed after a poop came due: the pile appears without a scene.
PetState applyPendingPoop(PetState s, DateTime now) => poopIsDue(s, now) ? applyEvent(s, const PoopHappened(), now) : s;

/// Any stat low enough that the UI should surface the stats strip.
bool hasLowNeed(PetState s) => isSleepy(s) || isCurious(s) || isHungry(s) || isMessy(s) || s.mood < 30;

double _clamp(double v, double floor) => v.clamp(floor, maxStat);

/// Applies elapsed time since [PetState.lastTick], capped at [maxCatchUp]. A clock that went
/// backwards changes nothing but the tick. Mood only drains for the part after the last interaction.
PetState applyDecay(PetState s, DateTime now) {
  var elapsed = now.difference(s.lastTick);
  if (elapsed <= Duration.zero) return s.copyWith(lastTick: now);
  if (elapsed > maxCatchUp) elapsed = maxCatchUp;
  final minutes = elapsed.inMicroseconds / Duration.microsecondsPerMinute;
  final hours = minutes / 60;

  final windowStart = now.subtract(elapsed);
  final idleStart = s.lastInteraction.isAfter(windowStart) ? s.lastInteraction : windowStart;
  final idleMin = max(0, now.difference(idleStart).inMicroseconds / Duration.microsecondsPerMinute);

  final energy = s.sleeping ? s.energy + _energyRefillPerHour * hours : s.energy - _energyDrainPerHour * hours;
  final hunger = s.hunger - (s.sleeping ? _hungerDrainAsleepPerHour : _hungerDrainPerHour) * hours;
  final mood = s.mood - _moodDrainPerMin * idleMin - _poopMoodDrainPerMin * s.poops * minutes;
  return s.copyWith(
    energy: _clamp(energy, energyFloor),
    hunger: _clamp(hunger, hungerFloor),
    mood: _clamp(mood, moodFloor),
    curiosity: _clamp(s.curiosity - _curiosityDrainPerMin * minutes, curiosityFloor),
    lastTick: now,
  );
}

bool canFeed(PetState s, DateTime now) => s.lastFeedAt == null || now.difference(s.lastFeedAt!) >= feedCooldown;

/// Applies [e] to [s] (decay first, so deltas land on current values).
PetState applyEvent(PetState s, PetEvent e, DateTime now) {
  final cur = applyDecay(s, now);

  PetState bump({double mood = 0, double curiosity = 0}) => cur.copyWith(
    mood: _clamp(cur.mood + mood, moodFloor),
    curiosity: _clamp(cur.curiosity + curiosity, curiosityFloor),
    lastInteraction: now,
    sleeping: false,
  );

  return switch (e) {
    UserMessageSent() => bump(mood: 4, curiosity: 5),
    ReplyFinished() => bump(mood: 2),
    ThanksDetected() => bump(mood: 10),
    AvatarTapped() => bump(mood: 6),
    TaskCompleted() => bump(mood: 8),
    PlayTapped() => bump(mood: 10),
    FeedTapped(:final gotFact) => bump(curiosity: gotFact ? 25 : 8).copyWith(
      hunger: _clamp(cur.hunger + feedHunger, hungerFloor),
      lastFeedAt: gotFact ? now : cur.lastFeedAt,
      poopDueAt: cur.poopDueAt ?? now.add(poopDelay),
    ),
    PoopHappened() => cur.copyWith(poops: min(cur.poops + 1, maxPoops), clearPoopDue: true),
    CleanTapped() => bump(mood: 5).copyWith(poops: 0),
    AlertRaised() || DailyFirstTouch() => cur,
    TuckedIn() || NightStarted() => cur.copyWith(sleeping: true),
    NightEnded() || WokeUp() => cur.copyWith(sleeping: false),
  };
}

/// How long the avatar idles before sleeping; a sleepy pet turns in earlier.
Duration sleepAfterFor(PetState s, Duration normal) => isSleepy(s) ? normal * 0.5 : normal;

/// Weighted idle-activity pick. Never repeats [PetState.lastActivity], honors the night
/// allow-list, and leans on mood and needs. Returns null if nothing qualifies.
AvatarState? pickActivity(PetState s, List<AvatarState> candidates, {required bool night, required Random rng}) {
  final pool = [
    for (final a in candidates)
      if (a != s.lastActivity && (!night || a.nightOk)) a,
  ];
  if (pool.isEmpty) return null;

  final label = moodLabel(s);
  final favored = <AvatarState>{
    if (label == MoodLabel.bored || label == MoodLabel.gloomy) ...const [
      AvatarState.doodling,
      AvatarState.gaming,
      AvatarState.daydreaming,
    ],
    if (isCurious(s)) ...const [AvatarState.reading, AvatarState.stargazing],
    if (isSleepy(s)) ...const [AvatarState.stretching, AvatarState.meditating],
    if (label == MoodLabel.joyful) ...const [AvatarState.singing, AvatarState.coffee],
  };

  double weight(AvatarState a) => favored.contains(a) ? 3 : 1;
  final total = pool.fold<double>(0, (t, a) => t + weight(a));
  var roll = rng.nextDouble() * total;
  for (final a in pool) {
    roll -= weight(a);
    if (roll < 0) return a;
  }
  return pool.last;
}
