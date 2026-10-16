import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Lays [child] out on the fixed design canvas (740x360 landscape, 360x740 portrait) and scales
/// it to fit the real screen, so measurements from design/*.dc.html apply verbatim.
class ScaledStage extends StatelessWidget {
  const ScaledStage({super.key, required this.child, required this.size, this.offset = Offset.zero});

  final Widget child;
  final Size size;

  /// Small translation used for AMOLED burn-in pixel shift.
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HColors.bg,
      // Tight constraints so FittedBox scales the canvas up, not just centers it.
      child: SizedBox.expand(
        child: FittedBox(
          child: Transform.translate(
            offset: offset,
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    );
  }
}
