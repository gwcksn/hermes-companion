import 'dart:convert';
import 'dart:typed_data';

import '../hermes_client.dart';

/// Server TTS can take a while on the first call while its voice loads.
const speakTimeout = Duration(seconds: 90);

class SpeechClip {
  const SpeechClip(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

/// POST /api/audio/speak with `{text}`. The server answers with a base64 data URL; the exact
/// envelope is not documented, so a bare string or a map holding it is accepted.
Future<SpeechClip> speakText(HermesClient client, String text) async {
  final data = await client.postJson('/api/audio/speak', body: {'text': text}, receiveTimeout: speakTimeout);
  final clip = parseSpeakResponse(data);
  if (clip == null) throw const HermesError(HermesErrorKind.server);
  return clip;
}

/// Decodes a `data:<mime>;base64,<payload>` URL found in [data] (a string, or a map under
/// `data_url`, `audio`, `audio_url`, `url` or `data`). Returns null when none is usable.
SpeechClip? parseSpeakResponse(Object? data) {
  if (data is Map) {
    if (data['ok'] == false) return null;
    for (final key in const ['data_url', 'audio', 'audio_url', 'url', 'data']) {
      final clip = parseSpeakResponse(data[key]);
      if (clip != null) return clip;
    }
    return null;
  }
  if (data is! String) return null;
  final m = RegExp(r'^data:([^;,]+)(?:;[^,]*)?;base64,(.+)$', dotAll: true).firstMatch(data.trim());
  if (m == null) return null;
  try {
    final bytes = base64Decode(m.group(2)!);
    return bytes.isEmpty ? null : SpeechClip(bytes, m.group(1)!);
  } on FormatException {
    return null;
  }
}

const _maxSpeechChars = 1200;

/// Reduces a markdown reply to what reads naturally aloud: no code, links, tables or markup,
/// capped at a sentence boundary so the request stays short.
String speechText(String markdown) {
  var t = markdown
      .replaceAll(RegExp(r'```[\s\S]*?(```|$)'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'https?://\S+'), ' ')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*([-*+]|\d+[.)])\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\|?[\s:|-]{3,}\|?\s*$', multiLine: true), ' ')
      .replaceAll('|', ', ')
      .replaceAll(RegExp(r'[*_~]{1,3}'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.length > _maxSpeechChars) {
    t = t.substring(0, _maxSpeechChars);
    final end = t.lastIndexOf(RegExp(r'[.!?]\s'));
    if (end > _maxSpeechChars ~/ 2) t = t.substring(0, end + 1);
  }
  return t;
}
