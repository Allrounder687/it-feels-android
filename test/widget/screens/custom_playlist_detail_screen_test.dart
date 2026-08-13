import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/features/library/custom_playlist_detail_screen.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/data/models/custom_playlist.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLyricsService extends Mock implements LyricsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockMusicApiService extends Mock implements MusicApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSocialService extends Mock implements SocialService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCustomPlaylistNotifier extends CustomPlaylistNotifier {
  final CustomPlaylist playlist;

  FakeCustomPlaylistNotifier(this.playlist);

  @override
  CustomPlaylistState build() => CustomPlaylistState(
    playlists: [playlist],
  );
  
  @override
  Future<void> createPlaylist(String title) async {}

  @override
  Future<void> deletePlaylist(String id) async {}
  
  @override
  Future<void> addSongToPlaylist(String playlistId, Song song) async {}

  @override
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {}

  @override
  Future<void> loadPlaylists() async {}
}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

void main() {
  setUp(() {
    if (!locator.isRegistered<LyricsService>()) {
      locator.registerSingleton<LyricsService>(MockLyricsService());
    }
    if (!locator.isRegistered<MusicApiService>()) {
      locator.registerSingleton<MusicApiService>(MockMusicApiService());
    }
    if (!locator.isRegistered<SocialService>()) {
      locator.registerSingleton<SocialService>(MockSocialService());
    }
  });
  final mockSong = Song(
    id: 'song1',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: 200,
    saavnId: 'saavn1',
    coverArt: 'cover.jpg',
    addedAt: DateTime.now(),
  );

  final mockPlaylist = CustomPlaylist(
    id: 'playlist1',
    title: 'My Custom Playlist',
    songs: [mockSong],
    createdAt: DateTime.now(),
  );

  Widget createWidgetUnderTest() {
    appProviderContainer = ProviderContainer(
      overrides: [
        customPlaylistProvider.overrideWith(() => FakeCustomPlaylistNotifier(mockPlaylist)),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/custom-playlist/playlist1',
          routes: [
            GoRoute(
              path: '/custom-playlist/:id',
              builder: (context, state) => CustomPlaylistDetailScreen(
                playlist: mockPlaylist,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('CustomPlaylistDetailScreen renders correctly', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CustomPlaylistDetailScreen), findsOneWidget);
    expect(find.text('My Custom Playlist'), findsOneWidget);
  });
}
