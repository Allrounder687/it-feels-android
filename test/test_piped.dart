import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(Uri.parse('https://pipedapi.smnz.de/trending?region=US'));
  final List data = jsonDecode(response.body);
  if (data.isNotEmpty) {
    print('First item keys: ${data[0].keys}');
    print('Title: ${data[0]['title']}');
    print('Uploader: ${data[0]['uploaderName']}');
    print('VideoId: ${data[0]['url']?.split("?v=").last}');
    print('Thumbnail: ${data[0]['thumbnail']}');
    print('Views: ${data[0]['views']}');
  }
}
