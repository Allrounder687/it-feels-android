import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:logger/logger.dart';

class RadioApiService {
  final Logger _logger = Logger();
  // We use a reliable endpoint for radio-browser
  static const String _baseUrl = 'https://de1.api.radio-browser.info/json';

  Future<List<Song>> getTopStations({int limit = 50}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/stations/topclick/$limit'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => _mapStationToSong(json)).toList();
      }
    } catch (e) {
      _logger.e('Failed to fetch top radio stations: $e');
    }
    return [];
  }

  Future<List<Song>> searchStations(String query, {int limit = 50}) async {
    try {
      final subLimit = (limit / 2).ceil();
      final safeQuery = Uri.encodeComponent(query.trim());
      
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/stations/search?name=$safeQuery&limit=$subLimit&order=clickcount&reverse=true')),
        http.get(Uri.parse('$_baseUrl/stations/search?country=$safeQuery&limit=$subLimit&order=clickcount&reverse=true')),
        http.get(Uri.parse('$_baseUrl/stations/search?tag=$safeQuery&limit=$subLimit&order=clickcount&reverse=true')),
      ]);

      final List<Song> allStations = [];
      final Set<String> seenIds = {};

      for (var response in responses) {
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (var json in data) {
            final song = _mapStationToSong(json);
            if (!seenIds.contains(song.id)) {
              seenIds.add(song.id);
              allStations.add(song);
            }
          }
        }
      }
      return allStations.take(limit).toList();
    } catch (e) {
      _logger.e('Failed to search radio stations: $e');
    }
    return [];
  }
  
  Future<List<Song>> getStationsByCountry(String countryCode, {int limit = 50}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/stations/bycountrycodeexact/$countryCode?limit=$limit'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => _mapStationToSong(json)).toList();
      }
    } catch (e) {
      _logger.e('Failed to fetch radio stations by country: $e');
    }
    return [];
  }

  Song _mapStationToSong(Map<String, dynamic> json) {
    String name = json['name'] ?? 'Unknown Station';
    name = name.trim();
    if (name.isEmpty) name = 'Live Radio';

    String tags = json['tags'] ?? '';
    List<String> tagList = tags.split(',').where((t) => t.isNotEmpty).toList();
    String genre = tagList.isNotEmpty ? tagList.first : 'Radio';

    String favicon = json['favicon'] ?? '';
    // Use a placeholder if no favicon
    if (favicon.isEmpty) {
      favicon = 'https://ui-avatars.com/api/?name=\${Uri.encodeComponent(name)}&background=random';
    }

    return Song(
      id: 'radio:${json["stationuuid"]}',
      saavnId: '',
      title: name,
      artist: json['country'] ?? 'Global Radio',
      album: 'Live FM',
      duration: 0, // Infinite duration for live streams
      coverArt: favicon,
      addedAt: DateTime.now(),
      genre: genre,
      encryptedMediaUrl: json['url_resolved'] ?? json['url'],
    );
  }
}
