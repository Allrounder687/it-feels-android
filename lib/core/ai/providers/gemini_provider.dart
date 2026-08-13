import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';
import '../../../data/models/song_model.dart';

class GeminiProvider implements AIProvider {
  final String apiKey;
  final http.Client _client;
  GeminiProvider(this.apiKey, {http.Client? client}) : _client = client ?? http.Client();

  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Gemini';

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

    final prompt = '''
You are an intelligent music DJ. Given the user's request and the list of available songs in their library, return a playlist consisting ONLY of songs from their library that match the request.
If you are unfamiliar with some tracks (e.g. regional or indie songs), take your best guess based on the title, artist, or genre. 
ALWAYS try to return at least 10 songs if possible. If the library doesn't have 10 matching songs, return as many as you can. If the user's request is very generic (like "play something" or "any"), return a varied mix of songs.
Return the output as a JSON object matching this schema exactly (no markdown formatting):
{"playlist": ["Exact Song Title 1", "Exact Song Title 2"]}

User Request: "$userRequest"

Available Library:
${json.encode(libraryMetadata)}
''';

    final response = await _postRequest(
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      },
      timeout: maxResponseTime ?? const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini candidate content was empty.');
    }
    final text = parts[0]['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned empty text.');
    }

    String cleanedText = text.trim();
    if (cleanedText.startsWith('```json')) {
      cleanedText = cleanedText.replaceAll(RegExp(r'^```json\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
    } else if (cleanedText.startsWith('```')) {
      cleanedText = cleanedText.replaceAll(RegExp(r'^```\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
    }

    final parsedJson = json.decode(cleanedText) as Map<String, dynamic>;
    final playlistNames = (parsedJson['playlist'] as List?)?.cast<String>() ?? [];

    // Map names back to library using exact or basic title containment
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
      if (match.id.isNotEmpty && !results.any((r) => r.id == match.id)) {
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
    final prompt = '''
You are an intelligent music DJ. Given the user's request, recommend exactly 15 highly relevant songs from across all global music.
Return the output as a JSON object matching this schema exactly (no markdown formatting):
{"playlist": ["Song Title Artist", "Song Title Artist"]}

User Request: "$userRequest"
''';

    final response = await _postRequest(
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      },
      timeout: maxResponseTime ?? const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini candidate content was empty.');
    }
    final text = parts[0]['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned empty text.');
    }

    String cleanedText = text.trim();
    if (cleanedText.startsWith('```json')) {
      cleanedText = cleanedText.replaceAll(RegExp(r'^```json\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
    } else if (cleanedText.startsWith('```')) {
      cleanedText = cleanedText.replaceAll(RegExp(r'^```\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
    }

    final parsedJson = json.decode(cleanedText) as Map<String, dynamic>;
    final playlistNames = (parsedJson['playlist'] as List?)?.cast<String>() ?? [];
    
    return playlistNames.take(15).toList();
  }

  @override
  Future<List<Song>> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  }) async {
    final queueMetadata = queue.map((s) => s.title).toList();
    final prompt = '''
Reorder this queue of songs to fit the mood: "$moodDescription".
Return the output as a JSON object matching this schema:
{"playlist": ["Song Title A", "Song Title B"]}
Do not add any new songs. Reorder the existing ones.

Queue:
${json.encode(queueMetadata)}
''';

    final response = await _postRequest(
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      },
      timeout: const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final parsedJson = json.decode(text.trim()) as Map<String, dynamic>;
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
    final prompt = '''
Suggest a creative playlist name based on these songs:
${json.encode(songDetails)}
Initial temporary name: "$initialName"
Return the output as a JSON object:
{"suggested_name": "Creative Name"}
''';

    final response = await _postRequest(
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      },
      timeout: const Duration(seconds: 10),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final parsedJson = json.decode(text.trim()) as Map<String, dynamic>;
    return parsedJson['suggested_name'] as String? ?? initialName;
  }

  @override
  Future<String> describePlaylistVibe({required List<Song> songs}) async {
    final songDetails = songs.map((s) => '${s.title} - ${s.artist} - ${s.genre}').toList();
    final prompt = '''
Describe the musical vibe of this playlist in one or two short sentences:
${json.encode(songDetails)}
Return the output as a JSON object:
{"vibe": "Description here"}
''';

    final response = await _postRequest(
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      },
      timeout: const Duration(seconds: 10),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final parsedJson = json.decode(text.trim()) as Map<String, dynamic>;
    return parsedJson['vibe'] as String? ?? 'No vibe description available.';
  }

  @override
  Future<List<Song>> recommendSongs({
    required List<Song> library,
    required String context,
  }) async {
    final libraryDetails = library.map((s) => '${s.title} - ${s.artist}').toList();
    final prompt = '''
Based on this context: "$context", recommend up to 5 songs from this user's library:
${json.encode(libraryDetails)}
Return the output as a JSON object:
{"playlist": ["Song Title 1", "Song Title 2"]}
''';

    final response = await _postRequest(
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      body: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      },
      timeout: const Duration(seconds: 15),
    );

    final data = json.decode(response) as Map<String, dynamic>;
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final parsedJson = json.decode(text.trim()) as Map<String, dynamic>;
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
      final response = await _client.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': 'ping'}
              ]
            }
          ]
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _postRequest({
    required String url,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    ).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('API request failed with status: ${response.statusCode}');
    }
    return response.body;
  }
}
