import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_state.dart';
import '../avatar/scenes.dart' show eatInfoFor, eatingFor;
import '../data/gateway/chat_controller.dart';
import '../layout/ambient.dart';
import 'pet_controller.dart';
import 'pet_events.dart';
import 'pet_rules.dart';

/// Scenes for the care actions: play, a plain snack (`eating`) and a fun-fact snack (`eatInfo`).
const playScene = AvatarState.play;
const careSceneFor = Duration(seconds: 4);

const feedPrompt = 'Tell me one fun fact or interesting news item, in two or three short sentences.';

enum FeedResult { fact, snack, full }

/// Feed gives a snack (hunger up) and, when off cooldown and Hermes is idle and online, also
/// asks for a fun fact (shown as a normal chat reply). Refused when the pet is full.
/// Never blocks: the chat send is not awaited.
FeedResult feedPet(WidgetRef ref) {
  final pet = ref.read(petProvider.notifier);
  if (isFull(ref.read(petProvider))) return FeedResult.full;
  final chat = ref.read(chatProvider);
  final fact = pet.canFeedNow && chat.phase == ChatPhase.ready && !chat.busy;
  final ambient = ref.read(ambientProvider.notifier);
  ambient.poke();
  if (!fact) {
    ambient.showScene(AvatarState.eating, eatingFor);
    pet.onEvent(const FeedTapped(gotFact: false));
    return FeedResult.snack;
  }
  // Ask once the eat-info scene is over, or the chat's thinking avatar would cut it short.
  ambient.showScene(AvatarState.eatInfo, eatInfoFor);
  ambient.later(eatInfoFor, () => ref.read(chatProvider.notifier).send(feedPrompt));
  pet.onEvent(const FeedTapped());
  return FeedResult.fact;
}

void playWithPet(WidgetRef ref) {
  final ambient = ref.read(ambientProvider.notifier);
  ambient.poke();
  ref.read(petProvider.notifier).onEvent(const PlayTapped());
  ambient.showScene(playScene, careSceneFor);
}

/// Sweeps away the piles with the cleaning scene.
void cleanPet(WidgetRef ref) {
  HapticFeedback.lightImpact();
  ref.read(ambientProvider.notifier).cleanUp();
}

void tuckInPet(WidgetRef ref) {
  ref.read(petProvider.notifier).onEvent(const TuckedIn());
  ref.read(ambientProvider.notifier).sleepNow();
}

/// Minutes until Feed is ready again, rounded up; 0 when ready.
int feedMinutesLeft(DateTime? lastFeedAt, DateTime now) {
  if (lastFeedAt == null) return 0;
  final left = feedCooldown - now.difference(lastFeedAt);
  return left <= Duration.zero ? 0 : (left.inSeconds / 60).ceil();
}
