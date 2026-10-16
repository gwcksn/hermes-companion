import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// Microphone capture. Behind an interface so tests run without a mic.
abstract class Recorder {
  /// Asks for the microphone permission if needed.
  Future<bool> requestPermission();

  Future<void> start();

  /// Input level 0..1, roughly every 100 ms while recording.
  Stream<double> get levels;

  /// Ends the recording and returns the audio (AAC in an MP4 container), or null if nothing was captured.
  Future<Uint8List?> stop();

  Future<void> cancel();

  Future<void> dispose();

  String get mimeType;
}

class MicRecorder implements Recorder {
  final _rec = AudioRecorder();

  @override
  String get mimeType => 'audio/mp4';

  @override
  Future<bool> requestPermission() => _rec.hasPermission();

  @override
  Future<void> start() async {
    final path = '${Directory.systemTemp.path}/hermes_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1), path: path);
  }

  @override
  Stream<double> get levels =>
      _rec.onAmplitudeChanged(const Duration(milliseconds: 100)).map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  @override
  Future<Uint8List?> stop() async {
    final path = await _rec.stop();
    // record keeps Bluetooth SCO up after stop() for a next take, which holds a
    // BT headset in call mode and silences media playback (the read-aloud reply).
    // cancel() with no take running only tears SCO down.
    await _rec.cancel().catchError((_) {});
    if (path == null) return null;
    final f = File(path);
    try {
      return await f.readAsBytes();
    } finally {
      f.delete().catchError((_) => f);
    }
  }

  @override
  Future<void> cancel() async {
    await _rec.cancel();
  }

  @override
  Future<void> dispose() => _rec.dispose();
}

final recorderFactoryProvider = Provider<Recorder Function()>((ref) => MicRecorder.new);
