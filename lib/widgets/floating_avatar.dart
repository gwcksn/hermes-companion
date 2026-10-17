import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../avatar/avatar_state.dart';
import '../avatar/avatar_view.dart';

/// Avatar that floats over a fullscreen panel. Long-press, then drag to move it.
/// [fx]/[fy] are 0..1 fractions of the free area (parent size minus the avatar).
class FloatingAvatar extends StatefulWidget {
  const FloatingAvatar({
    super.key,
    required this.state,
    required this.fx,
    required this.fy,
    required this.onMoved,
    this.mess = 0,
    this.onTap,
    this.size = 84,
  });

  final AvatarState state;
  final int mess;
  final double fx;
  final double fy;
  final double size;
  final VoidCallback? onTap;
  final void Function(double fx, double fy) onMoved;

  @override
  State<FloatingAvatar> createState() => _FloatingAvatarState();
}

class _FloatingAvatarState extends State<FloatingAvatar> {
  Offset? _drag; // top-left in design dp while dragging
  Offset _start = Offset.zero;
  bool _lifted = false;

  /// Gesture offsets are in screen px; the ScaledStage above scales design dp.
  double _scale() =>
      (context.findRenderObject()?.getTransformTo(null).getMaxScaleOnAxis()) ??
      1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final freeW = (c.maxWidth - widget.size).clamp(0.0, double.infinity);
        final freeH = (c.maxHeight - widget.size).clamp(0.0, double.infinity);
        Offset clamp(Offset o) =>
            Offset(o.dx.clamp(0.0, freeW), o.dy.clamp(0.0, freeH));
        final pos = clamp(_drag ?? Offset(widget.fx * freeW, widget.fy * freeH));
        return Stack(
          children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onLongPressStart: (_) {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _lifted = true;
                    _start = pos;
                    _drag = pos;
                  });
                },
                onLongPressMoveUpdate: (d) => setState(
                  () => _drag = clamp(_start + d.offsetFromOrigin / _scale()),
                ),
                onLongPressEnd: (_) {
                  final end = _drag;
                  setState(() {
                    _lifted = false;
                    _drag = null;
                  });
                  if (end != null) {
                    widget.onMoved(
                      freeW == 0 ? 0 : end.dx / freeW,
                      freeH == 0 ? 0 : end.dy / freeH,
                    );
                  }
                },
                onLongPressCancel: () => setState(() {
                  _lifted = false;
                  _drag = null;
                }),
                child: AnimatedScale(
                  scale: _lifted ? 1.15 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: AvatarView(state: widget.state, size: widget.size, mess: widget.mess),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
