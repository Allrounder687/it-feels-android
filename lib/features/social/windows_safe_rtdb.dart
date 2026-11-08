import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

/// Transparent synthetic implementation of [DatabaseEvent] for polling transports
/// on desktop platforms where native background thread event channels violate
/// Flutter's platform thread requirement.
class PolledDatabaseEvent implements DatabaseEvent {
  @override
  final DataSnapshot snapshot;

  @override
  final DatabaseEventType type;

  @override
  final String? previousChildKey;

  PolledDatabaseEvent(
    this.snapshot, {
    this.type = DatabaseEventType.value,
    this.previousChildKey,
  });
}

/// Utility for safe, thread-compliant Firebase Realtime Database reads on Windows.
class WindowsSafeRtdb {
  /// Returns true if running on Windows desktop where native C++ FlutterFire RTDB
  /// EventChannels dispatch from non-platform threads.
  static bool get isWindowsDesktop => !kIsWeb && Platform.isWindows;

  /// Creates a controlled polling stream for a [Query] on Windows, or returns
  /// the native [onValue] stream on all other platforms (Android, iOS, macOS, Linux, Web).
  static Stream<DatabaseEvent> safeOnValue(
    Query query, {
    Duration interval = const Duration(seconds: 2),
  }) {
    if (!isWindowsDesktop) {
      return query.onValue;
    }

    // ignore: close_sinks
    late StreamController<DatabaseEvent> controller;
    Timer? timer;
    bool isPolling = false;

    Future<void> poll() async {
      if (isPolling || controller.isClosed) return;
      isPolling = true;
      try {
        final snapshot = await query.get();
        if (!controller.isClosed) {
          controller.add(PolledDatabaseEvent(snapshot, type: DatabaseEventType.value));
        }
      } catch (e) {
        // Silently tolerate transient offline/timeout errors to prevent unhandled stream faults
      } finally {
        isPolling = false;
      }
    }

    controller = StreamController<DatabaseEvent>.broadcast(
      onListen: () {
        poll();
        timer = Timer.periodic(interval, (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  /// Creates a controlled polling stream simulating [onChildAdded] on Windows,
  /// or returns the native [onChildAdded] stream on all other platforms.
  static Stream<DatabaseEvent> safeOnChildAdded(
    Query query, {
    Duration interval = const Duration(seconds: 2),
  }) {
    if (!isWindowsDesktop) {
      return query.onChildAdded;
    }

    // ignore: close_sinks
    late StreamController<DatabaseEvent> controller;
    Timer? timer;
    bool isPolling = false;
    final Set<String> seenKeys = <String>{};

    Future<void> poll() async {
      if (isPolling || controller.isClosed) return;
      isPolling = true;
      try {
        final snapshot = await query.get();
        if (!controller.isClosed && snapshot.value != null) {
          final currentKeys = <String>{};
          for (final child in snapshot.children) {
            final childKey = child.key;
            if (childKey != null) {
              currentKeys.add(childKey);
              if (seenKeys.add(childKey)) {
                controller.add(PolledDatabaseEvent(
                  child,
                  type: DatabaseEventType.childAdded,
                ));
              }
            }
          }
          // Prune dropped keys to allow re-addition if needed
          seenKeys.removeWhere((k) => !currentKeys.contains(k));
        }
      } catch (e) {
        // Silently tolerate transient offline/timeout errors
      } finally {
        isPolling = false;
      }
    }

    controller = StreamController<DatabaseEvent>.broadcast(
      onListen: () {
        poll();
        timer = Timer.periodic(interval, (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
        seenKeys.clear();
      },
    );

    return controller.stream;
  }
}
