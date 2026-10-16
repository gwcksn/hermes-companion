import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'common.dart';
import 'icons.dart';
import 'markdown_text.dart';
import 'waveform.dart';

const _userRadius = BorderRadius.only(
  topLeft: Radius.circular(22),
  topRight: Radius.circular(22),
  bottomRight: Radius.circular(4),
  bottomLeft: Radius.circular(22),
);
const _hermesRadius = BorderRadius.only(
  topLeft: Radius.circular(22),
  topRight: Radius.circular(22),
  bottomRight: Radius.circular(22),
  bottomLeft: Radius.circular(4),
);

/// Text bubble: peach for the user (right), dark for Hermes (left).
class TextBubble extends StatelessWidget {
  const TextBubble({super.key, required this.text, required this.fromUser, required this.maxWidth});

  final String text;
  final bool fromUser;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? HColors.peach : HColors.bubble,
          borderRadius: fromUser ? _userRadius : _hermesRadius,
        ),
        child: fromUser
            ? Text(
                text,
                style: hText(15, weight: FontWeight.w600, color: HColors.onPeach, height: 1.35),
              )
            // Hermes writes markdown; what you type is shown as typed.
            : MarkdownText(
                text,
                style: hText(15, weight: FontWeight.w600, color: HColors.text, height: 1.35),
              ),
      ),
    );
  }
}

/// User voice note: play button, waveform, duration.
class VoiceNoteBubble extends StatelessWidget {
  const VoiceNoteBubble({super.key, required this.duration, this.onPlay});

  final String duration;
  final VoidCallback? onPlay;

  static const _bars = <double>[6, 12, 8, 16, 10, 18, 8, 14, 6, 10];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: const BoxDecoration(color: HColors.peach, borderRadius: _userRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundIconButton(
              icon: HIcon.play,
              iconColor: HColors.peach,
              background: HColors.onPeach,
              onPressed: onPlay,
              semanticLabel: 'Play voice note',
              size: 28,
              iconSize: 14,
            ),
            const SizedBox(width: 10),
            const Waveform(heights: _bars, color: HColors.onPeach, barWidth: 3, step: 7, height: 20),
            const SizedBox(width: 10),
            Text(duration, style: hText(13, color: HColors.onPeach)),
          ],
        ),
      ),
    );
  }
}
