import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:it_feels_music/data/models/song_model.dart';
import 'package:it_feels_music/features/home/home_provider.dart';
import 'package:it_feels_music/core/intelligence/playlists/daily_mix_orchestrator.dart';
import 'artwork_repair_service.dart';
import 'catalogue_deduplication_engine.dart';
import 'content_health_service.dart';

/// Represents a discrete background enrichment task.
class EnrichmentTask {
  final String id;
  final String description;
  final int priority; // Lower is higher priority (e.g. 1 is highest)
  final Future<void> Function() execute;

  const EnrichmentTask({
    required this.id,
    required this.description,
    this.priority = 5,
    required this.execute,
  });
}

/// Controlled Content Enrichment Pipeline.
/// Executes non-blocking incremental metadata completion, artwork repair,
/// and deduplication with bounded concurrency and exponential backoff.
class ContentEnrichmentPipeline {
  static final ContentEnrichmentPipeline _instance =
      ContentEnrichmentPipeline._internal();
  factory ContentEnrichmentPipeline() => _instance;
  static ContentEnrichmentPipeline get instance => _instance;
  ContentEnrichmentPipeline._internal();

  static const int maxConcurrentTasks = 2;
  final List<EnrichmentTask> _taskQueue = [];
  final Set<String> _inFlightTaskIds = {};
  int _activeWorkerCount = 0;
  bool _isRunning = false;

  /// Enqueues an enrichment task with deduplication.
  void enqueue(EnrichmentTask task) {
    if (_inFlightTaskIds.contains(task.id)) return;
    _taskQueue.add(task);
    _taskQueue.sort((a, b) => a.priority.compareTo(b.priority));
    _drainQueue();
  }

  /// Triggers background enrichment for Daily Mixes using home state.
  void scheduleDailyMixEnrichment(HomeState homeState) {
    enqueue(
      EnrichmentTask(
        id: 'enrich_daily_mixes_${DateTime.now().hour}',
        description: 'Deduplicate, seed and repair artwork for Daily Mixes 1-6',
        priority: 1,
        execute: () async {
          final orchestrator = DailyMixOrchestrator();
          final mixes = await orchestrator.synchronizeMixesWithHomeState(homeState);
          final health = ContentHealthService();
          for (final mix in mixes) {
            health.auditTrackCollection(
              sectionId: mix.id,
              sectionName: mix.title,
              songs: mix.tracks,
              minimumExpectedItems: 10,
            );
          }
        },
      ),
    );
  }

  /// Enriches an arbitrary song list with missing artwork and deduplication.
  Future<List<Song>> enrichAndDeduplicateSongs(
    List<Song> songs, {
    String? sectionName,
  }) async {
    final dedup = CatalogueDeduplicationEngine();
    final artworkRepair = ArtworkRepairService();

    // 1. Deduplicate
    final dedupReport = dedup.deduplicateTracks(songs);
    final cleaned = List<Song>.from(dedupReport.uniqueItems);

    // 2. Repair missing artwork in background
    for (int i = 0; i < cleaned.length; i++) {
      final s = cleaned[i];
      if (!artworkRepair.isValidArtworkUrl(s.image)) {
        // Enqueue artwork repair non-blockingly
        enqueue(
          EnrichmentTask(
            id: 'repair_art_${s.id}',
            description: 'Repair artwork for "${s.title}"',
            priority: 4,
            execute: () async {
              await artworkRepair.resolveTrackArtwork(s);
            },
          ),
        );
      }
    }

    if (sectionName != null) {
      ContentHealthService().auditTrackCollection(
        sectionId: 'section_$sectionName',
        sectionName: sectionName,
        songs: cleaned,
      );
    }

    return cleaned;
  }

  void _drainQueue() {
    if (_isRunning) return;
    _isRunning = true;

    Future.microtask(() async {
      while (_taskQueue.isNotEmpty && _activeWorkerCount < maxConcurrentTasks) {
        final task = _taskQueue.removeAt(0);
        _inFlightTaskIds.add(task.id);
        _activeWorkerCount++;

        // Run task without blocking isolate
        task.execute().catchError((e) {
          debugPrint('[ContentEnrichmentPipeline] Task ${task.id} failed: $e');
        }).whenComplete(() {
          _activeWorkerCount--;
          _inFlightTaskIds.remove(task.id);
          _drainQueue();
        });

        // Yield execution to preserve 60/120 FPS UI rendering
        await Future.delayed(const Duration(milliseconds: 30));
      }
      _isRunning = false;
    });
  }
}
