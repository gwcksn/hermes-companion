import 'dart:convert';
import 'dart:typed_data';

import '../hermes_client.dart';

/// The server's local speech-to-text loads its model on the first call (~40 s), then takes ~8 s a clip.
const transcribeTimeout = Duration(seconds: 90);

/// POST /api/audio/transcribe with a base64 data URL. Returns the trimmed transcript, empty when
/// the server heard nothing. Response shape (verified live): `{ok, transcript, provider}`.
Future<String> transcribeAudio(HermesClient client, Uint8List bytes, {required String mimeType}) async {
  final data = await client.postJson(
    '/api/audio/transcribe',
    body: {'data_url': 'data:$mimeType;base64,${base64Encode(bytes)}', 'mime_type': mimeType},
    receiveTimeout: transcribeTimeout,
  );
  if (data is! Map || data['ok'] == false) throw const HermesError(HermesErrorKind.server);
  return (data['transcript'] as String? ?? '').trim();
}
