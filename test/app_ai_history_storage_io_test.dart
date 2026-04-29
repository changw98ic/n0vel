import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage_io.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_ai_history_io_test',
    );
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqliteAppAiHistoryStorage', () {
    test('load returns null when no data exists', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      final result = await storage.load(projectId: 'project-x');
      expect(result, isNull);
    });

    test('save and load round-trip preserves entries', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      final data = <String, Object?>{
        'entries': [
          {'sequence': 1, 'mode': '改写', 'prompt': '将第一段改为悬疑风格'},
          {'sequence': 2, 'mode': '续写', 'prompt': '继续写第二段'},
          {'sequence': 3, 'mode': '润色', 'prompt': '润色整体文风'},
        ],
      };

      await storage.save(data, projectId: 'project-alpha');
      final loaded = await storage.load(projectId: 'project-alpha');

      expect(loaded, isNotNull);
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries, hasLength(3));

      final first = entries[0] as Map<String, Object?>;
      expect(first['sequence'], 1);
      expect(first['mode'], '改写');
      expect(first['prompt'], '将第一段改为悬疑风格');

      final second = entries[1] as Map<String, Object?>;
      expect(second['sequence'], 2);
      expect(second['mode'], '续写');

      final third = entries[2] as Map<String, Object?>;
      expect(third['sequence'], 3);
      expect(third['mode'], '润色');
    });

    test('entries are ordered by position_no', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      final data = <String, Object?>{
        'entries': [
          {'sequence': 10, 'mode': '续写', 'prompt': '最后一条'},
          {'sequence': 5, 'mode': '改写', 'prompt': '第一条'},
          {'sequence': 7, 'mode': '润色', 'prompt': '中间条'},
        ],
      };

      await storage.save(data, projectId: 'project-order');
      final loaded = await storage.load(projectId: 'project-order');

      final entries = loaded!['entries'] as List<Object?>;
      // position_no = insertion index, so order follows insertion order
      expect((entries[0] as Map<String, Object?>)['sequence'], 10);
      expect((entries[1] as Map<String, Object?>)['sequence'], 5);
      expect((entries[2] as Map<String, Object?>)['sequence'], 7);
    });

    test('save overwrites previous entries for same project', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': '旧记录'},
          ],
        },
        projectId: 'project-overwrite',
      );

      await storage.save(
        {
          'entries': [
            {'sequence': 2, 'mode': '续写', 'prompt': '新记录'},
            {'sequence': 3, 'mode': '润色', 'prompt': '另一条'},
          ],
        },
        projectId: 'project-overwrite',
      );

      final loaded = await storage.load(projectId: 'project-overwrite');
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries, hasLength(2));
      expect((entries[0] as Map<String, Object?>)['prompt'], '新记录');
      expect((entries[1] as Map<String, Object?>)['prompt'], '另一条');
    });

    test('different projects are fully isolated', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': '项目 A 历史'},
          ],
        },
        projectId: 'project-a',
      );
      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '续写', 'prompt': '项目 B 历史'},
          ],
        },
        projectId: 'project-b',
      );

      final loadedA = await storage.load(projectId: 'project-a');
      final loadedB = await storage.load(projectId: 'project-b');

      expect(
        ((loadedA!['entries'] as List<Object?>).first
            as Map<String, Object?>)['prompt'] as String,
        contains('项目 A'),
      );
      expect(
        ((loadedB!['entries'] as List<Object?>).first
            as Map<String, Object?>)['prompt'] as String,
        contains('项目 B'),
      );
    });

    test('clear with projectId removes only that project', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': '保留我'},
          ],
        },
        projectId: 'project-keep',
      );
      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '续写', 'prompt': '删除我'},
          ],
        },
        projectId: 'project-delete',
      );

      await storage.clear(projectId: 'project-delete');

      expect(await storage.load(projectId: 'project-delete'), isNull);
      expect(
        await storage.load(projectId: 'project-keep'),
        isNotNull,
      );
    });

    test('clear without projectId removes all projects', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': 'A'},
          ],
        },
        projectId: 'project-a',
      );
      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '续写', 'prompt': 'B'},
          ],
        },
        projectId: 'project-b',
      );

      await storage.clear();

      expect(await storage.load(projectId: 'project-a'), isNull);
      expect(await storage.load(projectId: 'project-b'), isNull);
    });

    test('save with empty entries list clears project data', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': '初始数据'},
          ],
        },
        projectId: 'project-empty',
      );

      await storage.save(
        {'entries': <Object?>[]},
        projectId: 'project-empty',
      );

      // DELETE + INSERT with empty list → no rows → load returns null
      expect(await storage.load(projectId: 'project-empty'), isNull);
    });

    test('save skips malformed entries gracefully', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      final data = <String, Object?>{
        'entries': [
          {'sequence': 1, 'mode': '改写', 'prompt': '正常条目'},
          'this is not a map',
          42,
          null,
          {'sequence': 2, 'mode': '续写', 'prompt': '另一个正常条目'},
        ],
      };

      await storage.save(data, projectId: 'project-malformed');
      final loaded = await storage.load(projectId: 'project-malformed');

      final entries = loaded!['entries'] as List<Object?>;
      expect(entries, hasLength(2));
      expect((entries[0] as Map<String, Object?>)['mode'], '改写');
      expect((entries[1] as Map<String, Object?>)['mode'], '续写');
    });

    test('save handles entries with missing or invalid fields', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      final data = <String, Object?>{
        'entries': [
          <String, Object?>{}, // all fields missing
          {'mode': '只有mode'}, // sequence and prompt missing
          {'sequence': 'not-a-number', 'mode': '续写', 'prompt': '数字异常'},
        ],
      };

      await storage.save(data, projectId: 'project-partial');
      final loaded = await storage.load(projectId: 'project-partial');

      final entries = loaded!['entries'] as List<Object?>;
      expect(entries, hasLength(3));

      final first = entries[0] as Map<String, Object?>;
      expect(first['sequence'], 0); // fallback
      expect(first['mode'], '');
      expect(first['prompt'], '');

      final second = entries[1] as Map<String, Object?>;
      expect(second['mode'], '只有mode');
      expect(second['prompt'], '');

      final third = entries[2] as Map<String, Object?>;
      expect(third['sequence'], 0); // int.tryParse fails → 0
      expect(third['mode'], '续写');
    });

    test('multiple storage instances share the same database', () async {
      final writer = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await writer.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': '跨实例数据'},
          ],
        },
        projectId: 'project-shared',
      );

      final reader = SqliteAppAiHistoryStorage(dbPath: dbPath);
      final loaded = await reader.load(projectId: 'project-shared');

      expect(loaded, isNotNull);
      final entries = loaded!['entries'] as List<Object?>;
      expect(entries, hasLength(1));
      expect((entries.first as Map<String, Object?>)['prompt'], '跨实例数据');
    });

    test('returned data is a defensive copy', () async {
      final storage = SqliteAppAiHistoryStorage(dbPath: dbPath);

      await storage.save(
        {
          'entries': [
            {'sequence': 1, 'mode': '改写', 'prompt': '原始'},
          ],
        },
        projectId: 'project-clone',
      );

      final first = await storage.load(projectId: 'project-clone');
      (first!['entries'] as List<Object?>).clear();

      final second = await storage.load(projectId: 'project-clone');
      expect(second, isNotNull);
      expect(second!['entries'] as List<Object?>, hasLength(1));
    });
  });
}
