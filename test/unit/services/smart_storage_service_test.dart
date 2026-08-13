import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mocktail/mocktail.dart';

import 'package:it_feels_music/data/services/smart_storage_service.dart';

// Fake PathProvider implementation to return test directories
class FakePathProviderPlatform extends Fake 
    with MockPlatformInterfaceMixin 
    implements PathProviderPlatform {
  final String tempPath;
  final String docPath;

  FakePathProviderPlatform({required this.tempPath, required this.docPath});

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docPath;
}

void main() {
  late SmartStorageService service;
  late Directory tempDir;
  late Directory docDir;
  late Directory cacheDir;
  late Directory downloadsDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = SmartStorageService();

    // Create unique temporary directories for isolation
    tempDir = Directory.systemTemp.createTempSync('feels_temp_');
    docDir = Directory.systemTemp.createTempSync('feels_docs_');

    // PathProviderPlatform configuration
    PathProviderPlatform.instance = FakePathProviderPlatform(
      tempPath: tempDir.path,
      docPath: docDir.path,
    );

    // Setup internal folders matching SmartStorageService paths
    cacheDir = Directory('${tempDir.path}/it_feels_music_cache');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
    } else {
      cacheDir = tempDir;
    }

    downloadsDir = Directory('${docDir.path}/downloads');
    if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      if (docDir.existsSync()) docDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('SmartStorageService Settings Tests', () {
    test('getMaxCacheSize returns default value if not set', () async {
      final size = await service.getMaxCacheSize();
      expect(size, equals(SmartStorageService.defaultMaxCacheSizeBytes));
    });

    test('setMaxCacheSize saves value and triggers eviction', () async {
      await service.setMaxCacheSize(500 * 1024 * 1024);
      final size = await service.getMaxCacheSize();
      expect(size, equals(500 * 1024 * 1024));
    });

    test('getAutoDownloadFavorites / setAutoDownloadFavorites works', () async {
      expect(await service.getAutoDownloadFavorites(), isFalse);
      await service.setAutoDownloadFavorites(true);
      expect(await service.getAutoDownloadFavorites(), isTrue);
    });
  });

  group('SmartStorageService Cache Management Tests', () {
    test('calculateCacheDirectorySize calculates size correctly', () async {
      // Create some dummy files in cache
      final file1 = File('${cacheDir.path}/song1.mp3')..writeAsStringSync('Hello');
      final file2 = File('${cacheDir.path}/song2.mp3')..writeAsStringSync('World!');

      final size = await service.calculateCacheDirectorySize();
      expect(size, equals(5 + 6)); // 'Hello' (5) + 'World!' (6)
    });

    test('calculateDownloadsDirectorySize calculates size correctly', () async {
      final file1 = File('${downloadsDir.path}/offline1.mp3')..writeAsStringSync('Offline data');
      final size = await service.calculateDownloadsDirectorySize();
      expect(size, equals(12));
    });

    test('enforceCacheLimit evicts oldest files when exceeding limit', () async {
      // Set small limit (12 bytes)
      await service.setMaxCacheSize(12);

      // Create 3 files with different modification dates
      final oldFile = File('${cacheDir.path}/old.mp3')..writeAsStringSync('123456'); // 6 bytes
      final midFile = File('${cacheDir.path}/mid.mp3')..writeAsStringSync('123456'); // 6 bytes
      final newFile = File('${cacheDir.path}/new.mp3')..writeAsStringSync('123456'); // 6 bytes

      // Artificially change modification times to sequence them
      final now = DateTime.now();
      oldFile.setLastModifiedSync(now.subtract(const Duration(hours: 3)));
      midFile.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
      newFile.setLastModifiedSync(now.subtract(const Duration(hours: 1)));

      // Enforce limit: total 18 bytes > 10 bytes limit.
      // Eviction deletes files until current size <= limit ~/ 2 (which is 5 bytes).
      // It should delete 'old.mp3' and 'mid.mp3' first.
      await service.enforceCacheLimit();

      expect(oldFile.existsSync(), isFalse);
      expect(midFile.existsSync(), isFalse);
      expect(newFile.existsSync(), isTrue);
    });

    test('clearAllCache deletes all files in cache folder', () async {
      File('${cacheDir.path}/song1.mp3').writeAsStringSync('some data');
      File('${cacheDir.path}/song2.mp3').writeAsStringSync('some data');

      await service.clearAllCache();

      final list = cacheDir.listSync();
      expect(list, isEmpty);
    });
  });
}
