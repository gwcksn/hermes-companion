// Care scenes: pooping, eating, cleaning, hungry, plus the poop-pile overlay. Hand-written in the
// scene engine (no SVG source). Part of scenes.dart to share its private helpers and keyframes.
//
// The one-shot scenes (pooping, eating, cleaning) loop with a period equal to the time the app
// shows them for, and the scene stopwatch starts when the scene mounts, so each plays exactly once.
part of 'scenes.dart';

const poopingFor = Duration(milliseconds: 3500);
const eatingFor = Duration(milliseconds: 3600);
const eatInfoFor = Duration(seconds: 3);
const cleaningFor = Duration(seconds: 4);
const hungryFor = Duration(seconds: 4);

const _poopBrown = Color(0xFF8B5A3C);
const _poopMid = Color(0xFFA06A46);
const _poopLight = Color(0xFFC9946A);
const _stink = Color(0xFF9BC53D);
const _cookie = Color(0xFFD9A066);
const _cookieEdge = Color(0xFFB97A3F);
const _sweat = Color(0xFF8FB8FF);
const _bristle = Color(0xFFE5B567);
const _handle = Color(0xFF9B7B5A);
const _dust = Color(0xFFEDE7F6);
const _bubble = Color(0xFFBFE3FF);

/// Where piles sit, in fill order. The sides are clear of the body; the third overlaps its base.
const poopSlots = [Offset(164, 178), Offset(36, 178), Offset(100, 198)];

/// Opacity window: visible from [a] to [b] (fractions of the loop), instantly in and out.
Keyframes _window(double a, double b) => Keyframes({
  Prop.opacity: [
    if (a > 0) ...[(0, 0), (a, 0), (a + 0.01, 1)] else (0, 1),
    if (b < 1) ...[(b, 1), (b + 0.01, 0), (1, 0)] else (1, 1),
  ],
});

Group _phase(double a, double b, List<Node> kids, double seconds) => Group(
  kids,
  anims: [_window(a, b).run(seconds, curve: Ease.linear)],
  origin: _center,
);

String _drop = 'M0 -6 Q5 2 0 6 Q-5 2 0 -6Z';

/// One pile with its base centre at (0,0), about 34 wide and 36 tall, with stink lines and a fly.
Group _poopPile({double flyDelay = 0}) => Group([
  _e(0, -6, 17, 8, _poopBrown),
  _e(0, -15, 12.5, 6.5, _poopMid),
  _e(0, -23, 8, 5.5, _poopBrown),
  _fill('M-3 -26 Q0 -37 5 -29 Q2 -27 -3 -26Z', _poopBrown),
  _e(-7, -17, 2.8, 1.2, _poopLight, opacity: 0.7, rotate: -20),
  _c(-5, -8, 1.8, AvatarColors.ink),
  _c(5, -8, 1.8, AvatarColors.ink),
  _stroke('M-3 -4 Q0 -2 3 -4', AvatarColors.ink, 1.5),
  for (final (i, x) in [-6.0, 6.0].indexed)
    Group([
      _anim(
        _stroke('M0 0 q-3 -4 0 -8 t0 -8', _stink, 2),
        _steam.run(1.8, curve: Ease.inOut, delay: i * 0.9),
        origin: _center,
      ),
    ], translate: Offset(x, -38)),
  Group([
    Group(
      [_c(13, 0, 1.6, AvatarColors.ink)],
      anims: [_spin.run(1.4, curve: Ease.linear, delay: flyDelay)],
    ),
  ], translate: const Offset(0, -26)),
]);

Group _pileAt(int slot) => Group([_poopPile(flyDelay: slot * 0.5)], translate: poopSlots[slot], scale: 0.9);

/// The piles left on screen, drawn over whatever scene is playing.
final List<Group> messLayers = [
  for (var n = 0; n <= maxPoopSlots; n++) Group([for (var i = 0; i < n; i++) _pileAt(i)]),
];
const maxPoopSlots = 3;

Node _sparkleAt(Offset at, Keyframes kf, double seconds) =>
    Group([_anim(_fill(_starPath, _sparkle), kf.run(seconds, curve: Ease.inOut), origin: _center)], translate: at);

Keyframes _pop1(double start, {double rise = 0}) => Keyframes({
  Prop.sx: [(0, 0), (start, 0), (start + 0.08, 1.15), (start + 0.14, 1), (1, 1)],
  Prop.sy: [(0, 0), (start, 0), (start + 0.08, 1.15), (start + 0.14, 1), (1, 1)],
  Prop.ty: [(0, 0), (1, rise)],
});

Keyframes _glint(double start) => Keyframes({
  Prop.sx: [(0, 0), (start, 0), (start + 0.08, 1), (start + 0.2, 0), (1, 0)],
  Prop.sy: [(0, 0), (start, 0), (start + 0.08, 1), (start + 0.2, 0), (1, 0)],
  Prop.opacity: [(0, 0), (start, 0), (start + 0.08, 1), (start + 0.2, 0), (1, 0)],
});

// ---- pooping ------------------------------------------------------------------

/// Squats and strains, then drops a pile into slot [existing] (the next free one).
Group _pooping(int existing) {
  const d = 3.5;
  final strain = Keyframes({
    Prop.tx: [(0, 0), (0.1, 0), for (var i = 0; i < 10; i++) (0.1 + i * 0.05, i.isEven ? -1.5 : 1.5), (0.6, 0), (1, 0)],
  });
  final squat = Keyframes({
    Prop.sx: [(0, 1), (0.1, 1.04), (0.6, 1.04), (0.7, 0.98), (0.85, 1), (1, 1)],
    Prop.sy: [(0, 1), (0.1, 0.92), (0.6, 0.92), (0.7, 1.04), (0.85, 1), (1, 1)],
  });
  final slot = poopSlots[existing.clamp(0, poopSlots.length - 1)];
  return Group([
    _groundShadow,
    Group(
      [
        ..._wings(seconds: 0.3),
        ..._body(),
        ..._blush(opacity: 0.9, color: HColors.pink),
        _phase(0, 0.62, [
          _stroke('M66 94 L84 100 L66 106', AvatarColors.ink, 4.5),
          _stroke('M134 94 L116 100 L134 106', AvatarColors.ink, 4.5),
          _stroke('M93 121 Q100 116 107 121', AvatarColors.ink, 4),
        ], d),
        _phase(0.62, 1, [..._happyEyes(), _stroke('M88 116 Q100 128 112 116', AvatarColors.ink, 4)], d),
      ],
      anims: [
        squat.run(d, curve: Ease.inOut),
        strain.run(d, curve: Ease.linear),
      ],
      origin: _bottomCenter,
    ),
    _phase(0, 0.62, [
      Group([
        _anim(_fill(_drop, _sweat), _drip.run(1, curve: Ease.easeIn), origin: _center),
      ], translate: const Offset(148, 76)),
    ], d),
    for (var i = 0; i < existing && i < poopSlots.length; i++) _pileAt(i),
    Group([
      _anim(
        Group([_poopPile(flyDelay: existing * 0.5)], scale: 0.9),
        _pop1(0.62).run(d, curve: Ease.inOut),
        origin: _bottomCenter,
      ),
    ], translate: slot),
    _sparkleAt(slot.translate(0, -48), _glint(0.74), d),
  ]);
}

// ---- eating -------------------------------------------------------------------

Group _cookieProp() => Group([
  const Ellipse(0, 0, 11, 11, Style(fill: _cookie, stroke: _cookieEdge, strokeWidth: 1.5)),
  _c(-4, -3, 1.6, _poopBrown),
  _c(3, -4, 1.6, _poopBrown),
  _c(2, 3, 1.6, _poopBrown),
  _c(-4, 4, 1.4, _poopBrown),
]);

/// A cookie flies in, is eaten in three bites, then a happy finish.
Group _eating() {
  const d = 3.6;
  final puff = Keyframes({
    Prop.sx: [
      (0, 1),
      (0.3, 1),
      (0.36, 1.03),
      (0.42, 1),
      (0.48, 1.03),
      (0.54, 1),
      (0.6, 1.03),
      (0.66, 1),
      (0.72, 1.03),
      (0.78, 1),
      (1, 1),
    ],
    Prop.sy: [
      (0, 1),
      (0.3, 1),
      (0.36, 1.03),
      (0.42, 1),
      (0.48, 1.03),
      (0.54, 1),
      (0.6, 1.03),
      (0.66, 1),
      (0.72, 1.03),
      (0.78, 1),
      (1, 1),
    ],
  });
  final fly = Keyframes({
    Prop.tx: [(0, 56), (0.25, 0), (1, 0)],
    Prop.ty: [(0, -90), (0.25, 0), (1, 0)],
    Prop.rot: [(0, -40), (0.25, 0), (1, 0)],
    Prop.sx: [(0, 1), (0.3, 1), (0.38, 0.72), (0.5, 0.72), (0.58, 0.42), (0.68, 0.42), (0.74, 0.12), (0.8, 0), (1, 0)],
    Prop.sy: [(0, 1), (0.3, 1), (0.38, 0.72), (0.5, 0.72), (0.58, 0.42), (0.68, 0.42), (0.74, 0.12), (0.8, 0), (1, 0)],
    Prop.opacity: [(0, 1), (0.79, 1), (0.8, 0), (1, 0)],
  });
  Node crumb(Offset at, double s) => Group([
    _anim(
      _e(0, 0, 2.5, 2, _cookie),
      Keyframes({
        Prop.opacity: [(0, 0), (s, 0), (s + 0.01, 1), (s + 0.1, 0), (1, 0)],
        Prop.ty: [(0, 0), (s, 0), (s + 0.1, 16), (1, 16)],
      }).run(d, curve: Ease.linear),
      origin: _center,
    ),
  ], translate: at);
  return Group([
    _groundShadow,
    Group(
      [
        ..._wings(seconds: 0.5),
        ..._body(),
        ..._blush(),
        _phase(0, 0.8, [
          Group([_blinking(_eyes())], translate: const Offset(0, -3)),
        ], d),
        _phase(0, 0.28, [_e(100, 122, 7, 8, AvatarColors.mouth)], d),
        _phase(0.28, 0.8, [
          Group(
            [_stroke('M90 118 Q100 130 110 118', AvatarColors.ink, 4)],
            anims: [_sing.run(0.3, curve: Ease.inOut, alternate: true)],
            origin: _center,
          ),
        ], d),
        _phase(0.8, 1, [..._happyEyes(), _stroke('M88 116 Q100 128 112 116', AvatarColors.ink, 4)], d),
      ],
      anims: [
        puff.run(d, curve: Ease.inOut),
        _bob.run(1.8, curve: Ease.inOut),
      ],
      origin: _bottomCenter,
    ),
    Group([_anim(_cookieProp(), fly.run(d, curve: Ease.inOut), origin: _center)], translate: const Offset(100, 130)),
    crumb(const Offset(88, 136), 0.38),
    crumb(const Offset(112, 134), 0.58),
    crumb(const Offset(100, 142), 0.74),
    Group([
      _anim(
        _fill(_heartPath, HColors.pink),
        Keyframes({
          Prop.ty: [(0, 10), (0.8, 10), (1, -26)],
          Prop.sx: [(0, 0.6), (0.8, 0.6), (1, 1.1)],
          Prop.sy: [(0, 0.6), (0.8, 0.6), (1, 1.1)],
          Prop.opacity: [(0, 0), (0.8, 0), (0.84, 1), (1, 0)],
        }).run(d, curve: Ease.easeOut),
        origin: _center,
      ),
    ], translate: const Offset(146, 66)),
  ]);
}

// ---- hungry -------------------------------------------------------------------

/// Wistful look at a cookie in a thought bubble, tummy rumbling. Never sad or sick.
Group _hungry() => Group([
  _groundShadow,
  Group(
    [
      ..._wings(seconds: 3),
      _e(100, 108, 68, 66, AvatarColors.body),
      Group([_e(100, 134, 40, 28, AvatarColors.belly)], anims: [_jit.run(0.14, curve: Ease.linear)]),
      _stroke(_tuftPath, AvatarColors.tuft, 6),
      ..._blush(),
      _stroke('M64 90 L86 82', AvatarColors.ink, 4),
      _stroke('M114 82 L136 90', AvatarColors.ink, 4),
      Group([_blinking(_eyes())], translate: const Offset(5, -5)),
      _e(100, 122, 4, 5, AvatarColors.mouth),
    ],
    anims: [_bob.run(2.4, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
  _anim(_stroke('M168 134 Q174 140 168 146', _stink, 3), _arcr.run(0.9, curve: Ease.inOut), origin: _center),
  _anim(_stroke('M32 134 Q26 140 32 146', _stink, 3), _arcl.run(0.9, curve: Ease.inOut), origin: _center),
  _c(150, 52, 4, _thought),
  _c(158, 40, 6, _thought),
  _e(166, 20, 30, 18, _thought),
  Group([_anim(_cookieProp(), _pulse.run(1.2, curve: Ease.inOut), origin: _center)], translate: const Offset(166, 20)),
]);

// ---- cleaning -----------------------------------------------------------------

/// A broom sweeps the ground right to left; each of [piles] shrinks as it passes. Sparkles at the end.
Group _cleaning(int piles) {
  const d = 4.0;
  // Broom x runs 200 -> 10 over 0.12..0.64; it reaches x=164, 100, 36 at these loop fractions.
  const reach = [0.22, 0.57, 0.39];
  final broom = Keyframes({
    Prop.tx: [(0, 200), (0.12, 200), (0.64, 10), (0.72, -30), (1, -30)],
    Prop.opacity: [(0, 0), (0.1, 0), (0.14, 1), (0.68, 1), (0.74, 0), (1, 0)],
  });
  final nodes = <Node>[];
  for (var i = 0; i < piles && i < poopSlots.length; i++) {
    final t = reach[i];
    nodes.add(
      Group([
        _anim(
          Group([_poopPile(flyDelay: i * 0.5)], scale: 0.9),
          Keyframes({
            Prop.sx: [(0, 1), (t, 1), (t + 0.1, 0), (1, 0)],
            Prop.sy: [(0, 1), (t, 1), (t + 0.1, 0), (1, 0)],
            Prop.opacity: [(0, 1), (t + 0.06, 1), (t + 0.1, 0), (1, 0)],
          }).run(d, curve: Ease.inOut),
          origin: _bottomCenter,
        ),
      ], translate: poopSlots[i]),
    );
    nodes.add(
      Group(
        [
          for (final o in const [Offset(-8, 0), Offset(8, -4), Offset(0, -10)]) _c(o.dx, o.dy, 7, _dust),
        ],
        translate: poopSlots[i].translate(0, -12),
        anims: [
          Keyframes({
            Prop.sx: [(0, 0.2), (t + 0.02, 0.2), (t + 0.14, 1.4), (1, 1.4)],
            Prop.sy: [(0, 0.2), (t + 0.02, 0.2), (t + 0.14, 1.4), (1, 1.4)],
            Prop.opacity: [(0, 0), (t + 0.02, 0), (t + 0.04, 0.8), (t + 0.16, 0), (1, 0)],
          }).run(d, curve: Ease.inOut),
        ],
        origin: _center,
      ),
    );
  }
  return Group([
    _groundShadow,
    Group(
      [
        ..._wings(seconds: 0.5),
        ..._body(),
        ..._blush(opacity: 0.85, color: HColors.pink),
        ..._happyEyes(),
        _stroke('M86 114 Q100 134 114 114', AvatarColors.ink, 4),
      ],
      anims: [_hop.run(2, curve: Ease.inOut)],
      origin: _bottomCenter,
    ),
    ...nodes,
    Group(
      [
        _stroke('M10 128 L2 174', _handle, 4),
        PathShape('M-10 174 L14 174 L18 192 L-14 192 Z', const Style(fill: _bristle)),
        _stroke('M-4 178 L-5 190 M3 178 L3 190 M9 178 L10 190', _cookieEdge, 1.5),
      ],
      anims: [broom.run(d, curve: Ease.linear)],
    ),
    for (final (at, s) in [(const Offset(40, 70), 0.74), (const Offset(160, 60), 0.8), (const Offset(100, 22), 0.86)])
      _sparkleAt(at, _glint(s), d),
    for (final (i, x) in [60.0, 90.0, 124.0, 150.0].indexed)
      Group([
        _anim(
          Ellipse(0, 0, 4, 4, const Style(stroke: _bubble, strokeWidth: 1.5)),
          Keyframes({
            Prop.ty: [(0, 0), (1, -34)],
            Prop.opacity: [(0, 0), (0.2, 0.9), (0.8, 0.9), (1, 0)],
          }).run(1.4, curve: Ease.linear, delay: i * 0.35),
          origin: _center,
        ),
      ], translate: Offset(x, 170)),
  ]);
}

final List<Group> poopingScenes = [for (var n = 0; n < 3; n++) _pooping(n)];
final List<Group> cleaningScenes = [for (var n = 0; n <= 3; n++) _cleaning(n)];

// ---- icons --------------------------------------------------------------------

/// A prop drawn on its own for use as button art, with the box it should be fitted to.
class PropIcon {
  const PropIcon(this.group, this.box);

  final Group group;
  final Rect box;
}

/// The cookie from the eating scene.
final PropIcon cookieIcon = PropIcon(
  Group([_cookieProp()]),
  Rect.fromCenter(center: Offset.zero, width: 26, height: 26),
);

/// The broom from the cleaning scene, upright.
final PropIcon broomIcon = PropIcon(
  Group([
    _stroke('M7 -13 L1 2', _handle, 3.5),
    PathShape('M-8 2 L10 2 L13 14 L-11 14 Z', const Style(fill: _bristle)),
    _stroke('M-4 5 L-5 13 M1 5 L1 13 M6 5 L7 13', _cookieEdge, 1.5),
  ]),
  const Rect.fromLTRB(-12, -15, 15, 15),
);
