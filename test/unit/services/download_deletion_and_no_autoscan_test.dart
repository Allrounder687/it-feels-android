import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/core/providers/riverpod_bridge.dart';
import 'package:it_feels_music/services/storage_service.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/data/services/lyrics_service.dart';
import 'package:mocktail/mocktail.dart';

class MockMusicRepository extends Mock implements IMusicRepository {}
class MockLyricsService extends Mock implements LyricsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockMusicRepository mockRepo;
  late MockLyricsService mockLyrics;

  setUpAll(() {
    mockRepo = MockMusicRepository();
    mockLyrics = MockLyricsService();
    if (!locator.isRegistered<IMusicRepository>()) {
      locator.registerSingleton<IMusicRepository>(mockRepo);
    }
    if (!locator.isRegistered<LyricsService>()) {
      locator.registerSingleton<LyricsService>(mockLyrics);
    }
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('download_delete_test');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Download Deletion and No Auto-Scan Tests', () {
    test('DownloadNotifier initializes from stored downloads without running auto-scan', () async {
      final initialSong = Song(
        id: 'saavn:test_song_1',
        saavnId: 'test_song_1',
        title: 'Initial Song',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: 180,
        coverArt: 'https://example.com/cover.jpg',
        offlineStatus: OfflineStatus.downloaded,
        addedAt: DateTime.now(),
      );

      await StorageService.saveDownloads([initialSong]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger initialization
      container.read(downloadProvider);
      
      // Allow async _init() to load from disk (DatabaseService.ensureInitialized has a 200ms delay)
      await Future.delayed(const Duration(milliseconds: 400));

      final state = container.read(downloadProvider);
      // Auto-scan should NOT have run
      expect(state.isScanning, isFalse);
      expect(state.downloadedSongs.length, 1);
      expect(state.downloadedSongs.first.title, 'Initial Song');
    });

    test('removeDownload permanently removes track from state and deletes file from disk', () async {
      final audioFile = File('${tempDir.path}/test_track.mp3');
      audioFile.writeAsBytesSync(List.filled(2048, 1));
      expect(audioFile.existsSync(), isTrue);

      final downloadedSong = Song(
        id: 'saavn:delete_target',
        saavnId: 'delete_target',
        title: 'To Be Deleted',
        artist: 'Artist',
        album: 'Album',
        duration: 210,
        coverArt: 'https://example.com/art.jpg',
        encryptedMediaUrl: audioFile.path,
        offlineStatus: OfflineStatus.downloaded,
        addedAt: DateTime.now(),
      );

      await StorageService.saveDownloads([downloadedSong]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(downloadProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 400));

      // Trigger deletion
      await notifier.removeDownload(downloadedSong);

      // Verify removed from Riverpod state
      final state = container.read(downloadProvider);
      expect(state.downloadedSongs.any((s) => s.id == downloadedSong.id), isFalse);

      // Verify removed from StorageService
      final persisted = await StorageService.loadDownloads();
      expect(persisted.any((s) => s.id == downloadedSong.id), isFalse);

      // Verify file deleted from disk
      expect(audioFile.existsSync(), isFalse);
    });

    test('clearAllDownloads wipes all downloaded songs and storage', () async {
      final f1 = File('${tempDir.path}/track1.mp3');
      final f2 = File('${tempDir.path}/track2.mp3');
      f1.writeAsBytesSync([1, 2, 3]);
      f2.writeAsBytesSync([4, 5, 6]);

      final song1 = Song(
        id: 'song_1',
        saavnId: 'song_1',
        title: 'Song 1',
        artist: 'A1',
        album: 'Alb1',
        duration: 100,
        coverArt: '',
        encryptedMediaUrl: f1.path,
        offlineStatus: OfflineStatus.downloaded,
        addedAt: DateTime.now(),
      );

      final song2 = Song(
        id: 'song_2',
        saavnId: 'song_2',
        title: 'Song 2',
        artist: 'A2',
        album: 'Alb2',
        duration: 120,
        coverArt: '',
        encryptedMediaUrl: f2.path,
        offlineStatus: OfflineStatus.downloaded,
        addedAt: DateTime.now(),
      );

      await StorageService.saveDownloads([song1, song2]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(downloadProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 400));

      await notifier.clearAllDownloads();

      expect(container.read(downloadProvider).downloadedSongs, isEmpty);
      expect(await StorageService.loadDownloads(), isEmpty);
      expect(f1.existsSync(), isFalse);
      expect(f2.existsSync(), isFalse);
    });
  });
}
