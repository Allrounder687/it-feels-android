import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final response = await http.post(
    Uri.parse('https://www.youtube.com/youtubei/v1/browse'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20240101.00.00'
        }
      },
      'browseId': 'FEtrending'
    })
  );
  
  final Map data = jsonDecode(response.body);
  print('Keys: ${data.keys}');
  
  if (data.containsKey('contents')) {
    final contents = data['contents'];
    print('Contents keys: ${contents.keys}');
  }
}
