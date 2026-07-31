import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final instances = [
    'https://vid.puffyan.us',
    'https://inv.tux.pizza',
    'https://invidious.jing.rocks',
    'https://pipedapi.smnz.de'
  ];

  for (final instance in instances) {
    print('Testing $instance...');
    try {
      if (instance.contains('piped')) {
        final res = await http.get(Uri.parse('$instance/streams/2Vv-BfVoq4g')).timeout(const Duration(seconds: 5));
        print('Status: ${res.statusCode}');
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          print('Streams found: ${data['videoStreams']?.length}');
          break;
        }
      } else {
        final res = await http.get(Uri.parse('$instance/api/v1/videos/2Vv-BfVoq4g')).timeout(const Duration(seconds: 5));
        print('Status: ${res.statusCode}');
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          print('Streams found: ${data['formatStreams']?.length}');
          break;
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
