// Pet-mood scenes ported 1:1 from assets/avatar/{curious,bored,proud,sulky,play,eat_info}.svg.
// Part of scenes.dart to share its private helpers and keyframes. Keyframes below are copied
// from the SVGs' <style>; timings and delays come from the class rules and inline styles.
part of 'scenes.dart';

const _curtilt = Keyframes({
  Prop.rot: [(0, -2), (0.4, 9), (0.7, 9), (1, -2)],
});
const _qmbob = Keyframes({
  Prop.ty: [(0, 0), (0.5, -5), (1, 0)],
  Prop.rot: [(0, -8), (0.5, 8), (1, -8)],
});
const _slump = Keyframes({
  Prop.ty: [(0, 0), (0.5, 3), (1, 0)],
  Prop.sx: [(0, 1), (0.5, 1.03), (1, 1)],
  Prop.sy: [(0, 1), (0.5, 0.95), (1, 1)],
});
const _sigh = Keyframes({
  Prop.tx: [(0, 0), (0.55, 0), (1, 14)],
  Prop.ty: [(0, 0), (0.55, 0), (1, -12)],
  Prop.sx: [(0, 0.4), (0.55, 0.4), (1, 1.2)],
  Prop.sy: [(0, 0.4), (0.55, 0.4), (1, 1.2)],
  Prop.opacity: [(0, 0), (0.55, 0), (0.65, 0.9), (1, 0)],
});
const _huff = Keyframes({
  Prop.tx: [(0, 0), (0.6, 0), (1, 12)],
  Prop.ty: [(0, 0), (0.6, 0), (1, -6)],
  Prop.sx: [(0, 0.4), (0.6, 0.4), (1, 1.15)],
  Prop.sy: [(0, 0.4), (0.6, 0.4), (1, 1.15)],
  Prop.opacity: [(0, 0), (0.6, 0), (0.7, 0.85), (1, 0)],
});
const _pride = Keyframes({
  Prop.ty: [(0, 0), (0.5, -3), (1, 0)],
  Prop.sx: [(0, 1), (0.5, 1.04), (1, 1)],
  Prop.sy: [(0, 1), (0.5, 1.04), (1, 1)],
  Prop.rot: [(0, -2), (1, -2)],
});
const _sulkysway = Keyframes({
  Prop.rot: [(0, -4), (0.5, -7), (1, -4)],
});
const _ballbounce = Keyframes({
  Prop.ty: [(0, 0), (0.25, -26), (0.5, 0), (0.75, -26), (1, 0)],
});
const _ballx = Keyframes({
  Prop.tx: [(0, -46), (1, 46)],
});
const _chomp = Keyframes({
  Prop.sy: [(0, 0.25), (0.4, 0.25), (0.52, 1), (0.62, 0.3), (0.72, 0.8), (0.84, 0.25), (1, 0.25)],
});
const _feedcard = Keyframes({
  Prop.tx: [(0, 48), (0.52, 0), (1, 0)],
  Prop.ty: [(0, -50), (0.52, 0), (1, 0)],
  Prop.sx: [(0, 1), (0.52, 0.4), (0.58, 0), (1, 0)],
  Prop.sy: [(0, 1), (0.52, 0.4), (0.58, 0), (1, 0)],
  Prop.rot: [(0, 14), (0.52, 0), (1, 0)],
  Prop.opacity: [(0, 0), (0.1, 1), (0.52, 1), (0.58, 0), (1, 0)],
});
const _feedglow = Keyframes({
  Prop.opacity: [(0, 0.25), (0.5, 0.5), (1, 0.25)],
});

const _lid = Color(0xFFE0A878);
const _feedMint = Color(0xFF8FE3C0);
const _ball = Color(0xFFFF8A80);

/// The wing pair with its own cx/cy/rotation; a null duration holds that wing still.
List<Node> _wingsX({
  double cxL = 34,
  double cxR = 166,
  double cy = 112,
  double rotate = 18,
  double? secL = 4,
  double? secR = 4,
}) => [
  Group(
    [_e(cxL, cy, 16, 30, AvatarColors.wing, rotate: -rotate)],
    anims: [if (secL != null) _wingL.run(secL, curve: Ease.inOut)],
    origin: _rightMid,
  ),
  Group(
    [_e(cxR, cy, 16, 30, AvatarColors.wing, rotate: rotate)],
    anims: [if (secR != null) _wingR.run(secR, curve: Ease.inOut)],
    origin: _leftMid,
  ),
];

/// A twinkling 8-point star of radius [r] at [at]; [delay] is the animation-delay.
Node _twinkleAt(Offset at, double r, Color color, double delay) => Group([
  _anim(
    Group([_fill(_starPath, color)], scale: r / 9),
    _twinkle.run(1.8, curve: Ease.inOut, delay: delay),
    origin: _center,
  ),
], translate: at);

Group _curious() => Group([
  _groundShadow,
  _anim(const TextShape('?', 146, 44, 40, HColors.lavender), _qmbob.run(1.8, curve: Ease.inOut), origin: _center),
  _twinkleAt(const Offset(36, 52), 6, const Color(0xFFFFE9A8), 0),
  _twinkleAt(const Offset(176, 92), 5, HColors.cyan, 0.7),
  Group(
    [
      ..._wingsX(secL: 1.2),
      ..._body(),
      ..._blush(),
      _stroke('M112 76Q124 66 138 74', AvatarColors.ink, 4),
      Group([
        _blinking([..._eyes(rx: 10, ry: 14, hr: 5, hy: 7), _c(72, 108, 2.2, _white), _c(120, 108, 2.2, _white)]),
      ], translate: const Offset(5, -3)),
      _e(100, 122, 4, 5, AvatarColors.mouth),
    ],
    anims: [_curtilt.run(4.5, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
]);

Group _bored() => Group([
  _groundShadow,
  Group(
    [
      ..._wingsX(cy: 120, rotate: 6, secL: 9, secR: 9),
      ..._body(),
      ..._blush(opacity: 0.5),
      Group(
        [
          _e(76, 102, 9, 6, AvatarColors.ink),
          _e(124, 102, 9, 6, AvatarColors.ink),
          _c(79, 101, 2.5, _white),
          _c(127, 101, 2.5, _white),
        ],
        anims: [_look.run(7, curve: Ease.inOut)],
        origin: _center,
      ),
      _stroke('M64 96H88M112 96H136', _lid, 5),
      _stroke('M92 122Q100 120 108 122', AvatarColors.ink, 3.5),
    ],
    anims: [_slump.run(5, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
  Group([
    _anim(Group([_c(0, 0, 6, _thought), _c(7, -4, 4, _thought)]), _sigh.run(5, curve: Ease.easeOut), origin: _center),
  ], translate: const Offset(126, 128)),
  Group([
    _e(0, 0, 26, 16, _thought),
    for (final (i, x) in [-12.0, 0.0, 12.0].indexed)
      _anim(_c(x, 0, 3.5, HColors.placeholder), _dot.run(1.2, curve: Ease.inOut, delay: i * 0.4)),
  ], translate: const Offset(150, 44)),
]);

Group _proud() => Group([
  _groundShadow,
  _twinkleAt(const Offset(34, 60), 7, const Color(0xFFFFE9A8), 0),
  _twinkleAt(const Offset(170, 56), 8, HColors.amber, 0.5),
  _twinkleAt(const Offset(160, 24), 5, _white, 1.1),
  _twinkleAt(const Offset(48, 26), 5, HColors.amber, 1.4),
  Group(
    [
      ..._wingsX(cxL: 30, cxR: 170, cy: 106, rotate: 34, secL: 2.6, secR: 2.6),
      ..._body(),
      ..._blush(rx: 11, ry: 6.5, opacity: 0.85),
      _stroke('M66 100Q76 90 86 100', AvatarColors.ink, 5),
      _stroke('M114 100Q124 90 134 100', AvatarColors.ink, 5),
      _stroke('M88 116Q100 130 112 116', AvatarColors.ink, 4),
      _stroke('M110 120Q116 118 118 114', AvatarColors.ink, 3),
    ],
    anims: [_pride.run(2.6, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
]);

Group _sulky() => Group([
  _groundShadow,
  Group(
    [
      ..._wingsX(secL: null, secR: null),
      ..._body(),
      ..._blush(rx: 11, ry: 6.5, opacity: 0.8),
      _stroke('M62 84L86 92M138 84L114 92', AvatarColors.ink, 4.5),
      _blinking([
        _e(70, 102, 8, 10, AvatarColors.ink),
        _e(118, 102, 8, 10, AvatarColors.ink),
        _c(66, 99, 3, _white),
        _c(114, 99, 3, _white),
      ]),
      _stroke('M90 124Q100 114 110 124', AvatarColors.ink, 3.5),
      _stroke('M44 124Q40 114 52 112M156 124Q160 114 148 112', AvatarColors.tuft, 4),
      _e(70, 156, 15, 24, AvatarColors.wing, rotate: 64),
      _e(130, 156, 15, 24, AvatarColors.wing, rotate: -64),
    ],
    anims: [_sulkysway.run(3.4, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
  Group([
    _anim(
      Group([_e(0, 0, 6, 6, _thought, opacity: 0.8), _e(8, -4, 4, 4, _thought, opacity: 0.8)]),
      _huff.run(3.4, curve: Ease.easeOut),
      origin: _center,
    ),
  ], translate: const Offset(166, 120)),
]);

Group _play() => Group([
  _groundShadow,
  Group(
    [
      ..._wingsX(secL: 0.5, secR: 0.5),
      ..._body(),
      ..._blush(rx: 11, ry: 6.5, opacity: 0.8),
      Group(
        [
          _blinking([..._eyes(rx: 9, ry: 12, hr: 3.5, hy: 5)]),
        ],
        anims: [_follow.run(2.4, curve: Ease.inOut, alternate: true)],
        origin: _center,
      ),
      PathShape(
        'M86 114Q100 136 114 114Z',
        const Style(fill: AvatarColors.mouth, stroke: AvatarColors.ink, strokeWidth: 3),
      ),
    ],
    anims: [_hop.run(1.2, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
  Group([
    Group(
      [
        Group(
          [
            Group(
              [_c(0, 0, 11, _ball), _stroke('M-11 0H11', _white, 3), _stroke('M0 -11V11', HColors.amber, 3)],
              anims: [_spin.run(1, curve: Ease.linear)],
              origin: _center,
            ),
          ],
          anims: [_ballbounce.run(1.2, curve: Ease.easeOut)],
        ),
      ],
      anims: [_ballx.run(2.4, curve: Ease.inOut, alternate: true)],
    ),
  ], translate: const Offset(100, 172)),
]);

Group _eatInfo() => Group([
  _groundShadow,
  Group(
    [
      ..._wingsX(),
      ..._body(),
      ..._blush(rx: 10.5, ry: 6.2, opacity: 0.75),
      _blinking([..._eyes(rx: 10, ry: 13, hr: 5, hy: 6), _c(72, 106, 2.2, _white), _c(120, 106, 2.2, _white)]),
      Group(
        [_e(100, 120, 9, 10, AvatarColors.mouth), _e(100, 126, 5, 3.5, AvatarColors.blush)],
        anims: [_chomp.run(3, curve: Ease.inOut)],
        origin: const Offset(0.5, 0.3),
      ),
    ],
    anims: [_bob.run(3.4, curve: Ease.inOut)],
    origin: _bottomCenter,
  ),
  Group([
    _anim(
      Group([
        _anim(_c(0, 0, 22, _feedMint), _feedglow.run(3, curve: Ease.inOut)),
        const RoundRect(-11, -15, 22, 30, 4, Style(fill: Color(0xFFFDF6E3))),
        _stroke('M-6 -8H6M-6 -2H6M-6 4H2', _feedMint, 2.6),
      ]),
      _feedcard.run(3, curve: Ease.easeIn),
      origin: _center,
    ),
  ], translate: const Offset(100, 118)),
  _twinkleAt(const Offset(160, 60), 6, _feedMint, 0.3),
  _twinkleAt(const Offset(40, 70), 5, const Color(0xFFFFE9A8), 1.0),
]);
