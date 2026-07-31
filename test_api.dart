import 'package:http/http.dart' as http;

void main() async {
  final url1 = Uri.parse('https://www.jiosaavn.com/api.php?__call=autocomplete.get&_format=json&_marker=0&api_version=4&ctx=web6dot0&query=taylor');
  final r1 = await http.get(url1, headers: {'User-Agent': 'Mozilla/5.0'});
  print('--- AUTOCOMPLETE ---');
  print(r1.body.substring(0, 100));

  final url2 = Uri.parse('https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&p=1&n=1&api_version=4&ctx=web6dot0&q=taylor');
  final r2 = await http.get(url2, headers: {'User-Agent': 'Mozilla/5.0'});
  print('--- GETRESULTS ---');
  print(r2.body.substring(0, 100));
}
