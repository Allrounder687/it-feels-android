import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final songId = 'EwG5i_yU'; // Example song ID

  // 1. Create Station
  final createUrl = Uri.parse('https://www.jiosaavn.com/api.php?__call=webradio.createEntityStation&entity_id=$songId&entity_type=queue&_format=json&ctx=web6dot0');
  final createRes = await http.get(createUrl, headers: {'User-Agent': 'Mozilla/5.0'});
  
  if (createRes.statusCode != 200) {
    print('Failed to create station');
    return;
  }
  
  final createData = jsonDecode(createRes.body);
  print('Create Data: $createData');
  final stationId = createData['stationid'];

  // 2. Get Songs
  if (stationId != null) {
    final getUrl = Uri.parse('https://www.jiosaavn.com/api.php?__call=webradio.getSong&stationid=$stationId&k=5&_format=json&ctx=web6dot0');
    final getRes = await http.get(getUrl, headers: {'User-Agent': 'Mozilla/5.0'});
    final getData = jsonDecode(getRes.body);
    
    print('\nRadio Songs:');
    if (getData is Map && getData.containsKey('stationid')) {
        for (var song in getData.values) {
           if (song is Map && song.containsKey('song')) {
              print('- ${song['song']} by ${song['primary_artists']}');
           }
        }
    } else {
        print(getData);
    }
  }
}
