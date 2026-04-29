import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_authoring_storage_io_support.dart';

void main() {
  test('event log storage writes one event to sqlite and jsonl', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_event_log_storage_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final logsDirectory = Directory('${directory.path}/logs');
    final storage = createTestAppEventLogStorage(
      sqlitePath: '${directory.path}/telemetry.db',
      logsDirectory: logsDirectory,
    );

    final entry = AppEventLogEntry(
      eventId: 'evt-1',
      timestampMs: DateTime.utc(2026, 4, 22, 8).millisecondsSinceEpoch,
      level: AppEventLogLevel.info,
      category: AppEventLogCategory.ai,
      action: 'ai.chat.request',
      status: AppEventLogStatus.started,
      sessionId: 'session-1',
      correlationId: 'corr-1',
      projectId: 'project-a',
      sceneId: 'scene-a',
      message: 'Started AI request.',
      metadata: {'provider': 'OpenAI compatible', 'timeoutMs': 30000},
    );

    await storage.write(entry);

    final sqliteRows = _readLoggedEventsFromSqlite(
      '${directory.path}/telemetry.db',
    );
    expect(sqliteRows, hasLength(1));
    expect(sqliteRows.single['event_id'], 'evt-1');
    expect(sqliteRows.single['category'], 'ai');
    expect(jsonDecode(sqliteRows.single['metadata_json'] as String), {
      'provider': 'OpenAI compatible',
      'timeoutMs': 30000,
    });

    final jsonlEvents = await _readJsonlEvents(logsDirectory);
    expect(jsonlEvents, hasLength(1));
    expect(jsonlEvents.single, entry.toJson());
  });

  test(
    'event log storage still appends jsonl when sqlite write fails',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_event_log_best_effort_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final sqliteParentAsFile = File('${directory.path}/sqlite-parent');
      await sqliteParentAsFile.writeAsString('not a directory');

      final logsDirectory = Directory('${directory.path}/logs');
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });
      final storage = createTestAppEventLogStorage(
        sqlitePath: '${sqliteParentAsFile.path}/telemetry.db',
        logsDirectory: logsDirectory,
      );

      await storage.write(
        AppEventLogEntry(
          eventId: 'evt-2',
          timestampMs: DateTime.utc(2026, 4, 22, 9).millisecondsSinceEpoch,
          level: AppEventLogLevel.error,
          category: AppEventLogCategory.persistence,
          action: 'persistence.write.failed',
          status: AppEventLogStatus.failed,
          sessionId: 'session-1',
          message: 'Primary sink failed.',
          errorCode: 'sqlite_open_failed',
        ),
      );

      final jsonlEvents = await _readJsonlEvents(logsDirectory);
      expect(jsonlEvents, hasLength(1));
      expect(jsonlEvents.single['eventId'], 'evt-2');
      expect(jsonlEvents.single['errorCode'], 'sqlite_open_failed');
    },
  );

  test('event log path helpers fall back when HOME is empty', () {
    expect(resolveTelemetryDbPath(homeOverride: ''), '.telemetry.db');
    expect(resolveTelemetryLogsDirectory(homeOverride: '').path, './logs');
  });

  test(
    'event log storage does not overwrite earlier sqlite rows on duplicate ids',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_event_log_duplicate_id_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final logsDirectory = Directory('${directory.path}/logs');
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });
      final storage = createTestAppEventLogStorage(
        sqlitePath: '${directory.path}/telemetry.db',
        logsDirectory: logsDirectory,
      );

      await storage.write(
        const AppEventLogEntry(
          eventId: 'evt-dup',
          timestampMs: 1,
          level: AppEventLogLevel.info,
          category: AppEventLogCategory.app,
          action: 'app.started',
          status: AppEventLogStatus.started,
          sessionId: 'session-1',
          message: 'first write',
        ),
      );
      await storage.write(
        const AppEventLogEntry(
          eventId: 'evt-dup',
          timestampMs: 2,
          level: AppEventLogLevel.error,
          category: AppEventLogCategory.app,
          action: 'app.started',
          status: AppEventLogStatus.failed,
          sessionId: 'session-1',
          message: 'second write',
        ),
      );

      final sqliteRows = _readLoggedEventsFromSqlite(
        '${directory.path}/telemetry.db',
      );
      expect(sqliteRows, hasLength(1));
      expect(sqliteRows.single['timestamp_ms'], 1);
      expect(sqliteRows.single['message'], 'first write');

      final jsonlEvents = await _readJsonlEvents(logsDirectory);
      expect(jsonlEvents, hasLength(2));
    },
  );

  test(
    'event log storage still writes sqlite when jsonl directory is invalid',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_event_log_sqlite_only_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final logsParentAsFile = File('${directory.path}/logs-parent');
      await logsParentAsFile.writeAsString('not a directory');

      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final storage = createTestAppEventLogStorage(
        sqlitePath: '${directory.path}/telemetry.db',
        logsDirectory: Directory('${logsParentAsFile.path}/logs'),
      );

      await storage.write(
        AppEventLogEntry(
          eventId: 'evt-sqlite-only',
          timestampMs: DateTime.utc(2026, 4, 23, 10).millisecondsSinceEpoch,
          level: AppEventLogLevel.warn,
          category: AppEventLogCategory.settings,
          action: 'settings.changed',
          status: AppEventLogStatus.warning,
          sessionId: 'session-2',
          message: 'JSONL sink failed but sqlite ok.',
        ),
      );

      final sqliteRows = _readLoggedEventsFromSqlite(
        '${directory.path}/telemetry.db',
      );
      expect(sqliteRows, hasLength(1));
      expect(sqliteRows.single['event_id'], 'evt-sqlite-only');
      expect(sqliteRows.single['level'], 'warn');
      expect(sqliteRows.single['category'], 'settings');
    },
  );

  test('event log storage splits jsonl by day for different dates', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_event_log_daily_rotation_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final logsDirectory = Directory('${directory.path}/logs');
    final storage = createTestAppEventLogStorage(
      sqlitePath: '${directory.path}/telemetry.db',
      logsDirectory: logsDirectory,
    );

    final day1 = DateTime.utc(2026, 4, 22, 8).millisecondsSinceEpoch;
    final day2 = DateTime.utc(2026, 4, 23, 15).millisecondsSinceEpoch;
    final day3 = DateTime.utc(2026, 3, 1, 0).millisecondsSinceEpoch;

    await storage.write(
      AppEventLogEntry(
        eventId: 'evt-d1a',
        timestampMs: day1,
        level: AppEventLogLevel.info,
        category: AppEventLogCategory.app,
        action: 'app.started',
        status: AppEventLogStatus.started,
        sessionId: 's1',
        message: 'day 1 event a',
      ),
    );
    await storage.write(
      AppEventLogEntry(
        eventId: 'evt-d1b',
        timestampMs: day1 + 1000,
        level: AppEventLogLevel.info,
        category: AppEventLogCategory.app,
        action: 'app.resumed',
        status: AppEventLogStatus.succeeded,
        sessionId: 's1',
        message: 'day 1 event b',
      ),
    );
    await storage.write(
      AppEventLogEntry(
        eventId: 'evt-d2',
        timestampMs: day2,
        level: AppEventLogLevel.info,
        category: AppEventLogCategory.ai,
        action: 'ai.chat.response',
        status: AppEventLogStatus.succeeded,
        sessionId: 's1',
        message: 'day 2 event',
      ),
    );
    await storage.write(
      AppEventLogEntry(
        eventId: 'evt-d3',
        timestampMs: day3,
        level: AppEventLogLevel.debug,
        category: AppEventLogCategory.simulation,
        action: 'sim.tick',
        status: AppEventLogStatus.started,
        sessionId: 's1',
        message: 'day 3 event',
      ),
    );

    final jsonlFiles = await logsDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();
    jsonlFiles.sort((a, b) => a.path.compareTo(b.path));

    expect(jsonlFiles, hasLength(3));
    expect(jsonlFiles[0].path, endsWith('2026-03-01.jsonl'));
    expect(jsonlFiles[1].path, endsWith('2026-04-22.jsonl'));
    expect(jsonlFiles[2].path, endsWith('2026-04-23.jsonl'));

    final day1Events = await _readJsonlEventsFrom(
      File('${logsDirectory.path}/2026-04-22.jsonl'),
    );
    expect(day1Events, hasLength(2));

    final day2Events = await _readJsonlEventsFrom(
      File('${logsDirectory.path}/2026-04-23.jsonl'),
    );
    expect(day2Events, hasLength(1));
    expect(day2Events.single['eventId'], 'evt-d2');

    final day3Events = await _readJsonlEventsFrom(
      File('${logsDirectory.path}/2026-03-01.jsonl'),
    );
    expect(day3Events, hasLength(1));
    expect(day3Events.single['eventId'], 'evt-d3');

    final sqliteRows = _readLoggedEventsFromSqlite(
      '${directory.path}/telemetry.db',
    );
    expect(sqliteRows, hasLength(4));
  });

  test(
    'event log storage round-trips minimal entry with no optional fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_event_log_minimal_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final logsDirectory = Directory('${directory.path}/logs');
      final storage = createTestAppEventLogStorage(
        sqlitePath: '${directory.path}/telemetry.db',
        logsDirectory: logsDirectory,
      );

      const entry = AppEventLogEntry(
        eventId: 'evt-minimal',
        timestampMs: 999,
        level: AppEventLogLevel.debug,
        category: AppEventLogCategory.ui,
        action: 'ui.tap',
        status: AppEventLogStatus.started,
        sessionId: 's-min',
        message: 'minimal',
      );

      await storage.write(entry);

      final sqliteRows = _readLoggedEventsFromSqlite(
        '${directory.path}/telemetry.db',
      );
      expect(sqliteRows, hasLength(1));
      final row = sqliteRows.single;
      expect(row['correlation_id'], isNull);
      expect(row['project_id'], isNull);
      expect(row['scene_id'], isNull);
      expect(row['error_code'], isNull);
      expect(row['error_detail'], isNull);
      expect(jsonDecode(row['metadata_json'] as String), isEmpty);

      final jsonlEvents = await _readJsonlEvents(logsDirectory);
      expect(jsonlEvents, hasLength(1));
      expect(jsonlEvents.single['correlationId'], isNull);
      expect(jsonlEvents.single['projectId'], isNull);
      expect(jsonlEvents.single['errorCode'], isNull);
      expect(jsonlEvents.single['metadata'], isEmpty);
    },
  );

  test(
    'event log storage round-trips entry with all optional fields populated',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_event_log_full_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final logsDirectory = Directory('${directory.path}/logs');
      final storage = createTestAppEventLogStorage(
        sqlitePath: '${directory.path}/telemetry.db',
        logsDirectory: logsDirectory,
      );

      final entry = AppEventLogEntry(
        eventId: 'evt-full',
        timestampMs: DateTime.utc(2026, 4, 25, 12, 30).millisecondsSinceEpoch,
        level: AppEventLogLevel.error,
        category: AppEventLogCategory.importExport,
        action: 'import.project',
        status: AppEventLogStatus.failed,
        sessionId: 'session-full',
        correlationId: 'corr-full',
        projectId: 'proj-full',
        sceneId: 'scene-full',
        message: 'Import failed due to corrupted file.',
        errorCode: 'IMPORT_CORRUPT',
        errorDetail: 'Stack trace: ...',
        metadata: {
          'fileName': 'novel.zip',
          'bytesRead': 1024,
          'nested': {'key': 'value'},
        },
      );

      await storage.write(entry);

      final sqliteRows = _readLoggedEventsFromSqlite(
        '${directory.path}/telemetry.db',
      );
      expect(sqliteRows, hasLength(1));
      final row = sqliteRows.single;
      expect(row['event_id'], 'evt-full');
      expect(row['level'], 'error');
      expect(row['category'], 'import_export');
      expect(row['action'], 'import.project');
      expect(row['status'], 'failed');
      expect(row['session_id'], 'session-full');
      expect(row['correlation_id'], 'corr-full');
      expect(row['project_id'], 'proj-full');
      expect(row['scene_id'], 'scene-full');
      expect(row['message'], 'Import failed due to corrupted file.');
      expect(row['error_code'], 'IMPORT_CORRUPT');
      expect(row['error_detail'], 'Stack trace: ...');
      expect(jsonDecode(row['metadata_json'] as String), {
        'fileName': 'novel.zip',
        'bytesRead': 1024,
        'nested': {'key': 'value'},
      });

      final jsonlEvents = await _readJsonlEvents(logsDirectory);
      expect(jsonlEvents, hasLength(1));
      expect(jsonlEvents.single, entry.toJson());
    },
  );

  test('event log storage round-trips all category enum values', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_event_log_enum_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final logsDirectory = Directory('${directory.path}/logs');
    final storage = createTestAppEventLogStorage(
      sqlitePath: '${directory.path}/telemetry.db',
      logsDirectory: logsDirectory,
    );

    final categories = AppEventLogCategory.values;
    final statuses = AppEventLogStatus.values;
    final levels = AppEventLogLevel.values;

    for (var i = 0; i < categories.length; i++) {
      await storage.write(
        AppEventLogEntry(
          eventId: 'evt-enum-$i',
          timestampMs: i,
          level: levels[i % levels.length],
          category: categories[i],
          action: '${categories[i].name}.test',
          status: statuses[i % statuses.length],
          sessionId: 's-enum',
          message: 'enum test $i',
        ),
      );
    }

    final sqliteRows = _readLoggedEventsFromSqlite(
      '${directory.path}/telemetry.db',
    );
    expect(sqliteRows, hasLength(categories.length));

    final storedCategories = sqliteRows
        .map((r) => r['category'] as String)
        .toList();
    expect(storedCategories, [
      'app',
      'settings',
      'ai',
      'persistence',
      'import_export',
      'ui',
      'simulation',
      'story_memory',
    ]);

    final jsonlEvents = await _readJsonlEvents(logsDirectory);
    expect(jsonlEvents, hasLength(categories.length));
    for (var i = 0; i < categories.length; i++) {
      expect(jsonlEvents[i]['category'], storedCategories[i]);
    }
  });

  test(
    'event log storage preserves write order for sequential entries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_event_log_sequential_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final logsDirectory = Directory('${directory.path}/logs');
      final storage = createTestAppEventLogStorage(
        sqlitePath: '${directory.path}/telemetry.db',
        logsDirectory: logsDirectory,
      );

      for (var i = 0; i < 10; i++) {
        await storage.write(
          AppEventLogEntry(
            eventId: 'evt-seq-$i',
            timestampMs: (10 - i) * 1000,
            level: AppEventLogLevel.info,
            category: AppEventLogCategory.ai,
            action: 'ai.step',
            status: AppEventLogStatus.succeeded,
            sessionId: 's-seq',
            message: 'step $i',
          ),
        );
      }

      final sqliteRows = _readLoggedEventsFromSqlite(
        '${directory.path}/telemetry.db',
      );
      expect(sqliteRows, hasLength(10));
      final orderedTimestamps = sqliteRows
          .map((r) => r['timestamp_ms'] as int)
          .toList();
      for (var i = 1; i < orderedTimestamps.length; i++) {
        expect(
          orderedTimestamps[i] >= orderedTimestamps[i - 1],
          isTrue,
          reason: 'SQLite rows should be ordered by timestamp_ms ASC',
        );
      }

      final jsonlEvents = await _readJsonlEvents(logsDirectory);
      expect(jsonlEvents, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(jsonlEvents[i]['eventId'], 'evt-seq-$i');
      }
    },
  );

  test('event log storage creates sqlite indexes after first write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_event_log_index_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final logsDirectory = Directory('${directory.path}/logs');
    final storage = createTestAppEventLogStorage(
      sqlitePath: '${directory.path}/telemetry.db',
      logsDirectory: logsDirectory,
    );

    await storage.write(
      const AppEventLogEntry(
        eventId: 'evt-idx',
        timestampMs: 1,
        level: AppEventLogLevel.info,
        category: AppEventLogCategory.app,
        action: 'app.indexcheck',
        status: AppEventLogStatus.started,
        sessionId: 's-idx',
        message: 'index check',
      ),
    );

    final database = sqlite3.open('${directory.path}/telemetry.db');
    try {
      final indexRows = database.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_app_event_log%'",
      );
      final indexNames = indexRows.map((r) => r['name'] as String).toList()
        ..sort();
      expect(indexNames, [
        'idx_app_event_log_entries_category_action_time',
        'idx_app_event_log_entries_correlation',
        'idx_app_event_log_entries_project_scene_time',
        'idx_app_event_log_entries_timestamp',
      ]);
    } finally {
      database.dispose();
    }
  });

  test('event log storage preserves all concurrent sqlite writes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_event_log_concurrent_write_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final logsDirectory = Directory('${directory.path}/logs');
    final storage = createTestAppEventLogStorage(
      sqlitePath: '${directory.path}/telemetry.db',
      logsDirectory: logsDirectory,
    );

    final entries = [
      for (var index = 0; index < 50; index += 1)
        AppEventLogEntry(
          eventId: 'evt-concurrent-$index',
          timestampMs: index,
          level: AppEventLogLevel.info,
          category: AppEventLogCategory.ai,
          action: 'ai.chat.request',
          status: AppEventLogStatus.started,
          sessionId: 'session-1',
          message: 'entry $index',
        ),
    ];

    await Future.wait([for (final entry in entries) storage.write(entry)]);

    final sqliteRows = _readLoggedEventsFromSqlite(
      '${directory.path}/telemetry.db',
    );
    expect(sqliteRows, hasLength(entries.length));

    final jsonlEvents = await _readJsonlEvents(logsDirectory);
    expect(jsonlEvents, hasLength(entries.length));
  });
}

List<Map<String, Object?>> _readLoggedEventsFromSqlite(String dbPath) {
  final database = sqlite3.open(dbPath);
  try {
    return [
      for (final row in database.select('''
        SELECT
          event_id,
          timestamp_ms,
          level,
          category,
          action,
          status,
          session_id,
          correlation_id,
          project_id,
          scene_id,
          message,
          error_code,
          error_detail,
          metadata_json
        FROM app_event_log_entries
        ORDER BY timestamp_ms ASC
        '''))
        Map<String, Object?>.from(row),
    ];
  } finally {
    database.dispose();
  }
}

Future<List<Map<String, Object?>>> _readJsonlEventsFrom(File file) async {
  final events = <Map<String, Object?>>[];
  final lines = await file.readAsLines();
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    events.add(
      Map<String, Object?>.from(jsonDecode(line) as Map<String, Object?>),
    );
  }
  return events;
}

Future<List<Map<String, Object?>>> _readJsonlEvents(
  Directory logsDirectory,
) async {
  final files = await logsDirectory
      .list()
      .where((entity) => entity is File && entity.path.endsWith('.jsonl'))
      .cast<File>()
      .toList();
  files.sort((left, right) => left.path.compareTo(right.path));

  final events = <Map<String, Object?>>[];
  for (final file in files) {
    final lines = await file.readAsLines();
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      events.add(
        Map<String, Object?>.from(jsonDecode(line) as Map<String, Object?>),
      );
    }
  }

  return events;
}
