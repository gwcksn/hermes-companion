import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hermes_client.dart';
import 'recorder.dart';
import 'transcribe.dart';

enum VoicePhase { idle, recording, transcribing, error }

const voiceBarCount = 28;
const voiceMaxLength = Duration(seconds: 60);
const _minLength = Duration(milliseconds: 800);
const _tick = Duration(milliseconds: 250);

class VoiceState {
  const VoiceState({
    this.phase = VoicePhase.idle,
    this.elapsed = Duration.zero,
    this.bars = const [],
    this.error,
  });

  final VoicePhase phase;
  final Duration elapsed;

  /// Bar heights for the `Waveform` (8..58), newest last.
  final List<double> bars;
  final String? error;

  VoiceState copyWith({VoicePhase? phase, Duration? elapsed, List<double>? bars, String? Function()? error}) =>
      VoiceState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        bars: bars ?? this.bars,
        error: error == null ? this.error : error(),
      );
}

/// One voice capture: record, then transcribe on [finish]. Scoped to the listening screen.
class VoiceInput extends Notifier<VoiceState> {
  Recorder? _created;
  Recorder get _recorder => _created ??= ref.read(recorderFactoryProvider)();
  Timer? _clock;
  StreamSubscription<double>? _levels;
  var _elapsed = Duration.zero;
  var _closed = false;

  @override
  VoiceState build() {
    ref.onDispose(() {
      _closed = true;
      _clock?.cancel();
      _levels?.cancel();
      // Never touch `_recorder` here: building it reads a provider, which is not allowed in dispose.
      _created?.cancel().catchError((_) {});
      _created?.dispose().catchError((_) {});
    });
    return const VoiceState();
  }

  Future<void> start() async {
    if (state.phase == VoicePhase.recording) return;
    try {
      if (!await _recorder.requestPermission()) {
        _fail('Microphone is blocked. Allow it in Android Settings > Apps > Hermes Companion.');
        return;
      }
      await _recorder.start();
    } catch (_) {
      _fail('Could not start the microphone.');
      return;
    }
    if (_closed) return;
    _elapsed = Duration.zero;
    _levels = _recorder.levels.listen((l) {
      final bars = [...state.bars, 8 + l * 50];
      state = state.copyWith(bars: bars.length > voiceBarCount ? bars.sublist(bars.length - voiceBarCount) : bars);
    });
    _clock = Timer.periodic(_tick, (_) {
      _elapsed += _tick;
      state = state.copyWith(elapsed: _elapsed);
      if (_elapsed >= voiceMaxLength) finish();
    });
    state = const VoiceState(phase: VoicePhase.recording);
  }

  /// Stops recording and returns the transcript, or null after setting an error (or a cancel).
  Future<String?> finish() async {
    if (state.phase != VoicePhase.recording) return null;
    _clock?.cancel();
    final long = _elapsed >= _minLength;
    state = state.copyWith(phase: VoicePhase.transcribing, elapsed: _elapsed);
    unawaited(_levels?.cancel());
    try {
      final bytes = await _recorder.stop();
      if (bytes == null || bytes.isEmpty || !long) return _fail("I didn't catch that. Try again.");
      final client = ref.read(hermesClientProvider);
      if (client == null) return _fail('Not connected to Hermes.');
      final text = await transcribeAudio(client, bytes, mimeType: _recorder.mimeType);
      if (text.isEmpty) return _fail("I didn't catch that. Try again.");
      if (!_closed) state = const VoiceState(); // done: the next press starts fresh
      return text;
    } on HermesError catch (e) {
      return _fail(e.message);
    } catch (_) {
      return _fail('Could not read the recording.');
    }
  }

  Future<void> cancel() async {
    _clock?.cancel();
    unawaited(_levels?.cancel());
    await _recorder.cancel();
    if (!_closed) state = const VoiceState();
  }

  String? _fail(String message) {
    if (!_closed) state = state.copyWith(phase: VoicePhase.error, error: () => message);
    return null;
  }
}

final voiceInputProvider = NotifierProvider.autoDispose<VoiceInput, VoiceState>(VoiceInput.new);
