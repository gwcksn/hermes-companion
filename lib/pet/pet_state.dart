import '../avatar/avatar_state.dart';

const petSchemaVersion = 2;

const maxStat = 100.0;
const energyFloor = 15.0;
const moodFloor = 25.0;
const curiosityFloor = 20.0;
const hungerFloor = 15.0;
const maxPoops = 3;

/// Immutable pet snapshot. Stats are doubles so slow decay accumulates; show them rounded.
class PetState {
  const PetState({
    required this.energy,
    required this.mood,
    required this.curiosity,
    this.hunger = 70,
    required this.lastTick,
    required this.lastInteraction,
    this.sleeping = false,
    this.lastActivity,
    this.lastFeedAt,
    this.poops = 0,
    this.poopDueAt,
  });

  factory PetState.initial(DateTime now) =>
      PetState(energy: 80, mood: 70, curiosity: 60, lastTick: now, lastInteraction: now);

  final double energy;
  final double mood;
  final double curiosity;
  final double hunger;

  /// Decay is applied from here to "now", so it survives restarts.
  final DateTime lastTick;
  final DateTime lastInteraction;

  /// Energy refills while true (tucked in, or night).
  final bool sleeping;
  final AvatarState? lastActivity;
  final DateTime? lastFeedAt;

  /// Uncleaned piles on screen (0..[maxPoops]).
  final int poops;

  /// When the last meal turns into a poop; null when none is expected.
  final DateTime? poopDueAt;

  PetState copyWith({
    double? energy,
    double? mood,
    double? curiosity,
    double? hunger,
    DateTime? lastTick,
    DateTime? lastInteraction,
    bool? sleeping,
    AvatarState? lastActivity,
    DateTime? lastFeedAt,
    int? poops,
    DateTime? poopDueAt,
    bool clearPoopDue = false,
  }) => PetState(
    energy: energy ?? this.energy,
    mood: mood ?? this.mood,
    curiosity: curiosity ?? this.curiosity,
    hunger: hunger ?? this.hunger,
    lastTick: lastTick ?? this.lastTick,
    lastInteraction: lastInteraction ?? this.lastInteraction,
    sleeping: sleeping ?? this.sleeping,
    lastActivity: lastActivity ?? this.lastActivity,
    lastFeedAt: lastFeedAt ?? this.lastFeedAt,
    poops: poops ?? this.poops,
    poopDueAt: clearPoopDue ? null : (poopDueAt ?? this.poopDueAt),
  );

  Map<String, Object?> toJson() => {
    'v': petSchemaVersion,
    'energy': energy,
    'mood': mood,
    'curiosity': curiosity,
    'hunger': hunger,
    'lastTick': lastTick.toIso8601String(),
    'lastInteraction': lastInteraction.toIso8601String(),
    'sleeping': sleeping,
    'lastActivity': lastActivity?.name,
    'lastFeedAt': lastFeedAt?.toIso8601String(),
    'poops': poops,
    'poopDueAt': poopDueAt?.toIso8601String(),
  };

  /// Reads a stored snapshot. v1 saves (no hunger or poop) and missing optional fields get defaults, and anything
  /// unreadable or from a newer schema returns null so the caller starts a fresh pet.
  static PetState? fromJson(Map<String, Object?> j, DateTime now) {
    try {
      final v = j['v'];
      if (v is! int || v > petSchemaVersion) return null;
      DateTime? time(String k) {
        final s = j[k];
        return s is String ? DateTime.tryParse(s) : null;
      }

      double stat(String k, double floor) => ((j[k] as num).toDouble()).clamp(floor, maxStat);
      final activityName = j['lastActivity'];
      return PetState(
        energy: stat('energy', energyFloor),
        mood: stat('mood', moodFloor),
        curiosity: stat('curiosity', curiosityFloor),
        hunger: j['hunger'] is num ? stat('hunger', hungerFloor) : 70,
        lastTick: time('lastTick') ?? now,
        lastInteraction: time('lastInteraction') ?? now,
        sleeping: j['sleeping'] == true,
        lastActivity: AvatarState.values.where((s) => s.name == activityName).firstOrNull,
        lastFeedAt: time('lastFeedAt'),
        poops: j['poops'] is int ? (j['poops'] as int).clamp(0, maxPoops) : 0,
        poopDueAt: time('poopDueAt'),
      );
    } catch (_) {
      return null;
    }
  }
}
