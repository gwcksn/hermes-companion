import 'dart:async';
import 'dart:typed_data';

import 'package:hermes_companion/data/voice/recorder.dart';

class FakeRecorder implements Recorder {
  bool permission = true;
  Uint8List? audio = Uint8List.fromList([1, 2, 3, 4]);
  bool started = false;
  bool cancelled = false;
  final _levels = StreamController<double>.broadcast();

  void emitLevel(double v) => _levels.add(v);

  @override
  String get mimeType => 'audio/mp4';

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> start() async => started = true;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<Uint8List?> stop() async => audio;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async {}
}
