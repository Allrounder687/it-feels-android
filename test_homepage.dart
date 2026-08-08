import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';

void main() async {
  final api = MusicApiService();
  final data = await api.fetchHomepageData();
  final playlists = <dynamic>[];
  if (data['top_playlists'] is List) playlists.addAll(data['top_playlists']);
  if (data['featured_playlists'] is List) playlists.addAll(data['featured_playlists']);
  
  for (var p in playlists) {
    print('Playlist: ${p['title']}, ID: ${p['id']}');
  }
}
