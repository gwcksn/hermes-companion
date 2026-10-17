// The 21 avatar states (12 core + 9 idle activities), ported 1:1 from assets/avatar/*.svg (200x200 viewBox).
// Keyframes and timings are copied from each SVG's <style>; see engine.dart for semantics.
import 'package:flutter/painting.dart';

import '../theme/tokens.dart';
import 'avatar_state.dart';
import 'engine.dart';

part 'scenes_care.dart';
part 'scenes_pet.dart';

// ---- @keyframes -------------------------------------------------------------

const _bob = Keyframes({
  Prop.ty: [(0, 0), (0.5, -5), (1, 0)],
});
const _bobfast = Keyframes({
  Prop.ty: [(0, 0), (0.5, -3), (1, 0)],
});
const _tilt = Keyframes({
  Prop.rot: [(0, -3), (0.5, 3), (1, -3)],
});
const _thinktilt = Keyframes({
  Prop.rot: [(0, 2), (0.5, 7), (1, 2)],
});
const _breathe = Keyframes({
  Prop.sx: [(0, 1), (0.5, 1.02), (1, 1)],
  Prop.sy: [(0, 1), (0.5, 1.05), (1, 1)],
});
const _hop = Keyframes({
  Prop.ty: [(0, 0), (0.12, 0), (0.45, -22), (0.75, 0), (1, 0)],
  Prop.sx: [(0, 1), (0.12, 1.06), (0.45, 0.96), (0.75, 1.05), (1, 1)],
  Prop.sy: [(0, 1), (0.12, 0.92), (0.45, 1.06), (0.75, 0.94), (1, 1)],
});
const _shake = Keyframes({
  Prop.tx: [(0, 0), (0.6, 0), (0.65, -3), (0.7, 3), (0.75, -3), (0.8, 3), (0.85, -2), (0.9, 0), (1, 0)],
});
const _blink = Keyframes({
  Prop.sy: [(0, 1), (0.92, 1), (0.96, 0.1), (1, 1)],
});
const _look = Keyframes({
  Prop.tx: [(0, 0), (0.3, 0), (0.38, -4), (0.55, -4), (0.63, 4), (0.8, 4), (1, 0)],
});
const _wingL = Keyframes({
  Prop.rot: [(0, 0), (0.5, 10), (1, 0)],
});
const _wingR = Keyframes({
  Prop.rot: [(0, 0), (0.5, -10), (1, 0)],
});
const _ring = Keyframes({
  Prop.opacity: [(0, 0.5), (1, 0)],
  Prop.sx: [(0, 0.96), (1, 1.08)],
  Prop.sy: [(0, 0.96), (1, 1.08)],
});
const _dot = Keyframes({
  Prop.opacity: [(0, 0.25), (0.2, 1), (0.6, 0.25), (1, 0.25)],
});
const _spin = Keyframes({
  Prop.rot: [(0, 0), (1, 360)],
});
const _code = Keyframes({
  Prop.sx: [(0, 0.25), (0.6, 1), (1, 1)],
});
const _sweep = Keyframes({
  Prop.tx: [(0, -26), (1, 26)],
});
const _follow = Keyframes({
  Prop.tx: [(0, -4), (1, 4)],
});
const _talk = Keyframes({
  Prop.sy: [(0, 0.25), (1, 1)],
});
const _arcr = Keyframes({
  Prop.opacity: [(0, 0), (0.4, 1), (1, 0)],
  Prop.tx: [(0, 0), (1, 6)],
});
const _arcl = Keyframes({
  Prop.opacity: [(0, 0), (0.4, 1), (1, 0)],
  Prop.tx: [(0, 0), (1, -6)],
});
const _twinkle = Keyframes({
  Prop.sx: [(0, 0), (0.5, 1), (1, 0)],
  Prop.sy: [(0, 0), (0.5, 1), (1, 0)],
  Prop.opacity: [(0, 0), (0.5, 1), (1, 0)],
});
const _popScale = [(0.0, 0.0), (0.1, 0.0), (0.22, 1.2), (0.3, 1.0), (0.85, 1.0), (1.0, 0.0)];
const _pop = Keyframes({Prop.sx: _popScale, Prop.sy: _popScale});
const _drip = Keyframes({
  Prop.ty: [(0, 0), (0.8, 16), (1, 16)],
  Prop.opacity: [(0, 1), (0.8, 0), (1, 0)],
});
const _pulse = Keyframes({
  Prop.sx: [(0, 1), (0.5, 1.12), (1, 1)],
  Prop.sy: [(0, 1), (0.5, 1.12), (1, 1)],
});
const _zfloat = Keyframes({
  Prop.tx: [(0, 0), (1, 18)],
  Prop.ty: [(0, 0), (1, -26)],
  Prop.opacity: [(0, 0), (0.2, 1), (1, 0)],
});
const _sway = Keyframes({
  Prop.rot: [(0, -4), (0.5, 4), (1, -4)],
});
const _heart = Keyframes({
  Prop.ty: [(0, 10), (1, -34)],
  Prop.sx: [(0, 0.6), (1, 1.1)],
  Prop.sy: [(0, 0.6), (1, 1.1)],
  Prop.opacity: [(0, 0), (0.2, 1), (1, 0)],
});
const _jit = Keyframes({
  Prop.tx: [(0, 0), (0.25, -1.5), (0.75, 1.5), (1, 0)],
});
const _ringclk = Keyframes({
  Prop.rot: [(0, -9), (0.5, 9), (1, -9)],
});
const _ringarc = Keyframes({
  Prop.opacity: [(0, 1), (0.5, 0.15), (1, 1)],
});
const _notefloat = Keyframes({
  Prop.tx: [(0, 0), (1, 10)],
  Prop.ty: [(0, 10), (1, -34)],
  Prop.rot: [(0, 0), (1, 15)],
  Prop.opacity: [(0, 0), (0.15, 1), (1, 0)],
});
const _sing = Keyframes({
  Prop.sy: [(0, 0.5), (1, 1)],
});

// idle activities
const _sip = Keyframes({
  Prop.ty: [(0, 0), (0.12, 0), (0.3, -14), (0.58, -14), (0.78, 0), (1, 0)],
  Prop.rot: [(0, 0), (0.12, 0), (0.3, -5), (0.58, -5), (0.78, 0), (1, 0)],
});
const _steam = Keyframes({
  Prop.ty: [(0, 3), (1, -6)],
  Prop.opacity: [(0, 0), (0.3, 0.8), (1, 0)],
});
const _scan = Keyframes({
  Prop.tx: [(0, -6), (0.08, -6), (0.46, 6), (0.54, 6), (0.6, -6), (1, -6)],
});
const _flip = Keyframes({
  Prop.sx: [(0, 1), (0.55, 1), (0.78, -1), (0.92, -1), (1, 1)],
  Prop.opacity: [(0, 1), (0.55, 1), (0.78, 1), (0.92, 0), (1, 0)],
});
const _starfall = Keyframes({
  Prop.tx: [(0, 0), (0.62, 0), (0.92, -62), (1, -62)],
  Prop.ty: [(0, 0), (0.62, 0), (0.92, 48), (1, 48)],
  Prop.opacity: [(0, 0), (0.62, 0), (0.68, 1), (0.92, 0), (1, 0)],
});
const _lookup = Keyframes({
  Prop.rot: [(0, -4), (0.5, 3), (1, -4)],
});
const _levitate = Keyframes({
  Prop.ty: [(0, 0), (0.5, -9), (1, 0)],
});
const _shadowfloat = Keyframes({
  Prop.sx: [(0, 1), (0.5, 0.78), (1, 1)],
  Prop.sy: [(0, 1), (0.5, 0.78), (1, 1)],
  Prop.opacity: [(0, 0.4), (0.5, 0.22), (1, 0.4)],
});
const _aura = Keyframes({
  Prop.sx: [(0, 0.96), (0.5, 1.08), (1, 0.96)],
  Prop.sy: [(0, 0.96), (0.5, 1.08), (1, 0.96)],
  Prop.opacity: [(0, 0.14), (0.5, 0.28), (1, 0.14)],
});
const _orb = Keyframes({
  Prop.ty: [(0, 0), (1, -44)],
  Prop.opacity: [(0, 0), (0.2, 0.9), (1, 0)],
});
const _mash = Keyframes({
  Prop.ty: [(0, 0), (0.5, 1.6), (1, 0)],
});
const _gamehero = Keyframes({
  Prop.tx: [(0, 0), (0.5, 38), (1, 0)],
});
const _gameenemy = Keyframes({
  Prop.tx: [(0, 0), (1, -14)],
});
const _tongue = Keyframes({
  Prop.tx: [(0, 0), (0.5, 3), (1, 0)],
});
const _draw = Keyframes({
  Prop.dash: [(0, 90), (0.4, 0), (0.8, 0), (1, 0)],
  Prop.opacity: [(0, 1), (0.8, 1), (0.95, 0), (1, 0)],
});
const _draw2 = Keyframes({
  Prop.dash: [(0, 60), (0.35, 60), (0.65, 0), (0.8, 0), (1, 0)],
  Prop.opacity: [(0, 1), (0.8, 1), (0.95, 0), (1, 0)],
});
const _pencil = Keyframes({
  Prop.tx: [(0, -14), (0.2, 8), (0.4, 6), (0.6, -4), (0.8, 14), (1, -14)],
  Prop.ty: [(0, 6), (0.2, -6), (0.4, 8), (0.6, 2), (0.8, 6), (1, 6)],
  Prop.rot: [(0, -6), (0.2, 4), (0.4, -3), (0.6, 0), (0.8, 5), (1, -6)],
});
const _stBody = Keyframes({
  Prop.sx: [(0, 1), (0.22, 1), (0.38, 0.95), (0.66, 0.95), (0.76, 1.03), (0.82, 1), (1, 1)],
  Prop.sy: [(0, 1), (0.22, 1), (0.38, 1.1), (0.66, 1.1), (0.76, 0.97), (0.82, 1), (1, 1)],
  Prop.rot: [(0, 0), (0.76, 0), (0.82, -3), (0.86, 3), (0.9, -2), (0.94, 0), (1, 0)],
});
Keyframes _stWing(double dir) => Keyframes({
  Prop.tx: [(0, 0), (0.22, 0), (0.38, 8 * dir), (0.66, 8 * dir), (0.76, 0), (1, 0)],
  Prop.ty: [(0, 0), (0.22, 0), (0.38, -18), (0.66, -18), (0.76, 0), (1, 0)],
  Prop.rot: [(0, 0), (0.22, 0), (0.38, -42 * dir), (0.66, -42 * dir), (0.76, 0), (1, 0)],
  Prop.sx: [(0, 1), (0.22, 1), (0.38, 1.25), (0.66, 1.25), (0.76, 1), (1, 1)],
  Prop.sy: [(0, 1), (0.22, 1), (0.38, 1.25), (0.66, 1.25), (0.76, 1), (1, 1)],
});
final _stWl = _stWing(-1);
final _stWr = _stWing(1);
const _stOpen = Keyframes({
  Prop.opacity: [(0, 1), (0.3, 1), (0.34, 0), (0.7, 0), (0.74, 1), (1, 1)],
});
const _stShut = Keyframes({
  Prop.opacity: [(0, 0), (0.3, 0), (0.34, 1), (0.7, 1), (0.74, 0), (1, 0)],
});
const _cycle = Keyframes({
  Prop.sx: [(0, 0.6), (0.05, 1), (0.28, 1), (0.33, 0.6), (1, 0.6)],
  Prop.sy: [(0, 0.6), (0.05, 1), (0.28, 1), (0.33, 0.6), (1, 0.6)],
  Prop.opacity: [(0, 0), (0.05, 1), (0.28, 1), (0.33, 0), (1, 0)],
});
const _daydrift = Keyframes({
  Prop.ty: [(0, 0), (0.5, -3), (1, 0)],
});
const _peek = Keyframes({
  Prop.tx: [(0, 0), (0.18, 0), (0.26, 7), (0.6, 7), (0.7, 0), (1, 0)],
  Prop.ty: [(0, 0), (0.18, 0), (0.26, -7), (0.6, -7), (0.7, 0), (1, 0)],
});
const _peeknod = Keyframes({
  Prop.ty: [(0, 0), (0.68, 0), (0.74, 5), (0.8, 0), (0.86, 4), (0.92, 0), (1, 0)],
});

// transform-box: fill-box origins
const _bottomCenter = Offset(0.5, 1); // .g
const _center = Offset(0.5, 0.5); // .c
const _rightMid = Offset(1, 0.5); // .wl
const _leftMid = Offset(0, 0.5); // .wr, .code

// ---- palette (SVG colors not in tokens.json) ---------------------------------

const _shadow = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _laptop = Color(0xFF3A3650);
const _sparkle = Color(0xFFFFE27A);
const _alertInk = Color(0xFF2B0F0D);
const _clockOrange = Color(0xFFFF9F6B);
const _clockFace = Color(0xFFFDF6E3);
const _notePink = Color(0xFFFF9ACD);
const _thought = HColors.text;
const _cup = Color(0xFFF4F0EA);
const _coffeeDrink = Color(0xFF7A5240);
const _foam = Color(0xFFF4E3C8);
const _pageShade = Color(0xFFE8E2F5);
const _moon = Color(0xFFFFE9A8);
const _gameGround = Color(0xFF2A5A48);
const _clay = Color(0xFFC98F63);

// ---- shape helpers -----------------------------------------------------------

Ellipse _e(double cx, double cy, double rx, double ry, Color fill, {double opacity = 1, double rotate = 0}) => Ellipse(
  cx,
  cy,
  rx,
  ry,
  Style(fill: fill, opacity: opacity),
  rotate: rotate,
);

Ellipse _c(double cx, double cy, double r, Color fill) => _e(cx, cy, r, r, fill);

PathShape _stroke(String d, Color color, double width, {double opacity = 1}) =>
    PathShape(d, Style(stroke: color, strokeWidth: width, opacity: opacity));

PathShape _fill(String d, Color color) => PathShape(d, Style(fill: color));

Group _anim(Node child, Anim anim, {Offset? origin}) => Group([child], anims: [anim], origin: origin);

Node get _groundShadow => _e(100, 186, 52, 7, _shadow, opacity: 0.4);

const _tuftPath = 'M88 44 Q92 28 100 36 Q108 28 112 44';

List<Node> _wings({double rotate = 18, double cy = 112, Color color = AvatarColors.wing, double seconds = 4}) => [
  Group(
    [_e(34, cy, 16, 30, color, rotate: -rotate)],
    anims: [_wingL.run(seconds, curve: Ease.inOut)],
    origin: _rightMid,
  ),
  Group(
    [_e(166, cy, 16, 30, color, rotate: rotate)],
    anims: [_wingR.run(seconds, curve: Ease.inOut)],
    origin: _leftMid,
  ),
];

List<Node> _body({Color body = AvatarColors.body, Color belly = AvatarColors.belly, Color tuft = AvatarColors.tuft}) =>
    [_e(100, 108, 68, 66, body), _e(100, 134, 40, 28, belly), _stroke(_tuftPath, tuft, 6)];

List<Node> _blush({
  double cy = 118,
  double opacity = 0.65,
  double dx = 57,
  double rx = 10,
  double ry = 6,
  Color color = AvatarColors.blush,
}) => [_e(dx, cy, rx, ry, color, opacity: opacity), _e(200 - dx, cy, rx, ry, color, opacity: opacity)];

/// Open eyes with highlights: ink ellipses at (76|124, cy), highlights offset (+3, -hy).
List<Node> _eyes({double cy = 98, double rx = 9, double ry = 12, double hr = 3.5, double hy = 5}) => [
  _e(76, cy, rx, ry, AvatarColors.ink),
  _e(124, cy, rx, ry, AvatarColors.ink),
  _c(79, cy - hy, hr, _white),
  _c(127, cy - hy, hr, _white),
];

Group _blinking(List<Node> eyes) => Group(eyes, anims: [_blink.run(5)], origin: _center);

/// ^ ^ happy eyes.
List<Node> _happyEyes({double peak = 90}) => [
  _stroke('M66 102 Q76 $peak 86 102', AvatarColors.ink, 5),
  _stroke('M114 102 Q124 $peak 134 102', AvatarColors.ink, 5),
];

Group _root(
  Anim bodyAnim,
  List<Node> body, {
  List<Node> before = const [],
  List<Node> after = const [],
  Node? shadow,
}) => Group([
  ...before,
  shadow ?? _groundShadow,
  Group(body, anims: [bodyAnim], origin: _bottomCenter),
  ...after,
]);

// ---- scenes ------------------------------------------------------------------

Group _idle() => _root(_bob.run(3.4, curve: Ease.inOut), [
  ..._wings(),
  ..._body(),
  ..._blush(),
  Group(
    [_blinking(_eyes())],
    anims: [_look.run(9, curve: Ease.inOut)],
    origin: _center,
  ),
  _stroke('M91 116 Q100 126 109 116', AvatarColors.ink, 4),
]);

Group _listening() {
  Node ring(double r, double w, double delay) => _anim(
    Ellipse(100, 108, r, r, Style(stroke: HColors.mint, strokeWidth: w)),
    _ring.run(2, curve: Ease.easeOut, delay: delay),
    origin: _center,
  );
  return _root(
    _tilt.run(3, curve: Ease.inOut),
    [
      ..._body(),
      _stroke('M36 100 Q36 36 100 36 Q164 36 164 100', HColors.mint, 8),
      const RoundRect(24, 86, 18, 34, 9, Style(fill: HColors.mint)),
      const RoundRect(158, 86, 18, 34, 9, Style(fill: HColors.mint)),
      ..._blush(cy: 122),
      _blinking([..._eyes(cy: 100, rx: 10, ry: 14, hr: 4, hy: 6), _c(72, 106, 2, _white), _c(120, 106, 2, _white)]),
      _e(100, 124, 4, 5, AvatarColors.mouth),
    ],
    before: [ring(84, 3, 0), ring(96, 2, 1)],
  );
}

Group _thinking() => _root(
  _thinktilt.run(3.6, curve: Ease.inOut),
  [
    ..._wings(),
    ..._body(),
    ..._blush(),
    _stroke('M64 86 Q74 82 84 86', AvatarColors.ink, 4),
    _stroke('M114 80 Q124 70 134 76', AvatarColors.ink, 4),
    Group([_blinking(_eyes())], translate: const Offset(5, -5)),
    _stroke('M92 124 Q96 120 100 124 T108 124', AvatarColors.ink, 4),
  ],
  after: [
    _c(150, 52, 4, _thought),
    _c(158, 40, 6, _thought),
    _e(166, 20, 30, 18, _thought),
    for (final (i, x) in [154.0, 166.0, 178.0].indexed)
      _anim(_c(x, 20, 4, AvatarColors.ink), _dot.run(1.2, curve: Ease.inOut, delay: i * 0.2)),
  ],
);

Group _working() => _root(
  _bobfast.run(0.5, curve: Ease.inOut),
  [
    ..._wings(seconds: 0.35),
    ..._body(),
    ..._blush(),
    _stroke('M64 84 L86 89', AvatarColors.ink, 4),
    _stroke('M114 89 L136 84', AvatarColors.ink, 4),
    _e(76, 100, 9, 7, AvatarColors.ink),
    _e(124, 100, 9, 7, AvatarColors.ink),
    _c(79, 98, 2.5, _white),
    _c(127, 98, 2.5, _white),
    _stroke('M95 119 H105', AvatarColors.ink, 4),
    const RoundRect(58, 128, 84, 46, 8, Style(fill: _laptop)),
    const RoundRect(64, 134, 72, 34, 5, Style(fill: HColors.onMint)),
    for (final (i, (y, w)) in [(140.0, 30.0), (149.0, 46.0), (158.0, 22.0)].indexed)
      _anim(
        RoundRect(70, y, w, 4, 2, const Style(fill: HColors.mint)),
        _code.run(1.6, curve: Ease.inOut, delay: i * 0.5),
        origin: _leftMid,
      ),
    const RoundRect(50, 172, 100, 8, 4, Style(fill: HColors.dim)),
  ],
  after: [
    Group([
      Group(
        [
          const Ellipse(0, 0, 9, 9, Style(stroke: HColors.amber, strokeWidth: 4)),
          _stroke(
            'M0 -16V-11M0 11V16M-16 0H-11M11 0H16M-11.3 -11.3L-8 -8M8 8L11.3 11.3M11.3 -11.3L8 -8M-8 8L-11.3 11.3',
            HColors.amber,
            4,
          ),
        ],
        anims: [_spin.run(3, curve: Ease.linear)],
        origin: _center,
      ),
    ], translate: const Offset(164, 38)),
  ],
);

Group _searching() => _root(
  _bob.run(3.4, curve: Ease.inOut),
  [
    ..._wings(),
    ..._body(),
    ..._blush(),
    Group(
      [_blinking(_eyes(rx: 10, ry: 13, hr: 4, hy: 6))],
      anims: [_follow.run(1.8, curve: Ease.inOut, alternate: true)],
    ),
    _e(100, 120, 4, 5, AvatarColors.mouth),
  ],
  after: [
    Group(
      [
        _stroke('M112 158L130 176', HColors.mint, 7),
        const Ellipse(
          100,
          146,
          18,
          18,
          Style(fill: HColors.mint, fillOpacity: 0.18, stroke: HColors.mint, strokeWidth: 5),
        ),
        _stroke('M90 140 Q93 134 99 133', _white, 3, opacity: 0.8),
      ],
      anims: [_sweep.run(1.8, curve: Ease.inOut, alternate: true)],
    ),
  ],
);

Group _speaking() {
  Node arc(String d, Keyframes k, double delay) =>
      _anim(_stroke(d, HColors.mint, 4), k.run(1.2, curve: Ease.easeOut, delay: delay));
  return _root(
    _bobfast.run(0.7, curve: Ease.inOut),
    [
      ..._wings(seconds: 1.2),
      ..._body(),
      ..._blush(),
      _blinking(_eyes()),
      Group(
        [_e(100, 122, 10, 8, AvatarColors.mouth), _e(100, 126, 5, 3, AvatarColors.blush)],
        anims: [_talk.run(0.4, curve: Ease.inOut, alternate: true)],
        origin: _center,
      ),
    ],
    after: [
      arc('M178 86Q190 100 178 114', _arcr, 0),
      arc('M188 74Q204 100 188 126', _arcr, 0.3),
      arc('M22 86Q10 100 22 114', _arcl, 0),
      arc('M12 74Q-4 100 12 126', _arcl, 0.3),
    ],
  );
}

const _starPath = 'M0 -9L2.5 -2.5L9 0L2.5 2.5L0 9L-2.5 2.5L-9 0L-2.5 -2.5Z';

Group _done() => _root(
  _hop.run(1.4, curve: Ease.inOut),
  [
    ..._wings(seconds: 0.45),
    ..._body(),
    ..._blush(opacity: 0.8),
    ..._happyEyes(),
    PathShape(
      'M86 114 Q100 138 114 114 Z',
      const Style(fill: AvatarColors.mouth, stroke: AvatarColors.mouth, strokeWidth: 3),
    ),
  ],
  after: [
    for (final (i, at) in [const Offset(30, 44), const Offset(172, 62), const Offset(148, 20)].indexed)
      Group([
        _anim(
          _fill(_starPath, _sparkle),
          _twinkle.run(1.6, curve: Ease.inOut, delay: i * 0.5),
          origin: _center,
        ),
      ], translate: at),
    Group([
      Group(
        [_c(0, 0, 14, HColors.mint), _stroke('M-6 0L-2 4L6 -4', HColors.onMint, 3.5)],
        anims: [_pop.run(2.8, curve: Ease.inOut)],
        origin: _center,
      ),
    ], translate: const Offset(162, 158)),
  ],
);

Group _oops() => _root(
  _shake.run(2.4, curve: Ease.inOut),
  [
    ..._wings(rotate: 8, seconds: 7),
    ..._body(),
    ..._blush(opacity: 0.4),
    _stroke('M64 88L86 80', AvatarColors.ink, 4),
    _stroke('M114 80L136 88', AvatarColors.ink, 4),
    _blinking(_eyes(cy: 100)),
    _stroke('M89 126Q94 120 100 126T111 126', AvatarColors.ink, 4),
    _anim(
      _fill('M144 64C144 64 137 74 137 79A7 7 0 0 0 151 79C151 74 144 64 144 64Z', HColors.sky),
      _drip.run(1.6, curve: Ease.easeIn),
    ),
  ],
  after: [
    Group([
      Group(
        [_c(0, 0, 16, HColors.coral), _stroke('M0 -8V3', _alertInk, 4), _c(0, 9, 2.4, _alertInk)],
        anims: [_pulse.run(0.8, curve: Ease.inOut)],
        origin: _center,
      ),
    ], translate: const Offset(166, 36)),
  ],
);

Group _sleeping() {
  Node z(String ch, double size, double delay) =>
      _anim(TextShape(ch, 150, 52, size, HColors.lavender), _zfloat.run(3.2, curve: Ease.easeIn, delay: delay));
  return _root(
    _breathe.run(4.2, curve: Ease.inOut),
    [
      ..._wings(rotate: 10, cy: 116, color: const Color(0xFFE9D3B2), seconds: 8),
      ..._body(body: const Color(0xFFE8C49A), belly: const Color(0xFFF0DCC0), tuft: const Color(0xFFD9A574)),
      ..._blush(opacity: 0.5, color: const Color(0xFFE88A94)),
      _stroke('M66 100Q76 108 86 100', AvatarColors.ink, 4),
      _stroke('M114 100Q124 108 134 100', AvatarColors.ink, 4),
      _stroke('M95 120Q100 124 105 120', AvatarColors.ink, 3.5),
    ],
    after: [z('z', 18, 0), z('z', 24, 1.07), z('Z', 30, 2.13)],
  );
}

const _heartPath = 'M0 4C-8 -4 -10 -12 -4 -14C-1 -15 0 -12 0 -10C0 -12 1 -15 4 -14C10 -12 8 -4 0 4Z';

Group _happy() => _root(
  _sway.run(1.6, curve: Ease.inOut),
  [
    ..._wings(seconds: 0.6),
    ..._body(),
    ..._blush(dx: 55, rx: 12, ry: 7, opacity: 0.9, color: HColors.pink),
    ..._happyEyes(),
    _stroke('M84 114 Q100 132 116 114', AvatarColors.ink, 4),
  ],
  after: [
    for (final (i, at) in [const Offset(152, 66), const Offset(46, 76), const Offset(104, 28)].indexed)
      Group([
        _anim(
          _fill(_heartPath, HColors.pink),
          _heart.run(2.4, curve: Ease.easeOut, delay: i * 0.8),
          origin: _center,
        ),
      ], translate: at),
  ],
);

Group _alarm() => _root(
  _jit.run(0.1, curve: Ease.linear),
  [
    ..._wings(seconds: 0.2),
    ..._body(),
    ..._blush(),
    _stroke('M64 80Q76 70 86 78', AvatarColors.ink, 4),
    _stroke('M114 78Q124 70 136 80', AvatarColors.ink, 4),
    ..._eyes(rx: 10, ry: 14, hr: 4, hy: 6),
    _e(100, 118, 4, 5, AvatarColors.mouth),
    Group(
      [
        _stroke('M88 172L84 179M112 172L116 179', _clockOrange, 4),
        _c(85, 133, 8, _clockOrange),
        _c(115, 133, 8, _clockOrange),
        const Ellipse(100, 152, 22, 22, Style(fill: _clockFace, stroke: _clockOrange, strokeWidth: 5)),
        _stroke('M100 152V140M100 152L108 157', AvatarColors.ink, 3),
      ],
      anims: [_ringclk.run(0.12, curve: Ease.inOut)],
      origin: _center,
    ),
  ],
  after: [
    for (final d in [
      'M64 130Q56 142 64 154',
      'M52 122Q40 142 52 162',
      'M136 130Q144 142 136 154',
      'M148 122Q160 142 148 162',
    ])
      _anim(_stroke(d, _clockOrange, 3.5), _ringarc.run(0.25, curve: Ease.step)),
  ],
);

Group _singing() {
  Node note(Offset at, Color color, double delay) => Group([
    Group(
      [_e(-3, 2, 5, 3.5, color, rotate: -20), _stroke('M1 1V-16Q9 -14 10 -6', color, 3)],
      anims: [_notefloat.run(2.4, curve: Ease.easeOut, delay: delay)],
      origin: _center,
    ),
  ], translate: at);
  return _root(
    _sway.run(1.2, curve: Ease.inOut),
    [
      ..._wings(seconds: 0.9),
      ..._body(),
      ..._blush(dx: 55, rx: 11, ry: 6.5, opacity: 0.8),
      ..._happyEyes(peak: 92),
      Group(
        [_e(100, 124, 9, 11, AvatarColors.mouth), _e(100, 129, 5, 3.5, AvatarColors.blush)],
        anims: [_sing.run(0.8, curve: Ease.inOut, alternate: true)],
        origin: _center,
      ),
    ],
    after: [
      note(const Offset(160, 78), HColors.cyan, 0),
      note(const Offset(40, 70), _notePink, 0.6),
      note(const Offset(174, 40), _notePink, 1.2),
      note(const Offset(26, 36), HColors.cyan, 1.8),
    ],
  );
}

// ---- idle activities ---------------------------------------------------------

String _star(double r) {
  final i = (r * 0.28).toStringAsFixed(1);
  return 'M0 -${r}L$i -${i}L$r 0L$i ${i}L0 ${r}L-$i ${i}L-$r 0L-$i -${i}Z';
}

Group _coffee() => _root(_bob.run(3.4, curve: Ease.inOut), [
  ..._wings(),
  ..._body(),
  ..._blush(),
  ..._happyEyes(peak: 92),
  _stroke('M91 116 Q100 126 109 116', AvatarColors.ink, 4),
  Group(
    [
      _stroke('M118 148Q132 148 132 158Q132 168 118 168', _cup, 5),
      const RoundRect(80, 140, 40, 32, 9, Style(fill: _cup)),
      _e(100, 141, 18, 4.5, _coffeeDrink),
      _stroke('M95 141Q100 137 105 141', _foam, 2),
      for (final (i, d) in ['M90 135Q87 130 91 126', 'M100 135Q97 129 101 124', 'M110 135Q107 130 111 126'].indexed)
        _anim(_stroke(d, _cup, 2.6), _steam.run(2.2, curve: Ease.easeOut, delay: i * 0.7)),
      _c(77, 158, 7, AvatarColors.wing),
      _c(130, 159, 7, AvatarColors.wing),
    ],
    anims: [_sip.run(5, curve: Ease.inOut)],
    origin: _center,
  ),
]);

Group _reading() {
  const glass = Style(stroke: HColors.lavender, strokeWidth: 3.5, round: false);
  return _root(_bob.run(3.4, curve: Ease.inOut), [
    ..._wings(),
    ..._body(),
    ..._blush(),
    Group(
      [
        _blinking([
          _e(76, 106, 8, 9, AvatarColors.ink),
          _e(124, 106, 8, 9, AvatarColors.ink),
          _c(78, 102, 3, _white),
          _c(126, 102, 3, _white),
        ]),
      ],
      anims: [_scan.run(5, curve: Ease.inOut)],
      origin: _center,
    ),
    const Ellipse(76, 104, 15, 15, glass),
    const Ellipse(124, 104, 15, 15, glass),
    PathShape('M91 102Q100 98 109 102', glass),
    _stroke('M93 123Q100 128 107 123', AvatarColors.ink, 3.5),
    _fill('M54 134L100 140L146 134L146 170L100 176L54 170Z', HColors.lavender),
    _fill('M58 130L100 136V170L58 164Z', _cup),
    _fill('M142 130L100 136V170L142 164Z', _pageShade),
    _stroke('M66 142L92 146M66 150L92 154M66 158L84 161', HColors.muted, 2.5),
    _stroke('M108 146L134 142M108 154L134 150M108 162L126 159', HColors.muted, 2.5),
    _anim(
      PathShape('M142 130L100 136V170L142 164Z', const Style(fill: _white, stroke: _pageShade, strokeWidth: 1.5)),
      _flip.run(6, curve: Ease.inOut),
      origin: _leftMid,
    ),
    _c(62, 158, 7, AvatarColors.wing),
    _c(138, 158, 7, AvatarColors.wing),
  ]);
}

Group _stargazing() {
  Node twinkle(double x, double y, double r, Color color, double delay, double seconds) => Group([
    _anim(_fill(_star(r), color), _twinkle.run(seconds, curve: Ease.inOut, delay: delay), origin: _center),
  ], translate: Offset(x, y));
  return _root(
    _lookup.run(6, curve: Ease.inOut),
    [
      ..._wings(),
      ..._body(),
      ..._blush(),
      _blinking([
        _e(76, 96, 10, 14, AvatarColors.ink),
        _e(124, 96, 10, 14, AvatarColors.ink),
        _c(79, 87, 5, _white),
        _c(127, 87, 5, _white),
        _c(72, 104, 2.2, _white),
        _c(120, 104, 2.2, _white),
      ]),
      _e(100, 121, 4.5, 5.5, AvatarColors.mouth),
    ],
    before: [
      _fill('M172 22A15 15 0 1 0 180 48A12 12 0 1 1 172 22Z', _moon),
      twinkle(30, 44, 7, _moon, 0, 1.8),
      twinkle(60, 18, 5, HColors.lavender, 0.5, 1.8),
      twinkle(120, 14, 6, HColors.cyan, 1.0, 1.8),
      twinkle(24, 98, 5, _moon, 1.3, 1.8),
      twinkle(178, 92, 5, _white, 0.8, 1.8),
      twinkle(150, 28, 4, AvatarColors.tuft, 0.3, 2.2),
      Group([
        Group(
          [_stroke('M0 0L16 -12', _white, 2.5, opacity: 0.5), _c(0, 0, 3, _white)],
          anims: [_starfall.run(7, curve: Ease.easeIn)],
        ),
      ], translate: const Offset(176, 16)),
    ],
  );
}

Group _meditating() => Group([
  _anim(_c(100, 108, 92, HColors.lavender), _aura.run(5, curve: Ease.inOut), origin: _center),
  _anim(_e(100, 186, 52, 7, _shadow), _shadowfloat.run(5, curve: Ease.inOut), origin: _center),
  for (final (x, y, r, color, delay) in [
    (40.0, 150.0, 4.0, HColors.lavender, 0.0),
    (160.0, 140.0, 5.0, HColors.mint, 1.6),
    (52.0, 116.0, 3.0, HColors.peach, 3.2),
    (150.0, 170.0, 3.5, HColors.cyan, 0.8),
  ])
    _anim(_c(x, y, r, color), _orb.run(5, curve: Ease.easeOut, delay: delay)),
  Group(
    [
      ..._wings(seconds: 8),
      ..._body(),
      ..._blush(),
      _stroke('M66 100 Q76 109 86 100', AvatarColors.ink, 4.5),
      _stroke('M114 100 Q124 109 134 100', AvatarColors.ink, 4.5),
      _c(100, 72, 3.5, HColors.mint),
      _stroke('M93 118Q100 123 107 118', AvatarColors.ink, 3.5),
      _e(100, 152, 13, 7, AvatarColors.wing),
    ],
    anims: [_levitate.run(5, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
]);

Group _gaming() => _root(_bobfast.run(0.5, curve: Ease.inOut), [
  ..._wings(seconds: 0.5),
  ..._body(),
  ..._blush(),
  _stroke('M64 84L86 90M136 84L114 90', AvatarColors.ink, 4),
  _blinking([
    _e(76, 102, 8, 10, AvatarColors.ink),
    _e(124, 102, 8, 10, AvatarColors.ink),
    _c(79, 98, 3, HColors.mint),
    _c(127, 98, 3, HColors.mint),
  ]),
  _stroke('M92 120Q100 124 108 120', AvatarColors.ink, 3.5),
  _anim(_e(106, 125, 4.5, 4, HColors.pink), _tongue.run(0.4, curve: Ease.inOut)),
  Group(
    [
      const RoundRect(48, 132, 104, 44, 14, Style(fill: HColors.sky)),
      const RoundRect(68, 137, 64, 34, 5, Style(fill: HColors.onMint)),
      _anim(const RoundRect(74, 156, 8, 8, 1.5, Style(fill: HColors.mint)), _gamehero.run(3, curve: Ease.inOut)),
      _anim(
        const RoundRect(114, 150, 7, 7, 1.5, Style(fill: HColors.amber)),
        _gameenemy.run(1.2, curve: Ease.linear, alternate: true),
      ),
      _stroke('M72 168H128', _gameGround, 2),
      _stroke('M58 154H70M64 148V160', HColors.onMint, 4),
      _c(138, 148, 4, HColors.pink),
      _c(144, 158, 4, HColors.amber),
      _c(54, 170, 6.5, AvatarColors.wing),
      _c(146, 170, 6.5, AvatarColors.wing),
    ],
    anims: [_mash.run(0.22, curve: Ease.linear)],
    origin: _center,
  ),
]);

Group _doodling() => _root(_bob.run(3.4, curve: Ease.inOut), [
  ..._wings(),
  ..._body(),
  ..._blush(),
  Group([_blinking(_eyes(hy: 4))], translate: const Offset(-3, 6)),
  _stroke('M92 117Q100 124 108 117', AvatarColors.ink, 3.5),
  // rotate(-6 100 150)
  Group([
    Group([
      const RoundRect(62, 128, 76, 46, 6, Style(fill: _cup)),
      _stroke('M70 128V124M82 128V124M94 128V124M106 128V124M118 128V124M130 128V124', HColors.placeholder, 3),
      DrawPath(
        'M100 166C84 156 82 144 91 142C96 141 99 144 100 147C101 144 104 141 109 142C118 144 116 156 100 166Z',
        const Style(stroke: HColors.coral, strokeWidth: 3.5),
        anim: _draw.run(6, curve: Ease.inOut),
        dashArray: 90,
      ),
      DrawPath(
        'M70 170C76 164 82 174 88 168',
        const Style(stroke: HColors.sky, strokeWidth: 3),
        anim: _draw2.run(6, curve: Ease.inOut),
        dashArray: 60,
      ),
    ], translate: const Offset(-100, -150)),
  ], translate: const Offset(100, 150), rotate: -6),
  Group(
    [
      Group([
        const RoundRect(-4, -18, 8, 26, 1.5, Style(fill: HColors.amber)),
        const RoundRect(-4, -22, 8, 6, 2, Style(fill: HColors.pink)),
        _fill('M-4 8L0 16L4 8Z', _foam),
        _fill('M-1.6 13L0 16L1.6 13Z', AvatarColors.ink),
      ], translate: const Offset(124, 138), rotate: 40),
      _c(119, 147, 6, AvatarColors.wing),
    ],
    anims: [_pencil.run(6, curve: Ease.inOut)],
    origin: _center,
  ),
]);

Group _stretching() => _root(
  _stBody.run(6, curve: Ease.inOut),
  [
    Group([_e(34, 112, 16, 30, AvatarColors.wing, rotate: -18)], anims: [_stWl.run(6, curve: Ease.inOut)], origin: _rightMid),
    Group([_e(166, 112, 16, 30, AvatarColors.wing, rotate: 18)], anims: [_stWr.run(6, curve: Ease.inOut)], origin: _leftMid),
    ..._body(),
    ..._blush(),
    Group(
      [_blinking(_eyes()), _stroke('M91 116 Q100 126 109 116', AvatarColors.ink, 4)],
      anims: [_stOpen.run(6, curve: Ease.step)],
    ),
    Group(
      [
        PathShape(
          'M64 90L86 100L64 110',
          const Style(stroke: AvatarColors.ink, strokeWidth: 5),
        ),
        PathShape(
          'M136 90L114 100L136 110',
          const Style(stroke: AvatarColors.ink, strokeWidth: 5),
        ),
        _e(100, 124, 11, 14, AvatarColors.mouth),
        _e(100, 131, 6, 4.5, AvatarColors.blush),
      ],
      anims: [_stShut.run(6, curve: Ease.step)],
    ),
  ],
);

Group _daydreaming() {
  Node thought(double delay, List<Node> icon) =>
      _anim(Group(icon), _cycle.run(7.5, curve: Ease.inOut, delay: delay), origin: _center);
  return _root(
    _thinktilt.run(5, curve: Ease.inOut),
    [
      ..._wings(),
      ..._body(),
      ..._blush(),
      Group([
        _blinking([
          _e(76, 98, 9, 12, AvatarColors.ink),
          _e(124, 98, 9, 12, AvatarColors.ink),
          _c(80, 93, 3.5, _white),
          _c(128, 93, 3.5, _white),
        ]),
      ], translate: const Offset(5, -4)),
      _stroke('M92 117Q100 124 108 117', AvatarColors.ink, 3.5),
    ],
    before: [
      Group(
        [
          _e(150, 32, 34, 26, _cup),
          _c(168, 66, 5.5, _cup),
          _c(176, 79, 3.2, _cup),
          Group([
            thought(0, [
              _fill('M-10 -4H8V8Q8 12 4 12H-6Q-10 12 -10 8Z', _clay),
              _stroke('M8 0Q15 0 15 5Q15 10 8 10', _clay, 3),
              _stroke('M-5 -7Q-8 -12 -4 -15M2 -7Q-1 -12 3 -15', HColors.muted, 2.2),
            ]),
            thought(2.5, [
              _fill(
                'M-12 4Q-16 4 -15 -1Q-14 -5 -9 -4Q-8 -11 0 -11Q7 -11 8 -5Q14 -5 14 0Q14 4 10 4Z',
                HColors.sky,
              ),
              _stroke('M-7 8L-9 13M0 8L-2 13M7 8L5 13', HColors.cyan, 2.5),
            ]),
            thought(5, [
              _fill('M-13 1L14 -11L6 13L1 5Z', HColors.coral),
              _stroke('M1 5L14 -11', _white, 1.8, opacity: 0.8),
            ]),
          ], translate: const Offset(150, 32), scale: 1.25),
        ],
        anims: [_daydrift.run(4, curve: Ease.inOut)],
      ),
    ],
  );
}

Group _clockpeek() => _root(
  _peeknod.run(8, curve: Ease.inOut),
  [
    ..._wings(),
    ..._body(),
    ..._blush(),
    Group([_blinking(_eyes())], anims: [_peek.run(8, curve: Ease.inOut)]),
    _stroke('M92 117Q100 124 108 117', AvatarColors.ink, 3.5),
  ],
  before: [
    const Ellipse(162, 52, 24, 24, Style(fill: _clockFace, stroke: HColors.mint, strokeWidth: 5)),
    _stroke('M162 33V37M181 52H177M162 71V67M143 52H147', AvatarColors.ink, 2.5),
    _stroke('M162 52L154 43', AvatarColors.ink, 4),
    Group([
      Group([_stroke('M0 0V-15', HColors.coral, 3)], anims: [_spin.run(10, curve: Ease.linear)]),
    ], translate: const Offset(162, 52)),
    _c(162, 52, 3, AvatarColors.ink),
  ],
);

final Map<AvatarState, Group> avatarScenes = {
  AvatarState.idle: _idle(),
  AvatarState.listening: _listening(),
  AvatarState.thinking: _thinking(),
  AvatarState.working: _working(),
  AvatarState.searching: _searching(),
  AvatarState.speaking: _speaking(),
  AvatarState.done: _done(),
  AvatarState.oops: _oops(),
  AvatarState.sleeping: _sleeping(),
  AvatarState.happy: _happy(),
  AvatarState.alarm: _alarm(),
  AvatarState.singing: _singing(),
  AvatarState.coffee: _coffee(),
  AvatarState.reading: _reading(),
  AvatarState.stargazing: _stargazing(),
  AvatarState.meditating: _meditating(),
  AvatarState.gaming: _gaming(),
  AvatarState.doodling: _doodling(),
  AvatarState.stretching: _stretching(),
  AvatarState.daydreaming: _daydreaming(),
  AvatarState.clockpeek: _clockpeek(),
  AvatarState.pooping: poopingScenes[0],
  AvatarState.eating: _eating(),
  AvatarState.cleaning: cleaningScenes[1],
  AvatarState.hungry: _hungry(),
  AvatarState.curious: _curious(),
  AvatarState.bored: _bored(),
  AvatarState.proud: _proud(),
  AvatarState.sulky: _sulky(),
  AvatarState.play: _play(),
  AvatarState.eatInfo: _eatInfo(),
};

/// The scene for [state]; the pooping and cleaning scenes depend on how many piles are already down.
Group sceneFor(AvatarState state, int mess) => switch (state) {
  AvatarState.pooping => poopingScenes[mess.clamp(0, poopingScenes.length - 1)],
  AvatarState.cleaning => cleaningScenes[mess.clamp(0, cleaningScenes.length - 1)],
  _ => avatarScenes[state]!,
};

/// Piles drawn over the scene, or null when there are none or the scene draws its own.
Group? overlayFor(AvatarState state, int mess) =>
    mess <= 0 || state == AvatarState.pooping || state == AvatarState.cleaning
    ? null
    : messLayers[mess.clamp(0, maxPoopSlots)];
