import 'dart:io';

import 'app_authoring_storage_io_support.dart';

/// Detects abnormal app exits by checking for a "running" marker file.
///
/// On startup the app writes a `.app_running` marker.  On clean shutdown it
/// deletes the marker.  If the marker is found on the *next* startup, the
/// previous session crashed or was killed before it could clean up.
class CrashDetector {
  CrashDetector({String? appDataDir})
    : _appDataDir = appDataDir ?? _defaultAppDataDir();

  final String _appDataDir;

  static const _markerFileName = '.app_running';

  /// Returns `true` if the previous session was *not* shut down cleanly.
  ///
  /// Call this once at app startup.  Writes the running marker for this session.
  bool wasDirtyShutdown() {
    final marker = File('$_appDataDir/$_markerFileName');
    final crashed = marker.existsSync();
    // (Re)write the marker for this session regardless.
    _writeMarker();
    return crashed;
  }

  /// Remove the running marker.  Call on normal app shutdown.
  void markCleanShutdown() {
    final marker = File('$_appDataDir/$_markerFileName');
    if (marker.existsSync()) {
      marker.deleteSync();
    }
  }

  void _writeMarker() {
    final dir = Directory(_appDataDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final marker = File('$_appDataDir/$_markerFileName');
    marker.writeAsStringSync(
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static String _defaultAppDataDir() {
    // Use the same parent directory as the authoring database.
    final dbPath = resolveAuthoringDbPath();
    return File(dbPath).parent.path;
  }
}
