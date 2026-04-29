import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/features/import_export/data/project_transfer_service.dart';
import 'package:novel_writer/features/story_generation/data/artifact_recorder.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';

void main() {
  test('manifest schema label and json defaults stay stable', () {
    const manifest = ProjectPackageManifest(
      packageName: 'lunarifest',
      projectId: 'project-1',
      projectTitle: '项目一',
      schemaMajor: 1,
      schemaMinor: 2,
      exportedAtMs: 123456,
      contentSummary: '正文 / 资料',
    );

    expect(manifest.schemaLabel, 'v1.2');
    expect(manifest.toJson(), {
      'name': 'lunarifest',
      'project_id': 'project-1',
      'project_title': '项目一',
      'schema_major': 1,
      'schema_minor': 2,
      'exported_at_ms': 123456,
      'content_summary': '正文 / 资料',
    });

    final restored = ProjectPackageManifest.fromJson(const {
      'name': 'restored',
    });
    expect(restored.packageName, 'restored');
    expect(restored.projectId, '');
    expect(restored.projectTitle, '未命名项目');
    expect(restored.schemaMajor, 1);
    expect(restored.schemaMinor, 0);
    expect(restored.contentSummary, '正文 / 资料 / 风格 / 版本');
  });

  test(
    'default project transfer paths resolve under the app documents directory',
    () {
      final service = ProjectTransferService();

      expect(service.exportPackagePath, contains('NovelWriter/exports'));
      expect(service.importPackagePath, contains('NovelWriter/imports'));
      expect(service.exportPackagePath, endsWith('lunaris-export.zip'));
      expect(service.importPackagePath, endsWith('lunaris-export.zip'));
    },
  );

  test('object-map decoder normalizes non-string keys', () {
    expect(decodeProjectTransferObjectMap({1: 'one', 'two': 2}), {
      '1': 'one',
      'two': 2,
    });
  });

  test(
    'default path helpers fall back to relative directories without HOME',
    () {
      expect(
        resolveProjectTransferExportsDirectory(homeOverride: '').path,
        './exports',
      );
      expect(
        resolveProjectTransferImportsDirectory(homeOverride: '').path,
        './imports',
      );
    },
  );

  test(
    'export returns noExportableProject when workspace has no projects',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_no_project_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final versionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(workspaceStore.dispose);

      for (final project in List<ProjectRecord>.from(workspaceStore.projects)) {
        workspaceStore.deleteProject(project);
      }

      final result = await service.exportPackage(
        draftStore: draftStore,
        versionStore: versionStore,
        workspaceStore: workspaceStore,
      );

      expect(result.state, ProjectTransferState.noExportableProject);
      expect(result.packagePath, service.exportPackagePath);
    },
  );

  test(
    'export writes a real project package zip with manifest summary',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_export_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final versionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(workspaceStore.dispose);

      draftStore.updateText('导出前的真实草稿');
      versionStore.captureSnapshot(label: '导出版本', content: '导出版本内容');
      workspaceStore.createProject();

      final result = await service.exportPackage(
        draftStore: draftStore,
        versionStore: versionStore,
        workspaceStore: workspaceStore,
      );

      expect(result.state, ProjectTransferState.exportSuccess);
      expect(await File(result.packagePath).exists(), isTrue);

      final inspection = await service.inspectPackage(File(result.packagePath));
      expect(inspection.state, ProjectTransferState.ready);
      expect(inspection.manifest, isNotNull);
      expect(inspection.manifest!.projectId, workspaceStore.currentProjectId);
      expect(inspection.manifest!.projectTitle, '新建项目 4');
      expect(inspection.manifest!.contentSummary, contains('正文'));
    },
  );

  test('import reads a real project package zip and hydrates stores', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_import_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final sourceDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final sourceVersionStore = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
    );
    final sourceWorkspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(sourceDraftStore.dispose);
    addTearDown(sourceVersionStore.dispose);
    addTearDown(sourceWorkspaceStore.dispose);

    sourceDraftStore.updateText('导入后的真实草稿');
    sourceVersionStore.captureSnapshot(label: '导入版本', content: '导入版本内容');
    sourceWorkspaceStore.createProject();
    sourceWorkspaceStore.createCharacter();
    sourceWorkspaceStore.createWorldNode();
    final exportResult = await service.exportPackage(
      draftStore: sourceDraftStore,
      versionStore: sourceVersionStore,
      workspaceStore: sourceWorkspaceStore,
    );

    final importFile = File('${directory.path}/imports/lunaris-export.zip');
    await importFile.parent.create(recursive: true);
    await File(exportResult.packagePath).copy(importFile.path);

    final targetDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final targetVersionStore = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
    );
    final targetWorkspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(targetDraftStore.dispose);
    addTearDown(targetVersionStore.dispose);
    addTearDown(targetWorkspaceStore.dispose);

    final importResult = await service.importPackage(
      draftStore: targetDraftStore,
      versionStore: targetVersionStore,
      workspaceStore: targetWorkspaceStore,
    );

    expect(importResult.state, ProjectTransferState.importSuccess);
    expect(targetDraftStore.snapshot.text, '导入后的真实草稿');
    expect(targetVersionStore.entries.first.label, '导入版本');
    expect(targetWorkspaceStore.projects.first.title, '新建项目 4');
    expect(targetWorkspaceStore.characters.first.name, '新角色 4');
    expect(targetWorkspaceStore.worldNodes.first.title, '新节点 4');
  });

  test('import blocks packages with missing manifest', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_missing_manifest_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final stagingDirectory = Directory('${directory.path}/staging');
    await stagingDirectory.create(recursive: true);
    await File(
      '${stagingDirectory.path}/draft.json',
    ).writeAsString('{"text":"坏包"}');
    final zipFile = File('${directory.path}/imports/lunaris-export.zip');
    await zipFile.parent.create(recursive: true);
    await Process.run('/usr/bin/zip', [
      '-qr',
      zipFile.path,
      '.',
    ], workingDirectory: stagingDirectory.path);

    final inspection = await service.inspectPackage(zipFile);
    expect(inspection.state, ProjectTransferState.missingManifest);
  });

  test(
    'import requires overwrite confirmation when package project id already exists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_overwrite_confirm_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('覆盖确认前的导入草稿');
      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );
      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final importResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );

      expect(importResult.state, ProjectTransferState.overwriteConfirm);
      expect(targetDraftStore.snapshot.text, isNot('覆盖确认前的导入草稿'));
    },
  );

  test(
    'overwrite import replaces matching project after confirmation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_overwrite_apply_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('覆盖后的真实草稿');
      sourceVersionStore.captureSnapshot(label: '覆盖版本', content: '覆盖版本内容');
      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );
      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      targetDraftStore.updateText('旧草稿');
      final overwriteResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
        overwriteExisting: true,
      );

      expect(overwriteResult.state, ProjectTransferState.overwriteSuccess);
      expect(targetDraftStore.snapshot.text, '覆盖后的真实草稿');
      expect(
        targetWorkspaceStore.currentProjectId,
        sourceWorkspaceStore.currentProjectId,
      );
    },
  );

  test('export package only contains the active project snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_active_snapshot_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);
    addTearDown(workspaceStore.dispose);

    workspaceStore.createProject();
    final activeProjectId = workspaceStore.currentProjectId;
    final inactiveProjectId = workspaceStore.projects.last.id;
    draftStore.updateText('只导出当前项目草稿');
    versionStore.captureSnapshot(label: '当前项目版本', content: '当前项目版本内容');

    final result = await service.exportPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
    );

    final extraction = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_active_snapshot_extract',
    );
    addTearDown(() async {
      if (await extraction.exists()) {
        await extraction.delete(recursive: true);
      }
    });
    final unzip = await Process.run('/usr/bin/unzip', [
      '-oq',
      result.packagePath,
      '-d',
      extraction.path,
    ]);
    expect(unzip.exitCode, 0);

    final workspaceJson =
        jsonDecode(
              await File('${extraction.path}/workspace.json').readAsString(),
            )
            as Map<String, Object?>;
    final projects = workspaceJson['projects'] as List<Object?>;

    expect(projects, hasLength(1));
    expect((projects.first as Map<Object?, Object?>)['id'], activeProjectId);
    expect(workspaceJson.toString(), isNot(contains(inactiveProjectId)));
  });

  test(
    'export and import carry AI history, scene context, and simulation for the active project',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_session_payload_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final sourceDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceAiHistoryStore = AppAiHistoryStore(
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceSceneContextStore = AppSceneContextStore(
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceSimulationStore = AppSimulationStore(
        storage: InMemoryAppSimulationStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      addTearDown(sourceWorkspaceStore.dispose);
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceAiHistoryStore.dispose);
      addTearDown(sourceSceneContextStore.dispose);
      addTearDown(sourceSimulationStore.dispose);

      sourceWorkspaceStore.createProject();
      sourceAiHistoryStore.addEntry(mode: '改写', prompt: '导出会话历史');
      sourceSceneContextStore.syncContext();
      sourceSimulationStore.startSuccessfulRun();
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final exportResult = await service.exportPackage(
        aiHistoryStore: sourceAiHistoryStore,
        draftStore: sourceDraftStore,
        sceneContextStore: sourceSceneContextStore,
        simulationStore: sourceSimulationStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      final targetAiHistoryStore = AppAiHistoryStore(
        workspaceStore: targetWorkspaceStore,
      );
      final targetSceneContextStore = AppSceneContextStore(
        workspaceStore: targetWorkspaceStore,
      );
      final targetSimulationStore = AppSimulationStore(
        storage: InMemoryAppSimulationStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      addTearDown(targetWorkspaceStore.dispose);
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetAiHistoryStore.dispose);
      addTearDown(targetSceneContextStore.dispose);
      addTearDown(targetSimulationStore.dispose);

      final importResult = await service.importPackage(
        aiHistoryStore: targetAiHistoryStore,
        draftStore: targetDraftStore,
        sceneContextStore: targetSceneContextStore,
        simulationStore: targetSimulationStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );

      expect(importResult.state, ProjectTransferState.importSuccess);
      expect(targetAiHistoryStore.entries.first.prompt, '导出会话历史');
      expect(targetSceneContextStore.snapshot.sceneSummary, contains('等待命名'));
      expect(targetSimulationStore.snapshot.status, SimulationStatus.completed);
    },
  );

  test(
    'project transfer exports and imports outline and generation payloads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_story_generation_transfer_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final sourceDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceOutlineStore = StoryOutlineStore(
        storage: InMemoryStoryOutlineStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      final sourceGenerationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: sourceWorkspaceStore,
      );
      addTearDown(sourceWorkspaceStore.dispose);
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceOutlineStore.dispose);
      addTearDown(sourceGenerationStore.dispose);

      sourceWorkspaceStore.createProject();
      sourceDraftStore.updateText('携带大纲和生成态的导出草稿');
      sourceVersionStore.captureSnapshot(label: '导出版本', content: '导出版本内容');
      sourceOutlineStore.replaceSnapshot(
        StoryOutlineSnapshot(
          projectId: sourceWorkspaceStore.currentProjectId,
          metadata: const {'tone': 'suspense', 'source': 'task-4-review'},
          chapters: const [
            StoryOutlineChapterSnapshot(
              id: 'chapter-01',
              title: '第一章 雨夜码头',
              summary: '主角在雨夜抵达码头并遇见向导。',
              metadata: {'chapterNote': '开篇必须压住节奏'},
              scenes: [
                StoryOutlineSceneSnapshot(
                  id: 'scene-01',
                  title: '抵达码头',
                  summary: '船只靠岸，向导现身。',
                  metadata: {'weather': 'rain', 'beat': 'arrival'},
                  cast: [
                    StoryOutlineCastSnapshot(
                      characterId: 'guide',
                      name: '沈渡',
                      role: '向导',
                      metadata: {'stance': 'guarded'},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      sourceGenerationStore.replaceSnapshot(
        StoryGenerationSnapshot(
          projectId: sourceWorkspaceStore.currentProjectId,
          chapters: [
            StoryChapterGenerationState(
              chapterId: 'chapter-01',
              status: StoryChapterGenerationStatus.reviewing,
              targetLength: 2400,
              actualLength: 1860,
              participatingRoleIds: const ['guide'],
              worldNodeIds: const ['dock'],
              scenes: [
                StorySceneGenerationState(
                  sceneId: 'scene-01',
                  status: StorySceneGenerationStatus.reviewing,
                  judgeStatus: StoryReviewStatus.passed,
                  consistencyStatus: StoryReviewStatus.pending,
                  proseRetryCount: 1,
                  directorRetryCount: 0,
                  castRoleIds: const ['guide'],
                  worldNodeIds: const ['dock'],
                  upstreamFingerprint: 'fingerprint-01',
                ),
              ],
            ),
          ],
        ),
      );
      await sourceGenerationStore.waitUntilReady();
      final expectedOutlineJson = sourceOutlineStore.exportJson();
      final expectedGenerationJson = sourceGenerationStore.exportJson();

      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
        storyOutlineStore: sourceOutlineStore,
        storyGenerationStore: sourceGenerationStore,
      );

      expect(exportResult.state, ProjectTransferState.exportSuccess);
      expect(
        await _packageContains(exportResult.packagePath, 'outline.json'),
        isTrue,
      );
      expect(
        await _packageContains(
          exportResult.packagePath,
          'generation_state.json',
        ),
        isTrue,
      );
      expect(
        await _readPackageJson(exportResult.packagePath, 'outline.json'),
        equals(expectedOutlineJson),
      );
      expect(
        await _readPackageJson(
          exportResult.packagePath,
          'generation_state.json',
        ),
        equals(expectedGenerationJson),
      );

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      final targetOutlineStore = StoryOutlineStore(
        storage: InMemoryStoryOutlineStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      final targetGenerationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: targetWorkspaceStore,
      );
      addTearDown(targetWorkspaceStore.dispose);
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetOutlineStore.dispose);
      addTearDown(targetGenerationStore.dispose);

      final importResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
        storyOutlineStore: targetOutlineStore,
        storyGenerationStore: targetGenerationStore,
      );

      expect(importResult.state, ProjectTransferState.importSuccess);
      await targetGenerationStore.waitUntilReady();
      expect(targetOutlineStore.exportJson(), equals(expectedOutlineJson));
      expect(
        targetGenerationStore.exportJson(),
        equals(expectedGenerationJson),
      );
      expect(targetOutlineStore.snapshot.chapters.single.title, '第一章 雨夜码头');
      final importedChapter = targetGenerationStore.snapshot.chapters.single;
      final importedScene = importedChapter.scenes.single;
      expect(importedChapter.status, StoryChapterGenerationStatus.reviewing);
      expect(importedChapter.actualLength, 1860);
      expect(importedChapter.participatingRoleIds, const ['guide']);
      expect(importedChapter.worldNodeIds, const ['dock']);
      expect(importedScene.sceneId, 'scene-01');
      expect(importedScene.status, StorySceneGenerationStatus.reviewing);
      expect(importedScene.judgeStatus, StoryReviewStatus.passed);
      expect(importedScene.consistencyStatus, StoryReviewStatus.pending);
      expect(importedScene.proseRetryCount, 1);
      expect(importedScene.directorRetryCount, 0);
      expect(importedScene.castRoleIds, const ['guide']);
      expect(importedScene.worldNodeIds, const ['dock']);
      expect(importedScene.upstreamFingerprint, 'fingerprint-01');
    },
  );

  test('artifact recorder writes visible chapter and report files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_artifact_recorder_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final recorder = ArtifactRecorder(rootDirectory: directory);

    await recorder.recordChapterText(
      chapterId: 'chapter-01',
      text: '# 第一章\n\n可见产物',
    );
    await recorder.recordReport(
      relativePath: 'reports/run-report.md',
      content: '运行摘要',
    );

    expect(
      await File('${directory.path}/chapters/chapter-01.md').exists(),
      isTrue,
    );
    expect(
      await File('${directory.path}/reports/run-report.md').readAsString(),
      '运行摘要',
    );
  });

  test(
    'artifact recorder rejects paths that escape the root directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_artifact_recorder_escape_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final recorder = ArtifactRecorder(rootDirectory: directory);

      expect(
        () => recorder.recordChapterText(chapterId: '../escape', text: 'bad'),
        throwsArgumentError,
      );
      expect(
        () =>
            recorder.recordReport(relativePath: '../escape.md', content: 'bad'),
        throwsArgumentError,
      );
      expect(
        () => recorder.recordReport(
          relativePath: '/tmp/novel_writer_escape.md',
          content: 'bad',
        ),
        throwsArgumentError,
      );
    },
  );

  test('project transfer emits structured export and inspect events', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_event_log_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final eventStorage = _RecordingAppEventLogStorage();
    final eventLog = AppEventLog(
      storage: eventStorage,
      sessionId: 'session-task4',
    );
    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
      eventLog: eventLog,
    );
    final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);
    addTearDown(workspaceStore.dispose);

    workspaceStore.createProject();
    final exportResult = await service.exportPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
    );
    final missingInspection = await service.inspectPackage(
      File('${directory.path}/missing/lunaris-export.zip'),
    );

    expect(exportResult.state, ProjectTransferState.exportSuccess);
    expect(missingInspection.state, ProjectTransferState.invalidPackage);

    expect(
      _entriesForAction(eventStorage.entries, 'project.export.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(eventStorage.entries, 'project.export.succeeded'),
      hasLength(1),
    );
    expect(
      _entriesForAction(eventStorage.entries, 'project.import.inspect.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(eventStorage.entries, 'project.import.inspect.failed'),
      hasLength(1),
    );

    final exportStarted = _entriesForAction(
      eventStorage.entries,
      'project.export.started',
    ).single;
    final exportSucceeded = _entriesForAction(
      eventStorage.entries,
      'project.export.succeeded',
    ).single;
    expect(exportStarted.correlationId, exportSucceeded.correlationId);
    expect(exportStarted.projectId, workspaceStore.currentProjectId);

    final inspectStarted = _entriesForAction(
      eventStorage.entries,
      'project.import.inspect.started',
    ).single;
    final inspectFailed = _entriesForAction(
      eventStorage.entries,
      'project.import.inspect.failed',
    ).single;
    expect(inspectStarted.correlationId, inspectFailed.correlationId);
    expect(inspectFailed.errorCode, 'invalid_package');
  });

  test('project transfer logging stays best-effort when writes fail', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_event_log_failure_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
      eventLog: AppEventLog(
        storage: _ThrowingAppEventLogStorage(),
        sessionId: 'session-task4',
      ),
    );
    final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);
    addTearDown(workspaceStore.dispose);

    workspaceStore.createProject();

    final result = await service.exportPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
    );

    expect(result.state, ProjectTransferState.exportSuccess);
    expect(await File(result.packagePath).exists(), isTrue);
  });

  test(
    'export replaces an existing stale package file with a real zip archive',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_replace_export_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final staleFile = File(service.exportPackagePath);
      await staleFile.parent.create(recursive: true);
      await staleFile.writeAsString('stale-package');

      final exportFile = await _exportRealPackageZip(
        directory: directory,
        service: service,
      );

      expect(exportFile.path, staleFile.path);
      final bytes = await staleFile.readAsBytes();
      expect(bytes.take(2).toList(), [0x50, 0x4b]);
    },
  );

  test('export surfaces zip command failures as invalid packages', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_export_failure_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
      zipExecutable: '/usr/bin/false',
    );
    final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);
    addTearDown(workspaceStore.dispose);

    final result = await service.exportPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
    );

    expect(result.state, ProjectTransferState.invalidPackage);
    expect(result.manifest, isNotNull);
  });

  test(
    'inspectPackage reports schema compatibility warnings and blocks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_schema_warning_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final exportFile = await _exportRealPackageZip(
        directory: directory,
        service: service,
      );

      final minorWarningPackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: '${directory.path}/minor-warning.zip',
        mutate: (staging) async {
          final manifestFile = File('${staging.path}/manifest.json');
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, Object?>;
          manifest['schema_minor'] = 1;
          await manifestFile.writeAsString(jsonEncode(manifest));
        },
      );
      final minorInspection = await service.inspectPackage(minorWarningPackage);
      expect(minorInspection.state, ProjectTransferState.minorVersionWarning);
      expect(minorInspection.manifest?.schemaMinor, 1);

      final majorBlockedPackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: '${directory.path}/major-blocked.zip',
        mutate: (staging) async {
          final manifestFile = File('${staging.path}/manifest.json');
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, Object?>;
          manifest['schema_major'] = 2;
          await manifestFile.writeAsString(jsonEncode(manifest));
        },
      );
      final majorInspection = await service.inspectPackage(majorBlockedPackage);
      expect(majorInspection.state, ProjectTransferState.majorVersionBlocked);
      expect(majorInspection.manifest?.schemaMajor, 2);
    },
  );

  test(
    'inspectPackage rejects malformed manifests and extraction failures',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_inspect_invalid_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final exportFile = await _exportRealPackageZip(
        directory: directory,
        service: service,
      );

      final malformedManifestPackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: '${directory.path}/manifest-malformed.zip',
        mutate: (staging) async {
          await File(
            '${staging.path}/manifest.json',
          ).writeAsString('{bad-json');
        },
      );
      final malformedInspection = await service.inspectPackage(
        malformedManifestPackage,
      );
      expect(malformedInspection.state, ProjectTransferState.invalidPackage);

      final wrongShapeManifestPackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: '${directory.path}/manifest-list.zip',
        mutate: (staging) async {
          await File('${staging.path}/manifest.json').writeAsString('[]');
        },
      );
      final wrongShapeInspection = await service.inspectPackage(
        wrongShapeManifestPackage,
      );
      expect(wrongShapeInspection.state, ProjectTransferState.invalidPackage);

      final failingExtractorService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports-false'),
        importsDirectory: Directory('${directory.path}/imports-false'),
        unzipExecutable: '/usr/bin/false',
      );
      final extractionFailure = await failingExtractorService.inspectPackage(
        exportFile,
      );
      expect(extractionFailure.state, ProjectTransferState.invalidPackage);
    },
  );

  test('inspectPackage rejects missing package files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_missing_file_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );

    final inspection = await service.inspectPackage(
      File('${directory.path}/missing/lunaris-export.zip'),
    );
    expect(inspection.state, ProjectTransferState.invalidPackage);
    expect(inspection.packagePath, contains('lunaris-export.zip'));
  });

  test(
    'import accepts minor-version warnings but rejects missing or malformed payloads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_import_invalid_payload_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final exportFile = await _exportRealPackageZip(
        directory: directory,
        service: service,
      );

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final minorWarningImport = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: service.importPackagePath,
        mutate: (staging) async {
          final manifestFile = File('${staging.path}/manifest.json');
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, Object?>;
          manifest['project_id'] = 'project-import-minor';
          manifest['schema_minor'] = 1;
          await manifestFile.writeAsString(jsonEncode(manifest));
        },
      );
      expect(await minorWarningImport.exists(), isTrue);

      final minorResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );
      expect(minorResult.state, ProjectTransferState.importSuccess);
      expect(minorResult.manifest?.projectId, 'project-import-minor');
      expect(targetDraftStore.snapshot.text, '真实导出草稿');

      final missingFilePackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: service.importPackagePath,
        mutate: (staging) async {
          final manifestFile = File('${staging.path}/manifest.json');
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, Object?>;
          manifest['project_id'] = 'project-import-missing';
          await manifestFile.writeAsString(jsonEncode(manifest));
          await File('${staging.path}/versions.json').delete();
        },
      );
      expect(await missingFilePackage.exists(), isTrue);

      final missingFileResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );
      expect(missingFileResult.state, ProjectTransferState.invalidPackage);

      final malformedDraftPackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: service.importPackagePath,
        mutate: (staging) async {
          final manifestFile = File('${staging.path}/manifest.json');
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, Object?>;
          manifest['project_id'] = 'project-import-malformed';
          await manifestFile.writeAsString(jsonEncode(manifest));
          await File('${staging.path}/draft.json').writeAsString('[1,2,3]');
        },
      );
      expect(await malformedDraftPackage.exists(), isTrue);

      final malformedDraftResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );
      expect(malformedDraftResult.state, ProjectTransferState.invalidPackage);

      final failingExtractorService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports-false'),
        importsDirectory: Directory('${directory.path}/imports-false'),
        unzipExecutable: '/usr/bin/false',
      );
      await File(
        failingExtractorService.importPackagePath,
      ).parent.create(recursive: true);
      await exportFile.copy(failingExtractorService.importPackagePath);

      final extractionFailureResult = await failingExtractorService
          .importPackage(
            draftStore: targetDraftStore,
            versionStore: targetVersionStore,
            workspaceStore: targetWorkspaceStore,
          );
      expect(
        extractionFailureResult.state,
        ProjectTransferState.invalidPackage,
      );
    },
  );

  test(
    'story memory export callback writes story_memory.json into the package',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_story_memory_export_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      String? exportedProjectId;
      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
        storyMemoryExport: (projectId) async {
          exportedProjectId = projectId;
          return {
            'entries': [
              {'key': 'character-arc-1', 'summary': '角色弧线记录'},
            ],
          };
        },
      );
      final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(workspaceStore.dispose);

      workspaceStore.createProject();
      final result = await service.exportPackage(
        draftStore: draftStore,
        versionStore: versionStore,
        workspaceStore: workspaceStore,
      );

      expect(result.state, ProjectTransferState.exportSuccess);
      expect(exportedProjectId, workspaceStore.currentProjectId);
      expect(
        await _packageContains(result.packagePath, 'story_memory.json'),
        isTrue,
      );
      final memoryJson = await _readPackageJson(
        result.packagePath,
        'story_memory.json',
      );
      expect(memoryJson['entries'], isA<List>());
      final entries = memoryJson['entries'] as List;
      expect(entries.first['key'], 'character-arc-1');
    },
  );

  test(
    'story memory export returning null omits story_memory.json from the package',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_story_memory_null_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
        storyMemoryExport: (projectId) async => null,
      );
      final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(workspaceStore.dispose);

      workspaceStore.createProject();
      final result = await service.exportPackage(
        draftStore: draftStore,
        versionStore: versionStore,
        workspaceStore: workspaceStore,
      );

      expect(result.state, ProjectTransferState.exportSuccess);
      expect(
        await _packageContains(result.packagePath, 'story_memory.json'),
        isFalse,
      );
    },
  );

  test(
    'story memory import callback receives data from imported package',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_story_memory_import_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
        storyMemoryExport: (projectId) async {
          return {
            'entries': [
              {'key': 'world-building-1', 'detail': '魔法体系'},
            ],
          };
        },
      );
      final sourceDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('story memory round-trip');
      sourceWorkspaceStore.createProject();
      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );
      expect(exportResult.state, ProjectTransferState.exportSuccess);

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      String? importedProjectId;
      Map<String, Object?>? importedData;
      final importService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports-2'),
        importsDirectory: Directory('${directory.path}/imports'),
        storyMemoryImport: (projectId, data) async {
          importedProjectId = projectId;
          importedData = data;
        },
      );

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final importResult = await importService.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );

      expect(importResult.state, ProjectTransferState.importSuccess);
      expect(importedProjectId, sourceWorkspaceStore.currentProjectId);
      expect(importedData, isNotNull);
      final entries = importedData!['entries'] as List;
      expect(entries.first['key'], 'world-building-1');
      expect(entries.first['detail'], '魔法体系');
    },
  );

  test(
    'import silently ignores story_memory.json when no import callback is provided',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_story_memory_no_callback_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final exportService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
        storyMemoryExport: (projectId) async {
          return {'entries': [{'key': 'orphan-data'}]};
        },
      );
      final sourceDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('no callback import');
      sourceWorkspaceStore.createProject();
      final exportResult = await exportService.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );

      final importFile = File(exportService.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final importService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports-2'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final importResult = await importService.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );

      expect(importResult.state, ProjectTransferState.importSuccess);
      expect(targetDraftStore.snapshot.text, 'no callback import');
    },
  );

  test(
    'import adds project alongside existing different projects without replacing them',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_add_to_existing_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('imported project draft');
      sourceVersionStore.captureSnapshot(
        label: 'imported version',
        content: 'imported version content',
      );
      sourceWorkspaceStore.createProject();
      final sourceProjectId = sourceWorkspaceStore.currentProjectId;
      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      for (final project
          in List<ProjectRecord>.from(targetWorkspaceStore.projects)) {
        targetWorkspaceStore.deleteProject(project);
      }
      targetWorkspaceStore.createProject();
      final existingProjectId = targetWorkspaceStore.currentProjectId;
      targetDraftStore.updateText('existing project draft');
      targetVersionStore.captureSnapshot(
        label: 'existing version',
        content: 'existing version content',
      );
      expect(targetWorkspaceStore.projects, hasLength(1));

      final importResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );

      expect(importResult.state, ProjectTransferState.importSuccess);
      expect(
        targetWorkspaceStore.hasProjectWithId(sourceProjectId),
        isTrue,
      );
      expect(
        targetWorkspaceStore.hasProjectWithId(existingProjectId),
        isTrue,
      );
      expect(targetWorkspaceStore.projects, hasLength(2));
      expect(targetWorkspaceStore.currentProjectId, sourceProjectId);
      expect(targetDraftStore.snapshot.text, 'imported project draft');
    },
  );

  test(
    'export and import with only default version entry preserves project integrity',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_default_versions_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('default version round-trip');
      for (final project
          in List<ProjectRecord>.from(sourceWorkspaceStore.projects)) {
        sourceWorkspaceStore.deleteProject(project);
      }
      sourceWorkspaceStore.createProject();
      final sourceVersionCount = sourceVersionStore.entries.length;
      final sourceVersionLabel = sourceVersionStore.entries.first.label;

      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );
      expect(exportResult.state, ProjectTransferState.exportSuccess);

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);
      for (final project
          in List<ProjectRecord>.from(targetWorkspaceStore.projects)) {
        targetWorkspaceStore.deleteProject(project);
      }

      final importResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );

      expect(importResult.state, ProjectTransferState.importSuccess);
      expect(targetDraftStore.snapshot.text, 'default version round-trip');
      expect(targetVersionStore.entries, hasLength(sourceVersionCount));
      expect(targetVersionStore.entries.first.label, sourceVersionLabel);
      expect(targetWorkspaceStore.projects, hasLength(1));
    },
  );

  test(
    'overwriteExisting true imports normally when no project id conflict exists',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_overwrite_no_conflict_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final sourceDraftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('overwrite flag with no conflict');
      sourceWorkspaceStore.createProject();
      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final importResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
        overwriteExisting: true,
      );

      expect(importResult.state, ProjectTransferState.overwriteSuccess);
      expect(targetDraftStore.snapshot.text, 'overwrite flag with no conflict');
    },
  );

  test(
    'import emits structured event log chain from start to success',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_import_event_log_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final eventStorage = _RecordingAppEventLogStorage();
      final eventLog = AppEventLog(
        storage: eventStorage,
        sessionId: 'session-boundary-import',
      );
      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
        eventLog: eventLog,
      );
      final sourceDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final sourceVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final sourceWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(sourceDraftStore.dispose);
      addTearDown(sourceVersionStore.dispose);
      addTearDown(sourceWorkspaceStore.dispose);

      sourceDraftStore.updateText('import event log test');
      sourceWorkspaceStore.createProject();
      final exportResult = await service.exportPackage(
        draftStore: sourceDraftStore,
        versionStore: sourceVersionStore,
        workspaceStore: sourceWorkspaceStore,
      );
      eventStorage.entries.clear();

      final importFile = File(service.importPackagePath);
      await importFile.parent.create(recursive: true);
      await File(exportResult.packagePath).copy(importFile.path);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final importResult = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );
      expect(importResult.state, ProjectTransferState.importSuccess);

      final startedEntries = _entriesForAction(
        eventStorage.entries,
        'project.import.started',
      );
      final inspectStarted = _entriesForAction(
        eventStorage.entries,
        'project.import.inspect.started',
      );
      final inspectSucceeded = _entriesForAction(
        eventStorage.entries,
        'project.import.inspect.succeeded',
      );
      final importSucceeded = _entriesForAction(
        eventStorage.entries,
        'project.import.succeeded',
      );

      expect(startedEntries, hasLength(1));
      expect(inspectStarted, hasLength(1));
      expect(inspectSucceeded, hasLength(1));
      expect(importSucceeded, hasLength(1));

      expect(
        startedEntries.single.correlationId,
        importSucceeded.single.correlationId,
      );
      expect(inspectStarted.single.correlationId, isNotEmpty);
      expect(
        inspectStarted.single.correlationId,
        inspectSucceeded.single.correlationId,
      );
      expect(importSucceeded.single.status, AppEventLogStatus.succeeded);
    },
  );

  test(
    'export without any optional stores writes only core payload files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_minimal_payload_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(workspaceStore.dispose);

      workspaceStore.createProject();
      draftStore.updateText('minimal core export');
      versionStore.captureSnapshot(label: 'v1', content: 'content');

      final result = await service.exportPackage(
        draftStore: draftStore,
        versionStore: versionStore,
        workspaceStore: workspaceStore,
      );

      expect(result.state, ProjectTransferState.exportSuccess);
      expect(await _packageContains(result.packagePath, 'manifest.json'), isTrue);
      expect(await _packageContains(result.packagePath, 'workspace.json'), isTrue);
      expect(await _packageContains(result.packagePath, 'draft.json'), isTrue);
      expect(await _packageContains(result.packagePath, 'versions.json'), isTrue);
      expect(await _packageContains(result.packagePath, 'ai_history.json'), isFalse);
      expect(await _packageContains(result.packagePath, 'scene_context.json'), isFalse);
      expect(await _packageContains(result.packagePath, 'simulation.json'), isFalse);
      expect(await _packageContains(result.packagePath, 'outline.json'), isFalse);
      expect(await _packageContains(result.packagePath, 'generation_state.json'), isFalse);
      expect(await _packageContains(result.packagePath, 'story_memory.json'), isFalse);
    },
  );

  test(
    'import returns invalidPackage when extraction fails after inspection succeeds',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_second_extract_failure_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final unzipScript = File('${directory.path}/toggle-unzip.sh');
      final counterFile = File('${directory.path}/toggle-unzip-count.txt');
      await unzipScript.writeAsString('''
#!/bin/sh
count=0
if [ -f "${counterFile.path}" ]; then
  count=\$(cat "${counterFile.path}")
fi
count=\$((count + 1))
echo "\$count" > "${counterFile.path}"
if [ "\$count" -eq 1 ]; then
  exec /usr/bin/unzip "\$@"
fi
exit 1
''');
      await Process.run('/bin/chmod', ['+x', unzipScript.path]);

      final exportService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final exportFile = await _exportRealPackageZip(
        directory: directory,
        service: exportService,
      );

      final importService = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports-script'),
        importsDirectory: Directory('${directory.path}/imports-script'),
        unzipExecutable: unzipScript.path,
      );
      await File(
        importService.importPackagePath,
      ).parent.create(recursive: true);
      await exportFile.copy(importService.importPackagePath);

      final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
      final versionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(draftStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(workspaceStore.dispose);

      final result = await importService.importPackage(
        draftStore: draftStore,
        versionStore: versionStore,
        workspaceStore: workspaceStore,
      );

      expect(result.state, ProjectTransferState.invalidPackage);
      expect(await counterFile.readAsString(), '2\n');
    },
  );

  test('computePayloadChecksum is deterministic', () {
    final a = computePayloadChecksum('hello world');
    final b = computePayloadChecksum('hello world');
    expect(a, b);
    expect(a, isNotEmpty);
  });

  test('computePayloadChecksum produces different hashes for different input', () {
    expect(
      computePayloadChecksum('hello'),
      isNot(equals(computePayloadChecksum('world'))),
    );
  });

  test('export generates checksums.json covering all payload files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_checksums_export_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
    final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(draftStore.dispose);
    addTearDown(versionStore.dispose);
    addTearDown(workspaceStore.dispose);

    workspaceStore.createProject();
    draftStore.updateText('checksum export test');
    versionStore.captureSnapshot(label: 'v1', content: 'content');

    final result = await service.exportPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
    );

    expect(result.state, ProjectTransferState.exportSuccess);
    expect(
      await _packageContains(result.packagePath, 'checksums.json'),
      isTrue,
    );
    final checksumsJson = await _readPackageJson(
      result.packagePath,
      'checksums.json',
    );
    expect(checksumsJson.containsKey('manifest.json'), isTrue);
    expect(checksumsJson.containsKey('workspace.json'), isTrue);
    expect(checksumsJson.containsKey('draft.json'), isTrue);
    expect(checksumsJson.containsKey('versions.json'), isTrue);
    expect(checksumsJson.containsKey('checksums.json'), isFalse);
  });

  test('import rejects tampered payload with integrityCheckFailed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_tampered_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final exportFile = await _exportRealPackageZip(
      directory: directory,
      service: service,
    );
    final tamperedPackage = await _rewritePackage(
      sourceZip: exportFile,
      targetZipPath: service.importPackagePath,
      preserveChecksums: true,
      mutate: (staging) async {
        final manifestFile = File('${staging.path}/manifest.json');
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, Object?>;
        manifest['project_id'] = 'project-tampered';
        await manifestFile.writeAsString(jsonEncode(manifest));
        await File('${staging.path}/draft.json').writeAsString(
          '{"text":"TAMPERED"}',
        );
      },
    );
    expect(await tamperedPackage.exists(), isTrue);

    final targetDraftStore = AppDraftStore(
      storage: InMemoryAppDraftStorage(),
    );
    final targetVersionStore = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
    );
    final targetWorkspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(targetDraftStore.dispose);
    addTearDown(targetVersionStore.dispose);
    addTearDown(targetWorkspaceStore.dispose);

    final result = await service.importPackage(
      draftStore: targetDraftStore,
      versionStore: targetVersionStore,
      workspaceStore: targetWorkspaceStore,
    );
    expect(result.state, ProjectTransferState.integrityCheckFailed);
  });

  test('import rejects workspace data with invalid structure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_invalid_workspace_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final exportFile = await _exportRealPackageZip(
      directory: directory,
      service: service,
    );
    final invalidPackage = await _rewritePackage(
      sourceZip: exportFile,
      targetZipPath: service.importPackagePath,
      mutate: (staging) async {
        final manifestFile = File('${staging.path}/manifest.json');
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, Object?>;
        manifest['project_id'] = 'project-invalid-ws';
        await manifestFile.writeAsString(jsonEncode(manifest));
        await File('${staging.path}/workspace.json').writeAsString(
          jsonEncode({
            'projects': [
              {
                'id': '',
                'sceneId': '',
                'title': '   ',
                'lastOpenedAtMs': -1,
              },
            ],
          }),
        );
      },
    );
    expect(await invalidPackage.exists(), isTrue);

    final targetDraftStore = AppDraftStore(
      storage: InMemoryAppDraftStorage(),
    );
    final targetVersionStore = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
    );
    final targetWorkspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(targetDraftStore.dispose);
    addTearDown(targetVersionStore.dispose);
    addTearDown(targetWorkspaceStore.dispose);

    final result = await service.importPackage(
      draftStore: targetDraftStore,
      versionStore: targetVersionStore,
      workspaceStore: targetWorkspaceStore,
    );
    expect(result.state, ProjectTransferState.integrityCheckFailed);
  });

  test('import succeeds for valid round-trip with checksums', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_project_transfer_checksum_round_trip_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final service = ProjectTransferService(
      exportsDirectory: Directory('${directory.path}/exports'),
      importsDirectory: Directory('${directory.path}/imports'),
    );
    final sourceDraftStore = AppDraftStore(
      storage: InMemoryAppDraftStorage(),
    );
    final sourceVersionStore = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
    );
    final sourceWorkspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(sourceDraftStore.dispose);
    addTearDown(sourceVersionStore.dispose);
    addTearDown(sourceWorkspaceStore.dispose);

    sourceDraftStore.updateText('checksum round-trip draft');
    sourceVersionStore.captureSnapshot(label: 'v1', content: 'content');
    sourceWorkspaceStore.createProject();

    final exportResult = await service.exportPackage(
      draftStore: sourceDraftStore,
      versionStore: sourceVersionStore,
      workspaceStore: sourceWorkspaceStore,
    );
    expect(exportResult.state, ProjectTransferState.exportSuccess);

    final importFile = File(service.importPackagePath);
    await importFile.parent.create(recursive: true);
    await File(exportResult.packagePath).copy(importFile.path);

    final targetDraftStore = AppDraftStore(
      storage: InMemoryAppDraftStorage(),
    );
    final targetVersionStore = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
    );
    final targetWorkspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(targetDraftStore.dispose);
    addTearDown(targetVersionStore.dispose);
    addTearDown(targetWorkspaceStore.dispose);

    final importResult = await service.importPackage(
      draftStore: targetDraftStore,
      versionStore: targetVersionStore,
      workspaceStore: targetWorkspaceStore,
    );
    expect(importResult.state, ProjectTransferState.importSuccess);
    expect(targetDraftStore.snapshot.text, 'checksum round-trip draft');
  });

  test(
    'import accepts packages without checksums.json for backward compatibility',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_project_transfer_no_checksums_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final service = ProjectTransferService(
        exportsDirectory: Directory('${directory.path}/exports'),
        importsDirectory: Directory('${directory.path}/imports'),
      );
      final exportFile = await _exportRealPackageZip(
        directory: directory,
        service: service,
      );
      final noChecksumsPackage = await _rewritePackage(
        sourceZip: exportFile,
        targetZipPath: service.importPackagePath,
        mutate: (staging) async {
          final manifestFile = File('${staging.path}/manifest.json');
          final manifest =
              jsonDecode(await manifestFile.readAsString())
                  as Map<String, Object?>;
          manifest['project_id'] = 'project-no-checksums';
          await manifestFile.writeAsString(jsonEncode(manifest));
          final checksumsFile = File('${staging.path}/checksums.json');
          if (await checksumsFile.exists()) {
            await checksumsFile.delete();
          }
        },
      );
      expect(await noChecksumsPackage.exists(), isTrue);

      final targetDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
      );
      final targetVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
      );
      final targetWorkspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      addTearDown(targetDraftStore.dispose);
      addTearDown(targetVersionStore.dispose);
      addTearDown(targetWorkspaceStore.dispose);

      final result = await service.importPackage(
        draftStore: targetDraftStore,
        versionStore: targetVersionStore,
        workspaceStore: targetWorkspaceStore,
      );
      expect(result.state, ProjectTransferState.importSuccess);
      expect(targetDraftStore.snapshot.text, '真实导出草稿');
    },
  );
}

Future<File> _exportRealPackageZip({
  required Directory directory,
  required ProjectTransferService service,
}) async {
  final draftStore = AppDraftStore(storage: InMemoryAppDraftStorage());
  final versionStore = AppVersionStore(storage: InMemoryAppVersionStorage());
  final workspaceStore = AppWorkspaceStore(
    storage: InMemoryAppWorkspaceStorage(),
  );

  draftStore.updateText('真实导出草稿');
  versionStore.captureSnapshot(label: '导出版本', content: '导出版本内容');
  workspaceStore.createProject();

  final result = await service.exportPackage(
    draftStore: draftStore,
    versionStore: versionStore,
    workspaceStore: workspaceStore,
  );

  draftStore.dispose();
  versionStore.dispose();
  workspaceStore.dispose();

  expect(result.state, ProjectTransferState.exportSuccess);
  return File(result.packagePath);
}

Future<bool> _packageContains(String packagePath, String relativePath) async {
  final extraction = await Directory.systemTemp.createTemp(
    'novel_writer_project_transfer_package_contains',
  );
  try {
    final unzip = await Process.run('/usr/bin/unzip', [
      '-oq',
      packagePath,
      '-d',
      extraction.path,
    ]);
    expect(unzip.exitCode, 0);
    return File('${extraction.path}/$relativePath').exists();
  } finally {
    if (await extraction.exists()) {
      await extraction.delete(recursive: true);
    }
  }
}

Future<Map<String, Object?>> _readPackageJson(
  String packagePath,
  String relativePath,
) async {
  final extraction = await Directory.systemTemp.createTemp(
    'novel_writer_project_transfer_package_json',
  );
  try {
    final unzip = await Process.run('/usr/bin/unzip', [
      '-oq',
      packagePath,
      '-d',
      extraction.path,
    ]);
    expect(unzip.exitCode, 0);
    return decodeProjectTransferObjectMap(
      jsonDecode(await File('${extraction.path}/$relativePath').readAsString()),
    );
  } finally {
    if (await extraction.exists()) {
      await extraction.delete(recursive: true);
    }
  }
}

Future<File> _rewritePackage({
  required File sourceZip,
  required String targetZipPath,
  required Future<void> Function(Directory staging) mutate,
  bool preserveChecksums = false,
}) async {
  final extraction = await Directory.systemTemp.createTemp(
    'novel_writer_project_transfer_rewrite_extract',
  );
  final staging = await Directory.systemTemp.createTemp(
    'novel_writer_project_transfer_rewrite_stage',
  );

  try {
    final unzip = await Process.run('/usr/bin/unzip', [
      '-oq',
      sourceZip.path,
      '-d',
      extraction.path,
    ]);
    expect(unzip.exitCode, 0);

    for (final entity in extraction.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relativePath = entity.path.substring(extraction.path.length + 1);
      final targetFile = File('${staging.path}/$relativePath');
      await targetFile.parent.create(recursive: true);
      await entity.copy(targetFile.path);
    }

    await mutate(staging);

    if (!preserveChecksums) {
      final checksumsFile = File('${staging.path}/checksums.json');
      if (await checksumsFile.exists()) {
        await checksumsFile.delete();
      }
    }

    final output = File(targetZipPath);
    await output.parent.create(recursive: true);
    if (await output.exists()) {
      await output.delete();
    }

    final zip = await Process.run('/usr/bin/zip', [
      '-qr',
      output.path,
      '.',
    ], workingDirectory: staging.path);
    expect(zip.exitCode, 0);
    return output;
  } finally {
    if (await extraction.exists()) {
      await extraction.delete(recursive: true);
    }
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }
}

List<AppEventLogEntry> _entriesForAction(
  List<AppEventLogEntry> entries,
  String action,
) {
  return entries.where((entry) => entry.action == action).toList();
}

class _RecordingAppEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}

class _ThrowingAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) {
    throw StateError('log write failed');
  }
}
