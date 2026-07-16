import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/story_generation_run_storage_io.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'borrowed run storage shares and does not close authoritative database',
    () async {
      final root = Directory.systemTemp.createTempSync('borrowed-run-storage-');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final database = sqlite3.open('${root.path}/authoritative.sqlite');
      addTearDown(database.dispose);
      final storage = SqliteStoryGenerationRunStorage.borrowed(database);

      expect(storage.usesDatabase(database), isTrue);
      await storage.save(<String, Object?>{
        'status': 'running',
      }, sceneScopeId: 'scene-1');
      expect(
        database
            .select('SELECT COUNT(*) AS count FROM story_generation_run_state')
            .single['count'],
        1,
      );

      storage.dispose();

      expect(database.select('SELECT 1').single.values.single, 1);
      expect(
        database
            .select('PRAGMA database_list')
            .where((row) => row['name'] == 'main'),
        hasLength(1),
      );
      await expectLater(
        storage.load(sceneScopeId: 'scene-1'),
        throwsStateError,
      );
    },
  );

  test(
    'borrowed writes stay on the caller transaction and cannot self-lock',
    () async {
      final root = Directory.systemTemp.createTempSync('borrowed-run-lock-');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final path = '${root.path}/authoritative.sqlite';
      final database = sqlite3.open(path);
      addTearDown(database.dispose);
      final storage = SqliteStoryGenerationRunStorage.borrowed(database);
      addTearDown(storage.dispose);
      database.execute('PRAGMA busy_timeout = 1');
      database.execute('BEGIN IMMEDIATE');
      try {
        await storage.save(const <String, Object?>{
          'status': 'inside-authority-transaction',
        }, sceneScopeId: 'scene-locked');
        expect(
          database.select(
            'SELECT COUNT(*) AS count FROM story_generation_run_state '
            'WHERE scene_scope_id = ?',
            const <Object?>['scene-locked'],
          ).single['count'],
          1,
        );
        database.execute('COMMIT');
      } finally {
        if (!database.autocommit) database.execute('ROLLBACK');
      }

      final observer = sqlite3.open(path, mode: OpenMode.readOnly);
      addTearDown(observer.dispose);
      expect(
        observer.select(
          'SELECT payload_json FROM story_generation_run_state '
          'WHERE scene_scope_id = ?',
          const <Object?>['scene-locked'],
        ).single['payload_json'],
        contains('inside-authority-transaction'),
      );
    },
  );
}
