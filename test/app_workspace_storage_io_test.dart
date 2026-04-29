import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_workspace_storage_io.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_workspace_io_test',
    );
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Map<String, Object?> fullWorkspaceData() {
    return {
      'projects': [
        {
          'id': 'project-alpha',
          'sceneId': 'scene-01',
          'title': '月潮回声',
          'genre': '悬疑 / 8.7 万字',
          'summary': '证人房间的对峙停在最危险的地方。',
          'recentLocation': '第 3 章 / 场景 05 · 证人房间对峙',
          'lastOpenedAtMs': 1700000000000,
        },
        {
          'id': 'project-beta',
          'sceneId': 'scene-12',
          'title': '盐港档案',
          'genre': '都市现实 / 4.3 万字',
          'summary': '仓库夜谈刚写到一半。',
          'recentLocation': '第 1 卷 / 场景 12 · 仓库夜谈',
          'lastOpenedAtMs': 1699900000000,
        },
      ],
      'charactersByProject': {
        'project-alpha': [
          {
            'name': '柳溪',
            'role': '调查记者',
            'note': '失去搭档后的控制欲',
            'need': '承认她也会判断失误',
            'summary': '冷静、急迫、对线索高度敏感。',
          },
        ],
        'project-beta': [
          {
            'name': '岳人',
            'role': '线人',
            'note': '把自己放进最危险的交汇点',
            'need': '在保命和忠诚之间做一次明确选择',
            'summary': '说话更快，信息密度高。',
          },
        ],
      },
      'scenesByProject': {
        'project-alpha': [
          {
            'id': 'scene-01',
            'chapterLabel': '第 3 章 / 场景 05',
            'title': '证人房间对峙',
            'summary': '证人与柳溪的对峙停在最危险的地方。',
          },
        ],
        'project-beta': [
          {
            'id': 'scene-12',
            'chapterLabel': '第 1 卷 / 场景 12',
            'title': '仓库夜谈',
            'summary': '仓库里的夜谈把第一层口供缓慢拆开。',
          },
        ],
      },
      'worldNodesByProject': {
        'project-alpha': [
          {
            'title': '旧港规则',
            'location': '旧港城',
            'type': '规则',
            'detail': '风暴前两小时内，外来船只不得靠泊。',
            'summary': '进入风暴预警后的仓库，出入口需要重新验证。',
          },
        ],
      },
      'auditIssuesByProject': {
        'project-alpha': [
          {
            'title': '角色动机冲突',
            'evidence': '角色上一场景处于防御姿态，当前段落突然主动进攻。',
            'target': '场景 05',
          },
          {
            'title': '时间线跳跃',
            'evidence': '同一小时内出现了两次不可能同时成立的行动记录。',
            'target': '场景 06',
          },
        ],
      },
      'projectStyles': {
        'project-alpha': {
          'styleInputMode': 'questionnaire',
          'styleIntensity': '2',
          'styleBindingFeedback': '已将风格绑定到项目。',
        },
      },
      'projectAuditStates': {
        'project-alpha': {
          'selectedAuditIssueIndex': '1',
          'auditActionFeedback': '已标记为已处理。',
        },
      },
      'projectTransferState': 'exportSuccess',
      'currentProjectId': 'project-alpha',
    };
  }

  group('SqliteAppWorkspaceStorage', () {
    test('load returns null when no data exists', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      final result = await storage.load();
      expect(result, isNull);
    });

    test('save and load round-trip preserves all workspace data', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final data = fullWorkspaceData();

      await storage.save(data);
      final loaded = await storage.load();

      expect(loaded, isNotNull);

      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 2);
      final firstProject = projects[0] as Map<String, Object?>;
      expect(firstProject['id'], 'project-alpha');
      expect(firstProject['sceneId'], 'scene-01');
      expect(firstProject['title'], '月潮回声');
      expect(firstProject['genre'], '悬疑 / 8.7 万字');
      expect(firstProject['summary'], '证人房间的对峙停在最危险的地方。');
      expect(
        firstProject['recentLocation'],
        '第 3 章 / 场景 05 · 证人房间对峙',
      );
      expect(firstProject['lastOpenedAtMs'], 1700000000000);

      final secondProject = projects[1] as Map<String, Object?>;
      expect(secondProject['id'], 'project-beta');
      expect(secondProject['title'], '盐港档案');

      final characters =
          loaded['charactersByProject'] as Map<String, Object?>;
      final alphaChars =
          (characters['project-alpha'] as List<Object?>).cast<Map<String, Object?>>();
      expect(alphaChars.length, 1);
      expect(alphaChars.first['name'], '柳溪');
      expect(alphaChars.first['role'], '调查记者');
      expect(alphaChars.first['note'], '失去搭档后的控制欲');
      expect(alphaChars.first['need'], '承认她也会判断失误');
      expect(alphaChars.first['summary'], '冷静、急迫、对线索高度敏感。');

      final betaChars =
          (characters['project-beta'] as List<Object?>).cast<Map<String, Object?>>();
      expect(betaChars.length, 1);
      expect(betaChars.first['name'], '岳人');

      final scenes = loaded['scenesByProject'] as Map<String, Object?>;
      final alphaScenes =
          (scenes['project-alpha'] as List<Object?>).cast<Map<String, Object?>>();
      expect(alphaScenes.length, 1);
      expect(alphaScenes.first['id'], 'scene-01');
      expect(alphaScenes.first['chapterLabel'], '第 3 章 / 场景 05');
      expect(alphaScenes.first['title'], '证人房间对峙');
      expect(alphaScenes.first['summary'], '证人与柳溪的对峙停在最危险的地方。');

      final worldNodes =
          loaded['worldNodesByProject'] as Map<String, Object?>;
      final alphaNodes =
          (worldNodes['project-alpha'] as List<Object?>).cast<Map<String, Object?>>();
      expect(alphaNodes.length, 1);
      expect(alphaNodes.first['title'], '旧港规则');
      expect(alphaNodes.first['location'], '旧港城');
      expect(alphaNodes.first['type'], '规则');
      expect(alphaNodes.first['detail'], '风暴前两小时内，外来船只不得靠泊。');
      expect(alphaNodes.first['summary'], '进入风暴预警后的仓库，出入口需要重新验证。');

      final auditIssues =
          loaded['auditIssuesByProject'] as Map<String, Object?>;
      final alphaIssues =
          (auditIssues['project-alpha'] as List<Object?>).cast<Map<String, Object?>>();
      expect(alphaIssues.length, 2);
      expect(alphaIssues[0]['title'], '角色动机冲突');
      expect(alphaIssues[0]['evidence'], '角色上一场景处于防御姿态，当前段落突然主动进攻。');
      expect(alphaIssues[0]['target'], '场景 05');
      expect(alphaIssues[1]['title'], '时间线跳跃');

      final styles = loaded['projectStyles'] as Map<String, Object?>;
      final alphaStyle = styles['project-alpha'] as Map<String, Object?>;
      expect(alphaStyle['styleInputMode'], 'questionnaire');
      expect(alphaStyle['styleIntensity'], '2');
      expect(alphaStyle['styleBindingFeedback'], '已将风格绑定到项目。');

      final auditStates = loaded['projectAuditStates'] as Map<String, Object?>;
      final alphaAuditState = auditStates['project-alpha'] as Map<String, Object?>;
      expect(alphaAuditState['selectedAuditIssueIndex'], '1');
      expect(alphaAuditState['auditActionFeedback'], '已标记为已处理。');

      expect(loaded['projectTransferState'], 'exportSuccess');
      expect(loaded['currentProjectId'], 'project-alpha');
    });

    test('save overwrites previous workspace data', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-old',
            'sceneId': 'scene-old',
            'title': '旧项目',
            'genre': '旧类型',
            'summary': '旧摘要',
            'recentLocation': '旧位置',
            'lastOpenedAtMs': 1000,
          },
        ],
        'charactersByProject': {
          'project-old': [
            {'name': '旧角色', 'role': '旧', 'note': '旧', 'need': '旧', 'summary': '旧'},
          ],
        },
      });

      await storage.save({
        'projects': [
          {
            'id': 'project-new',
            'sceneId': 'scene-new',
            'title': '新项目',
            'genre': '新类型',
            'summary': '新摘要',
            'recentLocation': '新位置',
            'lastOpenedAtMs': 2000,
          },
        ],
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 1);
      expect((projects.first as Map)['id'], 'project-new');
      expect((projects.first as Map)['title'], '新项目');

      final characters = loaded['charactersByProject'] as Map<String, Object?>;
      expect(characters['project-old'], isNull);
      expect(characters['project-new'], isNull);
    });

    test('clear removes all workspace data', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save(fullWorkspaceData());
      await storage.clear();

      final result = await storage.load();
      expect(result, isNull);
    });

    test('multiple storage instances share the same database', () async {
      final writer = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await writer.save({
        'projects': [
          {
            'id': 'project-shared',
            'sceneId': 'scene-shared',
            'title': '共享项目',
            'genre': '测试',
            'summary': '测试跨实例共享',
            'recentLocation': '第 1 章 / 场景 01 · 共享场景',
            'lastOpenedAtMs': 1700000000000,
          },
        ],
        'charactersByProject': {
          'project-shared': [
            {
              'name': '共享角色',
              'role': '主角',
              'note': '备注',
              'need': '需求',
              'summary': '摘要',
            },
          ],
        },
        'currentProjectId': 'project-shared',
      });

      final reader = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final loaded = await reader.load();

      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 1);
      expect((projects.first as Map)['id'], 'project-shared');
      expect(loaded['currentProjectId'], 'project-shared');
    });

    test('database has correct schema with all required tables', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-schema',
            'sceneId': 'scene-schema',
            'title': 'Schema',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
      });

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);

      final tableNames = database
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();

      expect(tableNames, containsAll([
        'workspace_projects',
        'workspace_characters',
        'workspace_scenes',
        'workspace_world_nodes',
        'workspace_audit_issues',
        'workspace_preferences',
        'workspace_project_preferences',
      ]));

      final projectColumns = database
          .select('PRAGMA table_info(workspace_projects)')
          .map((row) => row['name'] as String)
          .toList();
      expect(
        projectColumns,
        containsAll([
          'scope_key',
          'position_no',
          'id',
          'scene_id',
          'title',
          'genre',
          'summary',
          'recent_location',
          'last_opened_at_ms',
        ]),
      );

      final charColumns = database
          .select('PRAGMA table_info(workspace_characters)')
          .map((row) => row['name'] as String)
          .toList();
      expect(
        charColumns,
        containsAll(['scope_key', 'project_id', 'position_no', 'name', 'role', 'note', 'need_text', 'summary']),
      );
    });

    test('save with empty data results in load with empty collections', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({});
      final result = await storage.load();
      expect(result, isNotNull);
      expect(result!['projects'] as List, isEmpty);
      expect(result['charactersByProject'] as Map, isEmpty);
      expect(result['currentProjectId'], '');
    });

    test('save with null list values results in load with empty collections', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': null,
        'charactersByProject': null,
        'scenesByProject': null,
        'worldNodesByProject': null,
        'auditIssuesByProject': null,
        'projectStyles': null,
        'projectAuditStates': null,
      });
      final result = await storage.load();
      expect(result, isNotNull);
      expect(result!['projects'] as List, isEmpty);
    });

    test('save handles missing keys gracefully', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save(<String, Object?>{});
      final result = await storage.load();
      expect(result, isNotNull);
      expect(result!['projects'] as List, isEmpty);
    });

    test('save preserves unicode and emoji content', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-unicode',
            'sceneId': 'scene-unicode',
            'title': '你好世界 🌍 日本語テスト',
            'genre': 'émoji àccënts',
            'summary': 'Спокойствие',
            'recentLocation': '第 1 章 / 场景 01 · 🔥',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': {
          'project-unicode': [
            {
              'name': '角色 🎭',
              'role': '主角',
              'note': '备注 émoji',
              'need': '需求 àccënts',
              'summary': '摘要 🌸',
            },
          ],
        },
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      final project = projects.first as Map<String, Object?>;
      expect(project['title'], '你好世界 🌍 日本語テスト');
      expect(project['genre'], 'émoji àccënts');
      expect(project['summary'], 'Спокойствие');

      final characters = loaded['charactersByProject'] as Map<String, Object?>;
      final chars =
          (characters['project-unicode'] as List).cast<Map<String, Object?>>();
      expect(chars.first['name'], '角色 🎭');
      expect(chars.first['summary'], '摘要 🌸');
    });

    test('save handles non-string values by coercing to string', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 12345,
            'sceneId': true,
            'title': 3.14,
            'genre': null,
            'summary': null,
            'recentLocation': null,
            'lastOpenedAtMs': 'not-a-number',
          },
        ],
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final project =
          (loaded!['projects'] as List).first as Map<String, Object?>;
      expect(project['id'], '12345');
      expect(project['sceneId'], 'true');
      expect(project['title'], '3.14');
      expect(project['genre'], '');
      expect(project['lastOpenedAtMs'], 0);
    });

    test('project characters preserve insertion order', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-order',
            'sceneId': 'scene-01',
            'title': '排序测试',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': {
          'project-order': [
            {'name': '第一', 'role': 'r', 'note': 'n', 'need': 'ne', 'summary': 's'},
            {'name': '第二', 'role': 'r', 'note': 'n', 'need': 'ne', 'summary': 's'},
            {'name': '第三', 'role': 'r', 'note': 'n', 'need': 'ne', 'summary': 's'},
          ],
        },
      });

      final loaded = await storage.load();
      final characters =
          (loaded!['charactersByProject'] as Map)['project-order'] as List;
      final names = characters.map((c) => (c as Map)['name']).toList();
      expect(names, ['第一', '第二', '第三']);
    });

    test('project scenes preserve insertion order', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-scene-order',
            'sceneId': 'scene-01',
            'title': '场景排序',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'scenesByProject': {
          'project-scene-order': [
            {'id': 'scene-01', 'chapterLabel': '第 1 章', 'title': '场景一', 'summary': 's1'},
            {'id': 'scene-02', 'chapterLabel': '第 2 章', 'title': '场景二', 'summary': 's2'},
            {'id': 'scene-03', 'chapterLabel': '第 3 章', 'title': '场景三', 'summary': 's3'},
          ],
        },
      });

      final loaded = await storage.load();
      final scenes =
          (loaded!['scenesByProject'] as Map)['project-scene-order'] as List;
      final titles = scenes.map((s) => (s as Map)['title']).toList();
      expect(titles, ['场景一', '场景二', '场景三']);
    });

    test('save skips non-map entries in project list', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          'invalid string',
          {
            'id': 'project-valid',
            'sceneId': 'scene-valid',
            'title': '有效项目',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
          42,
          null,
        ],
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 1);
      expect((projects.first as Map)['id'], 'project-valid');
    });

    test('save skips non-map entries in character list', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-mixed',
            'sceneId': 'scene-01',
            'title': '混合数据',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': {
          'project-mixed': [
            'invalid string',
            {
              'name': '有效角色',
              'role': 'test',
              'note': 'test',
              'need': 'test',
              'summary': 'test',
            },
            42,
            null,
          ],
        },
      });

      final loaded = await storage.load();
      final characters =
          (loaded!['charactersByProject'] as Map)['project-mixed'] as List;
      expect(characters.length, 1);
      expect((characters.first as Map)['name'], '有效角色');
    });

    test('preferences are stored and loaded correctly', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-pref',
            'sceneId': 'scene-01',
            'title': '偏好测试',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'projectTransferState': 'importSuccess',
        'currentProjectId': 'project-pref',
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['projectTransferState'], 'importSuccess');
      expect(loaded['currentProjectId'], 'project-pref');
    });

    test('preferences with empty values default to empty string', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-empty-pref',
            'sceneId': 'scene-01',
            'title': '空偏好',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'projectTransferState': null,
        'currentProjectId': null,
      });

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!['projectTransferState'], '');
      expect(loaded['currentProjectId'], '');
    });

    test('project style preferences round-trip correctly', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-style',
            'sceneId': 'scene-01',
            'title': '风格测试',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'projectStyles': {
          'project-style': {
            'styleInputMode': 'json',
            'styleIntensity': '3',
            'styleBindingFeedback': '已绑定高强度风格。',
          },
        },
      });

      final loaded = await storage.load();
      final styles = loaded!['projectStyles'] as Map<String, Object?>;
      final style = styles['project-style'] as Map<String, Object?>;
      expect(style['styleInputMode'], 'json');
      expect(style['styleIntensity'], '3');
      expect(style['styleBindingFeedback'], '已绑定高强度风格。');
    });

    test('project audit state preferences round-trip correctly', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-audit',
            'sceneId': 'scene-01',
            'title': '审计测试',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'projectAuditStates': {
          'project-audit': {
            'selectedAuditIssueIndex': '2',
            'auditActionFeedback': '已标记为已处理，可在下一轮审计中复核。',
          },
        },
      });

      final loaded = await storage.load();
      final auditStates = loaded!['projectAuditStates'] as Map<String, Object?>;
      final auditState = auditStates['project-audit'] as Map<String, Object?>;
      expect(auditState['selectedAuditIssueIndex'], '2');
      expect(auditState['auditActionFeedback'], '已标记为已处理，可在下一轮审计中复核。');
    });

    test('clear then load returns null', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save(fullWorkspaceData());
      expect(await storage.load(), isNotNull);

      await storage.clear();
      expect(await storage.load(), isNull);
    });

    test('clear on empty database does not throw', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.clear();
      expect(await storage.load(), isNull);
    });

    test('legacy project schema migration preserves existing data', () async {
      final database = sqlite3.open(dbPath);
      database.execute('''
        CREATE TABLE workspace_projects (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          title TEXT NOT NULL,
          genre TEXT NOT NULL,
          summary TEXT NOT NULL,
          recent_location TEXT NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
      ''');
      database.execute(
        '''
        INSERT INTO workspace_projects (
          scope_key, position_no, title, genre, summary, recent_location
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
        [
          'workspace-default',
          0,
          '遗留月潮',
          '悬疑',
          '遗留摘要',
          '第 3 章 / 场景 05 · 遗留场景',
        ],
      );
      database.dispose();

      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 1);
      final project = projects.first as Map<String, Object?>;
      expect(project['title'], '遗留月潮');
      expect(project['genre'], '悬疑');
      expect(project['id'], 'project-yuechao');
      expect(project['lastOpenedAtMs'], greaterThan(0));
    });

    test('legacy scoped table migration assigns rows to existing projects', () async {
      final database = sqlite3.open(dbPath);
      database.execute('''
        CREATE TABLE workspace_projects (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          id TEXT NOT NULL,
          scene_id TEXT NOT NULL,
          title TEXT NOT NULL,
          genre TEXT NOT NULL,
          summary TEXT NOT NULL,
          recent_location TEXT NOT NULL,
          last_opened_at_ms INTEGER NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
      ''');
      database.execute(
        '''
        INSERT INTO workspace_projects (
          scope_key, position_no, id, scene_id, title, genre, summary, recent_location, last_opened_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          'workspace-default', 0, 'project-yuechao', 'scene-05', '月潮', '悬疑', '摘要', '位置', 1,
        ],
      );
      database.execute('''
        CREATE TABLE workspace_characters (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          name TEXT NOT NULL,
          role TEXT NOT NULL,
          note TEXT NOT NULL,
          need_text TEXT NOT NULL,
          summary TEXT NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
      ''');
      database.execute(
        '''
        INSERT INTO workspace_characters (
          scope_key, position_no, name, role, note, need_text, summary
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
        ['workspace-default', 0, '遗留角色', '主角', '备注', '需求', '摘要'],
      );
      database.dispose();

      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      final characters =
          loaded!['charactersByProject'] as Map<String, Object?>;
      final migratedChars =
          (characters['project-yuechao'] as List).cast<Map<String, Object?>>();
      expect(migratedChars.length, 1);
      expect(migratedChars.first['name'], '遗留角色');
    });

    test('legacy project preferences migration moves scoped keys to project preferences', () async {
      final database = sqlite3.open(dbPath);
      database.execute('''
        CREATE TABLE workspace_projects (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          id TEXT NOT NULL,
          scene_id TEXT NOT NULL,
          title TEXT NOT NULL,
          genre TEXT NOT NULL,
          summary TEXT NOT NULL,
          recent_location TEXT NOT NULL,
          last_opened_at_ms INTEGER NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
      ''');
      database.execute(
        '''
        INSERT INTO workspace_projects (
          scope_key, position_no, id, scene_id, title, genre, summary, recent_location, last_opened_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
        [
          'workspace-default', 0, 'project-migrate', 'scene-01', '迁移', 'test', 'test', 'test', 1,
        ],
      );
      database.execute('''
        CREATE TABLE workspace_preferences (
          scope_key TEXT NOT NULL,
          preference_key TEXT NOT NULL,
          preference_value TEXT NOT NULL,
          PRIMARY KEY (scope_key, preference_key)
        )
      ''');
      database.execute(
        '''
        INSERT INTO workspace_preferences (
          scope_key, preference_key, preference_value
        ) VALUES (?, ?, ?)
      ''',
        ['workspace-default', 'style_input_mode', 'json'],
      );
      database.execute(
        '''
        INSERT INTO workspace_preferences (
          scope_key, preference_key, preference_value
        ) VALUES (?, ?, ?)
      ''',
        ['workspace-default', 'style_intensity', '3'],
      );
      database.execute(
        '''
        INSERT INTO workspace_preferences (
          scope_key, preference_key, preference_value
        ) VALUES (?, ?, ?)
      ''',
        ['workspace-default', 'current_project_id', 'project-migrate'],
      );
      database.dispose();

      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final loaded = await storage.load();

      expect(loaded, isNotNull);

      final styles = loaded!['projectStyles'] as Map<String, Object?>;
      final style = styles['project-migrate'] as Map<String, Object?>;
      expect(style['styleInputMode'], 'json');
      expect(style['styleIntensity'], '3');

      expect(loaded['currentProjectId'], 'project-migrate');
    });

    test('large number of projects round-trip correctly', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      final projects = List.generate(
        20,
        (i) => <String, Object?>{
          'id': 'project-bulk-$i',
          'sceneId': 'scene-bulk-$i',
          'title': '批量项目 $i',
          'genre': '类型 $i',
          'summary': '摘要 $i',
          'recentLocation': '位置 $i',
          'lastOpenedAtMs': 1700000000000 - i * 1000,
        },
      );

      await storage.save({'projects': projects});
      final loaded = await storage.load();

      expect(loaded, isNotNull);
      final loadedProjects = loaded!['projects'] as List<Object?>;
      expect(loadedProjects.length, 20);
    });

    test('load after repeated save cycles is consistent', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      for (var cycle = 0; cycle < 5; cycle++) {
        await storage.save({
          'projects': [
            {
              'id': 'project-cycle',
              'sceneId': 'scene-cycle',
              'title': '循环 $cycle',
              'genre': 'test',
              'summary': '摘要 $cycle',
              'recentLocation': '位置 $cycle',
              'lastOpenedAtMs': cycle,
            },
          ],
        });
      }

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final project =
          (loaded!['projects'] as List).first as Map<String, Object?>;
      expect(project['title'], '循环 4');
      expect(project['summary'], '摘要 4');
    });

    test('world nodes with multiple projects are isolated', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-01',
            'title': '项目A',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 2,
          },
          {
            'id': 'project-b',
            'sceneId': 'scene-02',
            'title': '项目B',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'worldNodesByProject': {
          'project-a': [
            {'title': '节点A1', 'location': '位置A', 'type': '规则', 'detail': '细节A', 'summary': '摘要A'},
          ],
          'project-b': [
            {'title': '节点B1', 'location': '位置B', 'type': '事件', 'detail': '细节B', 'summary': '摘要B'},
            {'title': '节点B2', 'location': '位置B2', 'type': '流程', 'detail': '细节B2', 'summary': '摘要B2'},
          ],
        },
      });

      final loaded = await storage.load();
      final worldNodes = loaded!['worldNodesByProject'] as Map<String, Object?>;

      final nodesA = (worldNodes['project-a'] as List).cast<Map<String, Object?>>();
      expect(nodesA.length, 1);
      expect(nodesA.first['title'], '节点A1');

      final nodesB = (worldNodes['project-b'] as List).cast<Map<String, Object?>>();
      expect(nodesB.length, 2);
      expect(nodesB[0]['title'], '节点B1');
      expect(nodesB[1]['title'], '节点B2');
    });

    test('audit issues with multiple projects are isolated', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-audit-a',
            'sceneId': 'scene-01',
            'title': '审计项目A',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 2,
          },
          {
            'id': 'project-audit-b',
            'sceneId': 'scene-02',
            'title': '审计项目B',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'auditIssuesByProject': {
          'project-audit-a': [
            {'title': '问题A', 'evidence': '证据A', 'target': '场景 01'},
          ],
          'project-audit-b': [
            {'title': '问题B', 'evidence': '证据B', 'target': '场景 02'},
            {'title': '问题B2', 'evidence': '证据B2', 'target': '场景 03'},
          ],
        },
      });

      final loaded = await storage.load();
      final issues = loaded!['auditIssuesByProject'] as Map<String, Object?>;

      final issuesA =
          (issues['project-audit-a'] as List).cast<Map<String, Object?>>();
      expect(issuesA.length, 1);
      expect(issuesA.first['title'], '问题A');

      final issuesB =
          (issues['project-audit-b'] as List).cast<Map<String, Object?>>();
      expect(issuesB.length, 2);
      expect(issuesB[0]['title'], '问题B');
      expect(issuesB[1]['title'], '问题B2');
    });

    test('unknown style preference keys are ignored on save', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);

      await storage.save({
        'projects': [
          {
            'id': 'project-unknown-style',
            'sceneId': 'scene-01',
            'title': '未知风格键',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
        'projectStyles': {
          'project-unknown-style': {
            'styleInputMode': 'questionnaire',
            'unknown_key': 'should be ignored',
          },
        },
      });

      final loaded = await storage.load();
      final styles = loaded!['projectStyles'] as Map<String, Object?>;
      final style = styles['project-unknown-style'] as Map<String, Object?>;
      expect(style['styleInputMode'], 'questionnaire');
      expect(style.containsKey('unknown_key'), isFalse);
    });
  });
}
