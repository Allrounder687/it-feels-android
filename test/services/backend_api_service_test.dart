import 'package:flutter_test/flutter_test.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:it_feels_music/data/models/song_model.dart';

void main() {
  group('BackendApiService Search Query Sanitation & Video Caching', () {
    test('cleanSearchQuery strips bracketed metadata and uses primary artist', () {
      final query = BackendApiService.cleanSearchQuery(
        'Yeh Awarapan (From "Awarapan 2")',
        'Amaal Mallik, Rashmi-Virag, Arijit Singh',
      );
      expect(query, equals('Yeh Awarapan Amaal Mallik official music video'));
    });

    test('cleanSearchQuery handles clean titles and artists', () {
      final query = BackendApiService.cleanSearchQuery(
        'Perfect',
        'Ed Sheeran',
      );
      expect(query, equals('Perfect Ed Sheeran official music video'));
    });

    test('preloadVideoStreams handles empty song id safely', () async {
      final song = Song(
        id: '',
        saavnId: '',
        title: 'Unknown',
        artist: 'Unknown',
        album: '',
        coverArt: '',
        duration: 0,
        addedAt: DateTime.now(),
      );
      expect(() async => await BackendApiService.preloadVideoStreams(song), returnsNormally);
    });
  });
}
