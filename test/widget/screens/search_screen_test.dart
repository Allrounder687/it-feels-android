import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/features/search/search_screen.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/search/search_provider.dart';
import 'package:it_feels_music/main.dart';

class MockSearchProvider extends Notifier<SearchState> with Mock implements SearchNotifier {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAudioPlayerProvider extends Notifier<AudioPlayerState> with Mock implements AudioPlayerNotifier {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockSearchProvider mockSearchProvider;
  late MockAudioPlayerProvider mockAudioPlayerProvider;

  setUp(() {
    mockSearchProvider = MockSearchProvider();
    mockAudioPlayerProvider = MockAudioPlayerProvider();
    
    when(() => mockSearchProvider.build()).thenReturn(const SearchState());
    // We only need to mock build() because it's a Riverpod Notifier, and the framework will call build() to get the initial state, setting 'state' automatically.

    when(() => mockAudioPlayerProvider.build()).thenReturn(AudioPlayerState(isLoading: false));
  });

  Widget createWidgetUnderTest() {
    appProviderContainer = ProviderContainer(
      overrides: [
        searchProvider.overrideWith(() => mockSearchProvider),
        audioPlayerProvider.overrideWith(() => mockAudioPlayerProvider),
      ],
    );
    return UncontrolledProviderScope(
      container: appProviderContainer,
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
    when(() => mockSearchProvider.build()).thenReturn(const SearchState(recentSearches: ['Recent 1', 'Recent 2']));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (!isDesktop) {
      expect(find.byType(TextField), findsOneWidget);
    }
    expect(find.text('Recent 1'), findsOneWidget);
    expect(find.text('Recent 2'), findsOneWidget);
  });

  testWidgets('SearchScreen displays results when queried', (tester) async {
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

    when(() => mockSearchProvider.build()).thenReturn(SearchState(
      query: 'Test Query',
      songs: [mockSong]
    ));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    
    expect(find.text('Search Result Song'), findsOneWidget);
    expect(find.text('Search Artist'), findsWidgets);
  });
}
