import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:it_feels_music/features/social/room_deep_link_screen.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';

class MockListenTogetherService extends Mock implements ListenTogetherService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);

  @override
  Future<void> joinSession(String roomId) async {
    // Delay to allow UI to be tested before navigation
    await Future.delayed(const Duration(seconds: 1));
  }
}

void main() {
  late MockListenTogetherService mockListenTogetherService;
  late MockLyricsService mockLyricsService;
  late MockMusicApiService mockMusicApiService;
  late MockSocialService mockSocialService;

  setUpAll(() {
    mockListenTogetherService = MockListenTogetherService();
    mockLyricsService = MockLyricsService();
    mockMusicApiService = MockMusicApiService();
    mockSocialService = MockSocialService();

    if (!locator.isRegistered<ListenTogetherService>()) {
      locator.registerSingleton<ListenTogetherService>(mockListenTogetherService);
    }
    if (!locator.isRegistered<LyricsService>()) {
      locator.registerSingleton<LyricsService>(mockLyricsService);
    }
    if (!locator.isRegistered<MusicApiService>()) {
      locator.registerSingleton<MusicApiService>(mockMusicApiService);
    }
    if (!locator.isRegistered<SocialService>()) {
      locator.registerSingleton<SocialService>(mockSocialService);
    }
  });

  Widget createWidgetUnderTest(String roomId) {
    appProviderContainer = ProviderContainer(
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
    );

    return UncontrolledProviderScope(
      container: appProviderContainer,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/room/$roomId',
          routes: [
            GoRoute(
              path: '/room/:id', 
              builder: (context, state) => RoomDeepLinkScreen(
                roomId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) => const Scaffold(body: Text('Home')),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('RoomDeepLinkScreen shows joining state', (tester) async {
    when(() => mockListenTogetherService.joinSession(any())).thenAnswer((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    
    await tester.pumpWidget(createWidgetUnderTest('room123'));
    
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Joining Room...'), findsOneWidget);
    
    // Clear pending timers
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
