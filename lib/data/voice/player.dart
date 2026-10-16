import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays one spoken reply at a time. Test seam: override [audioPlayerProvider].
abstract class AudioPlayerService {
  /// Completes when playback ends, or when [stop] cuts it short.
  Future<void> play(Uint8List bytes, String mimeType);

  Future<void> stop();

  Future<void> dispose();
}

class AudioplayersPlayer implements AudioPlayerService {
  AudioplayersPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;
  Completer<void>? _playing;

  @override
  Future<void> play(Uint8List bytes, String mimeType) async {
    await stop();
    final done = _playing = Completer<void>();
    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _player.play(BytesSource(bytes, mimeType: mimeType));
      await done.future;
    } finally {
      await sub.cancel();
      if (identical(_playing, done)) _playing = null;
    }
  }

  @override
  Future<void> stop() async {
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
    await _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final player = AudioplayersPlayer();
  ref.onDispose(player.dispose);
  return player;
});
