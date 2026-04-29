import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_version_storage_io.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_version_io_test',
    );
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqliteAppVersionStorage', () {
    test('load returns null when no data exists', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      final result = await storage.load(projectId: 'project-x');
      expect(result, isNull);
    });

    test('save and load round-trip preserves entries', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      final data = {
        'entries': [
          {'label': '初始版本', 'content': '她推开仓库门，雨水顺着袖口滴进掌心。'},
          {'label': '修订版本', 'content': '远处码头的雾灯陷在雨里，像一根迟疑的针。'},
        ],
      };
      await storage.save(data, projectId: 'project-alpha');
      final loaded = await storage.load(projectId: 'project-alpha');

      expect(loaded, isNotNull);
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries.length, 2);
      expect((entries[0] as Map)['label'], '初始版本');
      expect((entries[0] as Map)['content'], '她推开仓库门，雨水顺着袖口滴进掌心。');
      expect((entries[1] as Map)['label'], '修订版本');
      expect((entries[1] as Map)['content'], '远处码头的雾灯陷在雨里，像一根迟疑的针。');
    });

    test('save overwrites previous entries for same project', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': '旧版本', 'content': '旧内容'},
        ],
      }, projectId: 'project-overwrite');

      await storage.save({
        'entries': [
          {'label': '新版本', 'content': '新内容'},
        ],
      }, projectId: 'project-overwrite');

      final loaded = await storage.load(projectId: 'project-overwrite');
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries.length, 1);
      expect((entries[0] as Map)['label'], '新版本');
    });

    test('different projects are fully isolated', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': '项目 A', 'content': '内容 A'},
        ],
      }, projectId: 'project-a');

      await storage.save({
        'entries': [
          {'label': '项目 B', 'content': '内容 B'},
        ],
      }, projectId: 'project-b');

      final loadedA = await storage.load(projectId: 'project-a');
      final loadedB = await storage.load(projectId: 'project-b');

      expect(
        ((loadedA!['entries'] as List).first as Map)['label'],
        '项目 A',
      );
      expect(
        ((loadedB!['entries'] as List).first as Map)['label'],
        '项目 B',
      );
    });

    test('clear with projectId removes only that project', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': '保留我', 'content': '保留内容'},
        ],
      }, projectId: 'project-keep');

      await storage.save({
        'entries': [
          {'label': '删除我', 'content': '删除内容'},
        ],
      }, projectId: 'project-delete');

      await storage.clear(projectId: 'project-delete');

      expect(await storage.load(projectId: 'project-delete'), isNull);
      expect(await storage.load(projectId: 'project-keep'), isNotNull);
    });

    test('clear without projectId removes all projects', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': 'A', 'content': 'A'},
        ],
      }, projectId: 'project-a');

      await storage.save({
        'entries': [
          {'label': 'B', 'content': 'B'},
        ],
      }, projectId: 'project-b');

      await storage.clear();

      expect(await storage.load(projectId: 'project-a'), isNull);
      expect(await storage.load(projectId: 'project-b'), isNull);
    });

    test('save with missing entries key results in null load', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save(<String, Object?>{}, projectId: 'project-empty');

      final loaded = await storage.load(projectId: 'project-empty');
      expect(loaded, isNull);
    });

    test('save with null entries list results in null load', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({'entries': null}, projectId: 'project-null');

      final loaded = await storage.load(projectId: 'project-null');
      expect(loaded, isNull);
    });

    test('save skips non-map entries in the list', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          'invalid string entry',
          {'label': '有效版本', 'content': '有效内容'},
          42,
          null,
        ],
      }, projectId: 'project-mixed');

      final loaded = await storage.load(projectId: 'project-mixed');
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries.length, 1);
      expect((entries[0] as Map)['label'], '有效版本');
    });

    test('entries are returned in sequence_no order', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': '第一版', 'content': '内容1'},
          {'label': '第二版', 'content': '内容2'},
          {'label': '第三版', 'content': '内容3'},
        ],
      }, projectId: 'project-order');

      final loaded = await storage.load(projectId: 'project-order');
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries.length, 3);
      expect((entries[0] as Map)['label'], '第一版');
      expect((entries[1] as Map)['label'], '第二版');
      expect((entries[2] as Map)['label'], '第三版');
    });

    test('multiple storage instances share the same database', () async {
      final writer = SqliteAppVersionStorage(dbPath: dbPath);

      await writer.save({
        'entries': [
          {'label': '跨实例版本', 'content': '跨实例内容'},
        ],
      }, projectId: 'project-shared');

      final reader = SqliteAppVersionStorage(dbPath: dbPath);
      final loaded = await reader.load(projectId: 'project-shared');

      expect(loaded, isNotNull);
      final entries = loaded!['entries'] as List<Object?>;
      expect((entries.first as Map)['label'], '跨实例版本');
    });

    test('database has correct schema', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': 'schema', 'content': 'test'},
        ],
      }, projectId: 'project-schema');

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);

      final tableNames = database
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tableNames, contains('version_entries'));

      final columns = database.select('PRAGMA table_info(version_entries)');
      final columnNames =
          columns.map((row) => row['name'] as String).toList();
      expect(
        columnNames,
        containsAll([
          'project_id',
          'sequence_no',
          'label',
          'content',
          'updated_at_ms',
        ]),
      );
    });

    test('updated_at_ms advances on subsequent saves', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': '第一次', 'content': 'ts1'},
        ],
      }, projectId: 'project-ts');

      await Future<void>.delayed(const Duration(milliseconds: 10));

      await storage.save({
        'entries': [
          {'label': '第二次', 'content': 'ts2'},
        ],
      }, projectId: 'project-ts');

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);

      final row = database.select(
        "SELECT updated_at_ms FROM version_entries WHERE project_id = 'project-ts'",
      ).first;
      expect(row['updated_at_ms'] as int, greaterThan(0));
    });

    test('legacy schema migration preserves existing data', () async {
      final database = sqlite3.open(dbPath);
      database.execute('''
        CREATE TABLE version_entries (
          sequence_no INTEGER NOT NULL,
          label TEXT NOT NULL,
          content TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
      ''');
      database.execute(
        'INSERT INTO version_entries (sequence_no, label, content, updated_at_ms) VALUES (?, ?, ?, ?)',
        [0, '遗留版本', '遗留内容', DateTime.now().millisecondsSinceEpoch],
      );
      database.dispose();

      final storage = SqliteAppVersionStorage(dbPath: dbPath);
      final loaded = await storage.load(projectId: 'project-yuechao');

      expect(loaded, isNotNull);
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries.length, 1);
      expect((entries[0] as Map)['label'], '遗留版本');
      expect((entries[0] as Map)['content'], '遗留内容');
    });

    test('legacy migration does not re-run if project_id column exists', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': '新格式', 'content': '新内容'},
        ],
      }, projectId: 'project-new');

      final storage2 = SqliteAppVersionStorage(dbPath: dbPath);
      final loaded = await storage2.load(projectId: 'project-new');

      final entries = loaded!['entries'] as List<Object?>;
      expect((entries[0] as Map)['label'], '新格式');
    });

    test('load on cleared non-existent project returns null without error', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.clear(projectId: 'non-existent');
      final result = await storage.load(projectId: 'non-existent');
      expect(result, isNull);
    });

    test('save preserves unicode and emoji content', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      const content = '你好世界 🌍 émoji àccënts 日本語テスト';
      await storage.save({
        'entries': [
          {'label': 'unicode 测试 🎉', 'content': content},
        ],
      }, projectId: 'project-unicode');

      final loaded = await storage.load(projectId: 'project-unicode');
      final entry = (loaded!['entries'] as List).first as Map;
      expect(entry['label'], 'unicode 测试 🎉');
      expect(entry['content'], content);
    });

    test('save handles very long content', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      final longContent = '长文本测试版本内容。' * 10000;
      await storage.save({
        'entries': [
          {'label': '长内容版本', 'content': longContent},
        ],
      }, projectId: 'project-long');

      final loaded = await storage.load(projectId: 'project-long');
      final entry = (loaded!['entries'] as List).first as Map;
      expect(entry['content'], longContent);
      expect((entry['content'] as String).length, 100000);
    });

    test('save with missing label defaults to empty string', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          <String, Object?>{'content': '无标签内容'},
        ],
      }, projectId: 'project-no-label');

      final loaded = await storage.load(projectId: 'project-no-label');
      final entry = (loaded!['entries'] as List).first as Map;
      expect(entry['label'], '');
      expect(entry['content'], '无标签内容');
    });

    test('save with missing content defaults to empty string', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          <String, Object?>{'label': '无内容标签'},
        ],
      }, projectId: 'project-no-content');

      final loaded = await storage.load(projectId: 'project-no-content');
      final entry = (loaded!['entries'] as List).first as Map;
      expect(entry['label'], '无内容标签');
      expect(entry['content'], '');
    });

    test('save with non-string label and content coerces to string', () async {
      final storage = SqliteAppVersionStorage(dbPath: dbPath);

      await storage.save({
        'entries': [
          {'label': 12345, 'content': 67890},
        ],
      }, projectId: 'project-int');

      final loaded = await storage.load(projectId: 'project-int');
      final entry = (loaded!['entries'] as List).first as Map;
      expect(entry['label'], '12345');
      expect(entry['content'], '67890');
    });
  });
}
