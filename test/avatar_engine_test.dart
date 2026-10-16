import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/avatar/avatar_state.dart';
import 'package:hermes_companion/avatar/engine.dart';
import 'package:hermes_companion/avatar/scenes.dart';

void main() {
  group('keyframes', () {
    const bob = Keyframes({
      Prop.ty: [(0, 0), (0.5, -5), (1, 0)],
    });

    test('samples per-segment with linear timing', () {
      final a = bob.run(2, curve: Ease.linear);
      expect(a.value(Prop.ty, 0), 0);
      expect(a.value(Prop.ty, 0.5), closeTo(-2.5, 1e-9));
      expect(a.value(Prop.ty, 1), closeTo(-5, 1e-9));
      expect(a.value(Prop.ty, 3), closeTo(-5, 1e-9)); // loops
      expect(a.value(Prop.tx, 1), isNull);
    });

    test('alternate reverses odd iterations', () {
      const sweep = Keyframes({
        Prop.tx: [(0, -26), (1, 26)],
      });
      final a = sweep.run(1, curve: Ease.linear, alternate: true);
      expect(a.value(Prop.tx, 0.25), closeTo(-13, 1e-9));
      expect(a.value(Prop.tx, 1.25), closeTo(13, 1e-9));
    });

    test('delay is a phase offset', () {
      final a = bob.run(2, curve: Ease.linear, delay: 1);
      expect(a.value(Prop.ty, 1), 0);
      expect(a.value(Prop.ty, 0), closeTo(-5, 1e-9));
    });

    test('steps(1) holds the segment start', () {
      const ringarc = Keyframes({
        Prop.opacity: [(0, 1), (0.5, 0.15), (1, 1)],
      });
      final a = ringarc.run(0.25, curve: Ease.step);
      expect(a.value(Prop.opacity, 0.1), 1);
      expect(a.value(Prop.opacity, 0.2), 0.15);
    });
  });

  test('path parser handles relative arcs and smooth quads', () {
    final drop = parseSvgPath('M12 3C12 3 5.5 10.5 5.5 15a6.5 6.5 0 0 0 13 0C18.5 10.5 12 3 12 3Z');
    final b = drop.getBounds();
    expect(b.left, closeTo(5.5, 0.01));
    expect(b.right, closeTo(18.5, 0.01));
    expect(b.bottom, closeTo(21.5, 0.01)); // arc dips below y=15 by its radius
    final mouth = parseSvgPath('M92 124 Q96 120 100 124 T108 124');
    expect(mouth.getBounds().right, closeTo(108, 0.01));
  });

  test('all 12 scenes exist and paint across a full cycle', () {
    expect(avatarScenes.keys, containsAll(AvatarState.values));
    for (final scene in avatarScenes.values) {
      for (var t = 0.0; t < 10; t += 0.37) {
        final rec = PictureRecorder();
        scene.paint(Canvas(rec), t, 1);
        rec.endRecording().dispose();
      }
    }
  });
}
