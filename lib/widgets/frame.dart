import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../avatar/avatar_state.dart';
import '../avatar/avatar_view.dart';
import '../screens/avatar_gallery.dart';
import '../screens/markdown_gallery.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Every screen: 268dp avatar stage on the left, rounded panel on the right.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.state,
    required this.panel,
    this.caption,
    this.captionColor,
    this.glow,
    this.stageAction,
    this.onAvatarTap,
    this.panelPadding = const EdgeInsets.fromLTRB(20, 0, 16, 12),
  });

  final AvatarState state;
  final Widget panel;

  /// Overrides the stage caption (e.g. "Let's connect" during setup).
  final String? caption;
  final Color? captionColor;
  final Color? glow;

  /// Optional widget shown under the avatar caption (e.g. a reconnect button).
  final Widget? stageAction;

  /// Called when the avatar itself is tapped.
  final VoidCallback? onAvatarTap;
  final EdgeInsets panelPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HColors.bg,
      body: Row(
        // Stretch so the stage glow fills the full 360dp height.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvatarStage(
            state: state,
            caption: caption,
            captionColor: captionColor,
            glow: glow,
            action: stageAction,
            onAvatarTap: onAvatarTap,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, HSizes.panelMargin, HSizes.panelMargin, HSizes.panelMargin),
              padding: panelPadding,
              decoration: BoxDecoration(color: HColors.panel, borderRadius: BorderRadius.circular(HRadii.panel)),
              child: panel,
            ),
          ),
        ],
      ),
    );
  }
}

class AvatarStage extends StatelessWidget {
  const AvatarStage({
    super.key,
    required this.state,
    this.caption,
    this.captionColor,
    this.glow,
    this.action,
    this.onAvatarTap,
  });

  final AvatarState state;
  final String? caption;
  final Color? captionColor;
  final Color? glow;
  final Widget? action;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HSizes.stage,
      // CSS: radial-gradient(circle at 50% 52%, glow 0%, bg 72%) on a 268x360 box.
      // 72% of the farthest-corner distance (230dp) = 166dp = 0.618 of the 268dp short side.
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, 0.04),
          radius: 0.618,
          colors: [glow ?? state.glow, HColors.bg],
        ),
      ),
      // scaleDown keeps the stage intact when the keyboard shrinks the screen.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: onAvatarTap, child: AvatarView(state: state)),
            const SizedBox(height: 6),
            GestureDetector(
              onLongPress: kDebugMode
                  ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AvatarGallery()))
                  : null,
              child: Text('Hermes', style: hDisplay(20)),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onLongPress: kDebugMode
                  ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MarkdownGallery()))
                  : null,
              child: Text(caption ?? state.label, style: hText(13, color: captionColor ?? state.labelColor)),
            ),
            if (action != null) ...[const SizedBox(height: 10), action!],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Panel content that scrolls only when squeezed (keyboard open), while
/// keeping Spacer/Expanded layout at full height.
class FlexibleScroll extends StatelessWidget {
  const FlexibleScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
