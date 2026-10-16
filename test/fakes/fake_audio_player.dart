import 'dart:async';
import 'dart:typed_data';

import 'package:hermes_companion/data/voice/player.dart';

/// Plays nothing: a clip "plays" until [finish] is called or it is stopped.
class FakeAudioPlayer implements AudioPlayerService {
  final played = <({Uint8List bytes, String mimeType})>[];
  int stops = 0;
  Completer<void>? _current;

  bool get playing => _current != null && !_current!.isCompleted;

  void finish() => _current?.complete();

  @override
  Future<void> play(Uint8List bytes, String mimeType) {
    played.add((bytes: bytes, mimeType: mimeType));
    final c = _current = Completer<void>();
    return c.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _current;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  Future<void> dispose() async {}
}
