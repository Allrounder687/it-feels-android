import 'dart:convert';
import 'dart:io';

void main() async {
  final instances = [
    'https://pipedapi.moomoo.me',
    'https://pipedapi.syncpundit.io',
    'https://piapi.ggtyler.dev',
    'https://pipedapi.kavin.rocks',
  ];
  final videoId = 'xEBVyHzyIM4';
  
  for (final url in instances) {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$url/streams/$videoId'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final videoStreams = data['videoStreams'] as List;
        final muxedStreams = videoStreams.where((s) => s['videoOnly'] == false).toList();
        print('SUCCESS: $url | Muxed Streams: ${muxedStreams.length}');
      } else {
        print('FAIL: $url (Status ${response.statusCode})');
      }
    } catch (e) {
      print('ERROR: $url - $e');
    }
  }
}
