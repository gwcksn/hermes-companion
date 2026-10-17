/// Time source for the pet, so rules and tests never touch the real clock.
abstract class PetClock {
  DateTime now();
}

class SystemPetClock implements PetClock {
  const SystemPetClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test clock; move it with [advance].
class FakePetClock implements PetClock {
  FakePetClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}
