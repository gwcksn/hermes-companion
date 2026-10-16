import 'package:flutter/material.dart';

import '../../avatar/avatar_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/frame.dart';

/// Shared layout for the 3 first-run steps: step counter + dots, title, body, content, actions.
class SetupFrame extends StatelessWidget {
  const SetupFrame({
    super.key,
    required this.step,
    required this.caption,
    required this.title,
    required this.body,
    required this.content,
    required this.actions,
    this.captionColor,
    this.glow,
  });

  final int step;
  final String caption;
  final Color? captionColor;
  final Color? glow;
  final String title;
  final String body;
  final Widget content;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      state: AvatarState.idle,
      caption: caption,
      captionColor: captionColor,
      glow: glow,
      panelPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      panel: FlexibleScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Step $step of 3', style: hText(13, color: HColors.muted)),
                  Row(
                    children: [
                      for (var i = 1; i <= 3; i++) ...[if (i > 1) const SizedBox(width: 6), PageDot(active: i == step)],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: hDisplay(26, height: 1.2)),
            const SizedBox(height: 10),
            Text(
              body,
              style: hText(15, weight: FontWeight.w600, color: HColors.body, height: 1.45),
            ),
            const SizedBox(height: 10),
            content,
            const Spacer(),
            const SizedBox(height: 10),
            SizedBox(height: 48, child: actions),
          ],
        ),
      ),
    );
  }
}
