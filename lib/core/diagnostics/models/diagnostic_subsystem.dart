/// Core architectural subsystems emitting diagnostic logs and telemetry.
enum DiagnosticSubsystem {
  /// Audio playback engine, buffering, decoders, and audio session management.
  playback,

  /// HTTP clients, API orchestrator, CDN asset resolution, and network fallbacks.
  network,

  /// Local Isar database, SharedPreferences, cache, and disk persistence.
  database,

  /// Metadata enrichment, Living Music Catalogue, deduplication, and artwork repair.
  content,

  /// Latency benchmarks, frame rendering, startup profiling, and memory tracking.
  performance,

  /// Flutter engine, widget rendering tree, and platform dispatchers.
  framework,

  /// Native OS integrations: Windows SMTC, Android AudioService, MediaSession, macOS/Linux.
  platform,

  /// Application state transitions: startup, backgrounding, foregrounding, termination.
  lifecycle,

  /// Authentication, token scrubbing, access validation, and sandbox security.
  security;

  String get label => name.toUpperCase();

  static DiagnosticSubsystem fromString(String? value) {
    if (value == null) return DiagnosticSubsystem.framework;
    return DiagnosticSubsystem.values.firstWhere(
      (s) => s.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DiagnosticSubsystem.framework,
    );
  }
}
