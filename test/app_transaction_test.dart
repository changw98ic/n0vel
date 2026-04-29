import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_authoring_storage_io_support.dart';
import 'package:novel_writer/app/state/app_simulation_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';

void main() {
  // ── runInTransaction unit tests ──────────────────────────────────────────

  group('runInTransaction', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      db.execute('CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)');
    });

    tearDown(() => db.dispose());

    test('commits on success', () {
      runInTransaction(db, () {
        db.execute("INSERT INTO items (name) VALUES ('a')");
        db.execute("INSERT INTO items (name) VALUES ('b')");
      });
      final rows = db.select('SELECT name FROM items ORDER BY name');
      expect(rows.map((r) => r['name']), ['a', 'b']);
    });

    test('rolls back on exception', () {
      expect(
        () => runInTransaction(db, () {
          db.execute("INSERT INTO items (name) VALUES ('a')");
          throw StateError('boom');
        }),
        throwsStateError,
      );
      expect(db.select('SELECT * FROM items'), isEmpty);
    });

    test('returns typed value from action', () {
      final result = runInTransaction(db, () {
        db.execute("INSERT INTO items (name) VALUES ('x')");
        return 42;
      });
      expect(result, 42);
      expect(db.select('SELECT * FROM items'), hasLength(1));
    });

    test('partial writes within transaction are atomic', () {
      db.execute('CREATE TABLE strict_tbl (val TEXT NOT NULL)');

      expect(
        () => runInTransaction(db, () {
          db.execute("INSERT INTO strict_tbl (val) VALUES ('ok')");
          db.execute("INSERT INTO strict_tbl (val) VALUES (NULL)");
        }),
        throwsA(anything),
      );

      expect(db.select('SELECT * FROM strict_tbl'), isEmpty);
    });
  });

  // ── withAuthoringDbInTxn ─────────────────────────────────────────────────

  group('withAuthoringDbInTxn', () {
    late String dbPath;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('txn_test');
      dbPath = '${tempDir.path}/test.db';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('commits and returns result', () {
      final count = withAuthoringDbInTxn(dbPath, (db) {
        db.execute(
          "INSERT INTO draft_documents (project_id, text_body, updated_at_ms) "
          "VALUES ('p1', 'hello', 1000)",
        );
        return db.select('SELECT count(*) AS c FROM draft_documents').first['c']
            as int;
      });
      expect(count, 1);
    });

    test('rolls back on error', () {
      expect(
        () => withAuthoringDbInTxn(dbPath, (db) {
          db.execute(
            "INSERT INTO draft_documents (project_id, text_body, updated_at_ms) "
            "VALUES ('p1', 'hello', 1000)",
          );
          throw StateError('fail');
        }),
        throwsStateError,
      );

      final remaining = withAuthoringDb(
        dbPath,
        (db) =>
            db.select('SELECT count(*) AS c FROM draft_documents').first['c']
                as int,
      );
      expect(remaining, 0);
    });
  });


  // ── SqliteAppSimulationStorage transaction in clear ──────────────────────

  group('SqliteAppSimulationStorage clear transaction', () {
    late SqliteAppSimulationStorage storage;
    late String dbPath;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sim_txn_test');
      dbPath = '${tempDir.path}/sim.db';
      storage = SqliteAppSimulationStorage(dbPath: dbPath);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('clear by project removes all related data', () async {
      await storage.save(
        {
          'template': 'dialogue',
          'promptOverrides': {'char1': 'prompt'},
          'extraMessages': [],
        },
        projectId: 'p1',
      );
      await storage.save(
        {
          'template': 'monologue',
          'promptOverrides': {},
          'extraMessages': [],
        },
        projectId: 'p2',
      );

      await storage.clear(projectId: 'p1');

      expect(await storage.load(projectId: 'p1'), isNull);
      final p2 = await storage.load(projectId: 'p2');
      expect(p2, isNotNull);
      expect(p2!['template'], 'monologue');
    });

    test('clear all removes everything', () async {
      await storage.save(
        {
          'template': 'dialogue',
          'promptOverrides': {},
          'extraMessages': [],
        },
        projectId: 'p1',
      );

      await storage.clear();

      expect(await storage.load(projectId: 'p1'), isNull);
    });
  });

  // ── SqliteAppWorkspaceStorage clear transaction ──────────────────────────

  group('SqliteAppWorkspaceStorage clear transaction', () {
    late SqliteAppWorkspaceStorage storage;
    late String dbPath;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ws_txn_test');
      dbPath = '${tempDir.path}/ws.db';
      storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('clear removes all workspace data atomically', () async {
      await storage.save({
        'projects': [
          {
            'id': 'p1',
            'sceneId': 's1',
            'title': 'Test',
            'genre': 'Fantasy',
            'summary': 'A test',
            'recentLocation': '场景1',
            'lastOpenedAtMs': 1000,
          },
        ],
        'charactersByProject': {
          'p1': [
            {'name': 'Alice', 'role': 'protagonist', 'note': '', 'need': '', 'summary': ''},
          ],
        },
        'scenesByProject': {},
        'worldNodesByProject': {},
        'auditIssuesByProject': {},
        'projectStyles': {},
        'projectAuditStates': {},
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect((loaded!['projects'] as List).length, 1);

      await storage.clear();

      expect(await storage.load(), isNull);
    });

    test('save and reload preserves data integrity', () async {
      final data = {
        'projects': [
          {
            'id': 'p1',
            'sceneId': 's1',
            'title': 'Novel',
            'genre': 'SciFi',
            'summary': 'Summary',
            'recentLocation': 'Ch1',
            'lastOpenedAtMs': 2000,
          },
        ],
        'charactersByProject': {
          'p1': [
            {'name': 'Bob', 'role': 'sidekick', 'note': 'n', 'need': 'nd', 'summary': 'sm'},
          ],
        },
        'scenesByProject': {
          'p1': [
            {'id': 'sc1', 'chapterLabel': 'Ch1', 'title': 'Scene 1', 'summary': 'S1'},
          ],
        },
        'worldNodesByProject': {},
        'auditIssuesByProject': {},
        'projectStyles': {'p1': {'styleInputMode': 'guided'}},
        'projectAuditStates': {},
        'projectTransferState': '',
        'currentProjectId': 'p1',
      };

      await storage.save(data);
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      expect((loaded!['projects'] as List).length, 1);
      expect(loaded['currentProjectId'], 'p1');
      final chars =
          loaded['charactersByProject'] as Map<Object?, Object?>?;
      expect(chars?['p1'], isNotNull);
      final scenes = loaded['scenesByProject'] as Map<Object?, Object?>?;
      expect(scenes?['p1'], isNotNull);
    });
  });
}
