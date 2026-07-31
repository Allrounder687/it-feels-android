import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final uri = Uri.parse('https://api.cobalt.tools/api/json');
  final res = await http.post(
    uri,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'url': 'https://www.youtube.com/watch?v=2Vv-BfVoq4g',
      'vCodec': 'h264',
      'vQuality': '720',
      'isAudioOnly': false,
    }),
  );
  print('Cobalt Status: ${res.statusCode}');
  print('Cobalt Body: ${res.body}');
}
