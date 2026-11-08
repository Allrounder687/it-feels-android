/// Standardized severity levels for structured logging across IT Feels Music.
enum LogLevel {
  /// Detailed low-level diagnostic events for deep engineering analysis.
  trace,

  /// Informational events useful during active debugging and feature development.
  debug,

  /// High-level confirmation of expected, normal application milestones.
  info,

  /// Unexpected or degraded operational conditions that do not fail the parent operation.
  warn,

  /// Failed operations, aborted tasks, or handled subsystem exceptions.
  error,

  /// Catastrophic failures resulting in crash, unrecoverable state, or application termination.
  fatal;

  /// Returns uppercase string representation (e.g. "ERROR", "INFO").
  String get label => name.toUpperCase();

  /// Compares severity level.
  bool isAtLeast(LogLevel other) => index >= other.index;

  /// Parses string to LogLevel with safe fallback to info.
  static LogLevel fromString(String? value) {
    if (value == null) return LogLevel.info;
    return LogLevel.values.firstWhere(
      (l) => l.name.toLowerCase() == value.toLowerCase() || l.label == value.toUpperCase(),
      orElse: () => LogLevel.info,
    );
  }
}
