import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/story_outline_storage_io.dart';

void main() {
  test('save and load round-trip persists chapter scenes and cast metadata', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_roundtrip_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);
    const projectId = 'project-outline-a';
    const expectedCastMetadata = <String, Object?>{
      'action': 'passes a rain-soaked ledger page under the dock light',
      'dialogueBeat': 'keeps her answer short and avoids names',
      'interactionFlags': ['conceals-source', 'urgent-handoff'],
      'isPointOfView': true,
    };
    final payload = <String, Object?>{
      'projectId': projectId,
      'chapters': [
        {
          'id': 'chapter-01',
          'title': '第一章 雨夜码头',
          'scenes': [
            {
              'id': 'scene-01',
              'title': '仓库门外',
              'summary': '她在雨里等一个迟到的证人。',
              'cast': [
                {
                  'characterId': 'char-liuxi',
                  'name': '柳溪',
                  'role': '调查记者',
                  'metadata': expectedCastMetadata,
                },
                {'characterId': 'char-chenmo', 'name': '陈默', 'role': '线人'},
              ],
            },
          ],
        },
      ],
    };

    await storage.save(payload, projectId: projectId);

    final restored = await storage.load(projectId: projectId);
    expect(restored, isNotNull);
    expect(restored?['projectId'], projectId);

    final chapters = restored?['chapters'] as List<Object?>;
    final firstChapter = chapters.first as Map<String, Object?>;
    final scenes = firstChapter['scenes'] as List<Object?>;
    final firstScene = scenes.first as Map<String, Object?>;
    final cast = firstScene['cast'] as List<Object?>;

    expect(cast, hasLength(2));
    expect((cast.first as Map<String, Object?>)['characterId'], 'char-liuxi');
    final restoredCastMetadata = Map<String, Object?>.from(
      (cast.first as Map<String, Object?>)['metadata']! as Map,
    );
    expect(restoredCastMetadata, equals(expectedCastMetadata));
  });

  test('load returns null when no snapshot exists for project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_missing_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteStoryOutlineStorage(
      dbPath: '${directory.path}/authoring.db',
    );

    final restored = await storage.load(projectId: 'nonexistent-project');
    expect(restored, isNull);
  });

  test('save upserts overwrites previous snapshot for same project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_upsert_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {
        'projectId': 'project-upsert',
        'chapters': [
          {'id': 'ch-old', 'title': '旧章节', 'scenes': []},
        ],
      },
      projectId: 'project-upsert',
    );

    await storage.save(
      {
        'projectId': 'project-upsert',
        'chapters': [
          {'id': 'ch-new', 'title': '新章节：雨后', 'scenes': []},
        ],
      },
      projectId: 'project-upsert',
    );

    final restored = await storage.load(projectId: 'project-upsert');
    expect(restored, isNotNull);
    final chapters = restored!['chapters'] as List<Object?>;
    expect(chapters, hasLength(1));
    final chapter = chapters.first as Map<String, Object?>;
    expect(chapter['id'], 'ch-new');
    expect(chapter['title'], '新章节：雨后');
  });

  test('clear with projectId removes only that project snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_clear_one_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {
        'chapters': [
          {'id': 'ch-a', 'title': '项目A章节', 'scenes': []},
        ],
      },
      projectId: 'project-a',
    );
    await storage.save(
      {
        'chapters': [
          {'id': 'ch-b', 'title': '项目B章节', 'scenes': []},
        ],
      },
      projectId: 'project-b',
    );

    await storage.clear(projectId: 'project-a');

    expect(await storage.load(projectId: 'project-a'), isNull);
    final restoredB = await storage.load(projectId: 'project-b');
    expect(restoredB, isNotNull);
    final chaptersB = restoredB!['chapters'] as List<Object?>;
    expect((chaptersB.first as Map<String, Object?>)['title'], '项目B章节');
  });

  test('clear without projectId removes all snapshots', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_clear_all_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {'chapters': []},
      projectId: 'project-x',
    );
    await storage.save(
      {'chapters': []},
      projectId: 'project-y',
    );

    await storage.clear();

    expect(await storage.load(projectId: 'project-x'), isNull);
    expect(await storage.load(projectId: 'project-y'), isNull);
  });

  test('creates story_outline_snapshots table with correct schema', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_schema_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {'chapters': []},
      projectId: 'project-schema',
    );

    final database = sqlite3.open(dbPath);
    addTearDown(database.dispose);

    final tableNames = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(tableNames, contains('story_outline_snapshots'));

    final columns = database
        .select('PRAGMA table_info(story_outline_snapshots)')
        .map((row) => row['name'] as String)
        .toList();
    expect(
      columns,
      containsAll(['project_id', 'snapshot_json', 'updated_at_ms']),
    );

    final count = database.select(
      'SELECT COUNT(*) AS c FROM story_outline_snapshots',
    ).first['c'] as int;
    expect(count, 1);
  });

  test('isolates snapshots by project id', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_isolation_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {
        'projectId': 'project-yuechao',
        'chapters': [
          {
            'id': 'ch-1',
            'title': '月潮第一章',
            'scenes': [
              {'id': 's-1', 'title': '海边', 'summary': '潮声入梦'},
            ],
          },
        ],
      },
      projectId: 'project-yuechao',
    );
    await storage.save(
      {
        'projectId': 'project-anliu',
        'chapters': [
          {
            'id': 'ch-1',
            'title': '暗流第一章',
            'scenes': [
              {'id': 's-1', 'title': '码头', 'summary': '暗涌不止'},
            ],
          },
        ],
      },
      projectId: 'project-anliu',
    );

    final yuechao = await storage.load(projectId: 'project-yuechao');
    final anliu = await storage.load(projectId: 'project-anliu');

    final yuechaoChapters = yuechao!['chapters'] as List<Object?>;
    final anliuChapters = anliu!['chapters'] as List<Object?>;
    final yuechaoTitle =
        (yuechaoChapters.first as Map<String, Object?>)['title'];
    final anliuTitle =
        (anliuChapters.first as Map<String, Object?>)['title'];

    expect(yuechaoTitle, '月潮第一章');
    expect(anliuTitle, '暗流第一章');
    expect(yuechaoTitle, isNot(equals(anliuTitle)));
  });

  test('save handles empty chapters list', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_empty_chapters_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {'projectId': 'project-empty', 'chapters': []},
      projectId: 'project-empty',
    );

    final restored = await storage.load(projectId: 'project-empty');
    expect(restored, isNotNull);
    expect(restored!['projectId'], 'project-empty');
    expect(restored['chapters'] as List<Object?>, isEmpty);
  });

  test('save normalizes projectId field to match projectId parameter', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_project_id_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);

    await storage.save(
      {'chapters': []},
      projectId: 'project-normalized',
    );

    final restored = await storage.load(projectId: 'project-normalized');
    expect(restored, isNotNull);
    expect(restored!['projectId'], 'project-normalized');
  });

  test('snapshot_json contains valid JSON with full outline structure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_outline_json_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryOutlineStorage(dbPath: dbPath);
    const projectId = 'project-json-check';

    final payload = <String, Object?>{
      'chapters': [
        {
          'id': 'ch-01',
          'title': '第一章',
          'scenes': [
            {
              'id': 's-01',
              'title': '场景一',
              'summary': '摘要文本',
              'cast': [
                {'characterId': 'c-01', 'name': '角色A', 'role': '主角'},
              ],
            },
          ],
        },
      ],
    };

    await storage.save(payload, projectId: projectId);

    final database = sqlite3.open(dbPath);
    addTearDown(database.dispose);

    final rows = database.select(
      'SELECT snapshot_json FROM story_outline_snapshots WHERE project_id = ?',
      [projectId],
    );
    expect(rows, hasLength(1));

    final jsonString = rows.first['snapshot_json'] as String;
    // Verify it's valid JSON by decoding
    final decoded = Map<String, Object?>.from(
      (const JsonDecoder().convert(jsonString)) as Map,
    );
    expect(decoded.containsKey('chapters'), isTrue);
    expect(decoded.containsKey('projectId'), isTrue);
    expect(decoded['projectId'], projectId);
  });
}
