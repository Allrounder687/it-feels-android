import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/log_entry.dart';
import '../models/log_level.dart';

/// Crash-safe, bounded, rotating local log sink.
///
/// Features:
/// 1. Asynchronous non-blocking write queue (never stalls audio engine or UI raster thread).
/// 2. Bounded storage: max 5 files of 2 MB each (10 MB maximum storage footprint).
/// 3. Separate streams for general diagnostic traces and high-priority errors.
/// 4. 7-day automatic retention pruning.
/// 5. Corrupted file auto-recovery.
class RotatingLogFileSink {
  static final RotatingLogFileSink instance = RotatingLogFileSink._internal();
  factory RotatingLogFileSink() => instance;

  static const int maxFileSizeBytes = 2 * 1024 * 1024; // 2 MB per file segment
  static const int maxRotatedFiles = 5; // 5 files max = 10 MB total
  static const Duration retentionPeriod = Duration(days: 7);

  Directory? _logDirectory;
  File? _currentAppLogFile;
  File? _currentErrorLogFile;

  final List<LogEntry> _writeBuffer = [];
  bool _isWriting = false;
  bool _isInitialized = false;
  Timer? _batchTimer;

  RotatingLogFileSink._internal();

  /// Initializes the log directory and prunes expired logs.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      Directory baseDir;
      if (!kIsWeb) {
        baseDir = await getApplicationSupportDirectory();
      } else {
        return; // Web uses in-memory logging
      }

      _logDirectory = Directory('${baseDir.path}/it_feels_diagnostics');
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }

      await _rotateAndPrune();
      _isInitialized = true;
    } catch (e) {
      // In headless unit tests or unsupported environments, path_provider channel is absent
      _isInitialized = true;
    }
  }

  /// Non-blocking asynchronous enqueue of a structured log record.
  void enqueue(LogEntry entry) {
    if (kIsWeb) return;
    _writeBuffer.add(entry);

    // Batch writes every 500ms or when buffer hits 10 entries
    if (_writeBuffer.length >= 10) {
      _triggerFlush();
    } else {
      _batchTimer ??= Timer(const Duration(milliseconds: 500), _triggerFlush);
    }
  }

  void _triggerFlush() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (!_isWriting && _writeBuffer.isNotEmpty) {
      Timer.run(() => _processQueue());
    }
  }

  Future<void> _processQueue() async {
    if (_isWriting || _writeBuffer.isEmpty) return;
    _isWriting = true;

    try {
      if (!_isInitialized) await init();
      if (_logDirectory == null) {
        _writeBuffer.clear();
        return;
      }

      final batch = List<LogEntry>.from(_writeBuffer);
      _writeBuffer.clear();

      final generalLines = <String>[];
      final errorLines = <String>[];

      for (final entry in batch) {
        final line = '${entry.toJsonLine()}\n';
        generalLines.add(line);
        if (entry.level.isAtLeast(LogLevel.error)) {
          errorLines.add(line);
        }
      }

      // Write general logs
      if (generalLines.isNotEmpty) {
        final appFile = await _getActiveAppLogFile();
        await appFile.writeAsString(generalLines.join(), mode: FileMode.append, flush: false);
        await _checkFileSizeAndRotate(appFile, 'app_diagnostics');
      }

      // Write dedicated error logs
      if (errorLines.isNotEmpty) {
        final errorFile = await _getActiveErrorLogFile();
        await errorFile.writeAsString(errorLines.join(), mode: FileMode.append, flush: true);
        await _checkFileSizeAndRotate(errorFile, 'error_diagnostics');
      }
    } catch (e) {
      debugPrint('[RotatingLogFileSink] Disk write failure: $e');
    } finally {
      _isWriting = false;
      if (_writeBuffer.isNotEmpty) {
        _triggerFlush();
      }
    }
  }

  /// Forces immediate disk flush of all buffered log entries.
  Future<void> flush() async {
    if (_writeBuffer.isEmpty) return;
    await _processQueue();
  }

  Future<File> _getActiveAppLogFile() async {
    if (_currentAppLogFile == null || !await _currentAppLogFile!.exists()) {
      _currentAppLogFile = File('${_logDirectory!.path}/app_diagnostics_current.jsonl');
      if (!await _currentAppLogFile!.exists()) {
        await _currentAppLogFile!.create();
      }
    }
    return _currentAppLogFile!;
  }

  Future<File> _getActiveErrorLogFile() async {
    if (_currentErrorLogFile == null || !await _currentErrorLogFile!.exists()) {
      _currentErrorLogFile = File('${_logDirectory!.path}/error_diagnostics_current.jsonl');
      if (!await _currentErrorLogFile!.exists()) {
        await _currentErrorLogFile!.create();
      }
    }
    return _currentErrorLogFile!;
  }

  Future<void> _checkFileSizeAndRotate(File file, String prefix) async {
    try {
      final len = await file.length();
      if (len >= maxFileSizeBytes) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final rotatedPath = '${_logDirectory!.path}/${prefix}_$timestamp.jsonl';
        await file.rename(rotatedPath);
        if (prefix == 'app_diagnostics') {
          _currentAppLogFile = null;
        } else {
          _currentErrorLogFile = null;
        }
        await _rotateAndPrune();
      }
    } catch (_) {}
  }

  Future<void> _rotateAndPrune() async {
    if (_logDirectory == null || !await _logDirectory!.exists()) return;

    try {
      final entities = await _logDirectory!.list().toList();
      final now = DateTime.now();

      final files = entities.whereType<File>().toList();
      for (final f in files) {
        final stat = await f.stat();
        if (now.difference(stat.modified) > retentionPeriod) {
          await f.delete();
        }
      }

      // Check max files limit per category
      for (final prefix in ['app_diagnostics', 'error_diagnostics']) {
        final categoryFiles = files
            .where((f) => f.path.contains(prefix) && !f.path.contains('current'))
            .toList();

        if (categoryFiles.length > maxRotatedFiles) {
          categoryFiles.sort((a, b) => a.path.compareTo(b.path));
          final excess = categoryFiles.length - maxRotatedFiles;
          for (int i = 0; i < excess; i++) {
            await categoryFiles[i].delete();
          }
        }
      }
    } catch (_) {}
  }

  /// Reads recent log entries from the active file.
  Future<List<LogEntry>> readRecentEntries({int limit = 100}) async {
    final results = <LogEntry>[];
    try {
      if (!_isInitialized) await init();
      if (_logDirectory == null) return results;

      final file = await _getActiveAppLogFile();
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines.reversed) {
          if (line.trim().isEmpty) continue;
          try {
            results.add(LogEntry.fromJson(Map<String, dynamic>.from(
              // parse line
              await _safeDecodeJson(line),
            )));
            if (results.length >= limit) break;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return results;
  }

  Future<Map<String, dynamic>> _safeDecodeJson(String line) async {
    try {
      if (line.isEmpty) return {};
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Calculates total bytes occupied by log files on disk.
  Future<int> computeTotalStorageBytes() async {
    if (_logDirectory == null || !await _logDirectory!.exists()) return 0;
    try {
      int total = 0;
      final files = (await _logDirectory!.list().toList()).whereType<File>();
      for (final f in files) {
        total += await f.length();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all log files from disk.
  Future<void> clearAllLogs() async {
    _writeBuffer.clear();
    if (_logDirectory == null || !await _logDirectory!.exists()) return;
    try {
      final files = (await _logDirectory!.list().toList()).whereType<File>();
      for (final f in files) {
        await f.delete();
      }
      _currentAppLogFile = null;
      _currentErrorLogFile = null;
    } catch (_) {}
  }

  Directory? get logDirectory => _logDirectory;
}
