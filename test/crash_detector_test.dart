import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/crash_detector.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crash_detector_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  CrashDetector detectorForTempDir() => CrashDetector(appDataDir: tempDir.path);

  File markerFile() => File('${tempDir.path}/.app_running');

  test('fresh dir with no marker returns false', () {
    final detector = detectorForTempDir();
    expect(detector.wasDirtyShutdown(), isFalse);
    // Marker was written for current session.
    expect(markerFile().existsSync(), isTrue);
  });

  test('pre-existing marker indicates dirty shutdown', () {
    markerFile().writeAsStringSync('2026-01-01T00:00:00.000Z');
    final detector = detectorForTempDir();
    expect(detector.wasDirtyShutdown(), isTrue);
  });

  test('markCleanShutdown removes the marker', () {
    final detector = detectorForTempDir();
    detector.wasDirtyShutdown(); // writes marker
    expect(markerFile().existsSync(), isTrue);

    detector.markCleanShutdown();
    expect(markerFile().existsSync(), isFalse);
  });

  test('marker persists when markCleanShutdown is not called', () {
    final detector = detectorForTempDir();
    detector.wasDirtyShutdown();
    expect(markerFile().existsSync(), isTrue);
    // Intentionally do NOT call markCleanShutdown.
  });

  test('calling wasDirtyShutdown twice returns true on second call', () {
    final detector = detectorForTempDir();
    // First call: no marker → false, then writes marker.
    expect(detector.wasDirtyShutdown(), isFalse);
    // Second call: marker exists (written by first call) → true.
    expect(detector.wasDirtyShutdown(), isTrue);
  });

  test('non-existent directory is created automatically', () {
    final nestedDir = Directory('${tempDir.path}/deep/nested/dir');
    expect(nestedDir.existsSync(), isFalse);

    final detector = CrashDetector(appDataDir: nestedDir.path);
    expect(detector.wasDirtyShutdown(), isFalse);

    expect(nestedDir.existsSync(), isTrue);
    expect(File('${nestedDir.path}/.app_running').existsSync(), isTrue);
  });

  test('marker file contains valid ISO8601 timestamp', () {
    final detector = detectorForTempDir();
    detector.wasDirtyShutdown();

    final content = markerFile().readAsStringSync();
    expect(() => DateTime.parse(content), returnsNormally);

    final parsed = DateTime.parse(content);
    expect(parsed.isUtc, isTrue);
  });

  test('markCleanShutdown is idempotent', () {
    final detector = detectorForTempDir();
    detector.wasDirtyShutdown();
    detector.markCleanShutdown();
    // Second call on already-removed marker should not throw.
    expect(() => detector.markCleanShutdown(), returnsNormally);
  });

  test('full lifecycle: start → shutdown → crash detect → restore', () {
    // Simulate first session: normal start then clean shutdown.
    final d1 = detectorForTempDir();
    expect(d1.wasDirtyShutdown(), isFalse);
    d1.markCleanShutdown();
    expect(markerFile().existsSync(), isFalse);

    // Simulate second session: dirty shutdown (no markCleanShutdown).
    final d2 = detectorForTempDir();
    expect(d2.wasDirtyShutdown(), isFalse); // marker was deleted
    // App "crashes" — marker stays.

    // Simulate third session: detects crash.
    final d3 = detectorForTempDir();
    expect(d3.wasDirtyShutdown(), isTrue);
  });
}
