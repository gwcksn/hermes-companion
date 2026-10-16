import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_state.dart';
import '../data/connection.dart';
import '../data/gateway/chat_controller.dart';
import '../data/voice/voice_input.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/frame.dart';
import '../widgets/icons.dart';
import '../widgets/waveform.dart';

/// Voice capture: records, shows the live level, and on Stop sends the transcript to Hermes.
class ListeningScreen extends ConsumerStatefulWidget {
  const ListeningScreen({super.key});

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(voiceInputProvider.notifier).start());
  }

  Future<void> _stopAndSend() async {
    final text = await ref.read(voiceInputProvider.notifier).finish();
    if (text == null || !mounted) return;
    ref.read(chatProvider.notifier).send(text);
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    await ref.read(voiceInputProvider.notifier).cancel();
    if (mounted) Navigator.of(context).pop();
  }

  static String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(voiceInputProvider);
    final recording = v.phase == VoicePhase.recording;
    final transcribing = v.phase == VoicePhase.transcribing;
    final failed = v.phase == VoicePhase.error;
    final bars = [...List.filled(voiceBarCount - v.bars.length, 8.0), ...v.bars];
    final message = switch (v.phase) {
      VoicePhase.error => v.error ?? 'Something went wrong.',
      VoicePhase.transcribing => 'Transcribing…',
      VoicePhase.recording => 'Listening…',
      VoicePhase.idle => 'Getting the microphone ready…',
    };
    final hint = recording ? 'Tap the square to send' : (failed ? 'Tap the mic to try again' : ' ');

    return ScreenFrame(
      state: transcribing ? AvatarState.thinking : (failed ? AvatarState.idle : AvatarState.listening),
      panelPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      panel: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final link = ref.watch(connectionProvider);
                    return StatusLine(link.label, dotColor: link.color);
                  },
                ),
                TagChip(
                  _clock(v.elapsed),
                  color: HColors.mint,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  radius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Waveform(
                    heights: bars,
                    color: failed ? HColors.dim : HColors.mint,
                    barWidth: 4,
                    step: 10,
                    height: 64,
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(message, textAlign: TextAlign.center, style: hText(20, height: 1.3)),
                  ),
                  const SizedBox(height: 14),
                  Text(hint, style: hText(13, weight: FontWeight.w600, color: HColors.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PillButton('Cancel', style: PillStyle.secondary, onPressed: _cancel),
                const SizedBox(width: 20),
                if (failed)
                  RoundIconButton(
                    icon: HIcon.mic,
                    iconColor: HColors.onMint,
                    background: HColors.mint,
                    semanticLabel: 'Try again',
                    onPressed: () => ref.read(voiceInputProvider.notifier).start(),
                    size: 64,
                    iconSize: 24,
                  )
                else
                  RoundIconButton(
                    icon: HIcon.stop,
                    iconColor: HColors.onMint,
                    background: HColors.mint,
                    semanticLabel: 'Stop and send',
                    onPressed: recording ? _stopAndSend : () {},
                    size: 64,
                    iconSize: 24,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
