import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Line and fill icons ported from the inline SVGs in design/ (24x24 viewBox unless noted).
enum HIcon { sliders, arrowRight, arrowLeft, mic, play, stop, refresh, expand, collapse }

class HIconView extends StatelessWidget {
  const HIconView(
    this.icon, {
    super.key,
    required this.color,
    this.size = 22,
    this.strokeWidth = 2,
  });

  final HIcon icon;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _IconPainter(icon, color, strokeWidth),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.strokeWidth);

  final HIcon icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);

    switch (icon) {
      case HIcon.sliders:
        line(4, 7, 13, 7);
        line(17, 7, 20, 7);
        line(4, 17, 7, 17);
        line(11, 17, 20, 17);
        canvas.drawCircle(const Offset(15, 7), 2, stroke);
        canvas.drawCircle(const Offset(9, 17), 2, stroke);
      case HIcon.arrowRight:
        line(5, 12, 19, 12);
        canvas.drawPath(
          Path()
            ..moveTo(13, 6)
            ..lineTo(19, 12)
            ..lineTo(13, 18),
          stroke,
        );
      case HIcon.arrowLeft:
        line(19, 12, 5, 12);
        canvas.drawPath(
          Path()
            ..moveTo(11, 6)
            ..lineTo(5, 12)
            ..lineTo(11, 18),
          stroke,
        );
      case HIcon.mic:
        canvas.drawRRect(
          RRect.fromLTRBR(9, 3, 15, 14, const Radius.circular(3)),
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(5, 4, 14, 14),
          0,
          math.pi,
          false,
          stroke,
        );
        line(12, 18, 12, 21);
      case HIcon.play:
        canvas.drawPath(
          Path()
            ..moveTo(8, 5)
            ..lineTo(19, 12)
            ..lineTo(8, 19)
            ..close(),
          fill,
        );
      case HIcon.refresh:
        const start = -math.pi / 2 + 0.6, sweep = math.pi * 1.6, r = 7.0;
        canvas.drawArc(
          const Rect.fromLTWH(5, 5, 14, 14),
          start,
          sweep,
          false,
          stroke,
        );
        final end = start + sweep;
        final tip = Offset(12 + r * math.cos(end), 12 + r * math.sin(end));
        final back = Offset(
          math.sin(end),
          -math.cos(end),
        ); // against the clockwise tangent
        final out = Offset(math.cos(end), math.sin(end));
        canvas.drawLine(tip, tip + back * 4.5 + out * 3, stroke);
        canvas.drawLine(tip, tip + back * 4.5 - out * 3, stroke);
      case HIcon.expand:
        for (final (x, y, dx, dy) in const [
          (4.0, 4.0, 1.0, 1.0),
          (20.0, 4.0, -1.0, 1.0),
          (4.0, 20.0, 1.0, -1.0),
          (20.0, 20.0, -1.0, -1.0),
        ]) {
          line(x, y, x + 6 * dx, y);
          line(x, y, x, y + 6 * dy);
        }
      case HIcon.collapse:
        for (final (x, y, dx, dy) in const [
          (10.0, 10.0, -1.0, -1.0),
          (14.0, 10.0, 1.0, -1.0),
          (10.0, 14.0, -1.0, 1.0),
          (14.0, 14.0, 1.0, 1.0),
        ]) {
          line(x, y, x + 6 * dx, y);
          line(x, y, x, y + 6 * dy);
        }
      case HIcon.stop:
        canvas.drawRRect(
          RRect.fromLTRBR(5, 5, 19, 19, const Radius.circular(3)),
          fill,
        );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color;
}
