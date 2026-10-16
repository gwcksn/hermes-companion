import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

enum WeatherKind { clear, partlyCloudy, cloudy, rain }

/// Weather glyphs ported from design/Weather.dc.html.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.kind, {super.key, this.size = 28, this.large = false, this.night = false});

  final WeatherKind kind;
  final double size;

  /// Draw a moon instead of the sun (clear / partly cloudy at night).
  final bool night;

  /// The 64-viewBox hero icon (with sun rays) instead of the 32-viewBox slot icon.
  final bool large;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _WeatherPainter(kind, large, night));
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter(this.kind, this.large, this.night);

  final WeatherKind kind;
  final bool large;
  final bool night;

  /// Crescent: a disc minus an offset disc.
  void _moon(Canvas canvas, Offset c, double r) {
    final disc = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final bite = Path()..addOval(Rect.fromCircle(center: c + Offset(r * 0.55, -r * 0.35), radius: r * 0.85));
    canvas.drawPath(Path.combine(PathOperation.difference, disc, bite), Paint()..color = HColors.peach);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sun = Paint()..color = HColors.peach;
    final cloud = Paint()..color = HColors.cloud;

    if (kind == WeatherKind.rain) {
      canvas.scale(size.width / 24);
      canvas.drawPath(
        Path()
          ..moveTo(12, 3)
          ..cubicTo(12, 3, 5.5, 10.5, 5.5, 15)
          ..arcToPoint(const Offset(18.5, 15), radius: const Radius.circular(6.5), clockwise: false)
          ..cubicTo(18.5, 10.5, 12, 3, 12, 3)
          ..close(),
        Paint()..color = HColors.sky,
      );
      return;
    }

    if (large) {
      canvas.scale(size.width / 64);
      final hasCloud = kind != WeatherKind.clear;
      if (kind != WeatherKind.cloudy && night) {
        _moon(canvas, const Offset(22, 24), 13);
      } else if (kind != WeatherKind.cloudy) {
        canvas.drawCircle(const Offset(22, 24), 11, sun);
        final ray = Paint()
          ..color = HColors.peach
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(22, 5), const Offset(22, 9), ray);
        canvas.drawLine(const Offset(3, 24), const Offset(7, 24), ray);
        canvas.drawLine(const Offset(8.5, 10.5), const Offset(11.3, 13.3), ray);
        canvas.drawLine(const Offset(35.5, 10.5), const Offset(32.7, 13.3), ray);
      }
      if (hasCloud) {
        canvas.drawCircle(const Offset(26, 44), 10, cloud);
        canvas.drawCircle(const Offset(40, 38), 13, cloud);
        canvas.drawCircle(const Offset(52, 46), 8, cloud);
        canvas.drawRect(const Rect.fromLTWH(26, 44, 26, 10), cloud);
      }
      return;
    }

    canvas.scale(size.width / 32);
    if (kind == WeatherKind.clear) {
      night ? _moon(canvas, const Offset(16, 16), 9) : canvas.drawCircle(const Offset(16, 16), 8, sun);
      return;
    }
    if (kind == WeatherKind.partlyCloudy) {
      night ? _moon(canvas, const Offset(9, 10), 6) : canvas.drawCircle(const Offset(9, 10), 5, sun);
    }
    canvas.drawCircle(const Offset(11, 20), 6, cloud);
    canvas.drawCircle(const Offset(18, 17), 8, cloud);
    canvas.drawCircle(const Offset(25, 21), 5, cloud);
    canvas.drawRect(const Rect.fromLTWH(11, 20, 14, 6), cloud);
  }

  @override
  bool shouldRepaint(_WeatherPainter old) => old.kind != kind || old.large != large || old.night != night;
}
