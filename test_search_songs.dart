import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

void main() async {
  final api = MusicApiService();
  final songs = await api.searchSongs('Arijit Singh', count: 5);
  for (var i = 0; i < songs.length; i++) {
    print('Song $i: ID=${songs[i].id}, Title=${songs[i].title}, Artist=${songs[i].artist}');
  }
}
