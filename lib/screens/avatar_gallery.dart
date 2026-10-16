import 'package:flutter/material.dart';

import '../avatar/avatar_state.dart';
import '../avatar/avatar_view.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Debug-only grid of all 12 states, mirroring assets/avatar/gallery.html.
/// Open by long-pressing the "Hermes" name under the avatar (debug builds only).
class AvatarGallery extends StatelessWidget {
  const AvatarGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HColors.bg,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: GridView.count(
          crossAxisCount: 6,
          padding: const EdgeInsets.all(12),
          childAspectRatio: 0.82,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final s in AvatarState.values)
              Column(
                children: [
                  AvatarView(state: s, size: 120),
                  const SizedBox(height: 6),
                  Text(s.label, style: hText(13, color: s.labelColor)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
