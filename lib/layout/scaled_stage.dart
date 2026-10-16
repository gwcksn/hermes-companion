import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Lays [child] out on the fixed 740x360 design canvas and scales it to fit
/// the real screen, so measurements from design/*.dc.html apply verbatim.
class ScaledStage extends StatelessWidget {
  const ScaledStage({super.key, required this.child, this.offset = Offset.zero});

  final Widget child;

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
            child: SizedBox.fromSize(size: HSizes.designSize, child: child),
          ),
        ),
      ),
    );
  }
}
