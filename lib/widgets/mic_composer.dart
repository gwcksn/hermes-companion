import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_controller.dart';
import '../avatar/avatar_state.dart';
import '../data/gateway/chat_controller.dart';
import '../data/voice/voice_input.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'icons.dart';
import 'waveform.dart';

/// A press shorter than this is a tap (recording latches); longer is push-to-talk.
const micHoldThreshold = Duration(milliseconds: 350);

/// Dragging this far left or up from where the finger went down arms "release to cancel".
const micCancelDistance = 80.0;

const _errorLinger = Duration(seconds: 3);

enum _Press { none, holding, latched }

/// The chat composer row with a WhatsApp-style mic: hold to talk and release to send, slide away
/// to cancel, or tap to record hands-free and tap stop to send. While recording, [field] and
/// [trailing] give way to a live waveform bar.
class MicComposer extends ConsumerStatefulWidget {
  const MicComposer({super.key, required this.field, required this.trailing});

  /// The text field, shown when not recording.
  final Widget field;

  /// The send or stop-Hermes button beside the mic, shown when not recording.
  final Widget trailing;

  @override
  ConsumerState<MicComposer> createState() => _MicComposerState();
}

class _MicComposerState extends ConsumerState<MicComposer> {
  final _micKey = GlobalKey();
  var _press = _Press.none;
  var _down = false;
  var _armed = false; // finger dragged far enough that releasing cancels
  var _heldLong = false;
  var _starting = false;
  Offset _downPos = Offset.zero;
  Timer? _holdTimer;
  Timer? _errorTimer;

  VoiceInput get _voice => ref.read(voiceInputProvider.notifier);
  AvatarController get _avatar => ref.read(avatarProvider.notifier);

  @override
  void dispose() {
    _holdTimer?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }

  Future<void> _begin(PointerDownEvent e) async {
    if (_press != _Press.none || _starting || ref.read(voiceInputProvider).phase == VoicePhase.transcribing) return;
    _errorTimer?.cancel();
    _down = true;
    _armed = false;
    _heldLong = false;
    _downPos = e.localPosition;
    _holdTimer = Timer(micHoldThreshold, () => _heldLong = true);
    setState(() => _press = _Press.holding);
    HapticFeedback.selectionClick();
    _starting = true;
    await _voice.start();
    _starting = false;
    if (!mounted) return;
    final phase = ref.read(voiceInputProvider).phase;
    if (phase != VoicePhase.recording) {
      // Denied or failed: the bar shows the message, then clears itself.
      setState(() => _press = _Press.none);
      _showErrorThenClear();
      return;
    }
    _avatar.set(AvatarState.listening);
    // The finger lifted while the permission prompt was up: keep the clip, like a tap.
    if (!_down && _press == _Press.holding) setState(() => _press = _Press.latched);
  }

  void _move(PointerMoveEvent e) {
    if (_press != _Press.holding || !_down) return;
    final d = e.localPosition - _downPos;
    final armed = d.dx < -micCancelDistance || d.dy < -micCancelDistance;
    if (armed != _armed) setState(() => _armed = armed);
  }

  void _end(PointerUpEvent e) {
    _down = false;
    _holdTimer?.cancel();
    if (_press != _Press.holding || _starting) return; // _begin settles it once recording starts
    if (_armed) {
      _cancel();
    } else if (!_heldLong) {
      setState(() => _press = _Press.latched);
    } else {
      _sendRecording();
    }
  }

  void _abort() {
    _down = false;
    _holdTimer?.cancel();
    if (_press == _Press.holding && !_starting) _cancel();
  }

  Future<void> _cancel() async {
    setState(() {
      _press = _Press.none;
      _armed = false;
    });
    await _voice.cancel();
    _avatar.set(AvatarState.idle);
  }

  Future<void> _sendRecording() async {
    setState(() {
      _press = _Press.none;
      _armed = false;
    });
    _avatar.set(AvatarState.thinking);
    final text = await _voice.finish();
    if (!mounted) return;
    if (text == null) {
      _avatar.set(AvatarState.idle);
      _showErrorThenClear();
    } else {
      ref.read(chatProvider.notifier).send(text);
    }
  }

  void _showErrorThenClear() {
    _errorTimer?.cancel();
    _errorTimer = Timer(_errorLinger, () {
      if (mounted) _voice.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceInputProvider);
    final active = _press != _Press.none || voice.phase != VoicePhase.idle;
    final latched = _press == _Press.latched;

    final mic = latched
        ? RoundIconButton(
            key: const ValueKey('stop'),
            icon: HIcon.stop,
            iconColor: HColors.onMint,
            background: HColors.mint,
            semanticLabel: 'Stop and send',
            onPressed: _sendRecording,
          )
        : RawGestureDetector(
            key: _micKey,
            behavior: HitTestBehavior.opaque,
            gestures: {
              _MicGesture: GestureRecognizerFactoryWithHandlers<_MicGesture>(
                _MicGesture.new,
                (g) => g
                  ..onDown = _begin
                  ..onMove = _move
                  ..onUp = _end
                  ..onCancel = _abort,
              ),
            },
            child: Semantics(
              button: true,
              label: 'Talk to Hermes',
              child: _MicDisc(armed: _armed, holding: _press == _Press.holding),
            ),
          );

    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: active ? _RecordingBar(voice: voice, press: _press, armed: _armed, onCancel: _cancel) : widget.field,
          ),
          const SizedBox(width: 8),
          if (!active) ...[widget.trailing, const SizedBox(width: 8)],
          mic,
        ],
      ),
    );
  }
}

/// Claims the pointer the moment it lands, so a horizontal slide (to cancel) never also swipes the
/// home pager, and reports down, move, up and cancel.
class _MicGesture extends OneSequenceGestureRecognizer {
  void Function(PointerDownEvent)? onDown;
  void Function(PointerMoveEvent)? onMove;
  void Function(PointerUpEvent)? onUp;
  VoidCallback? onCancel;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onDown?.call(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onMove?.call(event);
    } else if (event is PointerUpEvent) {
      stopTrackingPointer(event.pointer);
      onUp?.call(event);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      onCancel?.call();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'mic';
}

class _MicDisc extends StatelessWidget {
  const _MicDisc({required this.armed, required this.holding});

  final bool armed;
  final bool holding;

  @override
  Widget build(BuildContext context) {
    // Grows while held, like WhatsApp; turns coral when sliding away would cancel.
    final scale = holding ? 1.25 : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(shape: BoxShape.circle, color: armed ? HColors.coral : HColors.mint),
        alignment: Alignment.center,
        child: HIconView(HIcon.mic, color: HColors.onMint, size: 22),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.voice, required this.press, required this.armed, required this.onCancel});

  final VoiceState voice;
  final _Press press;
  final bool armed;
  final VoidCallback onCancel;

  static String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final failed = voice.phase == VoicePhase.error;
    final transcribing = voice.phase == VoicePhase.transcribing;
    final bars = [...List.filled(voiceBarCount - voice.bars.length, 8.0), ...voice.bars];
    final hint = switch ((failed, transcribing, press, armed)) {
      (true, _, _, _) => voice.error ?? 'Something went wrong.',
      (_, true, _, _) => 'Transcribing…',
      (_, _, _, true) => 'Release to cancel',
      (_, _, _Press.latched, _) => 'Tap to send',
      _ => '‹ Slide to cancel',
    };
    final hintColor = failed || armed ? HColors.coral : HColors.muted;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: HColors.surface, borderRadius: BorderRadius.circular(24)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!failed && !transcribing) ...[
                Text(
                  _clock(voice.elapsed),
                  style: hText(14, weight: FontWeight.w700, color: HColors.mint),
                ),
                const SizedBox(width: 10),
                Waveform(heights: bars, color: armed ? HColors.coral : HColors.mint, barWidth: 3, step: 6, height: 28),
                const SizedBox(width: 12),
              ],
              Text(
                hint,
                style: hText(13, weight: FontWeight.w600, color: hintColor),
              ),
              if (press == _Press.latched) ...[
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  excludeSemantics: true,
                  label: 'Cancel recording',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'Cancel',
                        style: hText(13, weight: FontWeight.w700, color: HColors.coral),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
