import 'dart:async';

import 'package:flutter/material.dart';

import 'avatar_state.dart';
import 'engine.dart';
import 'scenes.dart';

/// The animated Hermes avatar. Changing [state] crossfades to the new scene in 200 ms.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.state, this.size = 190});

  final AvatarState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hermes avatar, ${state.label.toLowerCase()}',
      child: SizedBox.square(
        dimension: size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          // Stack both scenes in place, no layout shift.
          layoutBuilder: (current, previous) => Stack(children: [...previous, ?current]),
          child: _SceneView(key: ValueKey(state), scene: avatarScenes[state]!, fps: state.fps, size: size),
        ),
      ),
    );
  }
}

class _SceneView extends StatefulWidget {
  const _SceneView({super.key, required this.scene, required this.fps, required this.size});

  final Group scene;
  final int fps;
  final double size;

  @override
  State<_SceneView> createState() => _SceneViewState();
}

/// Repaints from a timer at the state's [AvatarState.fps] rather than on every vsync:
/// on the always-on S8 each frame is GPU-driver work, so fewer frames means less heat.
class _SceneViewState extends State<_SceneView> {
  final _time = ValueNotifier<double>(0);
  final _clock = Stopwatch();
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pause under prefers-reduced-motion (hold the first frame) and while the route is hidden.
    final run = !MediaQuery.disableAnimationsOf(context) && TickerMode.valuesOf(context).enabled;
    if (run && _timer == null) {
      _clock.start();
      _timer = Timer.periodic(
        Duration(microseconds: 1000000 ~/ widget.fps),
        (_) => _time.value = _clock.elapsedMicroseconds / 1e6,
      );
    } else if (!run && _timer != null) {
      _clock.stop();
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(size: Size.square(widget.size), painter: _ScenePainter(widget.scene, _time)),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.time) : super(repaint: time);

  final Group scene;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    // SVG overflow: visible — no clipping, so rings/notes may draw past the 200x200 box.
    canvas.scale(size.width / 200, size.height / 200);
    scene.paint(canvas, time.value, 1);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene;
}
