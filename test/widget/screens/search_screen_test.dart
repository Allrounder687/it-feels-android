import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/features/search/search_screen.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';

class MockSearchProvider extends AutoDisposeNotifier<AsyncValue<Map<String, dynamic>>> with Mock implements SearchNotifier {}
class MockAudioPlayerProvider extends Notifier<AudioPlayerState> with Mock implements AudioPlayerNotifier {}

void main() {
  late MockSearchProvider mockSearchProvider;
  late MockAudioPlayerProvider mockAudioPlayerProvider;

  setUp(() {
    mockSearchProvider = MockSearchProvider();
    mockAudioPlayerProvider = MockAudioPlayerProvider();
    
    when(() => mockSearchProvider.build()).thenReturn(const AsyncValue.data({}));
    when(() => mockSearchProvider.state).thenReturn(const AsyncValue.data({}));
    when(() => mockSearchProvider.searchQuery).thenReturn('');
    when(() => mockSearchProvider.selectedFilterIndex).thenReturn(0);
    when(() => mockSearchProvider.getRecentSearches()).thenReturn([]);

    when(() => mockAudioPlayerProvider.build()).thenReturn(AudioPlayerState(isLoading: false));
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        searchProvider.overrideWith(() => mockSearchProvider),
        audioPlayerProvider.overrideWith(() => mockAudioPlayerProvider),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/', 
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('SearchScreen displays search field and recent searches initially', (tester) async {
    when(() => mockSearchProvider.getRecentSearches()).thenReturn(['Recent 1', 'Recent 2']);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Recent 1'), findsOneWidget);
    expect(find.text('Recent 2'), findsOneWidget);
  });

  testWidgets('SearchScreen displays results when queried', (tester) async {
    when(() => mockSearchProvider.searchQuery).thenReturn('Test Query');
    final mockSong = Song(
      id: '123',
      saavnId: '123',
      title: 'Search Result Song',
      artist: 'Search Artist',
      album: 'Search Album',
      duration: 200,
      coverArt: '',
      addedAt: DateTime.now(),
    );

    when(() => mockSearchProvider.build()).thenReturn(AsyncValue.data({
      'songs': [mockSong]
    }));
    when(() => mockSearchProvider.state).thenReturn(AsyncValue.data({
      'songs': [mockSong]
    }));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    
    expect(find.text('Search Result Song'), findsOneWidget);
    expect(find.text('Search Artist'), findsWidgets);
  });
}
