import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://www.jiosaavn.com/api.php?__call=webapi.getHomepageData&_format=json&_marker=0&api_version=4&ctx=web6dot0');
  final response = await http.get(url);
  final data = jsonDecode(response.body);
  print(data.keys);
  
  if (data['new_trending'] != null) {
      print(data['new_trending'][0]);
  }
}
