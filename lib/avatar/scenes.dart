// The 12 avatar states, ported 1:1 from assets/avatar/*.svg (200x200 viewBox).
// Keyframes and timings are copied from each SVG's <style>; see engine.dart for semantics.
import 'package:flutter/painting.dart';

import '../theme/tokens.dart';
import 'avatar_state.dart';
import 'engine.dart';

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

Group _root(Anim bodyAnim, List<Node> body, {List<Node> before = const [], List<Node> after = const []}) => Group([
  ...before,
  _groundShadow,
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
};
