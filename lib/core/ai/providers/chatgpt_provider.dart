import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../../../data/models/song_model.dart';

class ChatGPTProvider implements AIProvider {
  final String apiKey;
  ChatGPTProvider(this.apiKey);

  @override
  String get id => 'chatgpt';

  @override
  String get displayName => 'ChatGPT';

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
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a music recommender. From the available library, output a playlist matching the user request. Return only the structured schema.'
          },
          {
            'role': 'user',
            'content': 'Request: "$userRequest"\n\nLibrary:\n${json.encode(libraryMetadata)}'
          }
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'playlist_schema',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist'],
              'additionalProperties': false
            }
          }
        }
      },
      timeout: maxResponseTime ?? const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final choice = data['choices'][0]['message']['content'] as String;
    final parsedJson = json.decode(choice.trim()) as Map<String, dynamic>;
    final playlistNames = (parsedJson['playlist'] as List?)?.cast<String>() ?? [];

    final results = <Song>[];
    for (final name in playlistNames) {
      final nameLower = name.toLowerCase();
      final match = localLibrary.firstWhere(
        (s) => s.title.toLowerCase() == nameLower || s.title.toLowerCase().contains(nameLower),
        orElse: () => Song(id: '', saavnId: '', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) {
        results.add(match);
      }
    }
    return results;
  }

  @override
  Future<List<Song>> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  }) async {
    final queueMetadata = queue.map((s) => s.title).toList();
    final response = await _postRequest(
      body: {
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': 'Reorder the queue to match the mood. Do not add new songs.'
          },
          {
            'role': 'user',
            'content': 'Mood: "$moodDescription"\n\nQueue:\n${json.encode(queueMetadata)}'
          }
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'reorder_schema',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist'],
              'additionalProperties': false
            }
          }
        }
      },
      timeout: const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final choice = data['choices'][0]['message']['content'] as String;
    final parsedJson = json.decode(choice.trim()) as Map<String, dynamic>;
    final playlistNames = (parsedJson['playlist'] as List?)?.cast<String>() ?? [];

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
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': 'Suggest a playlist name based on the songs provided.'
          },
          {
            'role': 'user',
            'content': 'Initial name: "$initialName"\n\nSongs:\n${json.encode(songDetails)}'
          }
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'suggest_name_schema',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'suggested_name': {'type': 'string'}
              },
              'required': ['suggested_name'],
              'additionalProperties': false
            }
          }
        }
      },
      timeout: const Duration(seconds: 10),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final choice = data['choices'][0]['message']['content'] as String;
    final parsedJson = json.decode(choice.trim()) as Map<String, dynamic>;
    return parsedJson['suggested_name'] as String? ?? initialName;
  }

  @override
  Future<String> describePlaylistVibe({required List<Song> songs}) async {
    final songDetails = songs.map((s) => '${s.title} - ${s.artist} - ${s.genre}').toList();
    final response = await _postRequest(
      body: {
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': 'Describe the playlist vibe in one or two short sentences.'
          },
          {
            'role': 'user',
            'content': 'Songs:\n${json.encode(songDetails)}'
          }
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'vibe_schema',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'vibe': {'type': 'string'}
              },
              'required': ['vibe'],
              'additionalProperties': false
            }
          }
        }
      },
      timeout: const Duration(seconds: 10),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final choice = data['choices'][0]['message']['content'] as String;
    final parsedJson = json.decode(choice.trim()) as Map<String, dynamic>;
    return parsedJson['vibe'] as String? ?? 'No vibe description available.';
  }

  @override
  Future<List<Song>> recommendSongs({
    required List<Song> library,
    required String context,
  }) async {
    final libraryDetails = library.map((s) => '${s.title} - ${s.artist}').toList();
    final response = await _postRequest(
      body: {
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content': 'Recommend up to 5 songs from the user\'s library based on the context.'
          },
          {
            'role': 'user',
            'content': 'Context: "$context"\n\nLibrary:\n${json.encode(libraryDetails)}'
          }
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'recommendation_schema',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'playlist': {
                  'type': 'array',
                  'items': {'type': 'string'}
                }
              },
              'required': ['playlist'],
              'additionalProperties': false
            }
          }
        }
      },
      timeout: const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final choice = data['choices'][0]['message']['content'] as String;
    final parsedJson = json.decode(choice.trim()) as Map<String, dynamic>;
    final playlistNames = (parsedJson['playlist'] as List?)?.cast<String>() ?? [];

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
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
          'max_tokens': 5,
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
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
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
