/// Things other features report to the pet. The pet never calls them back.
sealed class PetEvent {
  const PetEvent();
}

class UserMessageSent extends PetEvent {
  const UserMessageSent();
}

class ReplyFinished extends PetEvent {
  const ReplyFinished();
}

class ThanksDetected extends PetEvent {
  const ThanksDetected();
}

class AvatarTapped extends PetEvent {
  const AvatarTapped();
}

class TaskCompleted extends PetEvent {
  const TaskCompleted();
}

/// An alert was raised elsewhere (e.g. a monitoring failure). Costs the pet nothing.
class AlertRaised extends PetEvent {
  const AlertRaised();
}

/// First interaction after 06:00; a hook for the morning greeting.
class DailyFirstTouch extends PetEvent {
  const DailyFirstTouch();
}

/// [gotFact] is false when Hermes was unreachable, which earns only a small boost.
class FeedTapped extends PetEvent {
  const FeedTapped({this.gotFact = true});

  final bool gotFact;
}

class PlayTapped extends PetEvent {
  const PlayTapped();
}

class TuckedIn extends PetEvent {
  const TuckedIn();
}

class NightStarted extends PetEvent {
  const NightStarted();
}

class NightEnded extends PetEvent {
  const NightEnded();
}

/// The avatar woke from idle sleep (a touch, with no other event).
class WokeUp extends PetEvent {
  const WokeUp();
}

/// A meal turned into a poop: one more pile, up to [maxPoops].
class PoopHappened extends PetEvent {
  const PoopHappened();
}

/// All piles cleaned up.
class CleanTapped extends PetEvent {
  const CleanTapped();
}
