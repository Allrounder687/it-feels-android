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

class MockListenTogetherService extends Mock implements ListenTogetherService {}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => AudioPlayerState(isLoading: false);
}

void main() {
  late MockListenTogetherService mockListenTogetherService;

  setUpAll(() {
    appProviderContainer = ProviderContainer();
  });

  setUp(() {
    mockListenTogetherService = MockListenTogetherService();
    if (!locator.isRegistered<ListenTogetherService>()) {
      locator.registerSingleton<ListenTogetherService>(mockListenTogetherService);
    }
  });

  Widget createWidgetUnderTest(String roomId) {
    return ProviderScope(
      parent: appProviderContainer,
      overrides: [
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier()),
      ],
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
          ],
        ),
      ),
    );
  }

  testWidgets('RoomDeepLinkScreen shows joining state', (tester) async {
    when(() => mockListenTogetherService.joinSession(any())).thenAnswer((_) async {});
    
    await tester.pumpWidget(createWidgetUnderTest('room123'));
    
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Joining room...'), findsOneWidget);
  });
}
