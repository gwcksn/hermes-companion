import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/avatar/avatar_state.dart';
import 'package:hermes_companion/data/settings_store.dart';
import 'package:hermes_companion/layout/ambient.dart' show idleActivities;
import 'package:hermes_companion/pet/pet_clock.dart';
import 'package:hermes_companion/pet/pet_controller.dart';
import 'package:hermes_companion/pet/pet_events.dart';
import 'package:hermes_companion/pet/pet_rules.dart';
import 'package:hermes_companion/pet/pet_state.dart';
import 'package:hermes_companion/pet/pet_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final t0 = DateTime(2026, 10, 18, 12);

PetState base({
  double energy = 80,
  double mood = 70,
  double curiosity = 60,
  double hunger = 70,
  int poops = 0,
  DateTime? poopDueAt,
  bool sleeping = false,
  AvatarState? last,
}) => PetState(
  energy: energy,
  mood: mood,
  curiosity: curiosity,
  hunger: hunger,
  poops: poops,
  poopDueAt: poopDueAt,
  lastTick: t0,
  lastInteraction: t0,
  sleeping: sleeping,
  lastActivity: last,
);

void main() {
  group('decay', () {
    test('awake: maps elapsed time to drain', () {
      final s = applyDecay(base(), t0.add(const Duration(hours: 1)));
      expect(s.energy, closeTo(76, 1e-9));
      expect(s.mood, closeTo(67, 1e-9)); // 60 min / 20
      expect(s.curiosity, closeTo(56, 1e-9)); // 60 min / 15
      expect(s.lastTick, t0.add(const Duration(hours: 1)));
    });

    test('sleeping refills energy', () {
      final s = applyDecay(base(energy: 50, sleeping: true), t0.add(const Duration(hours: 2)));
      expect(s.energy, closeTo(70, 1e-9));
    });

    test('mood only drains after the last interaction', () {
      final s = base().copyWith(lastInteraction: t0.add(const Duration(minutes: 40)));
      final d = applyDecay(s, t0.add(const Duration(hours: 1)));
      expect(d.mood, closeTo(69, 1e-9)); // 20 idle minutes
    });

    test('floors hold', () {
      final s = applyDecay(base(energy: 16, mood: 26, curiosity: 21), t0.add(const Duration(hours: 12)));
      expect(s.energy, energyFloor);
      expect(s.mood, moodFloor);
      expect(s.curiosity, curiosityFloor);
    });

    test('catch-up caps at 12 hours', () {
      final a = applyDecay(base(), t0.add(const Duration(hours: 12)));
      final b = applyDecay(base(), t0.add(const Duration(days: 5)));
      expect(b.energy, a.energy);
      expect(b.mood, a.mood);
    });

    test('clock going backwards changes only the tick', () {
      final s = applyDecay(base(), t0.subtract(const Duration(hours: 1)));
      expect(s.energy, 80);
      expect(s.lastTick, t0.subtract(const Duration(hours: 1)));
    });
  });

  group('events', () {
    PetState go(PetEvent e, [PetState? s]) => applyEvent(s ?? base(), e, t0);

    test('deltas', () {
      expect(go(const UserMessageSent()).mood, 74);
      expect(go(const UserMessageSent()).curiosity, 65);
      expect(go(const ReplyFinished()).mood, 72);
      expect(go(const ThanksDetected()).mood, 80);
      expect(go(const AvatarTapped()).mood, 76);
      expect(go(const TaskCompleted()).mood, 78);
      expect(go(const PlayTapped()).mood, 80);
      expect(go(const FeedTapped()).curiosity, 85);
      expect(go(const FeedTapped(gotFact: false)).curiosity, 68);
    });

    test('alert and first touch cost nothing', () {
      expect(go(const AlertRaised()).mood, 70);
      expect(go(const DailyFirstTouch()).mood, 70);
    });

    test('stats clamp at 100', () {
      final s = go(const ThanksDetected(), base(mood: 95));
      expect(s.mood, 100);
      expect(go(const FeedTapped(), base(curiosity: 90)).curiosity, 100);
    });

    test('sleep transitions', () {
      expect(go(const TuckedIn()).sleeping, isTrue);
      expect(go(const NightStarted()).sleeping, isTrue);
      expect(go(const NightEnded(), base(sleeping: true)).sleeping, isFalse);
      expect(go(const AvatarTapped(), base(sleeping: true)).sleeping, isFalse);
    });

    test('feed cooldown only starts when a fact was delivered', () {
      expect(canFeed(base(), t0), isTrue);
      final fed = go(const FeedTapped());
      expect(canFeed(fed, t0.add(const Duration(minutes: 29))), isFalse);
      expect(canFeed(fed, t0.add(const Duration(minutes: 30))), isTrue);
      expect(canFeed(go(const FeedTapped(gotFact: false)), t0), isTrue);
    });
  });

  group('hunger and poop', () {
    test('hunger drains slower asleep and keeps its floor', () {
      final awake = applyDecay(base(), t0.add(const Duration(hours: 2)));
      expect(awake.hunger, closeTo(58, 1e-9));
      final asleep = applyDecay(base(sleeping: true), t0.add(const Duration(hours: 2)));
      expect(asleep.hunger, closeTo(67, 1e-9));
      expect(applyDecay(base(hunger: 16), t0.add(const Duration(hours: 12))).hunger, hungerFloor);
    });

    test('hungry and full thresholds', () {
      expect(isHungry(base(hunger: 34)), isTrue);
      expect(isHungry(base(hunger: 35)), isFalse);
      expect(isFull(base(hunger: 90)), isTrue);
      expect(isFull(base(hunger: 89)), isFalse);
      expect(hasLowNeed(base(hunger: 20)), isTrue);
      expect(hasLowNeed(base(poops: 1)), isTrue);
    });

    test('feeding fills hunger (clamped) and schedules one poop', () {
      final fed = applyEvent(base(hunger: 20), const FeedTapped(gotFact: false), t0);
      expect(fed.hunger, 55);
      expect(fed.poopDueAt, t0.add(poopDelay));
      final again = applyEvent(fed, const FeedTapped(gotFact: false), t0.add(const Duration(minutes: 10)));
      expect(again.poopDueAt, t0.add(poopDelay)); // not pushed back
      expect(applyEvent(base(hunger: 80), const FeedTapped(), t0).hunger, 100);
    });

    test('poopIsDue, PoopHappened caps at 3 and clears the schedule', () {
      final s = base(poopDueAt: t0.add(poopDelay));
      expect(poopIsDue(s, t0.add(poopDelay - const Duration(seconds: 1))), isFalse);
      expect(poopIsDue(s, t0.add(poopDelay)), isTrue);
      var p = applyEvent(s, const PoopHappened(), t0.add(poopDelay));
      expect(p.poops, 1);
      expect(p.poopDueAt, isNull);
      for (var i = 0; i < 5; i++) {
        p = applyEvent(p, const PoopHappened(), t0.add(poopDelay));
      }
      expect(p.poops, maxPoops);
    });

    test('resuming after a due poop adds the pile silently', () {
      final s = base(poopDueAt: t0.add(const Duration(minutes: 5)));
      expect(applyPendingPoop(s, t0.add(const Duration(hours: 1))).poops, 1);
      expect(applyPendingPoop(s, t0).poops, 0);
    });

    test('piles drain mood faster; cleaning clears them and cheers up', () {
      final clean = applyDecay(base(), t0.add(const Duration(hours: 1)));
      final messy = applyDecay(base(poops: 2), t0.add(const Duration(hours: 1)));
      expect(clean.mood - messy.mood, closeTo(6, 1e-9)); // 2 piles * 60 min / 20
      final after = applyEvent(base(poops: 3), const CleanTapped(), t0);
      expect(after.poops, 0);
      expect(after.mood, 75);
    });

    test('need hints: priority order and roll', () {
      expect(needHint(base()), isNull);
      expect(needHint(base(curiosity: 20)), NeedHint.curious);
      expect(needHint(base(curiosity: 20, energy: 20)), NeedHint.sleepy);
      expect(needHint(base(mood: 40, curiosity: 20)), NeedHint.bored);
      expect(needHint(base(mood: 40, energy: 20)), NeedHint.sleepy);
      expect(needHint(base(mood: 50)), isNull);
      expect(needHint(base(energy: 20, poops: 1)), NeedHint.messy);
      expect(needHint(base(poops: 1, hunger: 20)), NeedHint.hungry);
      expect(pickNeedHint(base(hunger: 20), Random(1), chance: 1), NeedHint.hungry);
      expect(pickNeedHint(base(hunger: 20), Random(1), chance: 0), isNull);
      expect(pickNeedHint(base(), Random(1), chance: 1), isNull);
    });
  });

  group('labels', () {
    test('mood bands', () {
      expect(moodLabel(base(mood: 80)), MoodLabel.joyful);
      expect(moodLabel(base(mood: 79)), MoodLabel.content);
      expect(moodLabel(base(mood: 50)), MoodLabel.content);
      expect(moodLabel(base(mood: 49)), MoodLabel.bored);
      expect(moodLabel(base(mood: 30)), MoodLabel.bored);
      expect(moodLabel(base(mood: 29)), MoodLabel.gloomy);
    });

    test('needs', () {
      expect(isSleepy(base(energy: 29)), isTrue);
      expect(isSleepy(base(energy: 30)), isFalse);
      expect(isCurious(base(curiosity: 34)), isTrue);
      expect(isCurious(base(curiosity: 35)), isFalse);
      expect(hasLowNeed(base()), isFalse);
    });

    test('sleepy sleeps earlier', () {
      const ten = Duration(minutes: 10);
      expect(sleepAfterFor(base(), ten), ten);
      expect(sleepAfterFor(base(energy: 20), ten), const Duration(minutes: 5));
    });
  });

  group('pickActivity', () {
    test('never repeats and honors night allow-list', () {
      final rng = Random(1);
      var last = AvatarState.coffee;
      for (var i = 0; i < 200; i++) {
        final pick = pickActivity(base(last: last), idleActivities, night: true, rng: rng)!;
        expect(pick.nightOk, isTrue);
        expect(pick, isNot(last));
        last = pick;
      }
      for (var i = 0; i < 200; i++) {
        final pick = pickActivity(base(last: AvatarState.gaming), idleActivities, night: false, rng: rng)!;
        expect(pick, isNot(AvatarState.gaming));
      }
    });

    test('null when nothing qualifies', () {
      expect(pickActivity(base(), [AvatarState.gaming], night: true, rng: Random(1)), isNull);
    });

    Map<AvatarState, int> tally(PetState s) {
      final rng = Random(7);
      final counts = <AvatarState, int>{};
      for (var i = 0; i < 4000; i++) {
        final a = pickActivity(s, idleActivities, night: false, rng: rng)!;
        counts[a] = (counts[a] ?? 0) + 1;
      }
      return counts;
    }

    test('weights follow mood and needs', () {
      final bored = tally(base(mood: 40));
      expect(bored[AvatarState.doodling]!, greaterThan(bored[AvatarState.coffee]! * 2));
      final sleepy = tally(base(energy: 20));
      expect(sleepy[AvatarState.stretching]!, greaterThan(sleepy[AvatarState.gaming]! * 2));
      final curious = tally(base(curiosity: 20));
      expect(curious[AvatarState.reading]!, greaterThan(curious[AvatarState.gaming]! * 2));
      final joyful = tally(base(mood: 90));
      expect(joyful[AvatarState.singing]!, greaterThan(joyful[AvatarState.gaming]! * 2));
    });
  });

  group('persistence', () {
    test('round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PetStore(await SharedPreferences.getInstance());
      final s = base(
        energy: 44,
        mood: 55,
        curiosity: 66,
        sleeping: true,
        last: AvatarState.reading,
      ).copyWith(lastFeedAt: t0);
      await store.save(s);
      final back = store.load(t0)!;
      expect(back.energy, 44);
      expect(back.mood, 55);
      expect(back.curiosity, 66);
      expect(back.sleeping, isTrue);
      expect(back.lastActivity, AvatarState.reading);
      expect(back.lastFeedAt, t0);
      expect(back.lastTick, t0);
    });

    test('a v1 save (no hunger or poop) migrates with defaults', () async {
      SharedPreferences.setMockInitialValues({PetStore.key: '{"v":1,"energy":50,"mood":60,"curiosity":70}'});
      final s = PetStore(await SharedPreferences.getInstance()).load(t0)!;
      expect(s.hunger, 70);
      expect(s.poops, 0);
      expect(s.poopDueAt, isNull);
    });

    test('hunger and poop round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PetStore(await SharedPreferences.getInstance());
      await store.save(base(hunger: 33, poops: 2, poopDueAt: t0));
      final s = store.load(t0)!;
      expect(s.hunger, 33);
      expect(s.poops, 2);
      expect(s.poopDueAt, t0);
    });

    test('older save without optional fields loads with defaults', () async {
      SharedPreferences.setMockInitialValues({PetStore.key: '{"v":1,"energy":50,"mood":60,"curiosity":70}'});
      final store = PetStore(await SharedPreferences.getInstance());
      final s = store.load(t0)!;
      expect(s.energy, 50);
      expect(s.lastTick, t0);
      expect(s.lastActivity, isNull);
      expect(s.sleeping, isFalse);
    });

    test('out-of-range stats are clamped to floors', () async {
      SharedPreferences.setMockInitialValues({PetStore.key: '{"v":1,"energy":0,"mood":-5,"curiosity":999}'});
      final s = PetStore(await SharedPreferences.getInstance()).load(t0)!;
      expect(s.energy, energyFloor);
      expect(s.mood, moodFloor);
      expect(s.curiosity, maxStat);
    });

    test('newer schema or garbage starts fresh', () async {
      for (final raw in ['{"v":99,"energy":50,"mood":60,"curiosity":70}', 'nope', '[]']) {
        SharedPreferences.setMockInitialValues({PetStore.key: raw});
        expect(PetStore(await SharedPreferences.getInstance()).load(t0), isNull);
      }
    });
  });

  group('controller', () {
    Future<(ProviderContainer, FakePetClock)> rig([Map<String, Object> prefs = const {}]) async {
      SharedPreferences.setMockInitialValues(prefs);
      final clock = FakePetClock(t0);
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
          petClockProvider.overrideWithValue(clock),
        ],
      );
      addTearDown(c.dispose);
      return (c, clock);
    }

    test('starts fresh, applies events and persists after debounce', () async {
      final (c, _) = await rig();
      final pet = c.read(petProvider.notifier);
      expect(c.read(petProvider).mood, 70);
      pet.onEvent(const ThanksDetected());
      expect(c.read(petProvider).mood, 80);
      c.dispose(); // flushes the pending save
      final prefs = await SharedPreferences.getInstance();
      expect(PetStore(prefs).load(t0)!.mood, 80);
    });

    test('restart applies elapsed decay', () async {
      final (c, clock) = await rig();
      c.read(petProvider.notifier).onEvent(const AvatarTapped());
      c.dispose();
      clock.advance(const Duration(hours: 2));
      final prefs = await SharedPreferences.getInstance();
      final c2 = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs), petClockProvider.overrideWithValue(clock)],
      );
      addTearDown(c2.dispose);
      final s = c2.read(petProvider);
      expect(s.mood, closeTo(76 - 6, 1e-9)); // tap saved 76, then 2 idle hours
    });

    test('reset restores defaults and clears storage', () async {
      final (c, _) = await rig();
      final pet = c.read(petProvider.notifier);
      pet.onEvent(const PlayTapped());
      await pet.reset();
      expect(c.read(petProvider).mood, 70);
      expect((await SharedPreferences.getInstance()).getString(PetStore.key), isNull);
    });
  });
}
