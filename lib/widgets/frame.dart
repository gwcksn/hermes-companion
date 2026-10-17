import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../avatar/avatar_state.dart';
import '../avatar/avatar_view.dart';
import '../screens/avatar_gallery.dart';
import '../screens/markdown_gallery.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'floating_avatar.dart';

/// Every screen: 268dp avatar stage on the left, rounded panel on the right.
/// In portrait the stage is on top and the panel below.
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
    this.onAvatarLongPress,
    this.petStrip,
    this.mess = 0,
    this.panelPadding = const EdgeInsets.fromLTRB(20, 0, 16, 12),
    this.panelKey,
    this.fullscreen = false,
    this.avatarPos,
    this.onAvatarMoved,
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
  final VoidCallback? onAvatarLongPress;

  /// Pet stats strip, drawn at the bottom of the stage without moving the avatar.
  final Widget? petStrip;

  /// Poop piles drawn over the avatar (0..3).
  final int mess;
  final EdgeInsets panelPadding;

  /// Keeps the panel's state when toggling [fullscreen] reparents it.
  final GlobalKey? panelKey;

  /// Panel fills the screen; the avatar floats over it at [avatarPos] (0..1 fractions).
  final bool fullscreen;
  final Offset? avatarPos;
  final void Function(double fx, double fy)? onAvatarMoved;

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;
    final stage = AvatarStage(
      state: state,
      caption: caption,
      captionColor: captionColor,
      glow: glow,
      action: stageAction,
      onAvatarTap: onAvatarTap,
      onAvatarLongPress: onAvatarLongPress,
      petStrip: petStrip,
      mess: mess,
      portrait: portrait,
    );
    final panelBox = Container(
      key: panelKey,
      margin: fullscreen
          ? const EdgeInsets.all(8)
          : portrait
          ? const EdgeInsets.fromLTRB(
              HSizes.panelMargin,
              0,
              HSizes.panelMargin,
              HSizes.panelMargin,
            )
          : const EdgeInsets.fromLTRB(
              0,
              HSizes.panelMargin,
              HSizes.panelMargin,
              HSizes.panelMargin,
            ),
      padding: panelPadding,
      decoration: BoxDecoration(color: HColors.panel, borderRadius: BorderRadius.circular(HRadii.panel)),
      child: panel,
    );
    if (fullscreen) {
      return Scaffold(
        backgroundColor: HColors.bg,
        body: Stack(
          children: [
            Positioned.fill(child: panelBox),
            Positioned.fill(
              child: FloatingAvatar(
                state: state,
                mess: mess,
                fx: avatarPos?.dx ?? 1,
                fy: avatarPos?.dy ?? 0.5,
                onTap: onAvatarTap,
                onMoved: onAvatarMoved ?? (_, _) {},
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: HColors.bg,
      // Stretch so the stage glow fills the full height (landscape) or width (portrait).
      body: portrait
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [stage, Expanded(child: panelBox)])
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [stage, Expanded(child: panelBox)]),
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
    this.onAvatarLongPress,
    this.petStrip,
    this.mess = 0,
    this.portrait = false,
  });

  final AvatarState state;
  final bool portrait;
  final String? caption;
  final Color? captionColor;
  final Color? glow;
  final Widget? action;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final Widget? petStrip;
  final int mess;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: portrait ? null : HSizes.stage,
      height: portrait ? HSizes.stage : null,
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAvatarTap,
              onLongPress: onAvatarLongPress,
              child: AvatarView(state: state, mess: mess),
            ),
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
          if (petStrip != null && action == null)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(child: petStrip!),
            ),
        ],
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
