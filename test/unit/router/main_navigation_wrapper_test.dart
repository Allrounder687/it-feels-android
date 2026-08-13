import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import 'package:it_feels_music/main.dart';
import 'package:it_feels_music/core/router/main_navigation_wrapper.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/features/settings/settings_provider.dart';
import 'package:it_feels_music/features/player/audio_player_provider.dart';
import 'package:it_feels_music/features/player/video_player_provider.dart';
import 'package:it_feels_music/features/player/active_media_provider.dart';
import 'package:it_feels_music/core/providers/bottom_ui_provider.dart';
import 'package:it_feels_music/features/library/listening_history_provider.dart';
import 'package:it_feels_music/features/library/custom_playlist_provider.dart';
import 'package:it_feels_music/services/config_service.dart';
import 'package:it_feels_music/features/social/unread_count_provider.dart';
import 'package:it_feels_music/data/models/song_model.dart';

import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/podcast_provider.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:it_feels_music/services/notification_service.dart';
import 'package:it_feels_music/services/cloud_sync_service.dart';
import 'package:it_feels_music/services/telemetry_service.dart';
import 'package:it_feels_music/features/social/social_service.dart';
import 'package:it_feels_music/features/cast/cast_service.dart' as it_feels_music_cast_service;
import 'package:it_feels_music/features/social/room_service.dart';
import 'package:it_feels_music/data/services/smart_storage_service.dart';
import 'package:it_feels_music/services/lastfm_service.dart';
import 'package:it_feels_music/data/services/radio_api_service.dart';
import 'package:it_feels_music/features/player/palette_extractor_service.dart';
import 'package:it_feels_music/data/services/audio_engine_service.dart';
import 'package:it_feels_music/features/social/listen_together_service.dart';
import 'package:it_feels_music/services/download_service.dart';
import 'package:it_feels_music/data/services/smart_cache_service.dart';

class MockLogger extends Mock implements Logger {}
class MockCloudSyncService extends Mock implements CloudSyncService {}
class MockTelemetryService extends Mock implements TelemetryService {}
class MockMusicApiService extends Mock implements MusicApiService {}
class MockLyricsService extends Mock implements LyricsService {}
class MockNotificationService extends Mock implements NotificationService {}
class MockSocialService extends Mock implements SocialService {}
class MockRoomService extends Mock implements RoomService {}
class MockCastService extends Mock implements it_feels_music_cast_service.CastService {}
class MockSmartStorageService extends Mock implements SmartStorageService {}
class MockLastfmService extends Mock implements LastfmService {}
class MockRadioApiService extends Mock implements RadioApiService {}
class MockPaletteExtractorService extends Mock implements PaletteExtractorService {}
class MockAudioEngineService extends Mock implements AudioEngineService {
  @override
  bool isAutoplayEnabled = false;
  @override
  Future<void> saveAudioSettings() async {}
}
class MockListenTogetherService extends Mock implements ListenTogetherService {}
class MockDownloadService extends Mock implements DownloadService {}
class MockSmartCacheService extends Mock implements SmartCacheService {}
class MockPodcastProvider extends Mock implements PodcastProvider {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

class MockListeningHistoryNotifier extends Notifier<ListeningHistoryState>
    with Mock
    implements ListeningHistoryNotifier {}

class MockCustomPlaylistNotifier extends Notifier<CustomPlaylistState>
    with Mock
    implements CustomPlaylistNotifier {}

class FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState _state;
  FakeSettingsNotifier(this._state);

  @override
  SettingsState build() => _state;
}

class FakeAudioPlayerNotifier extends AudioPlayerNotifier {
  final AudioPlayerState _state;
  FakeAudioPlayerNotifier(this._state);

  @override
  AudioPlayerState build() => _state;
}

class FakeVideoPlayerNotifier extends VideoPlayerNotifier {
  final VideoPlayerState _state;
  FakeVideoPlayerNotifier(this._state);

  @override
  VideoPlayerState build() => _state;
}

class FakeActiveMediaNotifier extends ActiveMediaNotifier {
  final ActiveMediaType _state;
  FakeActiveMediaNotifier(this._state);

  @override
  ActiveMediaType build() => _state;
}

class FakeBottomUiNotifier extends BottomUiNotifier {
  @override
  double build() => 0.0;

  @override
  void updateHeight(double height) {}
}

void setupMockLocator() {
  if (!locator.isRegistered<Logger>()) {
    locator.registerSingleton<Logger>(MockLogger());
  }
  if (!locator.isRegistered<CloudSyncService>()) {
    locator.registerSingleton<CloudSyncService>(MockCloudSyncService());
  }
  if (!locator.isRegistered<TelemetryService>()) {
    locator.registerSingleton<TelemetryService>(MockTelemetryService());
  }
  if (!locator.isRegistered<MusicApiService>()) {
    locator.registerSingleton<MusicApiService>(MockMusicApiService());
  }
  if (!locator.isRegistered<LyricsService>()) {
    locator.registerSingleton<LyricsService>(MockLyricsService());
  }
  if (!locator.isRegistered<NotificationService>()) {
    locator.registerSingleton<NotificationService>(MockNotificationService());
  }
  if (!locator.isRegistered<SocialService>()) {
    locator.registerSingleton<SocialService>(MockSocialService());
  }
  if (!locator.isRegistered<RoomService>()) {
    locator.registerSingleton<RoomService>(MockRoomService());
  }
  if (!locator.isRegistered<it_feels_music_cast_service.CastService>()) {
    locator.registerSingleton<it_feels_music_cast_service.CastService>(MockCastService());
  }
  if (!locator.isRegistered<SmartStorageService>()) {
    locator.registerSingleton<SmartStorageService>(MockSmartStorageService());
  }
  if (!locator.isRegistered<LastfmService>()) {
    locator.registerSingleton<LastfmService>(MockLastfmService());
  }
  if (!locator.isRegistered<RadioApiService>()) {
    locator.registerSingleton<RadioApiService>(MockRadioApiService());
  }
  if (!locator.isRegistered<PaletteExtractorService>()) {
    locator.registerSingleton<PaletteExtractorService>(MockPaletteExtractorService());
  }
  if (!locator.isRegistered<AudioEngineService>()) {
    locator.registerSingleton<AudioEngineService>(MockAudioEngineService());
  }
  if (!locator.isRegistered<ListenTogetherService>()) {
    locator.registerSingleton<ListenTogetherService>(MockListenTogetherService());
  }
  if (!locator.isRegistered<DownloadService>()) {
    locator.registerSingleton<DownloadService>(MockDownloadService());
  }
  if (!locator.isRegistered<SmartCacheService>()) {
    locator.registerSingleton<SmartCacheService>(MockSmartCacheService());
  }
  if (!locator.isRegistered<PodcastProvider>()) {
    locator.registerSingleton<PodcastProvider>(MockPodcastProvider());
  }
}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockColl;
  late MockDocumentReference mockDoc;
  late MockDocumentSnapshot mockSnapshot;

  late MockListeningHistoryNotifier mockHistoryNotifier;
  late MockCustomPlaylistNotifier mockCustomPlaylistNotifier;

  setUpAll(() {
    registerFallbackValue(const GetOptions());
    registerFallbackValue(Song(
      id: '',
      saavnId: '',
      title: '',
      artist: '',
      album: '',
      duration: 0,
      coverArt: '',
      genre: '',
      year: 2026,
      language: '',
      isExplicit: false,
      playCount: 0,
      skipCount: 0,
      addedAt: DateTime.now(),
      isFavorite: false,
      offlineStatus: OfflineStatus.none,
      searchVector: [],
    ));
    
    PackageInfo.setMockInitialValues(
      appName: 'IT-Feels',
      packageName: 'com.itfeels.music',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    setupMockLocator();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    mockFirestore = MockFirebaseFirestore();
    mockColl = MockCollectionReference();
    mockDoc = MockDocumentReference();
    mockSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection(any())).thenReturn(mockColl);
    when(() => mockColl.doc(any())).thenReturn(mockDoc);
    when(() => mockDoc.get(any())).thenAnswer((_) async => mockSnapshot);
    when(() => mockSnapshot.exists).thenReturn(false);
    when(() => mockSnapshot.data()).thenReturn(null);

    ConfigService.customFirestore = mockFirestore;

    mockHistoryNotifier = MockListeningHistoryNotifier();
    when(() => mockHistoryNotifier.build()).thenReturn(const ListeningHistoryState());
    when(() => mockHistoryNotifier.logSong(any())).thenAnswer((_) async {});

    mockCustomPlaylistNotifier = MockCustomPlaylistNotifier();
    when(() => mockCustomPlaylistNotifier.build()).thenReturn(const CustomPlaylistState());

    // Initialize global appProviderContainer for context lookups inside wrapper components
    try {
      appProviderContainer;
    } catch (_) {
      appProviderContainer = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => FakeSettingsNotifier(const SettingsState())),
          audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier(const AudioPlayerState())),
        ],
      );
    }
  });

  Widget buildTestWidget({
    required SettingsState settings,
    required AudioPlayerState audio,
    required VideoPlayerState video,
    required ActiveMediaType activeMedia,
    required double width,
  }) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationWrapper(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Text('Home Screen Content'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const Text('Search Screen Content'),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => FakeSettingsNotifier(settings)),
        audioPlayerProvider.overrideWith(() => FakeAudioPlayerNotifier(audio)),
        videoPlayerProvider.overrideWith(() => FakeVideoPlayerNotifier(video)),
        activeMediaProvider.overrideWith(() => FakeActiveMediaNotifier(activeMedia)),
        listeningHistoryProvider.overrideWith(() => mockHistoryNotifier),
        customPlaylistProvider.overrideWith(() => mockCustomPlaylistNotifier),
        bottomUiProvider.overrideWith(() => FakeBottomUiNotifier()),
        sidebarPinnedProvider.overrideWith((ref) => true),
        unreadCountProvider.overrideWith((ref) => Stream.value(0)),
        shorebirdUpdatePendingProvider.overrideWith((ref) => false),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
  }

  group('MainNavigationWrapper responsive layouts', () {
    testWidgets('renders sidebar navigation on wide screens', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          settings: const SettingsState(enableMusicVideos: false),
          audio: const AudioPlayerState(),
          video: const VideoPlayerState(),
          activeMedia: ActiveMediaType.none,
          width: 800,
        ),
      );

      await tester.pumpAndSettle();

      // Check wide layout displays sidebar items
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
      
      // Bottom navigation pill should not be shown on wide screen
      expect(find.text('Social'), findsNothing);
    });

    testWidgets('renders bottom navigation bar on mobile/narrow screens', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          settings: const SettingsState(enableMusicVideos: false),
          audio: const AudioPlayerState(),
          video: const VideoPlayerState(),
          activeMedia: ActiveMediaType.none,
          width: 320,
        ),
      );

      await tester.pumpAndSettle();

      // Verify bottom nav items are visible on mobile width
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
    });
  });
}
