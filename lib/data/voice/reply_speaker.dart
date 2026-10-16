import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/avatar_controller.dart';
import '../../avatar/avatar_state.dart';
import '../hermes_client.dart';
import 'player.dart';
import 'speak.dart';

enum SpeakerPhase { idle, loading, playing }

/// Reads Hermes's replies aloud through server TTS. One clip at a time: a new reply, or [stop],
/// cuts the previous one. The speaking avatar follows the audio, not the text stream.
class ReplySpeaker extends Notifier<SpeakerPhase> {
  int _generation = 0;

  @override
  SpeakerPhase build() => SpeakerPhase.idle;

  /// Completes when the reply has finished playing, was cut short, or could not be spoken.
  Future<void> speak(String markdown) async {
    final text = speechText(markdown);
    if (text.isEmpty) return;
    final generation = ++_generation;
    final player = ref.read(audioPlayerProvider);
    state = SpeakerPhase.loading;
    try {
      await player.stop();
      final client = ref.read(hermesClientProvider);
      if (client == null) return;
      final clip = await speakText(client, text);
      if (generation != _generation) return;
      state = SpeakerPhase.playing;
      ref.read(avatarProvider.notifier).set(AvatarState.speaking);
      await player.play(clip.bytes, clip.mimeType);
    } on HermesError {
      // No voice this time; the text reply is already on screen.
    } catch (_) {
      // Same for playback failures.
    } finally {
      if (generation == _generation) {
        state = SpeakerPhase.idle;
        final avatar = ref.read(avatarProvider.notifier);
        if (ref.read(avatarProvider) == AvatarState.speaking) avatar.set(AvatarState.idle);
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    final wasPlaying = state == SpeakerPhase.playing;
    state = SpeakerPhase.idle;
    if (wasPlaying && ref.read(avatarProvider) == AvatarState.speaking) {
      ref.read(avatarProvider.notifier).set(AvatarState.idle);
    }
    await ref.read(audioPlayerProvider).stop();
  }
}

final replySpeakerProvider = NotifierProvider<ReplySpeaker, SpeakerPhase>(ReplySpeaker.new);
