import 'package:flutter/painting.dart';

import '../theme/tokens.dart';

/// The 31 avatar states: 12 core (tokens.json order), 9 idle activities, the 4 care scenes, then the 6 pet-mood scenes. See HANDOFF.md §5 for triggers.
enum AvatarState {
  idle('Idle'),
  listening('Listening'),
  thinking('Thinking'),
  working('Working'),
  searching('Searching'),
  speaking('Speaking'),
  done('Done'),
  oops('Oops'),
  sleeping('Sleeping'),
  happy('Happy'),
  alarm('Alarm'),
  singing('Singing'),
  coffee('Coffee'),
  reading('Reading'),
  stargazing('Stargazing'),
  meditating('Meditating'),
  gaming('Gaming'),
  doodling('Doodling'),
  stretching('Stretching'),
  daydreaming('Daydreaming'),
  clockpeek('Clock peek'),
  pooping('Pooping'),
  eating('Eating'),
  cleaning('Cleaning'),
  hungry('Hungry'),
  curious('Curious'),
  bored('Bored'),
  proud('Proud'),
  sulky('Sulky'),
  play('Play'),
  eatInfo('Fun fact');

  const AvatarState(this.label);

  final String label;

  /// Stage caption color: mint while Hermes is actively engaged, muted otherwise.
  Color get labelColor => switch (this) {
    oops => HColors.coral,
    working ||
    searching ||
    thinking ||
    listening ||
    speaking ||
    done ||
    happy ||
    alarm ||
    singing ||
    eating ||
    cleaning ||
    proud ||
    play ||
    eatInfo => HColors.mint,
    _ => HColors.muted,
  };

  /// Repaint rate. Each frame costs real GPU-driver time on the S8 (~1.6% of a core per fps),
  /// so calm states run slower; fast motions (jitter, talking, typing, hopping) keep 30 fps.
  int get fps => switch (this) {
    sleeping => 10,
    idle || thinking || searching || listening || happy || oops || hungry || curious || bored || proud || sulky => 20,
    working || speaking || done || alarm || singing || gaming || pooping || eating || cleaning || play || eatInfo => 30,
    coffee || reading || stargazing || meditating || doodling || stretching || daydreaming || clockpeek => 20,
  };

  /// Whether this idle activity is calm enough to play during the night window (HANDOFF.md §5b).
  bool get nightOk => switch (this) {
    coffee || reading || stargazing || meditating || daydreaming => true,
    _ => false,
  };

  /// Inner color of the stage's radial glow.
  Color get glow => this == listening ? HColors.mintGlow : HColors.surfaceActive;
}
