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
  setUpAll(() {
    appProviderContainer = ProviderContainer();
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
    return ProviderScope(
      parent: appProviderContainer,
      overrides: [
        customPlaylistProvider.overrideWith(() => FakeCustomPlaylistNotifier(mockPlaylist)),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
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
