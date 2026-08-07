import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:logger/logger.dart';
import 'package:it_feels_music/services/backend_api_service.dart';

class LastfmService {
  static const String _sessionKeyPref = 'lastfm_session_key_v1';
  static const String _usernamePref = 'lastfm_username_v1';

  final Logger _logger = Logger();
  final http.Client _client;

  LastfmService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // Since we proxy to Cloudflare, we assume it's always configured if we can reach the proxy.
  bool get isConfigured => BackendApiService.useProxyBackend;

  /// Authenticate and get a mobile session
  Future<bool> authenticate(String username, String password) async {
    if (!isConfigured) return false;

    try {
      final response = await _client.post(
        Uri.parse('${BackendApiService.baseUrl}/api/v1/lastfm/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['sessionKey'] != null) {
          final sessionKey = data['sessionKey'];
          final sessionName = data['name'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionKeyPref, sessionKey);
          await prefs.setString(_usernamePref, sessionName);
          return true;
        }
      } else {
        _logger.w('Last.fm proxy auth failed: ${response.body}');
      }
    } catch (e) {
      _logger.e('Error authenticating with Last.fm via proxy: $e');
    }
    return false;
  }

  /// Log out
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKeyPref);
    await prefs.remove(_usernamePref);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKeyPref) != null;
  }
  
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernamePref);
  }

  /// Update Now Playing status
  Future<void> updateNowPlaying(Song song) async {
    if (!isConfigured) return;
    
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = prefs.getString(_sessionKeyPref);
    if (sessionKey == null) return;

    try {
      final response = await _client.post(
        Uri.parse('${BackendApiService.baseUrl}/api/v1/lastfm/nowplaying'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionKey': sessionKey,
          'track': song.title,
          'artist': song.artist,
          'album': song.album.isNotEmpty ? song.album : null,
        }),
      );
      
      if (response.statusCode != 200) {
        _logger.w('Last.fm proxy updateNowPlaying failed: ${response.body}');
      }
    } catch (e) {
      _logger.e('Error updating Last.fm Now Playing via proxy: $e');
    }
  }

  /// Scrobble a track
  Future<void> scrobble(Song song, DateTime timestamp) async {
    if (!isConfigured) return;
    
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = prefs.getString(_sessionKeyPref);
    if (sessionKey == null) return;

    try {
      final timestampUnix = (timestamp.millisecondsSinceEpoch / 1000).floor().toString();
      
      final response = await _client.post(
        Uri.parse('${BackendApiService.baseUrl}/api/v1/lastfm/scrobble'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionKey': sessionKey,
          'track': song.title,
          'artist': song.artist,
          'timestamp': timestampUnix,
          'album': song.album.isNotEmpty ? song.album : null,
        }),
      );
      
      if (response.statusCode == 200) {
        _logger.i('Successfully scrobbled via proxy: ${song.title} by ${song.artist}');
      } else {
        _logger.w('Last.fm proxy scrobble failed: ${response.body}');
      }
    } catch (e) {
      _logger.e('Error scrobbling to Last.fm via proxy: $e');
    }
  }
}
