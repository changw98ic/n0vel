import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_auto_backup_io.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novel_writer_backup_test');
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeSampleData() async {
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA foreign_keys = ON');
    db.execute('''
      CREATE TABLE workspace_projects (
        scope_key TEXT NOT NULL,
        position_no INTEGER NOT NULL,
        id TEXT NOT NULL,
        title TEXT NOT NULL,
        PRIMARY KEY (scope_key, position_no)
      )
    ''');
    db.execute(
      'INSERT INTO workspace_projects (scope_key, position_no, id, title) VALUES (?, ?, ?, ?)',
      ['workspace-default', 0, 'project-1', '月潮回声'],
    );
    db.dispose();
  }

  group('FileAutoBackupService', () {
    test('createBackup throws when database file does not exist', () async {
      final service = FileAutoBackupService(dbPath: dbPath);

      expect(service.createBackup(), throwsA(isA<StateError>()));
    });

    test('createBackup creates a backup copy of the database', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry = await service.createBackup();

      expect(entry.id, isNotEmpty);
      expect(entry.sizeBytes, greaterThan(0));
      expect(entry.createdAtMs, greaterThan(0));

      final backupDir = Directory('${tempDir.path}/backups');
      expect(await backupDir.exists(), isTrue);

      final files = await backupDir.list().toList();
      expect(files.whereType<File>(), hasLength(1));
    });

    test('backup copy contains the same data as the original', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry = await service.createBackup();

      final backupFile = File(
        '${tempDir.path}/backups/authoring_${entry.id}.db',
      );
      expect(await backupFile.exists(), isTrue);

      final backupDb = sqlite3.open(backupFile.path);
      final rows = backupDb.select(
        'SELECT title FROM workspace_projects WHERE scope_key = ?',
        ['workspace-default'],
      );
      expect(rows.length, 1);
      expect(rows.first['title'], '月潮回声');
      backupDb.dispose();
    });

    test(
      'online snapshot includes committed rows still present in WAL',
      () async {
        await writeSampleData();
        final live = sqlite3.open(dbPath);
        addTearDown(live.dispose);
        live.execute('PRAGMA journal_mode = WAL');
        live.execute('PRAGMA wal_autocheckpoint = 0');
        live.execute(
          '''INSERT INTO workspace_projects
           (scope_key, position_no, id, title) VALUES (?, ?, ?, ?)''',
          <Object?>['workspace-default', 1, 'wal-row', 'WAL 已提交'],
        );
        expect(File('$dbPath-wal').existsSync(), isTrue);

        final service = FileAutoBackupService(dbPath: dbPath);
        final entry = await service.createBackup();
        final backup = sqlite3.open(
          '${tempDir.path}/backups/authoring_${entry.id}.db',
          mode: OpenMode.readOnly,
        );
        addTearDown(backup.dispose);
        expect(
          backup
              .select(
                "SELECT title FROM workspace_projects WHERE id = 'wal-row'",
              )
              .single['title'],
          'WAL 已提交',
        );
      },
    );

    test('listBackups returns empty list when no backups exist', () async {
      final service = FileAutoBackupService(dbPath: dbPath);

      final entries = await service.listBackups();
      expect(entries, isEmpty);
    });

    test(
      'listBackups returns backups sorted by creation time descending',
      () async {
        await writeSampleData();
        final service = FileAutoBackupService(dbPath: dbPath);

        await service.createBackup();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await service.createBackup();

        final entries = await service.listBackups();
        expect(entries, hasLength(2));
        expect(
          entries[0].createdAtMs,
          greaterThanOrEqualTo(entries[1].createdAtMs),
        );
      },
    );

    test('restoreBackup overwrites the current database', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry = await service.createBackup();

      final db = sqlite3.open(dbPath);
      db.execute(
        'UPDATE workspace_projects SET title = ? WHERE scope_key = ?',
        ['修改后的标题', 'workspace-default'],
      );
      db.dispose();

      await service.restoreBackup(entry.id);

      final restoredDb = sqlite3.open(dbPath);
      final rows = restoredDb.select(
        'SELECT title FROM workspace_projects WHERE scope_key = ?',
        ['workspace-default'],
      );
      expect(rows.first['title'], '月潮回声');
      restoredDb.dispose();
    });

    test('healthy backup replaces a corrupt current database', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);
      final entry = await service.createBackup();

      await File(dbPath).writeAsString('not a sqlite database', flush: true);

      await service.restoreBackup(entry.id);

      final restoredDb = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      addTearDown(restoredDb.dispose);
      expect(
        restoredDb
            .select(
              "SELECT title FROM workspace_projects WHERE id = 'project-1'",
            )
            .single['title'],
        '月潮回声',
      );
    });

    test('busy current database is not replaced', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);
      final entry = await service.createBackup();
      final live = sqlite3.open(dbPath);
      live.execute('UPDATE workspace_projects SET title = ? WHERE id = ?', [
        '当前库值',
        'project-1',
      ]);
      live.execute('BEGIN EXCLUSIVE');

      try {
        await expectLater(
          service.restoreBackup(entry.id),
          throwsA(
            isA<SqliteException>().having(
              (error) => error.resultCode,
              'resultCode',
              anyOf(SqlError.SQLITE_BUSY, SqlError.SQLITE_LOCKED),
            ),
          ),
        );
      } finally {
        live.execute('ROLLBACK');
        live.dispose();
      }

      final currentDb = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      addTearDown(currentDb.dispose);
      expect(
        currentDb
            .select(
              "SELECT title FROM workspace_projects WHERE id = 'project-1'",
            )
            .single['title'],
        '当前库值',
      );
      expect(
        tempDir.listSync().where((entry) => entry.path.contains('.restore-')),
        isEmpty,
      );
    });

    test('restoreBackup throws when backup id does not exist', () async {
      final service = FileAutoBackupService(dbPath: dbPath);

      expect(service.restoreBackup('nonexistent'), throwsA(isA<StateError>()));
    });

    test('corrupt backup cannot replace the live database', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);
      final entry = await service.createBackup();
      final backup = File('${tempDir.path}/backups/authoring_${entry.id}.db');
      await backup.writeAsString('corrupt', flush: true);

      await expectLater(service.restoreBackup(entry.id), throwsA(anything));
      final live = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      addTearDown(live.dispose);
      expect(
        live
            .select(
              "SELECT title FROM workspace_projects WHERE id = 'project-1'",
            )
            .single['title'],
        '月潮回声',
      );
    });

    test('deleteBackup removes a specific backup file', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry = await service.createBackup();
      expect(await service.listBackups(), hasLength(1));

      await service.deleteBackup(entry.id);
      expect(await service.listBackups(), isEmpty);
    });

    test('deleteBackup does nothing for nonexistent id', () async {
      final service = FileAutoBackupService(dbPath: dbPath);

      await service.deleteBackup('nonexistent');
    });

    test('pruneBackups removes oldest backups beyond keepCount', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      for (var i = 0; i < 5; i++) {
        await service.createBackup();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(await service.listBackups(), hasLength(5));

      final deleted = await service.pruneBackups(keepCount: 3);
      expect(deleted, 2);

      final remaining = await service.listBackups();
      expect(remaining, hasLength(3));
    });

    test('pruneBackups does nothing when under keepCount', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      await service.createBackup();
      await service.createBackup();

      final deleted = await service.pruneBackups(keepCount: 10);
      expect(deleted, 0);
      expect(await service.listBackups(), hasLength(2));
    });

    test('backup entries have correct metadata', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final before = DateTime.now().millisecondsSinceEpoch;
      final entry = await service.createBackup();
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(entry.createdAtMs, greaterThanOrEqualTo(before));
      expect(entry.createdAtMs, lessThanOrEqualTo(after));
      expect(entry.sizeBytes, greaterThan(0));
      expect(entry.id, matches(RegExp(r'^\d{8}_\d{6}_\d{3}$')));
    });

    test('multiple backups create separate files', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry1 = await service.createBackup();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final entry2 = await service.createBackup();

      expect(entry1.id, isNot(equals(entry2.id)));

      final backupDir = Directory('${tempDir.path}/backups');
      final allFiles = await backupDir.list().toList();
      final files = allFiles.whereType<File>().toList();
      expect(files, hasLength(2));
    });

    test('createBackup then restoreBackup preserves data integrity', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry = await service.createBackup();

      final db = sqlite3.open(dbPath);
      db.execute(
        'INSERT INTO workspace_projects (scope_key, position_no, id, title) VALUES (?, ?, ?, ?)',
        ['workspace-default', 1, 'project-2', '新增项目'],
      );
      final countBefore =
          db
                  .select('SELECT COUNT(*) as cnt FROM workspace_projects')
                  .first['cnt']
              as int;
      expect(countBefore, 2);
      db.dispose();

      await service.restoreBackup(entry.id);

      final restoredDb = sqlite3.open(dbPath);
      final countAfter =
          restoredDb
                  .select('SELECT COUNT(*) as cnt FROM workspace_projects')
                  .first['cnt']
              as int;
      expect(countAfter, 1);
      restoredDb.dispose();
    });

    test('listBackups ignores non-backup files in backup directory', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      await service.createBackup();

      final backupDir = Directory('${tempDir.path}/backups');
      await File('${backupDir.path}/other_file.txt').writeAsString('junk');
      await File(
        '${backupDir.path}/authoring.db',
      ).writeAsString('not-a-backup');

      final entries = await service.listBackups();
      expect(entries, hasLength(1));
    });

    test('full cycle: create, list, restore, delete', () async {
      await writeSampleData();
      final service = FileAutoBackupService(dbPath: dbPath);

      final entry = await service.createBackup();
      final listed = await service.listBackups();
      expect(listed, hasLength(1));
      expect(listed.first.id, entry.id);

      await service.restoreBackup(entry.id);
      expect(await service.listBackups(), hasLength(1));

      await service.deleteBackup(entry.id);
      expect(await service.listBackups(), isEmpty);
    });
  });
}
