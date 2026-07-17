import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_auto_backup.dart';
import 'package:novel_writer/app/state/app_auto_backup_io.dart';

void main() {
  group('BackupRecoveryCoordinator', () {
    test('prepares before restore and publishes terminal success', () async {
      final events = <BackupRecoveryPhase>[];
      final calls = <String>[];
      final coordinator = BackupRecoveryCoordinator(
        prepare: () async => calls.add('prepare'),
        restore: () async => calls.add('restore'),
        onStateChanged: (state) => events.add(state.phase),
      );

      final result = await coordinator.recover();

      expect(result.phase, BackupRecoveryPhase.succeeded);
      expect(calls, ['prepare', 'restore']);
      expect(events, [
        BackupRecoveryPhase.preparing,
        BackupRecoveryPhase.restoring,
        BackupRecoveryPhase.succeeded,
      ]);
      expect(coordinator.state, result);
    });

    test('exposes preparation failures and does not start restore', () async {
      var restoreCalled = false;
      final coordinator = BackupRecoveryCoordinator(
        prepare: () async => throw StateError('stores still active'),
        restore: () async => restoreCalled = true,
      );

      final result = await coordinator.recover();

      expect(result.phase, BackupRecoveryPhase.failed);
      expect(result.error, isA<StateError>());
      expect(restoreCalled, isFalse);
    });

    test('coalesces concurrent recover calls', () async {
      var prepareCalls = 0;
      var restoreCalls = 0;
      final coordinator = BackupRecoveryCoordinator(
        prepare: () async {
          prepareCalls++;
          await Future<void>.delayed(Duration.zero);
        },
        restore: () async {
          restoreCalls++;
          await Future<void>.delayed(Duration.zero);
        },
      );

      final results = await Future.wait([
        coordinator.recover(),
        coordinator.recover(),
      ]);

      expect(results[0], same(results[1]));
      expect(prepareCalls, 1);
      expect(restoreCalls, 1);
    });
  });

  group('FileAutoBackupService restore journal', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('novel_writer_recovery');
      dbPath = '${tempDir.path}/authoring.db';
      final db = sqlite3.open(dbPath);
      db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT)');
      db.execute("INSERT INTO notes (body) VALUES ('原始内容')");
      db.dispose();
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<String> createBackup() async {
      final service = FileAutoBackupService(dbPath: dbPath);
      final entry = await service.createBackup();
      return entry.id;
    }

    Future<String> readBody() async {
      final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      try {
        return db.select('SELECT body FROM notes').single['body'] as String;
      } finally {
        db.dispose();
      }
    }

    test(
      'recovers an interrupted old-renamed swap before listing backups',
      () async {
        await createBackup();
        const operationId = '123-456';
        final previous = File('$dbPath.restore-$operationId.previous');
        await File(dbPath).rename(previous.path);
        await File('$dbPath.restore-journal.json').writeAsString(
          jsonEncode({
            'targetPath': File(dbPath).absolute.path,
            'operationId': operationId,
            'phase': 'old-renamed',
          }),
          flush: true,
        );

        final entries = await FileAutoBackupService(
          dbPath: dbPath,
        ).listBackups();

        expect(entries, hasLength(1));
        expect(await readBody(), '原始内容');
        expect(await File('$dbPath.restore-journal.json').exists(), isFalse);
        expect(await previous.exists(), isFalse);
      },
    );

    test(
      'rolls back an invalid installed target to the previous database',
      () async {
        await createBackup();
        const operationId = '123-789';
        final previous = File('$dbPath.restore-$operationId.previous');
        await File(dbPath).rename(previous.path);
        await File(dbPath).writeAsString('not sqlite', flush: true);
        await File('$dbPath.restore-journal.json').writeAsString(
          jsonEncode({
            'targetPath': File(dbPath).absolute.path,
            'operationId': operationId,
            'phase': 'new-installed',
          }),
          flush: true,
        );

        await FileAutoBackupService(dbPath: dbPath).listBackups();

        expect(await readBody(), '原始内容');
        expect(await File('$dbPath.restore-journal.json').exists(), isFalse);
        expect(await previous.exists(), isFalse);
      },
    );
  });
}
