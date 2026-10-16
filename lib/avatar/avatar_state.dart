import 'package:flutter/painting.dart';

import '../theme/tokens.dart';

/// The 12 avatar states, in tokens.json order. See HANDOFF.md §5 for triggers.
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
  singing('Singing');

  const AvatarState(this.label);

  final String label;

  /// Stage caption color: mint while Hermes is actively engaged, muted otherwise.
  Color get labelColor => switch (this) {
    idle || sleeping => HColors.muted,
    oops => HColors.coral,
    _ => HColors.mint,
  };

  /// Repaint rate. Each frame costs real GPU-driver time on the S8 (~1.6% of a core per fps),
  /// so calm states run slower; fast motions (jitter, talking, typing, hopping) keep 30 fps.
  int get fps => switch (this) {
    sleeping => 10,
    idle || thinking || searching || listening || happy || oops => 20,
    working || speaking || done || alarm || singing => 30,
  };

  /// Inner color of the stage's radial glow.
  Color get glow => this == listening ? HColors.mintGlow : HColors.surfaceActive;
}
