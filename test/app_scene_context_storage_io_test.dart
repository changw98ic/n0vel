import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_scene_context_storage_io.dart';

void main() {
  test('save and load round-trip persists scene context snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_io_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {
        'sceneSummary': '当前场景：场景 03 · 雨夜码头',
        'characterSummary': '角色摘要：柳溪 · 调查记者',
        'worldSummary': '世界观摘要：港城旧码头 · 风暴预警',
      },
      projectId: 'project-yuechao',
    );

    final restored = await storage.load(projectId: 'project-yuechao');
    expect(restored, isNotNull);
    expect(restored!['sceneSummary'], '当前场景：场景 03 · 雨夜码头');
    expect(restored['characterSummary'], '角色摘要：柳溪 · 调查记者');
    expect(restored['worldSummary'], '世界观摘要：港城旧码头 · 风暴预警');
  });

  test('load returns null when no snapshot exists for project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_missing_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteAppSceneContextStorage(
      dbPath: '${directory.path}/authoring.db',
    );

    final restored = await storage.load(projectId: 'nonexistent-project');
    expect(restored, isNull);
  });

  test('save upserts overwrites previous snapshot for same project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_upsert_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {
        'sceneSummary': '旧场景',
        'characterSummary': '旧角色',
        'worldSummary': '旧世界观',
      },
      projectId: 'project-upsert',
    );

    await storage.save(
      {
        'sceneSummary': '新场景：仓库门外',
        'characterSummary': '新角色：陈默',
        'worldSummary': '新世界观：旧港规则',
      },
      projectId: 'project-upsert',
    );

    final restored = await storage.load(projectId: 'project-upsert');
    expect(restored, isNotNull);
    expect(restored!['sceneSummary'], '新场景：仓库门外');
    expect(restored['characterSummary'], '新角色：陈默');
    expect(restored['worldSummary'], '新世界观：旧港规则');
  });

  test('clear with projectId removes only that project snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_clear_one_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {
        'sceneSummary': '项目A场景',
        'characterSummary': '项目A角色',
        'worldSummary': '项目A世界观',
      },
      projectId: 'project-a',
    );
    await storage.save(
      {
        'sceneSummary': '项目B场景',
        'characterSummary': '项目B角色',
        'worldSummary': '项目B世界观',
      },
      projectId: 'project-b',
    );

    await storage.clear(projectId: 'project-a');

    expect(await storage.load(projectId: 'project-a'), isNull);
    final restoredB = await storage.load(projectId: 'project-b');
    expect(restoredB, isNotNull);
    expect(restoredB!['sceneSummary'], '项目B场景');
  });

  test('clear without projectId removes all snapshots', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_clear_all_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {
        'sceneSummary': '场景1',
        'characterSummary': '角色1',
        'worldSummary': '世界观1',
      },
      projectId: 'project-x',
    );
    await storage.save(
      {
        'sceneSummary': '场景2',
        'characterSummary': '角色2',
        'worldSummary': '世界观2',
      },
      projectId: 'project-y',
    );

    await storage.clear();

    expect(await storage.load(projectId: 'project-x'), isNull);
    expect(await storage.load(projectId: 'project-y'), isNull);
  });

  test('creates scene_context_snapshots table with correct schema', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_schema_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {
        'sceneSummary': 'schema测试场景',
        'characterSummary': 'schema测试角色',
        'worldSummary': 'schema测试世界观',
      },
      projectId: 'project-schema',
    );

    final database = sqlite3.open(dbPath);
    addTearDown(database.dispose);

    final tableNames = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(tableNames, contains('scene_context_snapshots'));

    final columns = database
        .select('PRAGMA table_info(scene_context_snapshots)')
        .map((row) => row['name'] as String)
        .toList();
    expect(columns, containsAll(['project_id', 'scene_summary', 'character_summary', 'world_summary', 'updated_at_ms']));

    final count = database.select(
      'SELECT COUNT(*) AS c FROM scene_context_snapshots',
    ).first['c'] as int;
    expect(count, 1);
  });

  test('isolates snapshots by project id', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_isolation_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {
        'sceneSummary': '月潮回声场景',
        'characterSummary': '月潮角色',
        'worldSummary': '月潮世界观',
      },
      projectId: 'project-yuechao',
    );
    await storage.save(
      {
        'sceneSummary': '暗流场景',
        'characterSummary': '暗流角色',
        'worldSummary': '暗流世界观',
      },
      projectId: 'project-anliu',
    );

    final yuechao = await storage.load(projectId: 'project-yuechao');
    final anliu = await storage.load(projectId: 'project-anliu');

    expect(yuechao!['sceneSummary'], '月潮回声场景');
    expect(anliu!['sceneSummary'], '暗流场景');
    expect(yuechao['characterSummary'], isNot(equals(anliu['characterSummary'])));
  });

  test('save handles missing keys with empty string fallback', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_context_missing_keys_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppSceneContextStorage(dbPath: dbPath);

    await storage.save(
      {'sceneSummary': 'only-scene'},
      projectId: 'project-partial',
    );

    final restored = await storage.load(projectId: 'project-partial');
    expect(restored, isNotNull);
    expect(restored!['sceneSummary'], 'only-scene');
    expect(restored['characterSummary'], '');
    expect(restored['worldSummary'], '');
  });
}
