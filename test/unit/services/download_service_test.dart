import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:background_downloader/background_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/services/music_api_service.dart';
import 'package:it_feels_music/services/download_service.dart';

class MockMusicApiService extends Mock implements MusicApiService {}
class MockFileDownloader extends Mock implements FileDownloader {}
class MockTaskStatusUpdate extends Mock implements TaskStatusUpdate {}
class MockClient extends Mock implements http.Client {}

class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;
  final String docPath;

  FakePathProviderPlatform({required this.tempPath, required this.docPath});

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;
}

void main() {
  late MockMusicApiService mockMusicApiService;
  late MockFileDownloader mockFileDownloader;
  late MockClient mockClient;
  late DownloadService service;
  late Directory tempDir;
  late Directory docDir;

  setUpAll(() {
    registerFallbackValue(DownloadTask(url: ''));
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('download_test_temp');
    docDir = Directory.systemTemp.createTempSync('download_test_doc');
    
    PathProviderPlatform.instance = FakePathProviderPlatform(
      tempPath: tempDir.path,
      docPath: docDir.path,
    );

    SharedPreferences.setMockInitialValues({
      'custom_download_path_setting': '',
    });

    mockMusicApiService = MockMusicApiService();
    mockFileDownloader = MockFileDownloader();
    mockClient = MockClient();

    DownloadService.httpClient = mockClient;

    // Stub FileDownloader configureNotification to return the mock downloader instance
    when(() => mockFileDownloader.configureNotification(
          running: any(named: 'running'),
          complete: any(named: 'complete'),
          error: any(named: 'error'),
          progressBar: any(named: 'progressBar'),
        )).thenReturn(mockFileDownloader);

    service = DownloadService(
      apiService: mockMusicApiService,
      downloader: mockFileDownloader,
    );
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      if (docDir.existsSync()) docDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DownloadService getDownloadDirectoryPath', () {
    test('returns default documents path on non-Android when custom path is empty', () async {
      final path = await service.getDownloadDirectoryPath();
      expect(path, '${docDir.path}/downloaded_music');
    });

    test('returns custom path if set in settings', () async {
      final customPath = '${tempDir.path}/custom_music';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_download_path_setting', customPath);

      final path = await service.getDownloadDirectoryPath();
      expect(path, customPath);
    });
  });

  group('DownloadService downloadSong', () {
    test('downloadSong returns false if stream URL cannot be resolved', () async {
      final song = Song(
        id: '123',
        saavnId: 'saavn_123',
        title: 'Song Title',
        artist: 'Artist',
        album: 'Album',
        duration: 180,
        coverArt: '',
        genre: '',
        year: 2026,
        language: 'English',
        isExplicit: false,
        playCount: 0,
        skipCount: 0,
        addedAt: DateTime.now(),
        isFavorite: false,
        offlineStatus: OfflineStatus.none,
        searchVector: [],
      );

      when(() => mockMusicApiService.getStreamUrl(song)).thenAnswer((_) async => null);

      final result = await service.downloadSong(song);
      expect(result, isFalse);
    });

    test('downloadSong downloads cover art and runs background downloader task successfully', () async {
      final song = Song(
        id: '123',
        saavnId: 'saavn_123',
        title: 'Song Title',
        artist: 'Artist',
        album: 'Album',
        duration: 180,
        coverArt: 'https://example.com/cover.jpg',
        genre: '',
        year: 2026,
        language: 'English',
        isExplicit: false,
        playCount: 0,
        skipCount: 0,
        addedAt: DateTime.now(),
        isFavorite: false,
        offlineStatus: OfflineStatus.none,
        searchVector: [],
      );

      when(() => mockMusicApiService.getStreamUrl(song))
          .thenAnswer((_) async => 'https://example.com/stream.mp3');

      // Stub HTTP client for cover art download
      when(() => mockClient.get(Uri.parse(song.coverArt)))
          .thenAnswer((_) async => http.Response.bytes([1, 2, 3], 200));

      final mockStatusUpdate = MockTaskStatusUpdate();
      when(() => mockStatusUpdate.status).thenReturn(TaskStatus.complete);

      when(() => mockFileDownloader.download(
            any(),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => mockStatusUpdate);

      final result = await service.downloadSong(song);
      expect(result, isTrue);

      // Verify task run
      verify(() => mockFileDownloader.download(any(), onProgress: any(named: 'onProgress'))).called(1);

      // Verify local file creation for cover art
      final customPath = '${docDir.path}/downloaded_music';
      final coverFile = File('$customPath/123.jpg');
      expect(coverFile.existsSync(), isTrue);
      expect(coverFile.readAsBytesSync(), [1, 2, 3]);
    });
  });
}
