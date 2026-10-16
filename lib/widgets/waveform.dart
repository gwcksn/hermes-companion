import 'package:flutter/widgets.dart';

/// Rounded vertical bars centered on a baseline, as in the design's waveform SVGs.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.heights,
    required this.color,
    required this.barWidth,
    required this.step,
    required this.height,
  });

  final List<double> heights;
  final Color color;
  final double barWidth;

  /// Distance between bar starts.
  final double step;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = (heights.length - 1) * step + barWidth;
    return CustomPaint(size: Size(width, height), painter: _WavePainter(heights, color, barWidth, step));
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.heights, this.color, this.barWidth, this.step);

  final List<double> heights;
  final Color color;
  final double barWidth;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final mid = size.height / 2;
    for (var i = 0; i < heights.length; i++) {
      final h = heights[i];
      canvas.drawRRect(
        RRect.fromLTRBR(i * step, mid - h / 2, i * step + barWidth, mid + h / 2, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.heights != heights || old.color != color;
}
