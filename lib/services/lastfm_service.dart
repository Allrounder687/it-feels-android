import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:logger/logger.dart';

class LastfmService {
  static const String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';
  static const String _sessionKeyPref = 'lastfm_session_key_v1';
  static const String _usernamePref = 'lastfm_username_v1';
  
  final Logger _logger = Logger();
  
  String get _apiKey => dotenv.isInitialized ? (dotenv.env['LASTFM_API_KEY'] ?? '') : '';
  String get _sharedSecret => dotenv.isInitialized ? (dotenv.env['LASTFM_SHARED_SECRET'] ?? '') : '';
  
  bool get isConfigured => _apiKey.isNotEmpty && _sharedSecret.isNotEmpty;

  /// Generate Last.fm API signature
  String _generateSignature(Map<String, String> params) {
    // 1. Order parameters alphabetically
    final sortedKeys = params.keys.toList()..sort();
    
    // 2. Concatenate name and value
    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      if (key != 'format' && key != 'callback') {
        buffer.write('$key${params[key]}');
      }
    }
    
    // 3. Append shared secret
    buffer.write(_sharedSecret);
    
    // 4. MD5 hash
    final bytes = utf8.encode(buffer.toString());
    final digest = md5.convert(bytes);
    
    return digest.toString();
  }

  /// Authenticate and get a mobile session
  Future<bool> authenticate(String username, String password) async {
    if (!isConfigured) return false;

    try {
      final params = {
        'method': 'auth.getMobileSession',
        'username': username,
        'password': password,
        'api_key': _apiKey,
      };
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await http.post(Uri.parse(_baseUrl), body: params);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['session'] != null) {
          final sessionKey = data['session']['key'];
          final sessionName = data['session']['name'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionKeyPref, sessionKey);
          await prefs.setString(_usernamePref, sessionName);
          return true;
        }
      } else {
        _logger.w('Last.fm auth failed: \${response.body}');
      }
    } catch (e) {
      _logger.e('Error authenticating with Last.fm: \$e');
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
      final params = {
        'method': 'track.updateNowPlaying',
        'track': song.title,
        'artist': song.artist,
        'api_key': _apiKey,
        'sk': sessionKey,
      };
      
      if (song.album.isNotEmpty) {
        params['album'] = song.album;
      }
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await http.post(Uri.parse(_baseUrl), body: params);
      
      if (response.statusCode != 200) {
        _logger.w('Last.fm updateNowPlaying failed: \${response.body}');
      }
    } catch (e) {
      _logger.e('Error updating Last.fm Now Playing: \$e');
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
      
      final params = {
        'method': 'track.scrobble',
        'track': song.title,
        'artist': song.artist,
        'timestamp': timestampUnix,
        'api_key': _apiKey,
        'sk': sessionKey,
      };
      
      if (song.album.isNotEmpty) {
        params['album'] = song.album;
      }
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final response = await http.post(Uri.parse(_baseUrl), body: params);
      
      if (response.statusCode == 200) {
        _logger.i('Successfully scrobbled: \${song.title} by \${song.artist}');
      } else {
        _logger.w('Last.fm scrobble failed: \${response.body}');
      }
    } catch (e) {
      _logger.e('Error scrobbling to Last.fm: \$e');
    }
  }
}
