import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/state/app_ai_history_storage_io.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage_io.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage_io.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_storage_io.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_storage_io.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_storage_io.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_storage_io.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/import_export/data/project_transfer_service.dart';
import 'package:novel_writer/features/story_generation/data/artifact_recorder.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_scheduler.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

const int _maxTransportRetriesPerScene = 6;
const int _maxConcurrentSceneRuns = 2;

void main() {
  test('phase 3 persists resonance world outline into workspace scenes', () {
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    addTearDown(workspaceStore.dispose);

    workspaceStore.createProject();
    _applyChapterOutlineToWorkspaceStore(
      workspaceStore: workspaceStore,
      chapters: _validationChapters,
    );

    final scenes = workspaceStore.scenes;
    expect(scenes, hasLength(1));
    expect(scenes.first.title, '第一章 无声的共振层');
    expect(scenes.first.chapterLabel, '第 1 章');
    expect(scenes.first.summary, contains('章节目标：'));
    expect(scenes.first.summary, contains('主要冲突：'));
    expect(scenes.first.summary, contains('转折点：'));
    expect(scenes.first.summary, contains('结尾钩子：'));
  });

  test('phase 3 real outline prompt asks for verifiable chapter beats', () {
    final prompt = _realOutlinePrompt(_validationChapters);

    expect(prompt, contains('章节目标'));
    expect(prompt, contains('主要冲突'));
    expect(prompt, contains('转折点'));
    expect(prompt, contains('结尾钩子'));
    expect(prompt, contains('只规划一章'));
  });

  test(
    'real resonance world one chapter generation leaves visible artifacts',
    () async {
      if (Platform.environment['RUN_REAL_STORY_VALIDATION'] != '1') {
        markTestSkipped(
          'Set RUN_REAL_STORY_VALIDATION=1 to run the real provider validation.',
        );
        return;
      }

      final result = await _runRealOneChapterValidation();

      expect(result.chapterSummaries, hasLength(1));
      expect(result.exportState, ProjectTransferState.exportSuccess);
      expect(result.importState, ProjectTransferState.importSuccess);
      expect(result.importedOutlineChapterCount, 1);
      expect(result.importedGenerationChapterCount, 1);
      expect(
        File('${result.outputRoot.path}/chapters/chapter-01.md').existsSync(),
        isTrue,
      );
      expect(
        File('${result.outputRoot.path}/reports/run-report.md').existsSync(),
        isTrue,
      );
      expect(
        File('${result.outputRoot.path}/run-report.md').existsSync(),
        isTrue,
      );
      expect(
        File(
          '${result.outputRoot.path}/reports/artifact-index.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${result.outputRoot.path}/outline/resonance_outline.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File('${result.outputRoot.path}/runtime/live-status.md').existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 60)),
  );
}

Future<_RealValidationResult> _runRealOneChapterValidation() async {
  final settingFile = File('setting.json');
  if (!await settingFile.exists()) {
    fail('setting.json is required for the real validation run.');
  }

  final localConfig = _loadLocalConfig(file: settingFile);
  final resolvedSettings = _resolveRealSettings(
    environment: Platform.environment,
    localConfig: localConfig,
  );
  if (resolvedSettings.apiKey.isEmpty) {
    fail('Missing OLLAMA_API_KEY in setting.json or the environment.');
  }

  final outputRoot = Directory('artifacts/real_validation/resonance_world');

  String? cachedOutline;
  final existingOutline = File(
    '${outputRoot.path}/outline/resonance_outline.md',
  );
  if (await existingOutline.exists()) {
    cachedOutline = await existingOutline.readAsString();
  }

  if (await outputRoot.exists()) {
    await outputRoot.delete(recursive: true);
  }
  await outputRoot.create(recursive: true);

  final runtimeDirectory = Directory('${outputRoot.path}/runtime');
  final sourceDirectory = Directory('${outputRoot.path}/source');
  final sourcePaths = _ValidationSourcePaths.fromDirectory(sourceDirectory);
  final statusReporter = _LiveStatusReporter(
    runtimeDirectory: runtimeDirectory,
  );
  await statusReporter.update(
    phase: 'initializing',
    detail: 'Preparing resonance world one-chapter validation workspace.',
  );
  final logsDirectory = Directory(sourcePaths.logsDirectoryPath);
  final telemetryDbPath = sourcePaths.telemetryDbPath;
  final eventLog = AppEventLog(
    storage: createTestAppEventLogStorage(
      sqlitePath: telemetryDbPath,
      logsDirectory: logsDirectory,
    ),
    sessionId: 'resonance-world-one-chapter-validation',
  );
  final settingsStore = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    eventLog: eventLog,
  );
  final recorder = ArtifactRecorder(rootDirectory: outputRoot);

  final workspaceStore = AppWorkspaceStore(
    storage: SqliteAppWorkspaceStorage(dbPath: sourcePaths.authoringDbPath),
  );
  final draftStore = AppDraftStore(
    storage: SqliteAppDraftStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final aiHistoryStore = AppAiHistoryStore(
    storage: SqliteAppAiHistoryStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final sceneContextStore = AppSceneContextStore(
    storage: SqliteAppSceneContextStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final versionStore = AppVersionStore(
    storage: SqliteAppVersionStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final outlineStore = StoryOutlineStore(
    storage: SqliteStoryOutlineStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final generationStore = StoryGenerationStore(
    storage: SqliteStoryGenerationStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final simulationStore = AppSimulationStore(
    storage: SqliteAppSimulationStorage(dbPath: sourcePaths.simulationDbPath),
    workspaceStore: workspaceStore,
    eventLog: eventLog,
  );

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
  final targetSimulationStore = AppSimulationStore(
    storage: InMemoryAppSimulationStorage(),
    workspaceStore: targetWorkspaceStore,
  );

  var sourceStoresDisposed = false;
  _RecoveredValidationStores? recoveredSourceStores;

  try {
    await statusReporter.update(
      phase: 'configuring-model',
      detail:
          'Saving settings and testing connection for kimi-k2.6 '
          '(timeout ${resolvedSettings.timeoutMs}ms, '
          'max concurrent ${resolvedSettings.maxConcurrentRequests}).',
    );
    final configuredModel = await _configureRealSettings(
      settingsStore: settingsStore,
      resolvedSettings: resolvedSettings,
    );
    await _writeSanitizedSettingsSnapshot(
      runtimeDirectory: runtimeDirectory,
      resolvedSettings: resolvedSettings,
      configuredModel: configuredModel,
    );

    workspaceStore.createProject();
    final projectId = workspaceStore.currentProjectId;
    _applyValidationResourcesToWorkspaceStore(
      workspaceStore: workspaceStore,
      chapters: _validationChapters,
    );
    sceneContextStore.syncContext();

    await statusReporter.update(
      phase: 'writing-inputs',
      detail: cachedOutline != null
          ? 'Writing world bible and character profiles; reusing cached outline.'
          : 'Writing resonance world bible and character profiles, then generating the outline.',
    );
    await recorder.recordReport(
      relativePath: 'inputs/world_bible.md',
      content: _worldBibleMarkdown(),
    );
    await recorder.recordReport(
      relativePath: 'inputs/character_profiles.md',
      content: _characterProfilesMarkdown(_validationChapters),
    );
    final realOutlineMarkdown =
        cachedOutline ??
        await _generateRealOneChapterOutline(
          settingsStore: settingsStore,
          chapters: _validationChapters,
        );
    await recorder.recordReport(
      relativePath: 'inputs/resonance_outline.md',
      content: realOutlineMarkdown,
    );
    await recorder.recordReport(
      relativePath: 'outline/resonance_outline.md',
      content: realOutlineMarkdown,
    );
    _applyChapterOutlineToWorkspaceStore(
      workspaceStore: workspaceStore,
      chapters: _validationChapters,
    );
    sceneContextStore.syncContext();
    expect(workspaceStore.scenes, hasLength(1));

    outlineStore.replaceSnapshot(
      StoryOutlineSnapshot(
        projectId: projectId,
        metadata: {
          'validationRun': 'resonance-world-one-chapter',
          'generatedAt': DateTime.now().toIso8601String(),
        },
        chapters: [
          for (final chapter in _validationChapters)
            StoryOutlineChapterSnapshot(
              id: chapter.id,
              title: chapter.title,
              summary: chapter.summary,
              metadata: Map<String, Object?>.from(chapter.metadata),
              scenes: [
                for (final scene in chapter.scenes)
                  StoryOutlineSceneSnapshot(
                    id: scene.id,
                    title: scene.title,
                    summary: scene.summary,
                    metadata: {
                      'worldNodeIds': scene.worldNodeIds,
                      'targetBeat': scene.targetBeat,
                    },
                    cast: [
                      for (final cast in scene.cast)
                        StoryOutlineCastSnapshot(
                          characterId: cast.characterId,
                          name: cast.name,
                          role: cast.role,
                          metadata: Map<String, Object?>.from(cast.metadata),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );

    ChapterGenerationOrchestrator createSceneOrchestrator() =>
        ChapterGenerationOrchestrator(
          settingsStore: settingsStore,
          maxProseRetries: 2,
        );
    final chapterSummaries = <_ValidationChapterSummary>[];
    final chapterStates = <StoryChapterGenerationState>[];
    final bookBuffer = StringBuffer();

    for (final chapter in _validationChapters) {
      await statusReporter.update(
        phase: 'chapter-start',
        detail: 'Starting ${chapter.id} ${chapter.title}.',
      );
      _selectWorkspaceSceneForChapter(
        workspaceStore: workspaceStore,
        chapter: chapter,
      );
      sceneContextStore.syncContext();
      final simulationSession = await _runChapterSimulation(
        settingsStore: settingsStore,
        simulationStore: simulationStore,
        chapter: chapter,
        eventLog: eventLog,
      );
      await recorder.recordReport(
        relativePath: _chapterSimulationRelativePath(chapter),
        content: simulationSession.markdown,
      );
      await statusReporter.update(
        phase: 'chapter-simulation-complete',
        detail:
            'Completed real multi-agent simulation for ${chapter.id} '
            'with ${simulationSession.messages.length} messages.',
      );

      final sceneExecutions = await _runChapterScenesWithEscalation(
        orchestratorFactory: createSceneOrchestrator,
        statusReporter: statusReporter,
        chapter: chapter,
        chapterSimulationInput: simulationSession.proseInput,
      );
      for (final execution in sceneExecutions) {
        await recorder.recordReport(
          relativePath: 'reviews/${chapter.id}-${execution.scene.id}.md',
          content: _sceneReviewMarkdown(
            chapter: chapter,
            scene: execution.scene,
            execution: execution,
          ),
        );
      }

      final chapterText = _chapterMarkdown(
        chapter: chapter,
        sceneExecutions: sceneExecutions,
      );
      await statusReporter.update(
        phase: 'chapter-written',
        detail:
            'Wrote ${chapter.id} with ${chapterText.trim().length} characters.',
      );
      await recorder.recordChapterText(
        chapterId: chapter.id,
        text: chapterText,
      );
      await versionStore.captureSnapshotAndPersist(
        label: chapter.title,
        content: chapterText,
      );
      aiHistoryStore.addEntry(
        mode: '真实正文生成',
        prompt:
            '${chapter.title} generated from outline, world bible, '
            'characters, and ${simulationSession.messages.length} '
            'real multi-agent messages.',
      );
      final summary = _ValidationChapterSummary(
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        sceneCount: sceneExecutions.length,
        sceneSummaries: [
          for (final execution in sceneExecutions)
            '${execution.scene.title}：${execution.scene.summary}',
        ],
        actualLength: chapterText.trim().length,
        reviewPassed: sceneExecutions.every(
          (execution) =>
              execution.output.review.decision == SceneReviewDecision.pass,
        ),
        fullRunRestarts: sceneExecutions.fold<int>(
          0,
          (sum, execution) => sum + execution.fullRunRestarts,
        ),
        proseRetryCount: sceneExecutions.fold<int>(
          0,
          (sum, execution) => sum + execution.output.softFailureCount,
        ),
        simulationMessageCount: simulationSession.messages.length,
      );
      chapterSummaries.add(summary);
      chapterStates.add(
        StoryChapterGenerationState(
          chapterId: chapter.id,
          status: summary.reviewPassed
              ? StoryChapterGenerationStatus.passed
              : StoryChapterGenerationStatus.blocked,
          targetLength: chapter.targetLength,
          actualLength: summary.actualLength,
          participatingRoleIds: _distinctStrings([
            for (final execution in sceneExecutions)
              for (final cast in execution.output.resolvedCast)
                cast.characterId,
          ]),
          worldNodeIds: _distinctStrings([
            for (final scene in chapter.scenes) ...scene.worldNodeIds,
          ]),
          scenes: [
            for (final execution in sceneExecutions)
              StorySceneGenerationState(
                sceneId: execution.output.brief.sceneId,
                status:
                    execution.output.review.decision == SceneReviewDecision.pass
                    ? StorySceneGenerationStatus.passed
                    : StorySceneGenerationStatus.blocked,
                judgeStatus: _mapReviewStatus(
                  execution.output.review.judge.status,
                ),
                consistencyStatus: _mapReviewStatus(
                  execution.output.review.consistency.status,
                ),
                proseRetryCount: execution.output.softFailureCount,
                directorRetryCount: execution.fullRunRestarts,
                castRoleIds: [
                  for (final cast in execution.output.resolvedCast)
                    cast.characterId,
                ],
                worldNodeIds: execution.scene.worldNodeIds,
                upstreamFingerprint:
                    '${chapter.id}:${execution.scene.id}:'
                    '${execution.fullRunRestarts}:${execution.output.proseAttempts}',
              ),
          ],
        ),
      );
      if (bookBuffer.isNotEmpty) {
        bookBuffer.writeln('\n');
      }
      bookBuffer.write(chapterText.trim());
    }

    await draftStore.updateTextAndPersist(bookBuffer.toString().trim());
    generationStore.replaceSnapshot(
      StoryGenerationSnapshot(projectId: projectId, chapters: chapterStates),
    );
    await generationStore.waitUntilReady();
    await _waitForStorePersistence();

    await statusReporter.update(
      phase: 'phase-7-recovery',
      detail: 'Reopening source sqlite files and verifying persisted stores.',
    );
    workspaceStore.dispose();
    draftStore.dispose();
    aiHistoryStore.dispose();
    sceneContextStore.dispose();
    versionStore.dispose();
    outlineStore.dispose();
    generationStore.dispose();
    simulationStore.dispose();
    sourceStoresDisposed = true;

    recoveredSourceStores = await _openAndVerifyRecoveredSourceStores(
      sourcePaths: sourcePaths,
      expectedChapterTitles: [
        for (final chapter in _validationChapters) chapter.title,
      ],
    );
    final recoveredStores = recoveredSourceStores;
    final recovery = recoveredStores.recovery;

    await statusReporter.update(
      phase: 'exporting',
      detail:
          'Phase 7 recovered ${recovery.chapterCount} scenes, '
          '${recovery.aiHistoryCount} AI history rows, and '
          '${recovery.simulationMessageCount} simulation messages. '
          'Exporting source package.',
    );
    final transferService = ProjectTransferService(
      exportsDirectory: Directory('${outputRoot.path}/exports'),
      importsDirectory: Directory('${outputRoot.path}/imports'),
      eventLog: eventLog,
    );
    final exportResult = await transferService.exportPackage(
      draftStore: recoveredStores.draftStore,
      versionStore: recoveredStores.versionStore,
      workspaceStore: recoveredStores.workspaceStore,
      storyOutlineStore: recoveredStores.outlineStore,
      storyGenerationStore: recoveredStores.generationStore,
      simulationStore: recoveredStores.simulationStore,
    );
    if (exportResult.state != ProjectTransferState.exportSuccess) {
      fail('Export failed with state: ${exportResult.state}.');
    }

    final importFile = File(transferService.importPackagePath);
    await importFile.parent.create(recursive: true);
    await File(exportResult.packagePath).copy(importFile.path);

    await statusReporter.update(
      phase: 'importing',
      detail: 'Importing the package into target stores for verification.',
    );
    final importResult = await transferService.importPackage(
      draftStore: targetDraftStore,
      versionStore: targetVersionStore,
      workspaceStore: targetWorkspaceStore,
      storyOutlineStore: targetOutlineStore,
      storyGenerationStore: targetGenerationStore,
      simulationStore: targetSimulationStore,
    );
    if (importResult.state != ProjectTransferState.importSuccess) {
      fail('Import failed with state: ${importResult.state}.');
    }
    await targetGenerationStore.waitUntilReady();

    expect(targetOutlineStore.snapshot.chapters, hasLength(1));
    expect(targetGenerationStore.snapshot.chapters, hasLength(1));
    expect(targetSimulationStore.snapshot.status, SimulationStatus.completed);
    expect(
      targetSimulationStore.snapshot.messages.length,
      greaterThanOrEqualTo(3),
    );

    await _waitForEventArtifacts(
      telemetryDbPath: telemetryDbPath,
      logsDirectory: logsDirectory,
    );
    final telemetryRows = await _readTelemetryCount(telemetryDbPath);
    final jsonlCount = await _readJsonlCount(logsDirectory);

    final runReportMarkdown = _runReportMarkdown(
      resolvedSettings: resolvedSettings,
      configuredModel: configuredModel,
      chapterSummaries: chapterSummaries,
      sourceRecovery: recovery,
      exportResult: exportResult,
      importResult: importResult,
      importedOutlineChapterCount: targetOutlineStore.snapshot.chapters.length,
      importedGenerationChapterCount:
          targetGenerationStore.snapshot.chapters.length,
      importedSimulationMessageCount:
          targetSimulationStore.snapshot.messages.length,
      telemetryRows: telemetryRows,
      jsonlCount: jsonlCount,
    );
    await recorder.recordReport(
      relativePath: 'run-report.md',
      content: runReportMarkdown,
    );
    await recorder.recordReport(
      relativePath: 'reports/run-report.md',
      content: runReportMarkdown,
    );
    await recorder.recordReport(
      relativePath: 'reports/artifact-index.md',
      content: await _artifactIndexMarkdown(outputRoot),
    );
    await statusReporter.update(
      phase: 'completed',
      detail: 'Resonance world one-chapter validation completed successfully.',
    );

    stdout.writeln('Resonance world one-chapter validation passed.');
    stdout.writeln('Artifact root: ${outputRoot.path}');
    stdout.writeln('Resolved model: ${configuredModel.model}');
    stdout.writeln('Telemetry rows: $telemetryRows');
    stdout.writeln('JSONL lines: $jsonlCount');

    return _RealValidationResult(
      outputRoot: outputRoot,
      chapterSummaries: chapterSummaries,
      exportState: exportResult.state,
      importState: importResult.state,
      importedOutlineChapterCount: targetOutlineStore.snapshot.chapters.length,
      importedGenerationChapterCount:
          targetGenerationStore.snapshot.chapters.length,
    );
  } finally {
    settingsStore.dispose();
    if (!sourceStoresDisposed) {
      workspaceStore.dispose();
      draftStore.dispose();
      aiHistoryStore.dispose();
      sceneContextStore.dispose();
      versionStore.dispose();
      outlineStore.dispose();
      generationStore.dispose();
      simulationStore.dispose();
    }
    recoveredSourceStores?.dispose();
    targetWorkspaceStore.dispose();
    targetDraftStore.dispose();
    targetVersionStore.dispose();
    targetOutlineStore.dispose();
    targetGenerationStore.dispose();
    targetSimulationStore.dispose();
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _ValidationSourcePaths {
  const _ValidationSourcePaths({
    required this.authoringDbPath,
    required this.simulationDbPath,
    required this.telemetryDbPath,
    required this.logsDirectoryPath,
  });

  factory _ValidationSourcePaths.fromDirectory(Directory sourceDirectory) {
    return _ValidationSourcePaths(
      authoringDbPath: '${sourceDirectory.path}/authoring.db',
      simulationDbPath: '${sourceDirectory.path}/simulation.db',
      telemetryDbPath: '${sourceDirectory.path}/telemetry.db',
      logsDirectoryPath: '${sourceDirectory.path}/logs',
    );
  }

  final String authoringDbPath;
  final String simulationDbPath;
  final String telemetryDbPath;
  final String logsDirectoryPath;
}

class _SourceRecoverySummary {
  const _SourceRecoverySummary({
    required this.chapterCount,
    required this.characterCount,
    required this.worldNodeCount,
    required this.aiHistoryCount,
    required this.versionCount,
    required this.simulationMessageCount,
  });

  final int chapterCount;
  final int characterCount;
  final int worldNodeCount;
  final int aiHistoryCount;
  final int versionCount;
  final int simulationMessageCount;
}

class _RecoveredValidationStores {
  const _RecoveredValidationStores({
    required this.workspaceStore,
    required this.draftStore,
    required this.aiHistoryStore,
    required this.sceneContextStore,
    required this.versionStore,
    required this.outlineStore,
    required this.generationStore,
    required this.simulationStore,
    required this.recovery,
  });

  final AppWorkspaceStore workspaceStore;
  final AppDraftStore draftStore;
  final AppAiHistoryStore aiHistoryStore;
  final AppSceneContextStore sceneContextStore;
  final AppVersionStore versionStore;
  final StoryOutlineStore outlineStore;
  final StoryGenerationStore generationStore;
  final AppSimulationStore simulationStore;
  final _SourceRecoverySummary recovery;

  void dispose() {
    workspaceStore.dispose();
    draftStore.dispose();
    aiHistoryStore.dispose();
    sceneContextStore.dispose();
    versionStore.dispose();
    outlineStore.dispose();
    generationStore.dispose();
    simulationStore.dispose();
  }
}

class _ResolvedRealSettings {
  const _ResolvedRealSettings({
    required this.providerName,
    required this.baseUrl,
    required this.apiKey,
    required this.candidateModels,
    required this.maxConcurrentRequests,
    required this.timeoutMs,
    required this.configSource,
  });

  final String providerName;
  final String baseUrl;
  final String apiKey;
  final List<String> candidateModels;
  final int maxConcurrentRequests;
  final int timeoutMs;
  final String configSource;
}

class _ConfiguredModel {
  const _ConfiguredModel({
    required this.model,
    required this.connectionMessage,
  });

  final String model;
  final String connectionMessage;
}

class _ValidationChapter {
  const _ValidationChapter({
    required this.id,
    required this.title,
    required this.summary,
    required this.targetLength,
    required this.metadata,
    required this.scenes,
  });

  final String id;
  final String title;
  final String summary;
  final int targetLength;
  final Map<String, Object?> metadata;
  final List<_ValidationScene> scenes;
}

class _ValidationScene {
  const _ValidationScene({
    required this.id,
    required this.title,
    required this.targetLength,
    required this.summary,
    required this.targetBeat,
    required this.worldNodeIds,
    required this.cast,
  });

  final String id;
  final String title;
  final int targetLength;
  final String summary;
  final String targetBeat;
  final List<String> worldNodeIds;
  final List<_ValidationCast> cast;
}

class _ValidationCast {
  const _ValidationCast({
    required this.characterId,
    required this.name,
    required this.role,
    required this.participation,
    required this.metadata,
  });

  final String characterId;
  final String name;
  final String role;
  final SceneCastParticipation participation;
  final Map<String, Object?> metadata;
}

class _SceneExecutionResult {
  const _SceneExecutionResult({
    required this.scene,
    required this.output,
    required this.fullRunRestarts,
    required this.restartNotes,
  });

  final _ValidationScene scene;
  final SceneRuntimeOutput output;
  final int fullRunRestarts;
  final List<String> restartNotes;
}

class _ValidationChapterSummary {
  const _ValidationChapterSummary({
    required this.chapterId,
    required this.chapterTitle,
    required this.sceneCount,
    required this.sceneSummaries,
    required this.actualLength,
    required this.reviewPassed,
    required this.fullRunRestarts,
    required this.proseRetryCount,
    required this.simulationMessageCount,
  });

  final String chapterId;
  final String chapterTitle;
  final int sceneCount;
  final List<String> sceneSummaries;
  final int actualLength;
  final bool reviewPassed;
  final int fullRunRestarts;
  final int proseRetryCount;
  final int simulationMessageCount;
}

class _ChapterSimulationSession {
  const _ChapterSimulationSession({
    required this.chapterId,
    required this.chapterTitle,
    required this.messages,
  });

  final String chapterId;
  final String chapterTitle;
  final List<SimulationChatMessage> messages;

  String get proseInput {
    return [
      '真实多 Agent 模拟输入：',
      for (final message in messages)
        '- ${message.sender} / ${message.title}：${message.body}',
    ].join('\n');
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# $chapterTitle Phase 5 多 Agent 真实模拟')
      ..writeln()
      ..writeln('- Chapter ID: `$chapterId`')
      ..writeln('- Agent count: 3')
      ..writeln('- Rounds: 2')
      ..writeln('- Message count: ${messages.length}')
      ..writeln();
    for (final message in messages) {
      buffer
        ..writeln('## ${message.title}')
        ..writeln()
        ..writeln('- Sender: `${message.sender}`')
        ..writeln('- Kind: `${message.kind.name}`')
        ..writeln()
        ..writeln(message.body.trim())
        ..writeln();
    }
    buffer
      ..writeln('## 正文生成输入')
      ..writeln()
      ..writeln(proseInput);
    return buffer.toString().trimRight();
  }
}

class _RealValidationResult {
  const _RealValidationResult({
    required this.outputRoot,
    required this.chapterSummaries,
    required this.exportState,
    required this.importState,
    required this.importedOutlineChapterCount,
    required this.importedGenerationChapterCount,
  });

  final Directory outputRoot;
  final List<_ValidationChapterSummary> chapterSummaries;
  final ProjectTransferState exportState;
  final ProjectTransferState importState;
  final int importedOutlineChapterCount;
  final int importedGenerationChapterCount;
}

class _LiveStatusReporter {
  _LiveStatusReporter({required this.runtimeDirectory})
    : _startedAt = DateTime.now();

  final Directory runtimeDirectory;
  final DateTime _startedAt;

  Future<void> update({required String phase, required String detail}) async {
    final now = DateTime.now();
    final elapsed = now.difference(_startedAt);
    final payload = {
      'phase': phase,
      'detail': detail,
      'timestamp': now.toIso8601String(),
      'elapsedSeconds': elapsed.inSeconds,
    };
    final jsonFile = File('${runtimeDirectory.path}/live-status.json');
    final markdownFile = File('${runtimeDirectory.path}/live-status.md');
    await jsonFile.parent.create(recursive: true);
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    await markdownFile.writeAsString(
      [
        '# Live Status',
        '',
        '- Phase: `$phase`',
        '- Detail: $detail',
        '- Timestamp: ${now.toIso8601String()}',
        '- Elapsed seconds: ${elapsed.inSeconds}',
      ].join('\n'),
    );
    stdout.writeln('[live-status] $phase :: $detail');
  }
}

// ---------------------------------------------------------------------------
// World data: resonance world
// ---------------------------------------------------------------------------

const List<_ValidationChapter> _validationChapters = [
  _ValidationChapter(
    id: 'chapter-01',
    title: '第一章 无声的共振层',
    summary:
        '调音师陆沉凌晨接到公寓噪音污染报案，前往倒悬珊瑚都市的一处旧区。'
        '受害者嘴被缝合却在笑，谐振器开启后听到"寂静"中藏着的几十个已故亲人声音。',
    targetLength: 2400,
    metadata: {'worldNode': 'bone-city'},
    scenes: [
      _ValidationScene(
        id: 'scene-01',
        title: '凌晨出警',
        targetLength: 800,
        summary:
            '凌晨三点，陆沉接到调度中心的噪音污染指令，前往巨兽骸骨脊椎下段的一处旧公寓。'
            '倒悬城市里，人们行走在天花板上，脚下是深渊般的"天空"。'
            '谐振器在胸口低频嗡鸣，最近越来越不稳定。',
        targetBeat: '建立共振层世界观基调：倒悬城市、谐振器、深渊天空，以及陆沉作为老调音师的疲惫感。',
        worldNodeIds: ['resonance-layer', 'bone-city'],
        cast: [
          _ValidationCast(
            characterId: 'luchen',
            name: '陆沉',
            role: '调音师',
            participation: SceneCastParticipation(
              action: '穿行在倒悬走廊中，调低谐振器灵敏度避免杂音干扰',
              interaction: '对调度中心的机械指令漠不关心，只关心案发地点的声波频谱记录',
            ),
            metadata: {'tag': '不稳定的老手'},
          ),
          _ValidationCast(
            characterId: 'dispatcher-zhong',
            name: '钟姐',
            role: '调度员',
            participation: SceneCastParticipation(
              dialogue: '提醒陆沉这已经是本周第三次出警，建议他做一次谐振器校准',
              interaction: '通过通讯器传达噪音污染的具体频段数据，暗示这次频率异常',
            ),
            metadata: {'tag': '知情者'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-02',
        title: '被缝嘴的笑者',
        targetLength: 800,
        summary:
            '陆沉抵达案发现场——一间附着在巨兽肋骨缝隙间的狭窄公寓。'
            '受害者坐在椅子上，嘴被粗糙的骨线缝合，但面部肌肉呈现诡异的笑容。'
            '陆沉打开谐振器扫描声波残留，本以为会检测到噪音污染源的频率，'
            '却听到了"绝对的寂静"——而寂静里藏着几十个声音。',
        targetBeat: '核心恐怖揭示：打开谐振器后，寂静不是空无，而是几十个已故亲人的声音隔着维度叫你的名字。',
        worldNodeIds: ['resonance-layer', 'bone-city'],
        cast: [
          _ValidationCast(
            characterId: 'luchen',
            name: '陆沉',
            role: '调音师',
            participation: SceneCastParticipation(
              action: '打开谐振器进行声波残留扫描，发现频率异常后强制自己不关机',
              dialogue: '对着缝合嘴的尸体低声说"你不是受害者，你是容器"',
            ),
            metadata: {'tag': '直面深渊的人'},
          ),
          _ValidationCast(
            characterId: 'victim-chen',
            name: '陈默',
            role: '受害者',
            participation: SceneCastParticipation(
              interaction: '缝合的嘴角渗出黑色液体，谐振器检测到他体内残留着多个叠加的声纹',
            ),
            metadata: {'tag': '声波容器'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-03',
        title: '亲人的回响',
        targetLength: 800,
        summary:
            '陆沉深入解析声波残留，发现几十个声纹中有一个是他已故母亲的声音。'
            '谐振器开始剧烈震荡，频率怪物"回响体"的征兆出现——'
            '声波被切碎重组，维度裂缝在公寓墙壁上若隐若现。'
            '陆沉必须在谐振器失控前完成现场取证并撤离，'
            '同时抵抗维度裂缝中亲人声音的致命吸引力。',
        targetBeat:
            '转折与悬念：陆沉听到了母亲的声音，险些被维度裂缝吞噬。'
            '完成取证后撤出公寓，但谐振器的不稳定加剧了——'
            '他开始怀疑巨兽骸骨本身在做梦，而这些声音是它的梦话。',
        worldNodeIds: ['resonance-layer', 'rot-ocean'],
        cast: [
          _ValidationCast(
            characterId: 'luchen',
            name: '陆沉',
            role: '调音师',
            participation: SceneCastParticipation(
              action: '用专业手法锁定声波取证后强制关闭谐振器撤离现场',
              dialogue: '低声自语"妈，那不是你"来抵抗维度裂缝的吸引',
              interaction: '撤出公寓时注意到巨兽骸骨的脊椎传来极低频的震颤——像心跳',
            ),
            metadata: {'tag': '被深渊凝视的人'},
          ),
          _ValidationCast(
            characterId: 'echo-mother',
            name: '母亲回响',
            role: '回响体',
            participation: SceneCastParticipation(
              dialogue: '从维度裂缝中传来"沉沉，回家吃饭"——完全还原生前语气',
              interaction: '声波频率与陆沉的谐振器产生共振，试图将他拉入裂缝',
            ),
            metadata: {'tag': '致命诱惑'},
          ),
        ],
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// World bible & character profiles
// ---------------------------------------------------------------------------

String _worldBibleMarkdown() {
  return [
    '# 世界设定：无声的共振层',
    '',
    '- 核心概念：声音即实体，沉默即深渊。声音是有质量的物理实体。',
    '- 谐振器：人类喉咙或胸口的机械装置，过滤杂音，防止因听到地底古神低语而脑死亡。',
    '- 地理：倒悬的珊瑚都市。地表是"腐烂之海"——胶质海洋，漂浮着古老生物遗骸。',
    '- 人类附着在"巨兽骸骨"的脊椎上，城市像藤壶长在骨头缝隙里。',
    '- 城市倒悬，人们行走在天花板上，深渊在脚下（天空位置）。',
    '- 恐怖来源："频率"怪物。',
    '  - 回响兽：寂静区说话后回声被切碎重组为"回响体"，死后取代家人。',
    '  - 骨传导体：寄生在神经系统，让你听到越来越动听的音乐直到耳膜破裂，头骨变成扩音器。',
    '- 绝对寂静区：意味着某种不可名状的存在正在吞噬物理法则。',
    '- 主角：调音师，去凶杀案现场通过还原"声波残留"破案。',
    '- 看得越多，谐振器越不稳定，开始听到巨兽骸骨本身的梦话。',
    '- 风格要求：中文恐怖悬疑节奏，场景感官化，声效描写必须具体可感，恐惧来自"听到的不可信"。',
  ].join('\n');
}

String _characterProfilesMarkdown(List<_ValidationChapter> chapters) {
  final unique = <String, _ValidationCast>{};
  for (final chapter in chapters) {
    for (final scene in chapter.scenes) {
      for (final cast in scene.cast) {
        unique.putIfAbsent(cast.characterId, () => cast);
      }
    }
  }

  final lines = <String>['# 角色档案', ''];
  for (final cast in unique.values) {
    lines.addAll([
      '## ${cast.name}',
      '',
      '- ID: `${cast.characterId}`',
      '- 身份：${cast.role}',
      '- 标签：${cast.metadata['tag'] ?? '未标注'}',
      '',
    ]);
  }
  return lines.join('\n').trim();
}

// ---------------------------------------------------------------------------
// Outline & prompt helpers
// ---------------------------------------------------------------------------

String _realOutlinePrompt(List<_ValidationChapter> chapters) {
  final seedChapters = chapters
      .map(
        (chapter) => [
          '- ${chapter.title}：${chapter.summary}',
          '  - 关键场景：${chapter.scenes.map((scene) => scene.title).join('、')}',
        ].join('\n'),
      )
      .join('\n');

  return [
    '请基于以下世界观和角色方向，真实规划一个中文恐怖类型小说第一章大纲。',
    '',
    '硬性要求：',
    '- 只规划一章，不要追加第二章或番外。',
    '- 每章必须包含四个字段：章节目标、主要冲突、转折点、结尾钩子。',
    '- 每章要能直接落成一个 AppWorkspaceStore 场景节点。',
    '- 保持恐怖悬疑、调音师、声波残留、维度裂缝的主线连续性。',
    '- 声效描写必须具体可感（频率数值、音色、物理感受）。',
    '',
    '世界观：',
    _worldBibleMarkdown(),
    '',
    '角色：',
    _characterProfilesMarkdown(chapters),
    '',
    '现有验证种子，允许改写但不得偏离主线：',
    seedChapters,
    '',
    '输出格式：',
    '## 第一章 标题',
    '- 章节目标：',
    '- 主要冲突：',
    '- 转折点：',
    '- 结尾钩子：',
  ].join('\n');
}

String _outlineMarkdown(List<_ValidationChapter> chapters) {
  final buffer = StringBuffer()
    ..writeln('# 共振层验证大纲')
    ..writeln();
  for (final chapter in chapters) {
    buffer
      ..writeln('## ${chapter.title} (`${chapter.id}`)')
      ..writeln()
      ..writeln(chapter.summary)
      ..writeln()
      ..writeln('- 目标字数：${chapter.targetLength}')
      ..writeln();
    for (final scene in chapter.scenes) {
      buffer
        ..writeln('### ${scene.title} (`${scene.id}`)')
        ..writeln()
        ..writeln(scene.summary)
        ..writeln()
        ..writeln('- 推进目标：${scene.targetBeat}')
        ..writeln('- 参与角色：${scene.cast.map((cast) => cast.name).join('、')}')
        ..writeln();
    }
  }
  return buffer.toString().trim();
}

// ---------------------------------------------------------------------------
// Store & orchestrator helpers
// ---------------------------------------------------------------------------

Future<String> _generateRealOneChapterOutline({
  required AppSettingsStore settingsStore,
  required List<_ValidationChapter> chapters,
}) async {
  final result = await settingsStore.requestAiCompletion(
    messages: [
      const AppLlmChatMessage(
        role: 'system',
        content: '你是长篇恐怖类型小说大纲编辑。输出必须具体、可执行，声效描写必须可感。避免泛泛而谈。',
      ),
      AppLlmChatMessage(role: 'user', content: _realOutlinePrompt(chapters)),
    ],
  );
  if (!result.succeeded || (result.text ?? '').trim().isEmpty) {
    fail(
      'Real outline generation failed: '
      '${result.failureKind} / ${result.detail}',
    );
  }

  return [
    '# 第一章大纲规划（共振层）',
    '',
    '## 真实 AI 输出',
    '',
    result.text!.trim(),
    '',
    '## Store 持久化镜像',
    '',
    _outlineMarkdown(chapters),
  ].join('\n').trimRight();
}

void _applyValidationResourcesToWorkspaceStore({
  required AppWorkspaceStore workspaceStore,
  required List<_ValidationChapter> chapters,
}) {
  final uniqueCast = <String, _ValidationCast>{};
  final uniqueWorldNodeIds = <String>{};
  for (final chapter in chapters) {
    for (final scene in chapter.scenes) {
      for (final cast in scene.cast) {
        uniqueCast.putIfAbsent(cast.characterId, () => cast);
      }
      uniqueWorldNodeIds.addAll(scene.worldNodeIds);
    }
  }

  for (final cast in uniqueCast.values) {
    workspaceStore.createCharacter();
    final character = workspaceStore.characters.first;
    workspaceStore.updateCharacter(
      characterId: character.id,
      name: cast.name,
      role: cast.role,
      note: '共振层验证角色：${cast.metadata['tag'] ?? cast.role}',
      need: '目标：推进 ${_participationSummary(cast.participation)}',
      summary: '风险与关系：参与共振层一章真实生成验证。',
      referenceSummary: '来源：共振层一章验证角色构建阶段。',
    );
  }

  for (final nodeId in uniqueWorldNodeIds) {
    workspaceStore.createWorldNode();
    final node = workspaceStore.worldNodes.first;
    workspaceStore.updateWorldNode(
      nodeId: node.id,
      title: _worldNodeTitle(nodeId),
      location: '共振层世界观',
      type: '共振层验证节点',
      detail: '节点 `$nodeId` 用于约束一章大纲、角色行动和正文生成。',
      summary: '世界节点 `$nodeId` 已落入可恢复 source authoring.db。',
      ruleSummary: '正文必须遵守此节点的声波规则、地点风险和频率怪物设定。',
      referenceSummary: '来源：共振层一章验证世界观创建阶段。',
    );
  }
}

String _participationSummary(SceneCastParticipation participation) {
  return [
    participation.action,
    participation.dialogue,
    participation.interaction,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join('；');
}

String _worldNodeTitle(String nodeId) {
  return switch (nodeId) {
    'resonance-layer' => '共振层法则',
    'bone-city' => '巨兽骸骨都市',
    'rot-ocean' => '腐烂之海',
    _ => '世界节点 $nodeId',
  };
}

void _applyChapterOutlineToWorkspaceStore({
  required AppWorkspaceStore workspaceStore,
  required List<_ValidationChapter> chapters,
}) {
  if (workspaceStore.currentProjectId.isEmpty || chapters.isEmpty) {
    return;
  }

  while (workspaceStore.scenes.length > 1) {
    final extraScene = workspaceStore.scenes.last;
    workspaceStore.updateCurrentScene(
      sceneId: extraScene.id,
      recentLocation: extraScene.displayLocation,
    );
    workspaceStore.deleteCurrentScene();
  }

  for (var index = 0; index < chapters.length; index += 1) {
    final chapter = chapters[index];
    if (index == 0) {
      final firstScene = workspaceStore.scenes.first;
      workspaceStore.updateCurrentScene(
        sceneId: firstScene.id,
        recentLocation: firstScene.displayLocation,
      );
    } else {
      workspaceStore.createScene(chapter.title);
    }
    workspaceStore.updateCurrentSceneChapterLabel('第 ${index + 1} 章');
    workspaceStore.renameCurrentScene(chapter.title);
    workspaceStore.updateCurrentSceneSummary(_chapterSceneSummary(chapter));
  }
}

String _chapterSceneSummary(_ValidationChapter chapter) {
  final turnScene = chapter.scenes.length >= 3
      ? chapter.scenes[2]
      : chapter.scenes.last;
  final hookScene = chapter.scenes.last;
  return [
    '章节目标：${chapter.summary}',
    '主要冲突：${chapter.scenes.first.summary}',
    '转折点：${turnScene.targetBeat}',
    '结尾钩子：${hookScene.targetBeat}',
  ].join('\n');
}

Future<_ConfiguredModel> _configureRealSettings({
  required AppSettingsStore settingsStore,
  required _ResolvedRealSettings resolvedSettings,
}) async {
  String? lastFailure;
  for (final model in resolvedSettings.candidateModels) {
    await settingsStore.saveWithFeedback(
      providerName: resolvedSettings.providerName,
      baseUrl: resolvedSettings.baseUrl,
      model: model,
      apiKey: resolvedSettings.apiKey,
      timeoutMs: resolvedSettings.timeoutMs,
      maxConcurrentRequests: resolvedSettings.maxConcurrentRequests,
    );
    if (!settingsStore.canRunConnectionTest) {
      lastFailure =
          'Model $model is not ready: ${settingsStore.feedback.message}';
      continue;
    }

    await settingsStore.testConnection(
      baseUrl: resolvedSettings.baseUrl,
      model: model,
      apiKey: resolvedSettings.apiKey,
      timeoutMs: resolvedSettings.timeoutMs,
      maxConcurrentRequests: resolvedSettings.maxConcurrentRequests,
    );
    if (settingsStore.connectionTestState.status ==
        AppSettingsConnectionTestStatus.success) {
      return _ConfiguredModel(
        model: model,
        connectionMessage:
            settingsStore.connectionTestState.message ??
            'Connection succeeded.',
      );
    }
    lastFailure =
        'Connection failed for $model: '
        '${settingsStore.connectionTestState.title} / '
        '${settingsStore.connectionTestState.message}';
  }

  fail(
    'No candidate model succeeded for the real validation run. '
    'Last failure: $lastFailure',
  );
}

void _selectWorkspaceSceneForChapter({
  required AppWorkspaceStore workspaceStore,
  required _ValidationChapter chapter,
}) {
  final scene = workspaceStore.scenes.firstWhere(
    (candidate) => candidate.title == chapter.title,
    orElse: () => workspaceStore.scenes.first,
  );
  workspaceStore.updateCurrentScene(
    sceneId: scene.id,
    recentLocation: scene.displayLocation,
  );
}

Future<_ChapterSimulationSession> _runChapterSimulation({
  required AppSettingsStore settingsStore,
  required AppSimulationStore simulationStore,
  required _ValidationChapter chapter,
  AppEventLog? eventLog,
}) async {
  final result = await simulationStore.runRealAgentSession(
    settingsStore: settingsStore,
    sceneContext: _chapterSimulationContext(chapter),
    authorGoal:
        'Phase 5 validation: each chapter must use this real multi-agent '
        'discussion as input before prose generation.',
    rounds: 1,
    eventLog: eventLog,
  );
  if (!result.succeeded) {
    fail(
      'Phase 5 real multi-agent simulation failed for ${chapter.id}: '
      '${result.failureDetail}',
    );
  }

  return _ChapterSimulationSession(
    chapterId: chapter.id,
    chapterTitle: chapter.title,
    messages: result.messages,
  );
}

String _chapterSimulationContext(_ValidationChapter chapter) {
  return [
    '章节：${chapter.title}',
    '章节目标：${chapter.summary}',
    '核心场景：',
    for (final scene in chapter.scenes)
      '- ${scene.title}：${scene.summary} 推进：${scene.targetBeat}',
    '角色：${_chapterCastSummary(chapter)}',
    '世界节点：${_distinctStrings([for (final scene in chapter.scenes) ...scene.worldNodeIds]).join('、')}',
  ].join('\n');
}

String _chapterCastSummary(_ValidationChapter chapter) {
  final byId = <String, _ValidationCast>{};
  for (final scene in chapter.scenes) {
    for (final cast in scene.cast) {
      byId.putIfAbsent(cast.characterId, () => cast);
    }
  }
  return byId.values
      .map(
        (cast) => '${cast.name}(${cast.role}/${cast.metadata['tag'] ?? '未标注'})',
      )
      .join('、');
}

String _chapterSimulationRelativePath(_ValidationChapter chapter) {
  final numberMatch = RegExp(r'chapter-0?(\d+)').firstMatch(chapter.id);
  final number = numberMatch?.group(1) ?? chapter.id;
  return 'simulation/ch$number-session.md';
}

Future<_SceneExecutionResult> _runSceneWithEscalation({
  required ChapterGenerationOrchestrator orchestrator,
  required _LiveStatusReporter statusReporter,
  required _ValidationChapter chapter,
  required _ValidationScene scene,
  required String chapterSimulationInput,
  void Function()? onReviewStarted,
}) async {
  final restartNotes = <String>[];
  var transportRetries = 0;
  var reviewStarted = false;
  for (var restart = 0; restart < 3; restart += 1) {
    await statusReporter.update(
      phase: 'scene-start',
      detail:
          'Running ${chapter.id}/${scene.id} full-run ${restart + 1} '
          '(transport retries: $transportRetries).',
    );
    try {
      final output = await orchestrator.runScene(
        SceneBrief(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          sceneId: scene.id,
          sceneTitle: scene.title,
          sceneSummary: [
            scene.summary,
            '目标推进：${scene.targetBeat}',
            chapterSimulationInput,
            if (restartNotes.isNotEmpty) '上一轮审查要求：${restartNotes.last}',
          ].join('\n\n'),
          targetLength: scene.targetLength,
          targetBeat: scene.targetBeat,
          worldNodeIds: scene.worldNodeIds,
          cast: [
            for (final cast in scene.cast)
              SceneCastCandidate(
                characterId: cast.characterId,
                name: cast.name,
                role: cast.role,
                participation: cast.participation,
                metadata: Map<String, Object?>.from(cast.metadata),
              ),
          ],
          metadata: {
            'worldNodeIds': scene.worldNodeIds,
            'fullRunRestart': restart,
            'transportRetryCount': transportRetries,
            'phase5SimulationInput': chapterSimulationInput,
          },
        ),
        onStatus: (message) {
          if (!reviewStarted && _isSceneReviewStage(message)) {
            reviewStarted = true;
            onReviewStarted?.call();
          }
          unawaited(
            statusReporter.update(phase: 'scene-pass', detail: message),
          );
        },
      );
      if (output.review.decision == SceneReviewDecision.pass) {
        await statusReporter.update(
          phase: 'scene-passed',
          detail:
              '${chapter.id}/${scene.id} passed after ${output.proseAttempts} '
              'prose attempts and $transportRetries transport retries.',
        );
        return _SceneExecutionResult(
          scene: scene,
          output: output,
          fullRunRestarts: restart,
          restartNotes: List<String>.unmodifiable(restartNotes),
        );
      }

      restartNotes.add(
        '${output.review.decision.name}: ${output.review.feedback.trim()}',
      );
      await statusReporter.update(
        phase: 'scene-restart',
        detail:
            '${chapter.id}/${scene.id} requires ${output.review.decision.name}. '
            'Feedback: ${output.review.feedback.trim()}',
      );
    } catch (error) {
      if (_isRetryableTransportFailure(error) &&
          transportRetries < _maxTransportRetriesPerScene) {
        transportRetries += 1;
        restartNotes.add(
          'transport-retry-$transportRetries: ${error.toString().trim()}',
        );
        await statusReporter.update(
          phase: 'scene-transport-retry',
          detail:
              '${chapter.id}/${scene.id} transport retry $transportRetries: '
              '${error.toString().trim()}',
        );
        await Future<void>.delayed(Duration(seconds: transportRetries));
        restart -= 1;
        continue;
      }
      if (!_isRetryableTransportFailure(error)) {
        rethrow;
      }
      throw StateError(
        'Scene ${chapter.id}/${scene.id} exhausted '
        '$_maxTransportRetriesPerScene transport retries: ${error.toString().trim()}',
      );
    }
  }

  throw StateError(
    'Scene ${chapter.id}/${scene.id} did not reach PASS after 3 full runs.',
  );
}

bool _isSceneReviewStage(String message) {
  return message.contains('scene judge review') ||
      message.contains('scene consistency review') ||
      message.contains('scene reader-flow review') ||
      message.contains('scene lexicon review') ||
      message.contains('local review');
}

Future<List<_SceneExecutionResult>> _runChapterScenesWithEscalation({
  required ChapterGenerationOrchestrator Function() orchestratorFactory,
  required _LiveStatusReporter statusReporter,
  required _ValidationChapter chapter,
  required String chapterSimulationInput,
  int maxConcurrentScenes = _maxConcurrentSceneRuns,
}) async {
  final scenes = chapter.scenes;
  if (scenes.isEmpty) {
    return const [];
  }

  final scheduler =
      ScenePipelineScheduler<_ValidationScene, _SceneExecutionResult>(
        maxConcurrentScenes: maxConcurrentScenes,
      );
  return scheduler.run(
    scenes: scenes,
    runScene: (scene, {required onReviewStarted}) {
      return _runSceneWithEscalation(
        orchestrator: orchestratorFactory(),
        statusReporter: statusReporter,
        chapter: chapter,
        scene: scene,
        chapterSimulationInput: chapterSimulationInput,
        onReviewStarted: onReviewStarted,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Markdown generation helpers
// ---------------------------------------------------------------------------

String _chapterMarkdown({
  required _ValidationChapter chapter,
  required List<_SceneExecutionResult> sceneExecutions,
}) {
  final buffer = StringBuffer()
    ..writeln('# ${chapter.title}')
    ..writeln()
    ..writeln('> 验证摘要：${chapter.summary}')
    ..writeln();

  for (final execution in sceneExecutions) {
    buffer
      ..writeln('## ${execution.scene.title}')
      ..writeln()
      ..writeln(execution.output.prose.text.trim())
      ..writeln();
  }

  return buffer.toString().trimRight();
}

String _sceneReviewMarkdown({
  required _ValidationChapter chapter,
  required _ValidationScene scene,
  required _SceneExecutionResult execution,
}) {
  final buffer = StringBuffer()
    ..writeln('# ${chapter.title} / ${scene.title}')
    ..writeln()
    ..writeln('- Full-run restarts: ${execution.fullRunRestarts}')
    ..writeln(
      '- Prose retries in final run: ${execution.output.softFailureCount}',
    )
    ..writeln('- Final decision: `${execution.output.review.decision.name}`')
    ..writeln();

  if (execution.restartNotes.isNotEmpty) {
    buffer
      ..writeln('## Restart History')
      ..writeln();
    for (final note in execution.restartNotes) {
      buffer.writeln('- $note');
    }
    buffer.writeln();
  }

  buffer
    ..writeln('## Director')
    ..writeln()
    ..writeln(execution.output.director.text)
    ..writeln()
    ..writeln('## Role Outputs')
    ..writeln();
  for (final role in execution.output.roleOutputs) {
    buffer
      ..writeln('### ${role.name} (`${role.characterId}`)')
      ..writeln()
      ..writeln(role.text)
      ..writeln();
  }
  if (execution.output.roleplaySession != null &&
      !execution.output.roleplaySession!.isEmpty) {
    buffer
      ..writeln('## Roleplay Session')
      ..writeln()
      ..writeln(execution.output.roleplaySession!.toPromptText(maxChars: 6000))
      ..writeln();
  }
  buffer
    ..writeln('## Prose')
    ..writeln()
    ..writeln(execution.output.prose.text)
    ..writeln()
    ..writeln('## Judge Review')
    ..writeln()
    ..writeln(execution.output.review.judge.rawText)
    ..writeln()
    ..writeln('## Consistency Review')
    ..writeln()
    ..writeln(execution.output.review.consistency.rawText);
  if (execution.output.review.roleplayFidelity != null) {
    buffer
      ..writeln()
      ..writeln('## Roleplay Fidelity Review')
      ..writeln()
      ..writeln(execution.output.review.roleplayFidelity!.rawText);
  }
  return buffer.toString().trimRight();
}

String _runReportMarkdown({
  required _ResolvedRealSettings resolvedSettings,
  required _ConfiguredModel configuredModel,
  required List<_ValidationChapterSummary> chapterSummaries,
  required _SourceRecoverySummary sourceRecovery,
  required ProjectTransferResult exportResult,
  required ProjectTransferResult importResult,
  required int importedOutlineChapterCount,
  required int importedGenerationChapterCount,
  required int importedSimulationMessageCount,
  required int telemetryRows,
  required int jsonlCount,
}) {
  final exportPackage = File(exportResult.packagePath);
  final exportPackageSize = exportPackage.existsSync()
      ? exportPackage.lengthSync()
      : 0;
  final importVerified =
      importResult.state == ProjectTransferState.importSuccess &&
      importedOutlineChapterCount >= 1 &&
      importedGenerationChapterCount >= 1 &&
      importedSimulationMessageCount >= sourceRecovery.simulationMessageCount;
  final buffer = StringBuffer()
    ..writeln('# Resonance World One-Chapter Validation Report')
    ..writeln()
    ..writeln('- Provider: ${resolvedSettings.providerName}')
    ..writeln('- Base URL: ${resolvedSettings.baseUrl}')
    ..writeln('- Resolved model: ${configuredModel.model}')
    ..writeln('- Connection result: ${configuredModel.connectionMessage}')
    ..writeln(
      '- Max concurrent requests: ${resolvedSettings.maxConcurrentRequests}',
    )
    ..writeln('- API key preview: ${_apiKeyPreview(resolvedSettings.apiKey)}')
    ..writeln('- Export state: `${exportResult.state.name}`')
    ..writeln('- Export package path: `${exportResult.packagePath}`')
    ..writeln('- Export package size: $exportPackageSize bytes')
    ..writeln('- Import state: `${importResult.state.name}`')
    ..writeln('- Chapter/scene rows: ${sourceRecovery.chapterCount}')
    ..writeln('- Character count: ${sourceRecovery.characterCount}')
    ..writeln('- World node count: ${sourceRecovery.worldNodeCount}')
    ..writeln('- AI history rows: ${sourceRecovery.aiHistoryCount}')
    ..writeln('- Version rows: ${sourceRecovery.versionCount}')
    ..writeln(
      '- Simulation message rows: ${sourceRecovery.simulationMessageCount}',
    )
    ..writeln('- Telemetry rows: $telemetryRows')
    ..writeln('- JSONL lines: $jsonlCount')
    ..writeln()
    ..writeln('## Chapter Summaries')
    ..writeln();

  for (final summary in chapterSummaries) {
    buffer
      ..writeln('### ${summary.chapterTitle} (`${summary.chapterId}`)')
      ..writeln()
      ..writeln('- Scene count: ${summary.sceneCount}')
      ..writeln('- Actual length: ${summary.actualLength}')
      ..writeln('- Review passed: ${summary.reviewPassed}')
      ..writeln('- Full-run restarts: ${summary.fullRunRestarts}')
      ..writeln('- Prose retries: ${summary.proseRetryCount}')
      ..writeln(
        '- Phase 5 simulation messages: ${summary.simulationMessageCount}',
      )
      ..writeln();
  }

  buffer
    ..writeln('## Key Scene Summaries')
    ..writeln();
  for (final summary in chapterSummaries) {
    buffer
      ..writeln('### ${summary.chapterTitle}')
      ..writeln();
    for (final sceneSummary in summary.sceneSummaries) {
      buffer.writeln('- $sceneSummary');
    }
    buffer.writeln();
  }

  buffer
    ..writeln('## Import Verification')
    ..writeln()
    ..writeln('- Imported outline chapters: $importedOutlineChapterCount')
    ..writeln('- Imported generated chapters: $importedGenerationChapterCount')
    ..writeln('- Imported simulation messages: $importedSimulationMessageCount')
    ..writeln('- Conclusion: ${importVerified ? '导入后复核通过' : '导入后复核未通过'}');

  return buffer.toString().trimRight();
}

// ---------------------------------------------------------------------------
// Store persistence & recovery helpers
// ---------------------------------------------------------------------------

Future<void> _waitForStorePersistence() =>
    Future<void>.delayed(const Duration(milliseconds: 120));

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue);
}

Future<_RecoveredValidationStores> _openAndVerifyRecoveredSourceStores({
  required _ValidationSourcePaths sourcePaths,
  required List<String> expectedChapterTitles,
}) async {
  final workspaceStore = AppWorkspaceStore(
    storage: SqliteAppWorkspaceStorage(dbPath: sourcePaths.authoringDbPath),
  );
  final draftStore = AppDraftStore(
    storage: SqliteAppDraftStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final aiHistoryStore = AppAiHistoryStore(
    storage: SqliteAppAiHistoryStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final sceneContextStore = AppSceneContextStore(
    storage: SqliteAppSceneContextStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final versionStore = AppVersionStore(
    storage: SqliteAppVersionStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final outlineStore = StoryOutlineStore(
    storage: SqliteStoryOutlineStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final generationStore = StoryGenerationStore(
    storage: SqliteStoryGenerationStorage(dbPath: sourcePaths.authoringDbPath),
    workspaceStore: workspaceStore,
  );
  final simulationStore = AppSimulationStore(
    storage: SqliteAppSimulationStorage(dbPath: sourcePaths.simulationDbPath),
    workspaceStore: workspaceStore,
  );

  try {
    await _waitUntil(
      () =>
          workspaceStore.scenes.length >= expectedChapterTitles.length &&
          expectedChapterTitles.every(
            (title) =>
                workspaceStore.scenes.any((scene) => scene.title == title),
          ) &&
          expectedChapterTitles.every(draftStore.snapshot.text.contains) &&
          aiHistoryStore.entries.isNotEmpty &&
          versionStore.entries.isNotEmpty &&
          sceneContextStore.snapshot.worldSummary.contains('已刷新') &&
          outlineStore.snapshot.chapters.length >=
              expectedChapterTitles.length &&
          simulationStore.snapshot.status == SimulationStatus.completed,
    );
    await generationStore.waitUntilReady();
    expect(
      generationStore.snapshot.chapters,
      hasLength(expectedChapterTitles.length),
    );

    return _RecoveredValidationStores(
      workspaceStore: workspaceStore,
      draftStore: draftStore,
      aiHistoryStore: aiHistoryStore,
      sceneContextStore: sceneContextStore,
      versionStore: versionStore,
      outlineStore: outlineStore,
      generationStore: generationStore,
      simulationStore: simulationStore,
      recovery: _SourceRecoverySummary(
        chapterCount: workspaceStore.scenes.length,
        characterCount: workspaceStore.characters.length,
        worldNodeCount: workspaceStore.worldNodes.length,
        aiHistoryCount: aiHistoryStore.entries.length,
        versionCount: versionStore.entries.length,
        simulationMessageCount: simulationStore.snapshot.messages.length,
      ),
    );
  } catch (_) {
    workspaceStore.dispose();
    draftStore.dispose();
    aiHistoryStore.dispose();
    sceneContextStore.dispose();
    versionStore.dispose();
    outlineStore.dispose();
    generationStore.dispose();
    simulationStore.dispose();
    rethrow;
  }
}

Future<void> _writeSanitizedSettingsSnapshot({
  required Directory runtimeDirectory,
  required _ResolvedRealSettings resolvedSettings,
  required _ConfiguredModel configuredModel,
}) async {
  final file = File('${runtimeDirectory.path}/settings.snapshot.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'providerName': resolvedSettings.providerName,
      'baseUrl': resolvedSettings.baseUrl,
      'resolvedModel': configuredModel.model,
      'candidateModels': resolvedSettings.candidateModels,
      'timeoutMs': resolvedSettings.timeoutMs,
      'maxConcurrentRequests': resolvedSettings.maxConcurrentRequests,
      'apiKeyPreview': _apiKeyPreview(resolvedSettings.apiKey),
      'configSource': resolvedSettings.configSource,
    }),
  );
}

Future<void> _waitForEventArtifacts({
  required String telemetryDbPath,
  required Directory logsDirectory,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    final telemetryRows = await _readTelemetryCount(telemetryDbPath);
    final jsonlCount = await _readJsonlCount(logsDirectory);
    if (telemetryRows > 0 && jsonlCount > 0) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

// ---------------------------------------------------------------------------
// Utility helpers
// ---------------------------------------------------------------------------

Map<String, String> _loadLocalConfig({File? file}) {
  final configFile = file ?? File('setting.json');
  if (!configFile.existsSync()) {
    return const {};
  }

  final raw = configFile.readAsStringSync();
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
  } on FormatException {
    // Fall through to local key-value parsing.
  }

  final config = <String, String>{};
  for (final line in const LineSplitter().convert(raw)) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
      continue;
    }
    final separatorIndex = trimmedLine.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }
    final key = trimmedLine.substring(0, separatorIndex).trim();
    final value = trimmedLine.substring(separatorIndex + 1).trim();
    if (key.isNotEmpty) {
      config[key] = value;
    }
  }
  return config;
}

_ResolvedRealSettings _resolveRealSettings({
  required Map<String, String> environment,
  required Map<String, String> localConfig,
}) {
  final baseUrl = _firstNonEmpty(environment, ['OLLAMA_BASE_URL']);
  final resolvedBaseUrl = baseUrl.isNotEmpty
      ? baseUrl
      : _firstNonEmpty(localConfig, ['OLLAMA_BASE_URL', 'baseUrl']).isNotEmpty
      ? _firstNonEmpty(localConfig, ['OLLAMA_BASE_URL', 'baseUrl'])
      : 'https://ollama.com/v1';
  final apiKey = _firstNonEmpty(environment, ['OLLAMA_API_KEY']).isNotEmpty
      ? _firstNonEmpty(environment, ['OLLAMA_API_KEY'])
      : _firstNonEmpty(localConfig, ['OLLAMA_API_KEY', 'apiKey']);

  const candidateModels = ['kimi-k2.6'];

  return _ResolvedRealSettings(
    providerName: _firstNonEmpty(localConfig, ['providerName']).isNotEmpty
        ? _firstNonEmpty(localConfig, ['providerName'])
        : 'Kimi Cloud',
    baseUrl: resolvedBaseUrl,
    apiKey: apiKey,
    candidateModels: candidateModels,
    maxConcurrentRequests: _resolvedMaxConcurrentRequests(
      environment: environment,
      localConfig: localConfig,
    ),
    timeoutMs: _resolvedTimeoutMs(
      environment: environment,
      localConfig: localConfig,
    ),
    configSource: localConfig.isEmpty ? 'environment-only' : 'setting.json',
  );
}

int _resolvedTimeoutMs({
  required Map<String, String> environment,
  required Map<String, String> localConfig,
}) {
  final requestedTimeout =
      int.tryParse(_firstNonEmpty(environment, ['REAL_AI_TIMEOUT_MS'])) ??
      int.tryParse(
        _firstNonEmpty(localConfig, ['REAL_AI_TIMEOUT_MS', 'timeoutMs']),
      ) ??
      600000;
  return requestedTimeout < 180000 ? 180000 : requestedTimeout;
}

int _resolvedMaxConcurrentRequests({
  required Map<String, String> environment,
  required Map<String, String> localConfig,
}) {
  final requested =
      int.tryParse(
        _firstNonEmpty(environment, ['REAL_AI_MAX_CONCURRENT_REQUESTS']),
      ) ??
      int.tryParse(
        _firstNonEmpty(localConfig, [
          'REAL_AI_MAX_CONCURRENT_REQUESTS',
          'maxConcurrentRequests',
        ]),
      ) ??
      1;
  return requested < 1 ? 1 : requested;
}

String _firstNonEmpty(Map<String, String> values, List<String> keys) {
  for (final key in keys) {
    final value = (values[key] ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _apiKeyPreview(String apiKey) {
  final trimmed = apiKey.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.length <= 6) {
    return '${trimmed.substring(0, 3)}...';
  }
  return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 2)}';
}

bool _isRetryableTransportFailure(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is HttpException) {
    return true;
  }

  final message = error.toString().toLowerCase();
  return message.contains(
        'connection closed before full header was received',
      ) ||
      message.contains('connection reset by peer') ||
      message.contains('broken pipe') ||
      message.contains('software caused connection abort') ||
      message.contains('connection terminated') ||
      message.contains('temporarily unavailable') ||
      message.contains('timed out') ||
      // AI output format unpredictability: treat malformed review as retryable
      // since a retry may produce a valid format from the LLM.
      (error is StateError && message.contains('malformed scene'));
}

Future<int> _readTelemetryCount(String dbPath) async {
  final process = await Process.run('/usr/bin/sqlite3', [
    dbPath,
    'SELECT COUNT(*) FROM app_event_log_entries;',
  ]);
  if (process.exitCode != 0) {
    return -1;
  }
  return int.tryParse(process.stdout.toString().trim()) ?? -1;
}

Future<int> _readJsonlCount(Directory logsDirectory) async {
  if (!await logsDirectory.exists()) {
    return 0;
  }

  var count = 0;
  await for (final entity in logsDirectory.list()) {
    if (entity is! File || !entity.path.endsWith('.jsonl')) {
      continue;
    }
    final lines = await entity.readAsLines();
    count += lines.where((line) => line.trim().isNotEmpty).length;
  }
  return count;
}

Future<String> _artifactIndexMarkdown(Directory outputRoot) async {
  final relativePaths = <String>[];
  await for (final entity in outputRoot.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final relativePath = entity.path.substring(outputRoot.path.length + 1);
    relativePaths.add(relativePath.replaceAll(r'\', '/'));
  }
  relativePaths.sort();

  return [
    '# Artifact Index',
    '',
    for (final path in relativePaths) '- `$path`',
  ].join('\n');
}

List<String> _distinctStrings(List<String> values) {
  final unique = <String>[];
  for (final value in values) {
    if (!unique.contains(value)) {
      unique.add(value);
    }
  }
  return unique;
}

StoryReviewStatus _mapReviewStatus(SceneReviewStatus status) {
  return switch (status) {
    SceneReviewStatus.pass => StoryReviewStatus.passed,
    SceneReviewStatus.rewriteProse => StoryReviewStatus.softFailed,
    SceneReviewStatus.replanScene => StoryReviewStatus.hardFailed,
  };
}
