import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/core/utils/audio_source_policy.dart';

/// Addons may return a media URL or a JSON resolution endpoint. Inspect the
/// response instead of guessing from an '/api/' substring in the URL.
class AddonAudioTransport {
  static Future<String?> resolve(String endpoint, {http.Client? client}) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return null;
    if (AudioSourcePolicy.declaredAudio(endpoint) == false) return null;
    if (AudioSourcePolicy.declaredAudio(endpoint) == true) return endpoint;
    final transport = client ?? http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll({'Range': 'bytes=0-0', 'User-Agent': 'Mozilla/5.0'});
      final response = await transport
          .send(request)
          .timeout(const Duration(seconds: 10));
      final type = response.headers['content-type']?.toLowerCase() ?? '';
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          type.startsWith('video/')) {
        await response.stream.listen((_) {}).cancel();
        return null;
      }
      if (type.startsWith('audio/')) {
        await response.stream.listen((_) {}).cancel();
        return endpoint;
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 10),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024) return null;
      }
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic> ||
          data['success'] == false ||
          data['error'] != null) {
        return null;
      }
      return AudioSourcePolicy.select(data);
    } catch (_) {
      return null;
    } finally {
      if (client == null) transport.close();
    }
  }
}
