import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://pipedapi.kavin.rocks/streams/2Vv-BfVoq4g'));
  print('Piped Status: ${res.statusCode}');
  if (res.statusCode == 200) {
    final data = json.decode(res.body);
    final videoStreams = data['videoStreams'] as List;
    print('Found ${videoStreams.length} video streams');
    if (videoStreams.isNotEmpty) {
      print('First stream URL: ${videoStreams.first['url']}');
    }
  }
}
