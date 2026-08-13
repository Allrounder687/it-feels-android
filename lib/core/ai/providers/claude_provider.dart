import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../../../data/models/song_model.dart';

class ClaudeProvider implements AIProvider {
  final String apiKey;
  final http.Client _client;
  ClaudeProvider(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  @override
  String get id => 'claude';

  @override
  String get displayName => 'Claude';

  @override
  Future<List<Song>> generatePlaylistFromRequest({
    required String userRequest,
    required List<Song> localLibrary,
    Duration? maxResponseTime,
  }) async {
    final libraryMetadata = localLibrary.map((s) => {
      'title': s.title,
      'artist': s.artist,
      'album': s.album,
      'duration': s.duration,
      'genre': s.genre,
    }).toList();

    final response = await _postRequest(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'You are an intelligent music DJ. From the available library, output a playlist matching the user request. If unfamiliar with some tracks, take your best guess based on the title, artist, or genre. ALWAYS try to return at least 3-5 songs if possible. If the user request is generic, return a varied mix.\n\nRequest: "$userRequest"\n\nLibrary:\n${json.encode(libraryMetadata)}'
          }
        ],
        'tools': [
          {
            'name': 'return_playlist',
            'description': 'Returns the selected playlist of songs',
            'input_schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist']
            }
          }
        ],
        'tool_choice': {'type': 'tool', 'name': 'return_playlist'}
      },
      timeout: maxResponseTime ?? const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final content = data['content'] as List;
    final toolUse = content.firstWhere((c) => c['type'] == 'tool_use') as Map<String, dynamic>;
    final input = toolUse['input'] as Map<String, dynamic>;
    final playlistNames = (input['playlist'] as List?)?.cast<String>() ?? [];

    final results = <Song>[];
    for (final name in playlistNames) {
      final nameLower = name.toLowerCase().trim();
      final match = localLibrary.firstWhere(
        (s) {
           final sTitle = s.title.toLowerCase().trim();
           return sTitle == nameLower || 
                  sTitle.contains(nameLower) || 
                  nameLower.contains(sTitle);
        },
        orElse: () => Song(id: '', saavnId: '', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) {
        results.add(match);
      }
    }
    return results;
  }

  @override
  Future<List<String>> generateGlobalPlaylistNames({
    required String userRequest,
    Duration? maxResponseTime,
  }) async {
    final response = await _postRequest(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'You are an intelligent music DJ. Given the user request, recommend exactly 10 highly relevant songs from across all global music.\n\nRequest: "$userRequest"'
          }
        ],
        'tools': [
          {
            'name': 'return_playlist',
            'description': 'Returns the selected playlist of songs',
            'input_schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist']
            }
          }
        ],
        'tool_choice': {'type': 'tool', 'name': 'return_playlist'}
      },
      timeout: maxResponseTime ?? const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final content = data['content'] as List;
    final toolUse = content.firstWhere((c) => c['type'] == 'tool_use') as Map<String, dynamic>;
    final input = toolUse['input'] as Map<String, dynamic>;
    final playlistNames = (input['playlist'] as List?)?.cast<String>() ?? [];
    
    return playlistNames.take(10).toList();
  }

  @override
  Future<List<Song>> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  }) async {
    final queueMetadata = queue.map((s) => s.title).toList();
    final response = await _postRequest(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'Mood: "$moodDescription"\n\nQueue:\n${json.encode(queueMetadata)}'
          }
        ],
        'tools': [
          {
            'name': 'return_reordered_playlist',
            'description': 'Returns the reordered playlist of songs',
            'input_schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist']
            }
          }
        ],
        'tool_choice': {'type': 'tool', 'name': 'return_reordered_playlist'}
      },
      timeout: const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final content = data['content'] as List;
    final toolUse = content.firstWhere((c) => c['type'] == 'tool_use') as Map<String, dynamic>;
    final input = toolUse['input'] as Map<String, dynamic>;
    final playlistNames = (input['playlist'] as List?)?.cast<String>() ?? [];

    final results = <Song>[];
    for (final name in playlistNames) {
      final match = queue.firstWhere(
        (s) => s.title.toLowerCase() == name.toLowerCase(),
        orElse: () => Song(id: '', saavnId: '', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) {
        results.add(match);
      }
    }
    return results.isNotEmpty ? results : queue;
  }

  @override
  Future<String> suggestPlaylistName({
    required String initialName,
    required List<Song> songs,
  }) async {
    final songDetails = songs.map((s) => '${s.title} - ${s.artist}').toList();
    final response = await _postRequest(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'Initial name: "$initialName"\n\nSongs:\n${json.encode(songDetails)}'
          }
        ],
        'tools': [
          {
            'name': 'return_playlist_name',
            'description': 'Returns the suggested playlist name',
            'input_schema': {
              'type': 'object',
              'properties': {
                'suggested_name': {'type': 'string'}
              },
              'required': ['suggested_name']
            }
          }
        ],
        'tool_choice': {'type': 'tool', 'name': 'return_playlist_name'}
      },
      timeout: const Duration(seconds: 10),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final content = data['content'] as List;
    final toolUse = content.firstWhere((c) => c['type'] == 'tool_use') as Map<String, dynamic>;
    final input = toolUse['input'] as Map<String, dynamic>;
    return input['suggested_name'] as String? ?? initialName;
  }

  @override
  Future<String> describePlaylistVibe({required List<Song> songs}) async {
    final songDetails = songs.map((s) => '${s.title} - ${s.artist} - ${s.genre}').toList();
    final response = await _postRequest(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'Songs:\n${json.encode(songDetails)}'
          }
        ],
        'tools': [
          {
            'name': 'return_playlist_vibe',
            'description': 'Returns the playlist vibe description',
            'input_schema': {
              'type': 'object',
              'properties': {
                'vibe': {'type': 'string'}
              },
              'required': ['vibe']
            }
          }
        ],
        'tool_choice': {'type': 'tool', 'name': 'return_playlist_vibe'}
      },
      timeout: const Duration(seconds: 10),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final content = data['content'] as List;
    final toolUse = content.firstWhere((c) => c['type'] == 'tool_use') as Map<String, dynamic>;
    final input = toolUse['input'] as Map<String, dynamic>;
    return input['vibe'] as String? ?? 'No vibe description available.';
  }

  @override
  Future<List<Song>> recommendSongs({
    required List<Song> library,
    required String context,
  }) async {
    final libraryDetails = library.map((s) => '${s.title} - ${s.artist}').toList();
    final response = await _postRequest(
      body: {
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': 'Context: "$context"\n\nLibrary:\n${json.encode(libraryDetails)}'
          }
        ],
        'tools': [
          {
            'name': 'return_recommendations',
            'description': 'Returns recommended songs',
            'input_schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist']
            }
          }
        ],
        'tool_choice': {'type': 'tool', 'name': 'return_recommendations'}
      },
      timeout: const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final content = data['content'] as List;
    final toolUse = content.firstWhere((c) => c['type'] == 'tool_use') as Map<String, dynamic>;
    final input = toolUse['input'] as Map<String, dynamic>;
    final playlistNames = (input['playlist'] as List?)?.cast<String>() ?? [];

    final results = <Song>[];
    for (final name in playlistNames) {
      final match = library.firstWhere(
        (s) => s.title.toLowerCase() == name.toLowerCase(),
        orElse: () => Song(id: '', saavnId: '', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) {
        results.add(match);
      }
    }
    return results;
  }

  @override
  Future<bool> checkAvailability() async {
    if (apiKey.isEmpty) return false;
    try {
      final response = await _client.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 5,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _postRequest({
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    ).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
    return response.body;
  }
}
