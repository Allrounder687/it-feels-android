import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final songId = 'EwG5i_yU'; // Example song ID

  // 1. Create Station
  final createUrl = Uri.parse('https://www.jiosaavn.com/api.php?__call=webradio.createEntityStation&entity_id=$songId&entity_type=queue&_format=json&ctx=web6dot0');
  final createRes = await http.get(createUrl, headers: {'User-Agent': 'Mozilla/5.0'});
  
  final createData = jsonDecode(createRes.body);
  print('Create Data queue: $createData');

  final createUrl2 = Uri.parse('https://www.jiosaavn.com/api.php?__call=webradio.createEntityStation&entity_id=$songId&entity_type=song&_format=json&ctx=web6dot0');
  final createRes2 = await http.get(createUrl2, headers: {'User-Agent': 'Mozilla/5.0'});
  final createData2 = jsonDecode(createRes2.body);
  print('Create Data song: $createData2');

  final createUrl3 = Uri.parse('https://www.jiosaavn.com/api.php?__call=webradio.createEntityStation&entity_id=$songId&entity_type=pid&_format=json&ctx=web6dot0');
  final createRes3 = await http.get(createUrl3, headers: {'User-Agent': 'Mozilla/5.0'});
  final createData3 = jsonDecode(createRes3.body);
  print('Create Data pid: $createData3');

  if (createData.containsKey('stationid')) {
    final stationId = createData['stationid'];
    final getUrl = Uri.parse('https://www.jiosaavn.com/api.php?__call=webradio.getSong&stationid=$stationId&k=5&_format=json&ctx=web6dot0');
    final getRes = await http.get(getUrl, headers: {'User-Agent': 'Mozilla/5.0'});
    print(getRes.body);
  }
}
