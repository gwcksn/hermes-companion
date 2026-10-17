import 'package:flutter/material.dart';

import '../../avatar/scenes.dart';
import '../../theme/tokens.dart';

/// Round image button whose art is a [PropIcon] from the avatar scenes (cookie, broom).
class PropButton extends StatelessWidget {
  const PropButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.size = 56,
  });

  final PropIcon icon;

  /// Spoken label; the button has no text.
  final String label;

  /// Ring color.
  final Color color;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: HColors.surface,
        shape: CircleBorder(side: BorderSide(color: color, width: 2)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: EdgeInsets.all(size * 0.2),
              child: CustomPaint(painter: _PropPainter(icon)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropPainter extends CustomPainter {
  const _PropPainter(this.icon);

  final PropIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final box = icon.box;
    final s = size.shortestSide / (box.width > box.height ? box.width : box.height);
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(s)
      ..translate(-box.center.dx, -box.center.dy);
    icon.group.paint(canvas, 0, 1);
  }

  @override
  bool shouldRepaint(_PropPainter old) => old.icon != icon;
}
