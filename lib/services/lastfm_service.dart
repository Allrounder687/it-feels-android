import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:logger/logger.dart';
import 'package:it_feels_music/services/backend_api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';

class LastfmService {
  static const String _sessionKeyPref = 'lastfm_session_key_v1';
  static const String _usernamePref = 'lastfm_username_v1';
  static const String _lastfmApiBaseUrl = 'https://ws.audioscrobbler.com/2.0/';

  final Logger _logger = Logger();
  final http.Client _client;

  LastfmService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => BackendApiService.useProxyBackend || _hasLocalKeys;
  
  bool get _hasLocalKeys => 
      dotenv.isInitialized && 
      dotenv.env['LASTFM_API_KEY'] != null && 
      dotenv.env['LASTFM_SHARED_SECRET'] != null;

  String? get _apiKey => dotenv.isInitialized ? dotenv.env['LASTFM_API_KEY'] : null;
  String? get _sharedSecret => dotenv.isInitialized ? dotenv.env['LASTFM_SHARED_SECRET'] : null;

  String _generateSignature(Map<String, String> params, String secret) {
    final keys = params.keys.toList()..sort();
    String sigStr = '';
    for (var k in keys) {
      sigStr += '$k${params[k]}';
    }
    sigStr += secret;
    return md5.convert(utf8.encode(sigStr)).toString();
  }

  /// Authenticate and get a mobile session
  Future<bool> authenticate(String username, String password) async {
    if (!isConfigured) return false;

    // Try Direct API first if keys are available
    if (_hasLocalKeys) {
      try {
        final params = {
          'method': 'auth.getMobileSession',
          'username': username,
          'password': password,
          'api_key': _apiKey!,
        };
        final apiSig = _generateSignature(params, _sharedSecret!);
        
        final requestBody = {
          ...params,
          'api_sig': apiSig,
          'format': 'json',
        };

        final response = await _client.post(
          Uri.parse(_lastfmApiBaseUrl),
          body: requestBody,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['session'] != null && data['session']['key'] != null) {
            final sessionKey = data['session']['key'];
            final sessionName = data['session']['name'];
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_sessionKeyPref, sessionKey);
            await prefs.setString(_usernamePref, sessionName);
            return true;
          }
        } else {
          _logger.w('Direct Last.fm auth failed: ${response.body}');
        }
      } catch (e) {
        _logger.e('Error authenticating directly with Last.fm: $e');
      }
    }

    // Fallback to Proxy
    if (BackendApiService.useProxyBackend) {
      try {
        final response = await _client.post(
          Uri.parse('${BackendApiService.baseUrl}/api/v1/lastfm/auth'),
          headers: {
            'Content-Type': 'application/json',
            // Pass proxy secret, assuming BackendApiService exposes it or using fallback
            'X-Feels-Secret': dotenv.isInitialized ? (dotenv.env['API_SECRET'] ?? 'development_secret_123') : 'development_secret_123',
          },
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

    if (_hasLocalKeys) {
      try {
        final params = {
          'method': 'track.updateNowPlaying',
          'track': song.title,
          'artist': song.artist,
          'api_key': _apiKey!,
          'sk': sessionKey,
        };
        if (song.album.isNotEmpty) params['album'] = song.album;
        
        final apiSig = _generateSignature(params, _sharedSecret!);
        final requestBody = {
          ...params,
          'api_sig': apiSig,
          'format': 'json',
        };

        final response = await _client.post(
          Uri.parse(_lastfmApiBaseUrl),
          body: requestBody,
        );
        
        if (response.statusCode != 200) {
          _logger.w('Direct Last.fm updateNowPlaying failed: ${response.body}');
        }
        return; // Success or failure, we tried direct
      } catch (e) {
        _logger.e('Error updating Last.fm Now Playing directly: $e');
      }
    }

    // Proxy fallback
    if (BackendApiService.useProxyBackend) {
      try {
        final response = await _client.post(
          Uri.parse('${BackendApiService.baseUrl}/api/v1/lastfm/nowplaying'),
          headers: {
            'Content-Type': 'application/json',
            'X-Feels-Secret': dotenv.isInitialized ? (dotenv.env['API_SECRET'] ?? 'development_secret_123') : 'development_secret_123',
          },
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
  }

  /// Scrobble a track
  Future<void> scrobble(Song song, DateTime timestamp) async {
    if (!isConfigured) return;
    
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = prefs.getString(_sessionKeyPref);
    if (sessionKey == null) return;

    final timestampUnix = (timestamp.millisecondsSinceEpoch / 1000).floor().toString();

    if (_hasLocalKeys) {
      try {
        final params = {
          'method': 'track.scrobble',
          'track': song.title,
          'artist': song.artist,
          'timestamp': timestampUnix,
          'api_key': _apiKey!,
          'sk': sessionKey,
        };
        if (song.album.isNotEmpty) params['album'] = song.album;
        
        final apiSig = _generateSignature(params, _sharedSecret!);
        final requestBody = {
          ...params,
          'api_sig': apiSig,
          'format': 'json',
        };

        final response = await _client.post(
          Uri.parse(_lastfmApiBaseUrl),
          body: requestBody,
        );
        
        if (response.statusCode == 200) {
          _logger.i('Successfully scrobbled directly: ${song.title} by ${song.artist}');
        } else {
          _logger.w('Direct Last.fm scrobble failed: ${response.body}');
        }
        return; // Success or failure, we tried direct
      } catch (e) {
        _logger.e('Error scrobbling to Last.fm directly: $e');
      }
    }

    // Proxy fallback
    if (BackendApiService.useProxyBackend) {
      try {
        final response = await _client.post(
          Uri.parse('${BackendApiService.baseUrl}/api/v1/lastfm/scrobble'),
          headers: {
            'Content-Type': 'application/json',
            'X-Feels-Secret': dotenv.isInitialized ? (dotenv.env['API_SECRET'] ?? 'development_secret_123') : 'development_secret_123',
          },
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

  /// Get user's top tracks for recommendations
  Future<List<Map<String, dynamic>>> getUserTopTracks(String username, {int limit = 5}) async {
    final apiKey = _apiKey;
    if (apiKey == null) return [];
    
    try {
      final response = await _client.get(
        Uri.parse('$_lastfmApiBaseUrl?method=user.gettoptracks&user=$username&api_key=$apiKey&limit=$limit&format=json'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['toptracks'] != null && data['toptracks']['track'] != null) {
          return List<Map<String, dynamic>>.from(data['toptracks']['track']);
        }
      } else {
        _logger.w('Failed to fetch user top tracks: ${response.body}');
      }
    } catch (e) {
      _logger.e('Error fetching user top tracks: $e');
    }
    return [];
  }
}
