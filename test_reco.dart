import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Try 'reco.getreco'
  final url = Uri.parse('https://www.jiosaavn.com/api.php?__call=reco.getreco&_format=json&api_version=4&ctx=web6dot0&pid=EwG5i_yU');
  final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('Reco length: ${data is List ? data.length : "Not list"}');
    if (data is List) {
       for (var item in data.take(10)) {
          print('- ${item['song']} by ${item['primary_artists']}');
       }
    } else {
       print(data);
    }
  }
}
