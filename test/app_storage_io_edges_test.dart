import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage_io.dart';
import 'package:novel_writer/app/state/app_settings_storage_io.dart';
import 'package:novel_writer/app/state/app_simulation_storage_io.dart';
import 'package:novel_writer/app/state/app_version_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';

void main() {
  group('sqlite and file storage edge coverage', () {
    test(
      'file settings storage returns null when file does not exist',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_settings_storage_missing_file_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final storage = FileAppSettingsStorage(
          file: File('${directory.path}/settings.json'),
        );

        expect(await storage.load(), isNull);
        expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.none);
        expect(storage.lastLoadDetail, isNull);
      },
    );

    test(
      'sqlite draft storage clears single project and migrates legacy rows',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_draft_storage_edges_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final dbPath = '${directory.path}/authoring.db';
        final storage = SqliteAppDraftStorage(dbPath: dbPath);
        await storage.save({'text': '项目 A 草稿'}, projectId: 'project-a');
        await storage.save({'text': '项目 B 草稿'}, projectId: 'project-b');

        await storage.clear(projectId: 'project-a');
        expect(await storage.load(projectId: 'project-a'), isNull);
        expect(await storage.load(projectId: 'project-b'), {'text': '项目 B 草稿'});

        await storage.clear();
        expect(await storage.load(projectId: 'project-b'), isNull);

        final legacyDbPath = '${directory.path}/legacy-draft.db';
        final legacyDb = sqlite3.open(legacyDbPath);
        legacyDb.execute('''
        CREATE TABLE draft_documents (
          text_body TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
        ''');
        legacyDb.execute('''
        INSERT INTO draft_documents (text_body, updated_at_ms)
        VALUES ('旧版草稿', 1)
        ''');
        legacyDb.dispose();

        final migratedStorage = SqliteAppDraftStorage(dbPath: legacyDbPath);
        expect(await migratedStorage.load(projectId: 'project-yuechao'), {
          'text': '旧版草稿',
        });
        expect(await migratedStorage.load(projectId: 'project-other'), isNull);
      },
    );

    test(
      'sqlite version storage clears single project and migrates legacy rows',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_version_storage_edges_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final dbPath = '${directory.path}/authoring.db';
        final storage = SqliteAppVersionStorage(dbPath: dbPath);
        await storage.save({
          'entries': [
            {'label': 'A1', 'content': '项目 A 版本'},
          ],
        }, projectId: 'project-a');
        await storage.save({
          'entries': [
            {'label': 'B1', 'content': '项目 B 版本'},
          ],
        }, projectId: 'project-b');

        await storage.clear(projectId: 'project-a');
        expect(await storage.load(projectId: 'project-a'), isNull);
        expect(await storage.load(projectId: 'project-b'), {
          'entries': [
            {'label': 'B1', 'content': '项目 B 版本'},
          ],
        });

        await storage.clear();
        expect(await storage.load(projectId: 'project-b'), isNull);

        final legacyDbPath = '${directory.path}/legacy-version.db';
        final legacyDb = sqlite3.open(legacyDbPath);
        legacyDb.execute('''
        CREATE TABLE version_entries (
          sequence_no INTEGER NOT NULL,
          label TEXT NOT NULL,
          content TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
        ''');
        legacyDb.execute('''
        INSERT INTO version_entries (sequence_no, label, content, updated_at_ms)
        VALUES (0, '旧版', '旧版内容', 1)
        ''');
        legacyDb.dispose();

        final migratedStorage = SqliteAppVersionStorage(dbPath: legacyDbPath);
        expect(await migratedStorage.load(projectId: 'project-yuechao'), {
          'entries': [
            {'label': '旧版', 'content': '旧版内容'},
          ],
        });
        expect(await migratedStorage.load(projectId: 'project-other'), isNull);
      },
    );

    test('sqlite workspace storage clears persisted payloads', () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_workspace_storage_clear_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final storage = SqliteAppWorkspaceStorage(
        dbPath: '${directory.path}/workspace.db',
      );
      await storage.save({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-1',
            'title': '项目 A',
            'genre': '悬疑',
            'summary': '摘要',
            'recentLocation': '第一章',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': const <String, Object?>{},
        'scenesByProject': const <String, Object?>{},
        'worldNodesByProject': const <String, Object?>{},
        'auditIssuesByProject': const <String, Object?>{},
        'projectStyles': const <String, Object?>{},
        'projectAuditStates': const <String, Object?>{},
        'projectTransferState': 'ready',
        'currentProjectId': 'project-a',
      });

      expect(await storage.load(), isNotNull);
      await storage.clear();
      expect(await storage.load(), isNull);
    });

    test(
      'sqlite workspace storage migrates legacy project schema, scoped tables, and project preferences',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_workspace_storage_legacy_migration_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final dbPath = '${directory.path}/workspace-legacy.db';
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
        database.execute('''
        INSERT INTO workspace_projects (scope_key, position_no, title, genre, summary, recent_location)
        VALUES
          ('workspace-default', 0, '旧项目一', '悬疑', '旧摘要一', '第 3 章 / 场景 05 · 仓库门外'),
          ('workspace-default', 3, '旧项目四', '幻想', '旧摘要四', '终章 / 尾声')
        ''');
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
        database.execute('''
        INSERT INTO workspace_characters (scope_key, position_no, name, role, note, need_text, summary)
        VALUES ('workspace-default', 0, '旧角色', '调查者', '旧备注', '旧需求', '旧角色摘要')
        ''');
        database.execute('''
        CREATE TABLE workspace_scenes (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          id TEXT NOT NULL,
          chapter_label TEXT NOT NULL,
          title TEXT NOT NULL,
          summary TEXT NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
        ''');
        database.execute('''
        INSERT INTO workspace_scenes (scope_key, position_no, id, chapter_label, title, summary)
        VALUES ('workspace-default', 0, 'legacy-scene', '第 1 章', '旧场景', '旧场景摘要')
        ''');
        database.execute('''
        CREATE TABLE workspace_world_nodes (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          title TEXT NOT NULL,
          location TEXT NOT NULL,
          type TEXT NOT NULL,
          detail TEXT NOT NULL,
          summary TEXT NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
        ''');
        database.execute('''
        INSERT INTO workspace_world_nodes (scope_key, position_no, title, location, type, detail, summary)
        VALUES ('workspace-default', 0, '旧节点', '旧地点', '设定', '旧细节', '旧节点摘要')
        ''');
        database.execute('''
        CREATE TABLE workspace_audit_issues (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          title TEXT NOT NULL,
          evidence TEXT NOT NULL,
          target TEXT NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
        ''');
        database.execute('''
        INSERT INTO workspace_audit_issues (scope_key, position_no, title, evidence, target)
        VALUES ('workspace-default', 0, '旧问题', '旧证据', '旧目标')
        ''');
        database.execute('''
        CREATE TABLE workspace_preferences (
          scope_key TEXT NOT NULL,
          preference_key TEXT NOT NULL,
          preference_value TEXT NOT NULL,
          PRIMARY KEY (scope_key, preference_key)
        )
        ''');
        database.execute('''
        INSERT INTO workspace_preferences (scope_key, preference_key, preference_value)
        VALUES
          ('workspace-default', 'style_input_mode', 'json'),
          ('workspace-default', 'style_intensity', '3'),
          ('workspace-default', 'style_binding_feedback', '旧绑定反馈'),
          ('workspace-default', 'selected_audit_issue_index', '1'),
          ('workspace-default', 'audit_action_feedback', '旧审计反馈'),
          ('workspace-default', 'current_project_id', 'project-yuechao'),
          ('workspace-default', 'project_transfer_state', 'overwriteSuccess')
        ''');
        database.dispose();

        final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
        final restored = await storage.load();

        expect(restored, isNotNull);
        final projects = restored!['projects'] as List<Object?>;
        expect(projects, hasLength(2));
        expect(
          (projects.first as Map<Object?, Object?>)['id'],
          'project-yuechao',
        );
        expect(
          (projects.first as Map<Object?, Object?>)['sceneId'],
          'scene-05-migrated-0',
        );
        expect(
          (projects.last as Map<Object?, Object?>)['id'],
          'project-migrated-3',
        );
        expect(
          (projects.last as Map<Object?, Object?>)['sceneId'],
          'scene-01-migrated-3',
        );

        final projectStyles =
            restored['projectStyles'] as Map<Object?, Object?>;
        expect(projectStyles['project-yuechao'], {
          'styleInputMode': 'json',
          'styleIntensity': '3',
          'styleBindingFeedback': '旧绑定反馈',
        });
        expect(projectStyles['project-migrated-3'], {
          'styleInputMode': 'json',
          'styleIntensity': '3',
          'styleBindingFeedback': '旧绑定反馈',
        });

        final projectAuditStates =
            restored['projectAuditStates'] as Map<Object?, Object?>;
        expect(projectAuditStates['project-yuechao'], {
          'selectedAuditIssueIndex': '1',
          'auditActionFeedback': '旧审计反馈',
        });
        expect(projectAuditStates['project-migrated-3'], {
          'selectedAuditIssueIndex': '1',
          'auditActionFeedback': '旧审计反馈',
        });
        expect(restored['currentProjectId'], 'project-yuechao');
        expect(restored['projectTransferState'], 'overwriteSuccess');

        final migratedDb = sqlite3.open(dbPath);
        addTearDown(migratedDb.dispose);
        final characterProjectIds = migratedDb
            .select(
              'SELECT project_id FROM workspace_characters WHERE scope_key = ? ORDER BY project_id ASC',
              ['workspace-default'],
            )
            .map((row) => row['project_id'] as String)
            .toList(growable: false);
        expect(characterProjectIds, ['project-migrated-3', 'project-yuechao']);

        final scopedPreferenceCount =
            migratedDb
                    .select(
                      '''
          SELECT COUNT(*) AS c
          FROM workspace_project_preferences
          WHERE scope_key = ?
          ''',
                      ['workspace-default'],
                    )
                    .first['c']
                as int;
        expect(scopedPreferenceCount, 10);

        final legacyPreferenceCount =
            migratedDb
                    .select(
                      '''
          SELECT COUNT(*) AS c
          FROM workspace_preferences
          WHERE scope_key = ?
            AND preference_key IN (
              'style_input_mode',
              'style_intensity',
              'style_binding_feedback',
              'selected_audit_issue_index',
              'audit_action_feedback'
            )
          ''',
                      ['workspace-default'],
                    )
                    .first['c']
                as int;
        expect(legacyPreferenceCount, 0);
      },
    );

    test(
      'sqlite workspace storage save ignores malformed nested rows and unknown preference keys',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_workspace_storage_malformed_rows_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final storage = SqliteAppWorkspaceStorage(
          dbPath: '${directory.path}/workspace.db',
        );
        await storage.save({
          'projects': [
            'bad-project-row',
            {
              'id': 'project-a',
              'sceneId': 'scene-a',
              'title': '项目 A',
              'genre': '悬疑',
              'summary': '摘要 A',
              'recentLocation': '第一章',
              'lastOpenedAtMs': 11,
            },
            {
              'id': 'project-b',
              'sceneId': 'scene-b',
              'title': '项目 B',
              'genre': '幻想',
              'summary': '摘要 B',
              'recentLocation': '第二章',
              'lastOpenedAtMs': 22,
            },
          ],
          'charactersByProject': {
            'project-a': [
              1,
              {
                'name': '角色 A',
                'role': '主角',
                'note': '备注',
                'need': '需求',
                'summary': '角色摘要',
              },
            ],
            'project-b': 'invalid-character-list',
          },
          'scenesByProject': {
            'project-a': [
              1,
              {
                'id': 'scene-a',
                'chapterLabel': '第 1 章',
                'title': '场景 A',
                'summary': '场景摘要',
              },
            ],
          },
          'worldNodesByProject': {
            'project-a': [
              1,
              {
                'title': '节点 A',
                'location': '地点 A',
                'type': '设定',
                'detail': '细节 A',
                'summary': '节点摘要',
              },
            ],
          },
          'auditIssuesByProject': {
            'project-a': [
              1,
              {'title': '问题 A', 'evidence': '证据 A', 'target': '目标 A'},
            ],
          },
          'projectStyles': {
            'project-a': 'invalid-style-map',
            'project-b': {
              'styleInputMode': 'json',
              'unknownPreference': 'ignored',
            },
          },
          'projectAuditStates': {
            'project-a': {
              'selectedAuditIssueIndex': 1,
              'unknownAuditKey': 'ignored',
            },
            'project-b': 'invalid-audit-map',
          },
          'projectTransferState': 'ready',
          'currentProjectId': 'project-b',
        });

        final restored = await storage.load();

        expect(restored, isNotNull);
        final projects = restored!['projects'] as List<Object?>;
        expect(projects, hasLength(2));
        expect((projects.first as Map<Object?, Object?>)['id'], 'project-a');
        expect((projects.last as Map<Object?, Object?>)['id'], 'project-b');

        final characters =
            restored['charactersByProject'] as Map<Object?, Object?>;
        expect(characters['project-a'], [
          {
            'name': '角色 A',
            'role': '主角',
            'note': '备注',
            'need': '需求',
            'summary': '角色摘要',
          },
        ]);
        expect(characters.containsKey('project-b'), isFalse);

        final projectStyles =
            restored['projectStyles'] as Map<Object?, Object?>;
        expect(projectStyles.containsKey('project-a'), isFalse);
        expect(projectStyles['project-b'], {'styleInputMode': 'json'});

        final projectAuditStates =
            restored['projectAuditStates'] as Map<Object?, Object?>;
        expect(projectAuditStates['project-a'], {
          'selectedAuditIssueIndex': '1',
        });
        expect(projectAuditStates.containsKey('project-b'), isFalse);
        expect(restored['currentProjectId'], 'project-b');
        expect(restored['projectTransferState'], 'ready');
      },
    );

    test(
      'sqlite workspace storage rolls back the transaction when the current schema is broken',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_workspace_storage_rollback_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final dbPath = '${directory.path}/workspace-broken.db';
        final database = sqlite3.open(dbPath);
        database.execute('''
        CREATE TABLE workspace_projects (
          scope_key TEXT NOT NULL,
          position_no INTEGER NOT NULL,
          id TEXT NOT NULL,
          scene_id TEXT NOT NULL,
          title TEXT NOT NULL,
          summary TEXT NOT NULL,
          recent_location TEXT NOT NULL,
          last_opened_at_ms INTEGER NOT NULL,
          PRIMARY KEY (scope_key, position_no)
        )
        ''');
        database.dispose();

        final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
        expect(
          () => storage.save({
            'projects': [
              {
                'id': 'project-a',
                'sceneId': 'scene-a',
                'title': '项目 A',
                'genre': '悬疑',
                'summary': '摘要 A',
                'recentLocation': '第一章',
                'lastOpenedAtMs': 1,
              },
            ],
            'charactersByProject': const <String, Object?>{},
            'scenesByProject': const <String, Object?>{},
            'worldNodesByProject': const <String, Object?>{},
            'auditIssuesByProject': const <String, Object?>{},
            'projectStyles': const <String, Object?>{},
            'projectAuditStates': const <String, Object?>{},
            'projectTransferState': 'ready',
            'currentProjectId': 'project-a',
          }),
          throwsA(isA<SqliteException>()),
        );

        final failedDb = sqlite3.open(dbPath);
        addTearDown(failedDb.dispose);
        final rowCount =
            failedDb
                    .select('SELECT COUNT(*) AS c FROM workspace_projects')
                    .first['c']
                as int;
        expect(rowCount, 0);
      },
    );

    test(
      'sqlite simulation storage clears scopes and migrates valid legacy state',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'novel_writer_simulation_storage_edges_test',
        );
        addTearDown(() async {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });

        final dbPath = '${directory.path}/simulation.db';
        final storage = SqliteAppSimulationStorage(dbPath: dbPath);
        await storage.save({
          'template': 'completed',
          'promptOverrides': {'liuXi': '项目 A 提示'},
          'extraMessages': const [],
        }, projectId: 'project-a');
        await storage.save({
          'template': 'failed',
          'promptOverrides': {'liuXi': '项目 B 提示'},
          'extraMessages': const [],
        }, projectId: 'project-b');

        await storage.clear(projectId: 'project-a');
        expect(await storage.load(projectId: 'project-a'), isNull);
        expect(await storage.load(projectId: 'project-b'), {
          'template': 'failed',
          'promptOverrides': {'liuXi': '项目 B 提示'},
          'extraMessages': const [],
        });

        await storage.clear();
        expect(await storage.load(projectId: 'project-b'), isNull);

        final legacyDbPath = '${directory.path}/legacy-simulation.db';
        final legacyDb = sqlite3.open(legacyDbPath);
        legacyDb.execute('''
        CREATE TABLE simulation_state (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          payload_json TEXT NOT NULL,
          updated_at_ms INTEGER NOT NULL
        )
        ''');
        legacyDb.execute('''
        INSERT INTO simulation_state (id, payload_json, updated_at_ms)
        VALUES (
          1,
          '{"template":"completed","promptOverrides":{"liuXi":"旧提示"},"extraMessages":[{"sender":"导演","title":"第 01 回合","body":"旧消息","tone":"calm","alignEnd":true}]}',
          1
        )
        ''');
        legacyDb.dispose();

        final migratedStorage = SqliteAppSimulationStorage(
          dbPath: legacyDbPath,
        );
        expect(await migratedStorage.load(projectId: 'project-yuechao'), {
          'template': 'completed',
          'promptOverrides': {'liuXi': '旧提示'},
          'extraMessages': [
            {
              'sender': '导演',
              'title': '第 01 回合',
              'body': '旧消息',
              'tone': 'calm',
              'alignEnd': true,
              'kind': 'speech',
            },
          ],
        });

        final migratedDb = sqlite3.open(legacyDbPath);
        addTearDown(migratedDb.dispose);
        final legacyTables = migratedDb
            .select(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'simulation_state'",
            )
            .map((row) => row['name'] as String)
            .toList(growable: false);
        expect(legacyTables, isEmpty);
      },
    );
  });
}
