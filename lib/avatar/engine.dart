// A tiny SVG + CSS-keyframes engine, just enough to replay assets/avatar/*.svg natively.
//
// Semantics mirrored from CSS:
// - each animated property has its own keyframe track; the timing function applies per segment
// - `alternate` reverses odd iterations (timing function applied to the reversed progress)
// - delays are treated as phase offsets (steady state), so delayed items never pop in unanimated
// - transform-origin is resolved against the element's fill-box when [Group.origin] is set,
//   otherwise against the user-space origin (SVG default)
// - transform lists compose as translate · rotate · scale around the origin
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

enum Prop { tx, ty, sx, sy, rot, opacity, dash }

/// CSS timing functions used by the avatar SVGs.
abstract final class Ease {
  static const ease = Cubic(0.25, 0.1, 0.25, 1);
  static const inOut = Cubic(0.42, 0, 0.58, 1);
  static const easeIn = Cubic(0.42, 0, 1, 1);
  static const easeOut = Cubic(0, 0, 0.58, 1);
  static const linear = Curves.linear;

  /// steps(1) / jump-end: hold the segment's start value.
  static const step = Threshold(1.0);
}

/// A @keyframes rule: per-property lists of (offset 0..1, value).
class Keyframes {
  const Keyframes(this.tracks);

  final Map<Prop, List<(double, double)>> tracks;

  Anim run(double seconds, {Curve curve = Ease.ease, double delay = 0, bool alternate = false}) =>
      Anim(this, seconds, curve, delay, alternate);
}

/// An `animation:` declaration bound to an element.
class Anim {
  const Anim(this.keyframes, this.duration, this.curve, this.delay, this.alternate);

  final Keyframes keyframes;
  final double duration;
  final Curve curve;
  final double delay;
  final bool alternate;

  double? value(Prop prop, double t) {
    final track = keyframes.tracks[prop];
    if (track == null) return null;
    final local = t - delay;
    final cycles = local / duration;
    final iteration = cycles.floor();
    var p = cycles - iteration;
    if (alternate && iteration.isOdd) p = 1 - p;
    return _sample(track, p);
  }

  double _sample(List<(double, double)> track, double p) {
    if (p <= track.first.$1) return track.first.$2;
    for (var i = 0; i < track.length - 1; i++) {
      final (o0, v0) = track[i];
      final (o1, v1) = track[i + 1];
      if (p <= o1) {
        if (o1 == o0) return v1;
        final eased = curve.transform(((p - o0) / (o1 - o0)).clamp(0.0, 1.0));
        return v0 + (v1 - v0) * eased;
      }
    }
    return track.last.$2;
  }
}

/// Paint attributes for a shape.
class Style {
  const Style({
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.opacity = 1,
    this.fillOpacity = 1,
    this.round = true,
  });

  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
  final double opacity;
  final double fillOpacity;

  /// stroke-linecap/linejoin round (all strokes in the avatar SVGs are round).
  final bool round;
}

sealed class Node {
  const Node();

  /// Fill-box in this node's own coordinate space (ignoring its own animation).
  Rect get bounds;

  void paint(Canvas canvas, double t, double alpha);
}

class Group extends Node {
  Group(
    this.children, {
    this.anims = const [],
    this.origin,
    this.translate = Offset.zero,
    this.rotate = 0,
    this.scale = 1,
  });

  final List<Node> children;
  final List<Anim> anims;

  /// transform-box: fill-box origin as fractions of the bounds (e.g. 0.5, 1 for "50% 100%").
  final Offset? origin;

  /// Static `transform="translate(..) rotate(..)"` attribute.
  final Offset translate;
  final double rotate;
  final double scale;

  @override
  late final Rect bounds = _computeBounds();

  Rect _computeBounds() {
    Rect? r;
    for (final c in children) {
      final b = c is Group ? c.bounds.shift(c.translate) : c.bounds;
      r = r == null ? b : r.expandToInclude(b);
    }
    return r ?? Rect.zero;
  }

  double _prop(Prop p, double t, double base) {
    for (final a in anims) {
      final v = a.value(p, t);
      if (v != null) return v;
    }
    return base;
  }

  @override
  void paint(Canvas canvas, double t, double alpha) {
    final a = alpha * _prop(Prop.opacity, t, 1);
    if (a <= 0.001) return;
    canvas.save();
    if (translate != Offset.zero || rotate != 0 || scale != 1) {
      canvas.translate(translate.dx, translate.dy);
      if (rotate != 0) canvas.rotate(rotate * math.pi / 180);
      if (scale != 1) canvas.scale(scale);
    }
    if (anims.isNotEmpty) {
      final b = bounds;
      final o = origin == null ? Offset.zero : Offset(b.left + b.width * origin!.dx, b.top + b.height * origin!.dy);
      canvas.translate(o.dx, o.dy);
      canvas.translate(_prop(Prop.tx, t, 0), _prop(Prop.ty, t, 0));
      final rot = _prop(Prop.rot, t, 0);
      if (rot != 0) canvas.rotate(rot * math.pi / 180);
      final sx = _prop(Prop.sx, t, 1), sy = _prop(Prop.sy, t, 1);
      if (sx != 1 || sy != 1) canvas.scale(sx == 0 ? 0.0001 : sx, sy == 0 ? 0.0001 : sy);
      canvas.translate(-o.dx, -o.dy);
    }
    for (final c in children) {
      c.paint(canvas, t, a);
    }
    canvas.restore();
  }
}

abstract class Shape extends Node {
  const Shape(this.style);

  final Style style;

  Path get path;

  @override
  void paint(Canvas canvas, double t, double alpha) {
    final a = alpha * style.opacity;
    if (a <= 0.001) return;
    final p = path;
    if (style.fill != null) {
      canvas.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..color = style.fill!.withValues(alpha: style.fill!.a * a * style.fillOpacity),
      );
    }
    if (style.stroke != null) {
      canvas.drawPath(
        p,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.strokeWidth
          ..strokeCap = style.round ? StrokeCap.round : StrokeCap.butt
          ..strokeJoin = style.round ? StrokeJoin.round : StrokeJoin.miter
          ..color = style.stroke!.withValues(alpha: style.stroke!.a * a),
      );
    }
  }
}

class Ellipse extends Shape {
  const Ellipse(this.cx, this.cy, this.rx, this.ry, super.style, {this.rotate = 0});

  final double cx, cy, rx, ry;

  /// `transform="rotate(deg cx cy)"` about the ellipse's own center.
  final double rotate;

  @override
  Path get path {
    final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2));
    final m = Matrix4Lite.rotateAt(rotate, cx, cy);
    return p.transform(m);
  }

  @override
  Rect get bounds {
    final r = rotate * math.pi / 180;
    final hw = math.sqrt(math.pow(rx * math.cos(r), 2) + math.pow(ry * math.sin(r), 2));
    final hh = math.sqrt(math.pow(rx * math.sin(r), 2) + math.pow(ry * math.cos(r), 2));
    return Rect.fromCenter(center: Offset(cx, cy), width: hw * 2, height: hh * 2);
  }
}

class RoundRect extends Shape {
  const RoundRect(this.x, this.y, this.w, this.h, this.r, super.style);

  final double x, y, w, h, r;

  @override
  Path get path => Path()..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)));

  @override
  Rect get bounds => Rect.fromLTWH(x, y, w, h);
}

class PathShape extends Shape {
  PathShape(String d, super.style) : path = parseSvgPath(d);

  @override
  final Path path;

  @override
  Rect get bounds => path.getBounds();
}

/// A stroked path revealed like a `stroke-dasharray`/`stroke-dashoffset` draw-on animation.
/// [Prop.dash] is the dashoffset (0 = fully drawn, [dashArray] = nothing drawn); opacity animates too.
class DrawPath extends Node {
  DrawPath(String d, this.style, {required this.anim, required this.dashArray}) : path = parseSvgPath(d);

  final Style style;
  final Anim anim;
  final double dashArray;
  final Path path;

  @override
  Rect get bounds => path.getBounds();

  @override
  void paint(Canvas canvas, double t, double alpha) {
    final a = alpha * style.opacity * (anim.value(Prop.opacity, t) ?? 1);
    final fraction = 1 - (anim.value(Prop.dash, t) ?? 0) / dashArray;
    if (a <= 0.001 || fraction <= 0) return;
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = style.stroke!.withValues(alpha: style.stroke!.a * a);
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * fraction.clamp(0.0, 1.0)), paint);
    }
  }
}

class TextShape extends Node {
  const TextShape(this.text, this.x, this.y, this.size, this.color, {this.family = 'Fredoka'});

  final String text;
  final double x, y, size;
  final Color color;
  final String family;

  @override
  Rect get bounds => Rect.fromLTWH(x, y - size, size * 0.6, size);

  @override
  void paint(Canvas canvas, double t, double alpha) {
    if (alpha <= 0.001) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: size,
          color: color.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // SVG y is the baseline.
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(x, y - baseline));
  }
}

/// 4x4 column-major matrices for Path.transform.
abstract final class Matrix4Lite {
  static Float64List rotateAt(double deg, double cx, double cy) {
    final r = deg * math.pi / 180;
    final c = math.cos(r), s = math.sin(r);
    return Float64List.fromList([c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, cx, cy, 0, 1]);
  }
}

/// Parses SVG path data (M L H V Q T C S A Z, absolute and relative).
Path parseSvgPath(String d) {
  final tokens = RegExp(r'[MmLlHhVvQqTtCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var cmd = '';
  var cur = Offset.zero, start = Offset.zero;
  Offset? lastQ, lastC;

  bool isCmd(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
  double n() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final base = rel ? cur : Offset.zero;
    Offset pt() {
      final x = n(), y = n();
      return base + Offset(x, y);
    }

    switch (cmd.toUpperCase()) {
      case 'M':
        cur = start = pt();
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L'; // implicit lineto for following pairs
        lastQ = lastC = null;
      case 'L':
        cur = pt();
        path.lineTo(cur.dx, cur.dy);
        lastQ = lastC = null;
      case 'H':
        cur = Offset((rel ? cur.dx : 0) + n(), cur.dy);
        path.lineTo(cur.dx, cur.dy);
        lastQ = lastC = null;
      case 'V':
        cur = Offset(cur.dx, (rel ? cur.dy : 0) + n());
        path.lineTo(cur.dx, cur.dy);
        lastQ = lastC = null;
      case 'Q':
        final c = pt(), e = pt();
        path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
        lastQ = c;
        lastC = null;
        cur = e;
      case 'T':
        final c = lastQ == null ? cur : cur * 2 - lastQ;
        final e = pt();
        path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
        lastQ = c;
        lastC = null;
        cur = e;
      case 'C':
        final c1 = pt(), c2 = pt(), e = pt();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastC = c2;
        lastQ = null;
        cur = e;
      case 'S':
        final c1 = lastC == null ? cur : cur * 2 - lastC;
        final c2 = pt(), e = pt();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastC = c2;
        lastQ = null;
        cur = e;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        final e = pt();
        path.arcToPoint(e, radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
        lastQ = lastC = null;
        cur = e;
      case 'Z':
        path.close();
        cur = start;
        lastQ = lastC = null;
    }
  }
  return path;
}
