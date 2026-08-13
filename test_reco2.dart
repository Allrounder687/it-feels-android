import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // 1. Search for a popular song
  final searchUrl = Uri.parse('https://www.jiosaavn.com/api.php?__call=search.getResults&q=Tum%20Hi%20Ho&n=1&_format=json&ctx=web6dot0');
  final searchRes = await http.get(searchUrl, headers: {'User-Agent': 'Mozilla/5.0'});
  final searchData = jsonDecode(searchRes.body);
  
  if (searchData['results'] != null && searchData['results'].isNotEmpty) {
     final songId = searchData['results'][0]['id'];
     print('Found song ID: $songId');
     
     // 2. Try reco
     final url = Uri.parse('https://www.jiosaavn.com/api.php?__call=reco.getreco&_format=json&api_version=4&ctx=web6dot0&pid=$songId');
     final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
     final data = jsonDecode(response.body);
     print('Reco Data: ${data is List ? data.length : data}');
     if (data is List) {
       for (var item in data.take(5)) {
          print('- ${item['title']} by ${item['more_info']?['primary_artists'] ?? item['subtitle']}');
       }
     }
  }
}
