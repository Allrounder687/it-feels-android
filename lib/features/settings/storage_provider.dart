import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:it_feels_music/core/utils/service_locator.dart';
import 'package:it_feels_music/data/services/smart_storage_service.dart';

class StorageState {
  final bool isLoading;
  final int cacheSize;
  final int downloadSize;
  final int maxCacheSize;
  final bool autoDownload;

  const StorageState({
    this.isLoading = true,
    this.cacheSize = 0,
    this.downloadSize = 0,
    this.maxCacheSize = 0,
    this.autoDownload = false,
  });

  StorageState copyWith({
    bool? isLoading,
    int? cacheSize,
    int? downloadSize,
    int? maxCacheSize,
    bool? autoDownload,
  }) {
    return StorageState(
      isLoading: isLoading ?? this.isLoading,
      cacheSize: cacheSize ?? this.cacheSize,
      downloadSize: downloadSize ?? this.downloadSize,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      autoDownload: autoDownload ?? this.autoDownload,
    );
  }
}

class StorageNotifier extends StateNotifier<StorageState> {
  final SmartStorageService _storageService = locator<SmartStorageService>();

  StorageNotifier() : super(const StorageState()) {
    loadStorageData();
  }

  Future<void> loadStorageData() async {
    state = state.copyWith(isLoading: true);
    
    final cache = await _storageService.calculateCacheDirectorySize();
    final downloads = await _storageService.calculateDownloadsDirectorySize();
    final maxSize = await _storageService.getMaxCacheSize();
    final autoDownload = await _storageService.getAutoDownloadFavorites();

    state = state.copyWith(
      cacheSize: cache,
      downloadSize: downloads,
      maxCacheSize: maxSize,
      autoDownload: autoDownload,
      isLoading: false,
    );
  }

  Future<void> clearCache() async {
    state = state.copyWith(isLoading: true);
    await _storageService.clearAllCache();
    await loadStorageData();
  }

  Future<void> clearDownloads() async {
    state = state.copyWith(isLoading: true);
    await _storageService.clearAllCache();
    await loadStorageData();
  }

  Future<void> updateMaxCacheSize(int sizeMB) async {
    await _storageService.setMaxCacheSize(sizeMB);
    state = state.copyWith(maxCacheSize: sizeMB * 1024 * 1024);
  }

  Future<void> toggleAutoDownload(bool val) async {
    await _storageService.setAutoDownloadFavorites(val);
    state = state.copyWith(autoDownload: val);
  }
}

final storageProvider = StateNotifierProvider<StorageNotifier, StorageState>((ref) {
  return StorageNotifier();
});
