import 'package:http/http.dart' as http;
void main() async {
  final res = await http.get(Uri.parse('https://it-feels-proxy.cleverfox687.workers.dev/api/v1/video?id=youtube:2Vv-BfVoq4g'), headers: {'X-Feels-Secret': 'development_secret_123'});
  print('Proxy response: ${res.statusCode} ${res.body}');
}
