import 'package:http/http.dart' as http;

/// Generic addon transport validation; no provider-specific extraction lives here.
class AudioSourcePolicy {
  static Uri unwrap(String value) {
    var uri = Uri.parse(value);
    for (var i = 0; i < 3; i++) {
      final wrapped = uri.queryParameters['url'];
      if (wrapped == null) break;
      final inner = Uri.tryParse(wrapped);
      if (inner == null || !{'https', 'http'}.contains(inner.scheme)) break;
      uri = inner;
    }
    return uri;
  }

  static bool? declaredAudio(String value) {
    Uri uri;
    try {
      uri = unwrap(value);
    } on FormatException {
      return false;
    }
    final mime = uri.queryParameters['mime']?.toLowerCase();
    if (mime != null) {
      if (mime.startsWith('audio/')) return true;
      if (mime.startsWith('video/')) return false;
    }
    if (RegExp(
      r'\.(mp3|m4a|aac|flac|opus|ogg|wav)$',
      caseSensitive: false,
    ).hasMatch(uri.path)) {
      return true;
    }
    // MP4/WebM may contain audio only; inspect their MIME instead of guessing.
    if (RegExp(r'\.mkv$', caseSensitive: false).hasMatch(uri.path)) {
      return false;
    }
    return null;
  }

  static String? select(Map<String, dynamic> data, {int depth = 0}) {
    if (data['success'] == false || data['error'] != null) return null;
    if (depth < 2 && data['data'] is Map<String, dynamic>) {
      final nested = select(
        data['data'] as Map<String, dynamic>,
        depth: depth + 1,
      );
      if (nested != null) return nested;
    }
    final audio = data['audioUrl'];
    if (audio is String && audio.isNotEmpty && declaredAudio(audio) != false) {
      return audio;
    }
    // 1. Audio-only streams
    for (final item in [
      ...?data['audioStreams'] as List?,
      ...?data['streams'] as List?,
      ...?data['adaptiveFormats'] as List?,
    ]) {
      if (item is! Map || item['url'] is! String) continue;
      final mime = item['mimeType']?.toString().toLowerCase() ?? '';
      if ((item['quality'] == 'audio' ||
              mime.startsWith('audio/') ||
              (item['hasAudio'] == true && item['hasVideo'] == false)) &&
          !mime.startsWith('video/') &&
          declaredAudio(item['url'] as String) != false) {
        return item['url'] as String;
      }
    }
    final mime = data['mimeType']?.toString().toLowerCase() ?? '';
    if (mime.startsWith('video/')) return null;
    final legacy = data['streamUrl'] ?? data['url'];
    return legacy is String &&
            legacy.isNotEmpty &&
            declaredAudio(legacy) != false
        ? legacy
        : null;
  }

  /// A full mix is downloaded only when the addon exposes an audio container.
  /// Unknown and video containers fall back to chapter-track matching.
  static Future<bool> probe(
    String value, {
    http.Client? client,
    bool verifyNetwork = false,
  }) async {
    final declared = declaredAudio(value);
    if (declared == false || (declared == true && !verifyNetwork)) {
      return declared!;
    }
    final transport = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(value));
      request.headers['Range'] = 'bytes=0-0';
      final response = await transport
          .send(request)
          .timeout(const Duration(seconds: 8));
      final type = response.headers['content-type']?.toLowerCase() ?? '';
      final subscription = response.stream.listen((_) {});
      await subscription.cancel();
      return response.statusCode >= 200 &&
          response.statusCode < 300 &&
          type.startsWith('audio/');
    } catch (_) {
      return false;
    } finally {
      if (client == null) transport.close();
    }
  }
}
