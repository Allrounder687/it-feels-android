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

    when(() => mockFileDownloader.configureNotificationForTask(
          any(),
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

    test('downloadSong creates dedicated song folder, saves metadata.json and cover.jpg', () async {
      final song = Song(
        id: 'saavn_track_456',
        saavnId: 'track_456',
        title: 'Tum Hi Ho',
        artist: 'Arijit Singh',
        album: 'Aashiqui 2',
        duration: 262,
        coverArt: 'https://example.com/cover.jpg',
        addedAt: DateTime.now(),
      );

      when(() => mockMusicRepository.getStreamUrl(song))
          .thenAnswer((_) async => 'https://example.com/audio/tum_hi_ho.m4a');
      when(() => mockMusicRepository.getLyrics(any(), any(), album: any(named: 'album'), duration: any(named: 'duration')))
          .thenAnswer((_) async => {'synced': '[00:05.00] Hum tere bin ab reh nahi sakte', 'plain': 'Hum tere bin ab reh nahi sakte'});

      when(() => mockClient.get(Uri.parse('https://example.com/cover.jpg')))
          .thenAnswer((_) async => http.Response.bytes(List.filled(2048, 1), 200));

      when(() => mockFileDownloader.download(any(), onProgress: any(named: 'onProgress')))
          .thenAnswer((invocation) async {
            final task = invocation.positionalArguments[0] as DownloadTask;
            // Write a valid fake audio file at task.directory / task.filename
            final audioFile = File('${task.directory}/${task.filename}');
            await audioFile.writeAsBytes(List.filled(4096, 2));
            return TaskStatusUpdate(task, TaskStatus.complete);
          });

      final result = await service.downloadSong(song);
      expect(result, isTrue);

      final downloadDir = await service.getDownloadDirectoryPath();
      final expectedFolderName = 'Tum Hi Ho - Arijit Singh';
      final songFolder = Directory('$downloadDir/$expectedFolderName');

      expect(songFolder.existsSync(), isTrue);

      // Verify original song name audio file
      final audioFile = File('${songFolder.path}/Tum Hi Ho - Arijit Singh.m4a');
      expect(audioFile.existsSync(), isTrue);

      // Verify cover.jpg
      final coverFile = File('${songFolder.path}/cover.jpg');
      expect(coverFile.existsSync(), isTrue);

      // Verify lyrics.lrc
      final lrcFile = File('${songFolder.path}/lyrics.lrc');
      expect(lrcFile.existsSync(), isTrue);
      expect(lrcFile.readAsStringSync(), contains('Hum tere bin'));

      // Verify metadata.json
      final metaFile = File('${songFolder.path}/metadata.json');
      expect(metaFile.existsSync(), isTrue);
      final metaContent = metaFile.readAsStringSync();
      expect(metaContent, contains('Tum Hi Ho'));
      expect(metaContent, contains('Arijit Singh'));
      expect(metaContent, contains('Tum Hi Ho - Arijit Singh.m4a'));
      expect(metaContent, contains('cover.jpg'));
    });
  });

  group('DownloadService sanitizeFileName', () {
    test('sanitizes illegal characters and preserves original names', () {
      expect(DownloadService.sanitizeFileName('AC/DC - Highway'), 'AC - DC - Highway');
      expect(DownloadService.sanitizeFileName('What? Where?'), 'What Where');
      expect(DownloadService.sanitizeFileName('Track: Intro'), 'Track - Intro');
      expect(DownloadService.sanitizeFileName('"Hero"'), 'Hero');
      expect(DownloadService.sanitizeFileName('Song...   '), 'Song');
      expect(DownloadService.sanitizeFileName(''), 'Unknown');
      expect(DownloadService.sanitizeFileName('&#039;Hello&#039;'), "'Hello'");
    });
  });

  group('DownloadService scanAllDownloads', () {
    test('scans and recovers existing songs from subfolders with metadata.json', () async {
      final downloadDir = await service.getDownloadDirectoryPath();
      final songDir = Directory('$downloadDir/Blinding Lights - The Weeknd');
      songDir.createSync(recursive: true);

      // Create fake audio file (> 1024 bytes)
      final audioFile = File('${songDir.path}/Blinding Lights - The Weeknd.m4a');
      audioFile.writeAsBytesSync(List.filled(2048, 5));

      // Create fake cover.jpg
      final coverFile = File('${songDir.path}/cover.jpg');
      coverFile.writeAsBytesSync(List.filled(1024, 6));

      // Create fake metadata.json
      final metaFile = File('${songDir.path}/metadata.json');
      metaFile.writeAsStringSync('''{
        "id": "saavn_blinding_123",
        "saavnId": "blinding_123",
        "title": "Blinding Lights",
        "artist": "The Weeknd",
        "album": "After Hours",
        "duration": 200,
        "audioFile": "Blinding Lights - The Weeknd.m4a",
        "coverFile": "cover.jpg"
      }''');

      final scannedSongs = await service.scanAllDownloads();
      expect(scannedSongs.any((s) => s.title == 'Blinding Lights' && s.artist == 'The Weeknd'), isTrue);

      final foundSong = scannedSongs.firstWhere((s) => s.title == 'Blinding Lights');
      expect(File(foundSong.encryptedMediaUrl!).existsSync(), isTrue);
      expect(foundSong.encryptedMediaUrl, contains('Blinding Lights - The Weeknd.m4a'));
      expect(foundSong.album, 'After Hours');
    });

    test('scans and recovers legacy saavn_ direct files without metadata.json', () async {
      final downloadDir = await service.getDownloadDirectoryPath();
      Directory(downloadDir).createSync(recursive: true);
      final legacyFile = File('$downloadDir/saavn_legacy999.mp4');
      legacyFile.writeAsBytesSync(List.filled(2048, 7));

      final scannedSongs = await service.scanAllDownloads();
      expect(scannedSongs.any((s) => s.id.contains('legacy999')), isTrue);
    });

    test('recursively discovers songs in nested artist and album subdirectories', () async {
      final downloadDir = await service.getDownloadDirectoryPath();
      final nestedDir = Directory('$downloadDir/Coldplay/A Head Full of Dreams');
      nestedDir.createSync(recursive: true);

      final audioFile = File('${nestedDir.path}/Adventure of a Lifetime - Coldplay.m4a');
      audioFile.writeAsBytesSync(List.filled(2048, 8));

      final scannedSongs = await service.scanAllDownloads();
      expect(scannedSongs.any((s) => s.title.contains('Adventure of a Lifetime') && s.artist == 'Coldplay'), isTrue);
    });
  });

  group('DownloadService isSongMissingDetails', () {
    test('correctly identifies songs with missing or placeholder details', () {
      final now = DateTime.now();
      final placeholderSong = Song(
        id: 'saavn_xNVbUezC',
        saavnId: 'xNVbUezC',
        title: 'Downloaded Track (xNVbUezC)',
        artist: 'Unknown Artist',
        album: '',
        duration: 0,
        coverArt: '',
        addedAt: now,
      );
      expect(DownloadService.isSongMissingDetails(placeholderSong), isTrue);

      final noCoverSong = Song(
        id: 'song_123',
        saavnId: '123',
        title: 'Valid Title',
        artist: 'Valid Artist',
        album: 'Album',
        duration: 180,
        coverArt: '',
        addedAt: now,
      );
      expect(DownloadService.isSongMissingDetails(noCoverSong), isTrue);

      final nonExistentLocalCover = Song(
        id: 'song_456',
        saavnId: '456',
        title: 'Valid Title',
        artist: 'Valid Artist',
        album: 'Album',
        duration: 180,
        coverArt: '/non/existent/path/cover.jpg',
        addedAt: now,
      );
      expect(DownloadService.isSongMissingDetails(nonExistentLocalCover), isTrue);

      final validSong = Song(
        id: 'song_789',
        saavnId: '789',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: 230,
        coverArt: 'https://c.saavncdn.com/123/Starboy-500x500.jpg',
        addedAt: now,
      );
      expect(DownloadService.isSongMissingDetails(validSong), isFalse);
    });
  });

  group('DownloadService restoreSongMetadata', () {
    test('restores full metadata, cover art, and lyrics from JioSaavn API', () async {
      final downloadDir = await service.getDownloadDirectoryPath();
      final songDir = Directory('$downloadDir/Undi Bundi - Shashi');
      songDir.createSync(recursive: true);

      final audioFile = File('${songDir.path}/Undi Bundi.m4a');
      audioFile.writeAsBytesSync(List.filled(2048, 9));

      final placeholderSong = Song(
        id: 'saavn_xNVbUezC',
        saavnId: 'xNVbUezC',
        title: 'Downloaded Track (xNVbUezC)',
        artist: 'Unknown Artist',
        album: '',
        duration: 0,
        coverArt: '',
        encryptedMediaUrl: audioFile.path,
        addedAt: DateTime.now(),
      );

      final mockSaavnResponse = '''{
        "songs": [
          {
            "id": "xNVbUezC",
            "title": "Undi Bundi",
            "image": "https://c.saavncdn.com/737/Undi-Bundi-150x150.jpg",
            "more_info": {
              "album": "Prem Keetanu",
              "duration": "162",
              "has_lyrics": "true",
              "artistMap": {
                "primary_artists": [
                  {"id": "483654", "name": "Shashi", "role": "primary_artists"}
                ]
              }
            }
          }
        ]
      }''';

      when(() => mockClient.get(
        Uri.parse('https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=xNVbUezC&_format=json&_marker=0&api_version=4&ctx=web6dot0'),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response(mockSaavnResponse, 200));

      when(() => mockClient.get(
        Uri.parse('https://c.saavncdn.com/737/Undi-Bundi-500x500.jpg'),
      )).thenAnswer((_) async => http.Response.bytes([1, 2, 3, 4], 200));

      when(() => mockClient.get(
        Uri.parse('https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=xNVbUezC&_format=json&ctx=web6dot0'),
        headers: any(named: 'headers'),
      )).thenAnswer((_) async => http.Response('{"lyrics": "Undi bundi bol de<br>Khul ke prem me dol de"}', 200));

      final restored = await service.restoreSongMetadata(placeholderSong);
      expect(restored, isNotNull);
      expect(restored!.title, 'Undi Bundi');
      expect(restored.artist, 'Shashi');
      expect(restored.album, 'Prem Keetanu');
      expect(restored.duration, 162);
      expect(restored.hasLyrics, isTrue);

      final metaFile = File('${songDir.path}/metadata.json');
      expect(metaFile.existsSync(), isTrue);

      final coverFile = File('${songDir.path}/cover.jpg');
      expect(coverFile.existsSync(), isTrue);

      final lyricsFile = File('${songDir.path}/lyrics.txt');
      expect(lyricsFile.existsSync(), isTrue);
      expect(lyricsFile.readAsStringSync(), contains('Undi bundi bol de'));
    });
  });
}
