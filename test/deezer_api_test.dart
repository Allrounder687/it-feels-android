import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/data/services/deezer_api_service.dart';

void main() {
  test('DeezerApiService getCharts returns tracks via fallback', () async {
    final api = DeezerApiService();
    
    final charts = await api.getCharts();
    
    print('Tracks count: ${charts['tracks']?.length}');
    print('Playlists count: ${charts['playlists']?.length}');
    
    if (charts['tracks'] != null && charts['tracks'].isNotEmpty) {
      print('First track: ${charts['tracks'][0].title} by ${charts['tracks'][0].artist}');
    }
    
    expect(charts['tracks'], isNotEmpty);
    expect(charts['playlists'], isNotEmpty);
  });
}
