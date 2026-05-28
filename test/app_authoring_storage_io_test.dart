import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage_io.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/workbench/data/workbench_ai_controller.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_review_dialog.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_revision_helpers.dart';

class _MemoryEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}

class _FailingDraftStorage implements AppDraftStorage {
  @override
  Future<void> clear({String? projectId}) async {}

  @override
  Future<void> clearProject(String projectId) async {}

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async => null;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    throw Exception('draft save failed');
  }
}

class _FailingVersionStorage implements AppVersionStorage {
  @override
  Future<void> clear({String? projectId}) async {}

  @override
  Future<void> clearProject(String projectId) async {}

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async => null;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    throw Exception('version save failed');
  }
}

class _SeededFailingVersionStorage implements AppVersionStorage {
  @override
  Future<void> clear({String? projectId}) async {}

  @override
  Future<void> clearProject(String projectId) async {}

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async {
    return {
      'entries': [
        {'label': '初始版本', 'content': '初始内容'},
      ],
    };
  }

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    throw Exception('version save failed');
  }
}

class _RollbackFailingDraftStorage implements AppDraftStorage {
  int saveCount = 0;

  @override
  Future<void> clear({String? projectId}) async {}

  @override
  Future<void> clearProject(String projectId) async {}

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async => null;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    saveCount += 1;
    if (saveCount >= 2) {
      throw Exception('draft rollback save failed');
    }
  }
}

void main() {
  testWidgets(
    'AI review accept refuses stale source draft before writing accepted text',
    (tester) async {
      const originalText = '她推开仓库门，雨声压在屋顶。';
      const changedText = '作者在审阅期间改写了仓库开场。';
      const acceptedText = '她推开仓库门，雨声像鼓点一样逼近。';

      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final draftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: workspaceStore,
      );
      final versionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: workspaceStore,
      );
      final historyStore = AppAiHistoryStore(
        storage: InMemoryAppAiHistoryStorage(),
        workspaceStore: workspaceStore,
      );
      final eventLog = AppEventLog(storage: _MemoryEventLogStorage());
      final aiController = WorkbenchAiController(
        settingsStore: AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          eventLog: eventLog,
        ),
        workspaceStore: workspaceStore,
        eventLog: eventLog,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(historyStore.dispose);
      addTearDown(aiController.settingsStore.dispose);

      await draftStore.updateTextAndPersist(originalText);

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final dialogFuture = showAiReviewDialog(
        context: hostContext,
        reviewTitle: 'AI 审阅',
        historyPrompt: '加强雨夜压迫感',
        blocks: const [
          WorkbenchAiReviewBlock(
            blockLabel: '修改块 1',
            previousText: '',
            originalText: originalText,
            nextText: '',
            authorPrompt: '加强雨夜压迫感',
            suggestionText: acceptedText,
          ),
        ],
        metadata: const AiRequestMetadata(
          providerSummary: '测试服务 · test-model',
          endpointLabel: 'example.test',
          styleSummary: '测试风格',
          sceneSummary: '测试场景',
          characterSummary: '角色：测试',
          worldSummary: '世界：测试',
          simulationSummary: '无',
        ),
        continueMode: false,
        clearSelectionsOnAccept: false,
        draftStore: draftStore,
        versionStore: versionStore,
        historyStore: historyStore,
        aiController: aiController,
        onAccepted: () {},
      );
      await tester.pumpAndSettle();
      expect(find.text('AI 审阅'), findsOneWidget);

      await draftStore.updateTextAndPersist(changedText);
      await tester.tap(find.text('接受变更'));
      await tester.pumpAndSettle();

      expect(find.textContaining('正文内容已变更'), findsOneWidget);
      expect(find.textContaining('重新打开 AI 审阅'), findsOneWidget);
      expect(draftStore.snapshot.text, changedText);
      expect(versionStore.entries, isEmpty);

      await tester.tap(find.text('拒绝变更'));
      await tester.pumpAndSettle();
      await dialogFuture;
    },
  );

  test('sqlite draft storage persists edited draft text', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_authoring_draft_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteAppDraftStorage(
      dbPath: '${directory.path}/authoring.db',
    );
    final store = AppDraftStore(storage: storage);
    addTearDown(store.dispose);

    store.updateText('新的仓库对峙草稿。');

    final restoredStore = AppDraftStore(storage: storage);
    addTearDown(restoredStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(restoredStore.snapshot.text, '新的仓库对峙草稿。');
  });

  test('sqlite version storage persists captured snapshots', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_authoring_version_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppVersionStorage(dbPath: dbPath);
    final store = AppVersionStore(storage: storage);
    addTearDown(store.dispose);

    store.captureSnapshot(label: '第二版', content: '新的第二版内容');
    store.restoreEntry(store.entries.last);

    final restoredStore = AppVersionStore(storage: storage);
    addTearDown(restoredStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(restoredStore.entries.first.label, '恢复版本');
    expect(restoredStore.entries.first.content, '');
    expect(restoredStore.entries.any((entry) => entry.label == '第二版'), isTrue);

    final database = sqlite3.open(dbPath);
    addTearDown(database.dispose);
    final tableNames = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(tableNames, contains('version_entries'));
  });

  test('sqlite workspace storage persists shelf and reference state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_authoring_workspace_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
    final store = AppWorkspaceStore(storage: storage);
    addTearDown(store.dispose);

    store.createProject();
    store.createCharacter();
    store.createWorldNode();
    store.setStyleInputMode(StyleInputMode.json);
    store.increaseStyleIntensity();
    store.bindStyleToScene();
    store.exportCurrentProject();
    store.setProjectTransferState(ProjectTransferState.overwriteConfirm);
    store.executeImport();
    store.selectAuditIssue(1);
    store.updateSelectedAuditIgnoreReason('已与设定会确认，无需继续追踪。');
    store.ignoreSelectedAuditIssue();

    final restoredStore = AppWorkspaceStore(storage: storage);
    addTearDown(restoredStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(restoredStore.projects.first.title, '新建项目 1');
    expect(restoredStore.characters.first.name, '新角色 1');
    expect(restoredStore.worldNodes.first.title, '新节点 1');
    expect(restoredStore.styleInputMode, StyleInputMode.json);
    expect(restoredStore.styleIntensity, 2);
    expect(restoredStore.styleBindingFeedback, contains('场景覆盖'));
    expect(
      restoredStore.projectTransferState,
      ProjectTransferState.overwriteSuccess,
    );
    expect(restoredStore.selectedAuditIssueIndex, 1);

    final database = sqlite3.open(dbPath);
    addTearDown(database.dispose);
    final tableNames = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(tableNames, contains('workspace_projects'));
    expect(tableNames, contains('workspace_scenes'));
    expect(tableNames, contains('workspace_characters'));
    expect(tableNames, contains('workspace_world_nodes'));
    expect(tableNames, contains('workspace_audit_issues'));
    expect(tableNames, contains('workspace_preferences'));
  });

  test(
    'workspace storage persists current project and recent-open ordering',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_authoring_workspace_order_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final store = AppWorkspaceStore(storage: storage);
      addTearDown(store.dispose);

      final originalProjectId = store.projects.last.id;
      store.createProject();
      final newestProjectId = store.projects.first.id;
      store.openProject(originalProjectId);

      final restoredStore = AppWorkspaceStore(storage: storage);
      addTearDown(restoredStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restoredStore.currentProjectId, originalProjectId);
      expect(restoredStore.projects.first.id, originalProjectId);
      expect(
        restoredStore.projects.any((project) => project.id == newestProjectId),
        isTrue,
      );

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);
      final currentProjectValue =
          database
                  .select(
                    '''
      SELECT preference_value
      FROM workspace_preferences
      WHERE scope_key = ? AND preference_key = ?
      ''',
                    ['workspace-default', 'current_project_id'],
                  )
                  .first['preference_value']
              as String;
      expect(currentProjectValue, originalProjectId);
    },
  );

  test('draft and versions are scoped by current project id', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_authoring_project_scopes_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
    final draftStorage = SqliteAppDraftStorage(dbPath: dbPath);
    final versionStorage = SqliteAppVersionStorage(dbPath: dbPath);

    final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
    final draftStore = AppDraftStore(
      storage: draftStorage,
      workspaceStore: workspaceStore,
    );
    final versionStore = AppVersionStore(
      storage: versionStorage,
      workspaceStore: workspaceStore,
    );
    addTearDown(workspaceStore.dispose);
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);

    workspaceStore.createProject();

    final firstProjectId = workspaceStore.currentProjectId;
    draftStore.updateText('项目一的草稿');
    versionStore.captureSnapshot(label: '项目一版本', content: '项目一版本内容');

    workspaceStore.createProject();
    final secondProjectId = workspaceStore.currentProjectId;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(secondProjectId, isNot(firstProjectId));
    expect(draftStore.snapshot.text, isNot('项目一的草稿'));

    draftStore.updateText('项目二的草稿');
    versionStore.captureSnapshot(label: '项目二版本', content: '项目二版本内容');

    workspaceStore.openProject(firstProjectId);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(draftStore.snapshot.text, '项目一的草稿');
    expect(versionStore.entries.first.label, '项目一版本');

    workspaceStore.openProject(secondProjectId);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(draftStore.snapshot.text, '项目二的草稿');
    expect(versionStore.entries.first.label, '项目二版本');
  });

  test(
    'draft and versions are scoped by current scene id within a project',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_authoring_scene_scopes_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final draftStorage = SqliteAppDraftStorage(dbPath: dbPath);
      final versionStorage = SqliteAppVersionStorage(dbPath: dbPath);

      final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
      final draftStore = AppDraftStore(
        storage: draftStorage,
        workspaceStore: workspaceStore,
      );
      final versionStore = AppVersionStore(
        storage: versionStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);

      workspaceStore.createProject();
      final defaultSceneId = workspaceStore.currentProject.sceneId;

      draftStore.updateText('场景 05 的草稿');
      versionStore.captureSnapshot(label: '场景 05 版本', content: '场景 05 版本内容');

      workspaceStore.updateCurrentScene(
        sceneId: 'scene-07-balcony-conflict',
        recentLocation: '第 3 章 / 场景 07 · 阳台争执',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(draftStore.snapshot.text, isNot('场景 05 的草稿'));

      draftStore.updateText('场景 07 的草稿');
      versionStore.captureSnapshot(label: '场景 07 版本', content: '场景 07 版本内容');

      workspaceStore.updateCurrentScene(
        sceneId: defaultSceneId,
        recentLocation: '第 1 章 / 场景 01 · 等待命名',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(draftStore.snapshot.text, '场景 05 的草稿');
      expect(versionStore.entries.first.label, '场景 05 版本');

      workspaceStore.updateCurrentScene(
        sceneId: 'scene-07-balcony-conflict',
        recentLocation: '第 3 章 / 场景 07 · 阳台争执',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(draftStore.snapshot.text, '场景 07 的草稿');
      expect(versionStore.entries.first.label, '场景 07 版本');
    },
  );

  test(
    'awaited authoring writes persist both accepted draft and version',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_authoring_ai_accept_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final draftStorage = SqliteAppDraftStorage(dbPath: dbPath);
      final versionStorage = SqliteAppVersionStorage(dbPath: dbPath);

      final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
      final draftStore = AppDraftStore(
        storage: draftStorage,
        workspaceStore: workspaceStore,
      );
      final versionStore = AppVersionStore(
        storage: versionStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);

      const acceptedText = '我推开仓库门，雨水顺着袖口淌进掌心。远处码头的雾灯陷在雨里，像一根迟疑的针。';

      await draftStore.updateTextAndPersist(acceptedText);
      await versionStore.captureSnapshotAndPersist(
        label: 'AI 接受变更',
        content: acceptedText,
      );

      final restoredDraftStore = AppDraftStore(
        storage: draftStorage,
        workspaceStore: workspaceStore,
      );
      final restoredVersionStore = AppVersionStore(
        storage: versionStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(restoredDraftStore.dispose);
      addTearDown(restoredVersionStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restoredDraftStore.snapshot.text, acceptedText);
      expect(restoredVersionStore.entries.first.label, 'AI 接受变更');
      expect(restoredVersionStore.entries.first.content, acceptedText);
    },
  );

  test(
    'updateTextAndPersist rolls back in-memory draft on save failure',
    () async {
      final store = AppDraftStore(storage: _FailingDraftStorage());
      addTearDown(store.dispose);

      final originalText = store.snapshot.text;
      await expectLater(
        store.updateTextAndPersist('不会成功写入的草稿'),
        throwsException,
      );
      expect(store.snapshot.text, originalText);
    },
  );

  test(
    'captureSnapshotAndPersist rolls back in-memory versions on save failure',
    () async {
      final store = AppVersionStore(storage: _SeededFailingVersionStorage());
      addTearDown(store.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(store.entries.first.label, '初始版本');
      await expectLater(
        store.captureSnapshotAndPersist(label: '失败版本', content: '不会成功写入'),
        throwsException,
      );
      expect(store.entries.first.label, '初始版本');
      expect(store.entries.length, 1);
    },
  );

  test(
    'compound accept-flow failure can leave accepted draft in memory when rollback also fails',
    () async {
      final draftStore = AppDraftStore(storage: _RollbackFailingDraftStorage());
      final versionStore = AppVersionStore(storage: _FailingVersionStorage());
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);

      const acceptedText = '我推开仓库门，雨水顺着袖口淌进掌心。远处码头的雾灯陷在雨里，像一根迟疑的针。';
      final originalText = draftStore.snapshot.text;

      await draftStore.updateTextAndPersist(acceptedText);
      await expectLater(
        versionStore.captureSnapshotAndPersist(
          label: 'AI 接受变更',
          content: acceptedText,
        ),
        throwsException,
      );
      await expectLater(
        draftStore.updateTextAndPersist(originalText),
        throwsException,
      );

      expect(draftStore.snapshot.text, acceptedText);
    },
  );

  test(
    'workspace storage persists scene records and current scene selection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_authoring_scene_model_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final store = AppWorkspaceStore(storage: storage);
      addTearDown(store.dispose);

      store.createProject();
      store.createScene('默认场景');
      expect(store.scenes, isNotEmpty);
      store.updateCurrentScene(
        sceneId: 'scene-07-balcony-conflict',
        recentLocation: '第 3 章 / 场景 07 · 阳台争执',
      );

      final restoredStore = AppWorkspaceStore(storage: storage);
      addTearDown(restoredStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restoredStore.currentProject.sceneId, 'scene-07-balcony-conflict');
      expect(
        restoredStore.currentSceneScopeId,
        contains('scene-07-balcony-conflict'),
      );

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);
      final tableNames = database
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tableNames, contains('workspace_scenes'));
    },
  );
}
