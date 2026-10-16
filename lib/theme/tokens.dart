// Design tokens ported 1:1 from tokens.json.
import 'package:flutter/painting.dart';

abstract final class HColors {
  static const bg = Color(0xFF0B0A10);
  static const panel = Color(0xFF14131A);
  static const surface = Color(0xFF1F1D29);
  static const surfaceActive = Color(0xFF2A2538);
  static const text = Color(0xFFF4F0EA);
  static const body = Color(0xFFC9C5D3);
  static const muted = Color(0xFFA9A5B5);
  static const dim = Color(0xFF4A4658);
  static const placeholder = Color(0xFF8C879A);
  static const peach = Color(0xFFFFD6A5);
  static const onPeach = Color(0xFF2B2233);
  static const mint = Color(0xFF8FE3C0);
  static const onMint = Color(0xFF10241B);
  static const lavender = Color(0xFFB8A9FF);
  static const amber = Color(0xFFFFC970);
  static const coral = Color(0xFFFF8A80);
  static const sky = Color(0xFF8FB8FF);
  static const pink = Color(0xFFFF8FA3);
  static const cyan = Color(0xFF7FD8FF);

  // Used in design/ markup but not listed in tokens.json.
  static const bubble = Color(0xFF23212E); // Hermes reply bubble
  static const cloud = Color(0xFFE8E4F2); // weather icon clouds
  static const mintGlow = Color(0xFF1E3A33); // stage glow while listening / all set
}

abstract final class AvatarColors {
  static const body = Color(0xFFFFD6A5);
  static const belly = Color(0xFFFFEBD0);
  static const wing = Color(0xFFFFE9C7);
  static const tuft = Color(0xFFFFB87A);
  static const blush = Color(0xFFFF9AA2);
  static const ink = Color(0xFF2B2233);
  static const mouth = Color(0xFFC2475B);
}

abstract final class HFonts {
  static const display = 'Fredoka'; // weights 500, 600
  static const body = 'Nunito'; // weights 600, 700
}

abstract final class HRadii {
  static const panel = 24.0;
  static const chip = 22.0;
  static const button = 24.0;
  static const input = 14.0;
  static const card = 28.0;
}

abstract final class HSizes {
  static const designSize = Size(740, 360);
  static const stage = 268.0;
  static const panelMargin = 12.0;
  static const minTouch = 44.0;
  static const inputHeight = 44.0;
  static const buttonHeight = 48.0;
}
