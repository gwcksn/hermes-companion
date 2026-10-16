import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/bubbles.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

/// Debug-only gallery of representative markdown blocks (headings, lists, tables)
/// mirroring the patterns Hermes emits in chat. Open by long-pressing the avatar
/// caption under "Hermes" (debug builds only), parallel to `AvatarGallery`.
class MarkdownGallery extends StatelessWidget {
  const MarkdownGallery({super.key});

  /// Each entry is shown as a Hermes bubble exactly as it would appear in chat.
  static const samples = <(String, String)>[
    (
      'Recap (the screenshot bug)',
      // Same content that build_recap.py emits and that previously rendered as raw pipe
      // characters in the bubble.
      '20:00 job — **Daily Work Recap Email** (bef9b3cd9cc6)\n\n'
          '|||\n'
          '|---|---|\n'
          '| Field | Value |\n'
          '| State | active, enabled, scheduled |\n'
          '| Schedule | `0 20 * * 1-5` (Mon–Fri) |\n'
          '| Next run | today, 2026-10-16 20:00 WIB — ~10.5h from now |\n'
          '| Script | `build_recap.py` (no-agent output → prompt feed) |',
    ),
    (
      'Aligned headers',
      '| Field | Count | Rate |\n'
          '| :--- | :---: | ---: |\n'
          '| tasks | 8 | 92% |\n'
          '| blockers | 2 | 25% |\n'
          '| notes | 14 | 70% |',
    ),
    (
      'Header-less (degenerate first row)',
      // Same `|||` pattern the recap cron emits; should render as a clean 2-col table
      // with no header bar.
      '|||\n'
          '|---|---|\n'
          '| user | hermes |\n'
          '| ligwina | main |\n'
          '| crawly | fetch |',
    ),
    (
      'Mixed inline styles',
      '# Heading\n'
          'A paragraph with **bold**, *italic*, ~~strike~~, `inline code`, and [a link](https://example.com).\n\n'
          '- bullet one\n'
          '- bullet two with `code`',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HColors.bg,
      appBar: AppBar(
        backgroundColor: HColors.bg,
        elevation: 0,
        leading: IconTap(
          icon: HIcon.arrowLeft,
          onPressed: () => Navigator.of(context).pop(),
          semanticLabel: 'Back',
        ),
        title: Text('Markdown gallery', style: hText(15, color: HColors.muted)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: samples.length,
          separatorBuilder: (_, _) => const SizedBox(height: 18),
          itemBuilder: (_, i) {
            final (label, source) = samples[i];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(label, style: hText(13, color: HColors.muted)),
                ),
                TextBubble(
                  text: source,
                  fromUser: false,
                  maxWidth: 1000, // bigger than the chat column so each layout reads at full size
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
