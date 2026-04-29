import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_draft_storage_io.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_draft_io_test',
    );
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqliteAppDraftStorage', () {
    test('load returns null when no data exists', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      final result = await storage.load(projectId: 'project-x');
      expect(result, isNull);
    });

    test('save and load round-trip preserves text', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      const text = '她推开仓库门，雨水顺着袖口淌进掌心。远处码头的雾灯陷在雨里，像一根迟疑的针。';
      await storage.save({'text': text}, projectId: 'project-alpha');
      final loaded = await storage.load(projectId: 'project-alpha');

      expect(loaded, isNotNull);
      expect(loaded!['text'], text);
    });

    test('save overwrites previous text for same project', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': '旧草稿内容'}, projectId: 'project-overwrite');
      await storage.save({'text': '新草稿内容'}, projectId: 'project-overwrite');

      final loaded = await storage.load(projectId: 'project-overwrite');
      expect(loaded!['text'], '新草稿内容');
    });

    test('different projects are fully isolated', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': '项目 A 草稿'}, projectId: 'project-a');
      await storage.save({'text': '项目 B 草稿'}, projectId: 'project-b');

      final loadedA = await storage.load(projectId: 'project-a');
      final loadedB = await storage.load(projectId: 'project-b');

      expect(loadedA!['text'], '项目 A 草稿');
      expect(loadedB!['text'], '项目 B 草稿');
    });

    test('clear with projectId removes only that project', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': '保留我'}, projectId: 'project-keep');
      await storage.save({'text': '删除我'}, projectId: 'project-delete');

      await storage.clear(projectId: 'project-delete');

      expect(await storage.load(projectId: 'project-delete'), isNull);
      expect(await storage.load(projectId: 'project-keep'), isNotNull);
    });

    test('clear without projectId removes all projects', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': 'A'}, projectId: 'project-a');
      await storage.save({'text': 'B'}, projectId: 'project-b');

      await storage.clear();

      expect(await storage.load(projectId: 'project-a'), isNull);
      expect(await storage.load(projectId: 'project-b'), isNull);
    });

    test('save with missing text key stores empty string', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save(<String, Object?>{}, projectId: 'project-empty-key');

      final loaded = await storage.load(projectId: 'project-empty-key');
      expect(loaded, isNotNull);
      expect(loaded!['text'], '');
    });

    test('save with null text value stores empty string', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': null}, projectId: 'project-null-text');

      final loaded = await storage.load(projectId: 'project-null-text');
      expect(loaded, isNotNull);
      expect(loaded!['text'], '');
    });

    test('save with non-string text coerces to string', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': 12345}, projectId: 'project-int-text');

      final loaded = await storage.load(projectId: 'project-int-text');
      expect(loaded, isNotNull);
      expect(loaded!['text'], '12345');
    });

    test('multiple storage instances share the same database', () async {
      final writer = SqliteAppDraftStorage(dbPath: dbPath);

      await writer.save({'text': '跨实例草稿'}, projectId: 'project-shared');

      final reader = SqliteAppDraftStorage(dbPath: dbPath);
      final loaded = await reader.load(projectId: 'project-shared');

      expect(loaded, isNotNull);
      expect(loaded!['text'], '跨实例草稿');
    });

    test('database has correct schema', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': 'schema test'}, projectId: 'project-schema');

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);

      final tableNames = database
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tableNames, contains('draft_documents'));

      final columns = database.select('PRAGMA table_info(draft_documents)');
      final columnNames = columns.map((row) => row['name'] as String).toList();
      expect(columnNames, containsAll(['project_id', 'text_body', 'updated_at_ms']));
    });

    test('updated_at_ms advances on subsequent saves', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.save({'text': '第一次'}, projectId: 'project-ts');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await storage.save({'text': '第二次'}, projectId: 'project-ts');

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);

      final row = database.select(
        "SELECT updated_at_ms FROM draft_documents WHERE project_id = 'project-ts'",
      ).first;
      expect(row['updated_at_ms'] as int, greaterThan(0));
    });

    test('legacy schema migration preserves existing data', () async {
      final database = sqlite3.open(dbPath);
      database.execute('''
        CREATE TABLE draft_documents (
          text_body TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
      ''');
      database.execute(
        'INSERT INTO draft_documents (text_body, updated_at_ms) VALUES (?, ?)',
        ['遗留草稿内容', DateTime.now().millisecondsSinceEpoch],
      );
      database.dispose();

      final storage = SqliteAppDraftStorage(dbPath: dbPath);
      final loaded = await storage.load(projectId: 'project-yuechao');

      expect(loaded, isNotNull);
      expect(loaded!['text'], '遗留草稿内容');
    });

    test('load on cleared non-existent project returns null without error', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      await storage.clear(projectId: 'non-existent');
      final result = await storage.load(projectId: 'non-existent');
      expect(result, isNull);
    });

    test('save preserves unicode and emoji content', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      const text = '你好世界 🌍 émoji àccënts 日本語テスト';
      await storage.save({'text': text}, projectId: 'project-unicode');
      final loaded = await storage.load(projectId: 'project-unicode');

      expect(loaded!['text'], text);
    });

    test('save handles very long text', () async {
      final storage = SqliteAppDraftStorage(dbPath: dbPath);

      final longText = '长文本测试。' * 10000;
      await storage.save({'text': longText}, projectId: 'project-long');
      final loaded = await storage.load(projectId: 'project-long');

      expect(loaded!['text'], longText);
      expect((loaded['text'] as String).length, 60000);
    });
  });
}
