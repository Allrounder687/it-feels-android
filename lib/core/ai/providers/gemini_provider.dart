import '../ai_provider.dart';
import '../../../data/models/song_model.dart';
import '../../../services/backend_api_service.dart';

class GeminiProvider implements AIProvider {
  final String apiKey; // Kept for backwards compatibility constructor signature
  GeminiProvider(this.apiKey);

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
    }).toList();

    final response = await BackendApiService.performAiAction(
      provider: 'gemini',
      action: 'generatePlaylistFromRequest',
      payload: {
        'userRequest': userRequest,
        'libraryMetadata': libraryMetadata,
      },
    );

    if (response == null || !response['success']) throw Exception('Failed to generate playlist');
    final playlistNames = (response['result']['playlist'] as List?)?.cast<String>() ?? [];

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
      if (match.id.isNotEmpty) results.add(match);
    }
    return results;
  }

  @override
  Future<List<String>> generateGlobalPlaylistNames({
    required String userRequest,
    Duration? maxResponseTime,
  }) async {
    final response = await BackendApiService.performAiAction(
      provider: 'gemini',
      action: 'generateGlobalPlaylistNames',
      payload: {
        'userRequest': userRequest,
      },
    );
    if (response == null || !response['success']) throw Exception('Failed to generate names');
    return (response['result']['playlist'] as List?)?.cast<String>() ?? [];
  }

  @override
  Future<List<Song>> reorderQueueByMood({
    required List<Song> queue,
    required String moodDescription,
  }) async {
    final queueMetadata = queue.map((s) => s.title).toList();
    final response = await BackendApiService.performAiAction(
      provider: 'gemini',
      action: 'reorderQueueByMood',
      payload: {
        'moodDescription': moodDescription,
        'queueMetadata': queueMetadata,
      },
    );
    if (response == null || !response['success']) return queue;
    
    final playlistNames = (response['result']['playlist'] as List?)?.cast<String>() ?? [];
    final results = <Song>[];
    for (final name in playlistNames) {
      final match = queue.firstWhere(
        (s) => s.title.toLowerCase() == name.toLowerCase(),
        orElse: () => Song(id: '', saavnId: '', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) results.add(match);
    }
    return results.isNotEmpty ? results : queue;
  }

  @override
  Future<String> suggestPlaylistName({
    required String initialName,
    required List<Song> songs,
  }) async {
    final songsMetadata = songs.take(5).map((s) => s.title).toList();
    final response = await BackendApiService.performAiAction(
      provider: 'gemini',
      action: 'suggestPlaylistName',
      payload: {
        'initialName': initialName,
        'songsMetadata': songsMetadata,
      },
    );
    if (response == null || !response['success']) return initialName;
    return response['result']['name'] ?? initialName;
  }

  @override
  Future<String> describePlaylistVibe({required List<Song> songs}) async {
    final songsMetadata = songs.take(10).map((s) => s.title).toList();
    final response = await BackendApiService.performAiAction(
      provider: 'gemini',
      action: 'describePlaylistVibe',
      payload: {
        'songsMetadata': songsMetadata,
      },
    );
    if (response == null || !response['success']) return 'A curated collection of your favorite tracks.';
    return response['result'] ?? 'A curated collection of your favorite tracks.';
  }

  @override
  Future<List<Song>> recommendSongs({
    required List<Song> library,
    required String context,
  }) async {
    final libraryMetadata = library.map((s) => s.title).toList();
    final response = await BackendApiService.performAiAction(
      provider: 'gemini',
      action: 'recommendSongs',
      payload: {
        'context': context,
        'libraryMetadata': libraryMetadata,
      },
    );
    if (response == null || !response['success']) return [];
    
    final playlistNames = (response['result']['playlist'] as List?)?.cast<String>() ?? [];
    final results = <Song>[];
    for (final name in playlistNames) {
      final match = library.firstWhere(
        (s) => s.title.toLowerCase() == name.toLowerCase(),
        orElse: () => Song(id: '', saavnId: '', title: '', artist: '', album: '', duration: 0, coverArt: '', addedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) results.add(match);
    }
    return results;
  }

  @override
  Future<bool> checkAvailability() async {
    return true; // Proxy handles key validation
  }
}
