import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum CacheContentType {
  artist,
  album,
  trackCredits,
  lyrics,
  charts,
  search,
  recommendations,
  editorial,
}

class CacheEntry<T> {
  final T data;
  final DateTime storedAt;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.storedAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(storedAt.add(ttl));
  bool get isStale => DateTime.now().isAfter(storedAt.add(ttl * 0.75));
}

/// Tiered Cache Manager offering Layer 1 (Memory LRU) and Layer 2 (Persistent Disk)
/// caching with Stale-While-Revalidate and content-specific TTLs.
class TieredCacheManager {
  static const int _maxL1Entries = 250;
  static final TieredCacheManager _instance = TieredCacheManager._internal();
  factory TieredCacheManager() => _instance;
  TieredCacheManager._internal();

  final Map<String, CacheEntry<dynamic>> _l1Memory = {};
  int _l1Hits = 0;
  int _l2Hits = 0;
  int _misses = 0;

  int get l1Hits => _l1Hits;
  int get l2Hits => _l2Hits;
  int get misses => _misses;
  double get hitRate => (_l1Hits + _l2Hits) == 0
      ? 0.0
      : (_l1Hits + _l2Hits) / (_l1Hits + _l2Hits + _misses);

  Duration defaultTtlFor(CacheContentType type) {
    switch (type) {
      case CacheContentType.artist:
        return const Duration(days: 7);
      case CacheContentType.album:
        return const Duration(days: 14);
      case CacheContentType.trackCredits:
        return const Duration(days: 14);
      case CacheContentType.lyrics:
        return const Duration(days: 30);
      case CacheContentType.editorial:
        return const Duration(days: 3);
      case CacheContentType.charts:
        return const Duration(hours: 6);
      case CacheContentType.recommendations:
        return const Duration(hours: 2);
      case CacheContentType.search:
        return const Duration(minutes: 15);
    }
  }

  /// Retrieves cached value from L1 or L2 if fresh.
  Future<T?> get<T>(String key, {bool allowStale = false}) async {
    // 1. Check L1 Memory
    if (_l1Memory.containsKey(key)) {
      final entry = _l1Memory[key]!;
      if (!entry.isExpired || allowStale) {
        _l1Hits++;
        return entry.data as T?;
      } else {
        _l1Memory.remove(key);
      }
    }

    // 2. Check L2 Persistent Storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = prefs.getString('tier2_cache_$key');
      if (serialized != null) {
        final decoded = jsonDecode(serialized) as Map<String, dynamic>;
        final storedAt = DateTime.parse(decoded['storedAt'] as String);
        final ttlMs = decoded['ttlMs'] as int;
        final ttl = Duration(milliseconds: ttlMs);

        final isExpired = DateTime.now().isAfter(storedAt.add(ttl));
        if (!isExpired || allowStale) {
          final data = decoded['data'] as T;
          // Promote to L1
          _putL1(key, CacheEntry(data: data, storedAt: storedAt, ttl: ttl));
          _l2Hits++;
          return data;
        } else {
          await prefs.remove('tier2_cache_$key');
        }
      }
    } catch (_) {
      // Local cache read error
    }

    _misses++;
    return null;
  }

  /// Stores a value across L1 and L2 persistent cache.
  Future<void> put<T>(
    String key,
    T data, {
    required CacheContentType type,
    Duration? customTtl,
    bool persistDisk = true,
  }) async {
    final ttl = customTtl ?? defaultTtlFor(type);
    final now = DateTime.now();

    // 1. Store in L1
    _putL1(key, CacheEntry(data: data, storedAt: now, ttl: ttl));

    // 2. Store in L2 Persistent Disk
    if (persistDisk) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final payload = jsonEncode({
          'storedAt': now.toIso8601String(),
          'ttlMs': ttl.inMilliseconds,
          'data': data,
        });
        await prefs.setString('tier2_cache_$key', payload);
      } catch (_) {
        // Disk serialization failure fallback
      }
    }
  }

  void _putL1(String key, CacheEntry<dynamic> entry) {
    if (_l1Memory.length >= _maxL1Entries) {
      // Evict oldest entry
      _l1Memory.remove(_l1Memory.keys.first);
    }
    _l1Memory[key] = entry;
  }

  /// Evicts all cached entries for a key.
  Future<void> invalidate(String key) async {
    _l1Memory.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tier2_cache_$key');
    } catch (_) {}
  }

  /// Clears in-memory cache completely.
  void clearL1() {
    _l1Memory.clear();
  }
}
