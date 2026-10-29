import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:background_downloader/background_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/data/repositories/music_repository.dart';
import 'package:it_feels_music/services/download_service.dart';

class MockMusicRepository extends Mock implements IMusicRepository {}
class MockFileDownloader extends Mock implements FileDownloader {}
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
  late MockMusicRepository mockMusicRepository;
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

    mockMusicRepository = MockMusicRepository();
    mockFileDownloader = MockFileDownloader();
    mockClient = MockClient();

    DownloadService.httpClient = mockClient;

    when(() => mockFileDownloader.configureNotification(
          running: any(named: 'running'),
          complete: any(named: 'complete'),
          error: any(named: 'error'),
          progressBar: any(named: 'progressBar'),
        )).thenReturn(mockFileDownloader);

    service = DownloadService(
      apiService: mockMusicRepository,
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
        id: 'test_song_1',
        saavnId: 'test_saavn_1',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        duration: 200,
        coverArt: '',
        addedAt: DateTime.now(),
      );

      when(() => mockMusicRepository.getStreamUrl(song)).thenAnswer((_) async => null);

      final result = await service.downloadSong(song);
      expect(result, isFalse);
    });
  });
}
