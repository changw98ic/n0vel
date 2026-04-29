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
import 'test_support/fake_app_llm_client.dart';

const int _maxTransportRetriesPerScene = 6;
const int _maxConcurrentSceneRuns = 2;

void main() {
  test('retryable transport failures are detected conservatively', () {
    expect(
      _isRetryableTransportFailure(
        const HttpException(
          'Connection closed before full header was received',
        ),
      ),
      isTrue,
    );
    expect(
      _isRetryableTransportFailure(
        StateError('Connection reset by peer while generating prose'),
      ),
      isTrue,
    );
    expect(
      _isRetryableTransportFailure(
        StateError('Scene chapter-01/scene-01 did not reach PASS.'),
      ),
      isFalse,
    );
  });

  test('phase 3 persists a three chapter outline into workspace scenes', () {
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
    expect(scenes, hasLength(3));
    expect(scenes.map((scene) => scene.title), [
      '第一章 雨夜码头',
      '第二章 档案楼暗门',
      '第三章 天台交锋',
    ]);
    expect(scenes.map((scene) => scene.chapterLabel), [
      '第 1 章',
      '第 2 章',
      '第 3 章',
    ]);
    for (final scene in scenes) {
      expect(scene.summary, contains('章节目标：'));
      expect(scene.summary, contains('主要冲突：'));
      expect(scene.summary, contains('转折点：'));
      expect(scene.summary, contains('结尾钩子：'));
    }
  });

  test('phase 3 real outline prompt asks for verifiable chapter beats', () {
    final prompt = _realOutlinePrompt(_validationChapters);

    expect(prompt, contains('章节目标'));
    expect(prompt, contains('主要冲突'));
    expect(prompt, contains('转折点'));
    expect(prompt, contains('结尾钩子'));
    expect(prompt, contains('只规划三章'));
  });

  test(
    'phase 5 chapter simulation runs two real-agent rounds and produces prose input',
    () async {
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          final role = system.contains('director')
              ? 'director'
              : system.contains('protagonist')
              ? 'protagonist'
              : 'antagonist';
          final round =
              RegExp(
                r'回合：(\d+)/2',
              ).firstMatch(request.messages.last.content)?.group(1) ??
              '0';
          return AppLlmChatResult.success(
            text: '真实讨论输出 $role round-$round：约束正文必须引用多 agent 结论。',
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final simulationStore = AppSimulationStore(
        storage: InMemoryAppSimulationStorage(),
        workspaceStore: workspaceStore,
      );
      addTearDown(settingsStore.dispose);
      addTearDown(workspaceStore.dispose);
      addTearDown(simulationStore.dispose);

      workspaceStore.createProject();
      _applyChapterOutlineToWorkspaceStore(
        workspaceStore: workspaceStore,
        chapters: _validationChapters,
      );

      final chapter = _validationChapters.first;
      final session = await _runChapterSimulation(
        settingsStore: settingsStore,
        simulationStore: simulationStore,
        chapter: chapter,
      );

      expect(fakeClient.requests, hasLength(6));
      expect(session.messages, hasLength(6));
      expect(session.proseInput, contains('真实多 Agent 模拟输入'));
      expect(session.proseInput, contains('director'));
      expect(session.proseInput, contains('protagonist'));
      expect(session.proseInput, contains('antagonist'));
      expect(session.markdown, contains('真实讨论输出 antagonist round-2'));
    },
  );

  test(
    'phase 7 reopens persisted validation stores from visible files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_phase7_recovery_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final sourceDirectory = Directory('${directory.path}/source');
      final sourcePaths = _ValidationSourcePaths.fromDirectory(sourceDirectory);
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
      final versionStore = AppVersionStore(
        storage: SqliteAppVersionStorage(dbPath: sourcePaths.authoringDbPath),
        workspaceStore: workspaceStore,
      );
      final sceneContextStore = AppSceneContextStore(
        storage: SqliteAppSceneContextStorage(
          dbPath: sourcePaths.authoringDbPath,
        ),
        workspaceStore: workspaceStore,
      );
      final simulationStore = AppSimulationStore(
        storage: SqliteAppSimulationStorage(
          dbPath: sourcePaths.simulationDbPath,
        ),
        workspaceStore: workspaceStore,
      );
      final outlineStore = StoryOutlineStore(
        storage: SqliteStoryOutlineStorage(dbPath: sourcePaths.authoringDbPath),
        workspaceStore: workspaceStore,
      );
      final generationStore = StoryGenerationStore(
        storage: SqliteStoryGenerationStorage(
          dbPath: sourcePaths.authoringDbPath,
        ),
        workspaceStore: workspaceStore,
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (request) => AppLlmChatResult.success(
            text: '真实多 agent 回复：${request.messages.last.content}',
          ),
        ),
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(draftStore.dispose);
      addTearDown(aiHistoryStore.dispose);
      addTearDown(versionStore.dispose);
      addTearDown(sceneContextStore.dispose);
      addTearDown(simulationStore.dispose);
      addTearDown(outlineStore.dispose);
      addTearDown(generationStore.dispose);
      addTearDown(settingsStore.dispose);

      workspaceStore.createProject();
      _applyValidationResourcesToWorkspaceStore(
        workspaceStore: workspaceStore,
        chapters: _validationChapters,
      );
      _applyChapterOutlineToWorkspaceStore(
        workspaceStore: workspaceStore,
        chapters: _validationChapters,
      );
      outlineStore.replaceSnapshot(
        StoryOutlineSnapshot(
          projectId: workspaceStore.currentProjectId,
          chapters: [
            for (final chapter in _validationChapters)
              StoryOutlineChapterSnapshot(
                id: chapter.id,
                title: chapter.title,
                summary: chapter.summary,
              ),
          ],
        ),
      );
      generationStore.replaceSnapshot(
        StoryGenerationSnapshot(
          projectId: workspaceStore.currentProjectId,
          chapters: [
            for (final chapter in _validationChapters)
              StoryChapterGenerationState(
                chapterId: chapter.id,
                status: StoryChapterGenerationStatus.passed,
                targetLength: chapter.targetLength,
                actualLength: chapter.targetLength,
              ),
          ],
        ),
      );
      sceneContextStore.syncContext();
      await draftStore.updateTextAndPersist(
        _validationChapters.map((chapter) => '# ${chapter.title}').join('\n\n'),
      );
      await versionStore.captureSnapshotAndPersist(
        label: '第三章快照',
        content: '# 第三章 天台交锋',
      );
      aiHistoryStore.addEntry(mode: '正文生成', prompt: '第三章真实生成历史');
      await simulationStore.runRealAgentSession(
        settingsStore: settingsStore,
        sceneContext: '第三章 天台交锋',
        authorGoal: '恢复验证',
        rounds: 2,
      );
      await _waitForStorePersistence();

      final recovery = await _reopenAndVerifySourcePersistence(
        sourcePaths: sourcePaths,
        expectedChapterTitles: [
          for (final chapter in _validationChapters) chapter.title,
        ],
      );

      expect(recovery.chapterCount, 3);
      expect(recovery.characterCount, greaterThanOrEqualTo(3));
      expect(recovery.worldNodeCount, greaterThanOrEqualTo(3));
      expect(recovery.aiHistoryCount, greaterThanOrEqualTo(1));
      expect(recovery.versionCount, greaterThanOrEqualTo(1));
      expect(recovery.simulationMessageCount, greaterThanOrEqualTo(6));
    },
  );

  test(
    'real three chapter generation leaves visible artifacts',
    () async {
      if (Platform.environment['RUN_REAL_STORY_VALIDATION'] != '1') {
        markTestSkipped(
          'Set RUN_REAL_STORY_VALIDATION=1 to run the real provider validation.',
        );
        return;
      }

      final result = await _runRealThreeChapterValidation();

      expect(result.chapterSummaries, hasLength(3));
      expect(result.exportState, ProjectTransferState.exportSuccess);
      expect(result.importState, ProjectTransferState.importSuccess);
      expect(result.importedOutlineChapterCount, 3);
      expect(result.importedGenerationChapterCount, 3);
      expect(
        File('${result.outputRoot.path}/chapters/chapter-01.md').existsSync(),
        isTrue,
      );
      expect(
        File('${result.outputRoot.path}/chapters/chapter-02.md').existsSync(),
        isTrue,
      );
      expect(
        File('${result.outputRoot.path}/chapters/chapter-03.md').existsSync(),
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
          '${result.outputRoot.path}/outline/three_chapter_outline.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File('${result.outputRoot.path}/runtime/live-status.md').existsSync(),
        isTrue,
      );
      expect(
        File(
          '${result.outputRoot.path}/exports/lunaris-export.zip',
        ).existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 45)),
  );

  test('phase 9 report records final acceptance evidence', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_phase_9_report_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final package = File('${directory.path}/lunaris-export.zip');
    await package.writeAsBytes(List<int>.filled(128, 0x50));

    final markdown = _runReportMarkdown(
      resolvedSettings: const _ResolvedRealSettings(
        providerName: '云端 Ollama',
        baseUrl: 'https://ollama.example/v1',
        apiKey: 'sk-test-key',
        candidateModels: ['kimi-k2.6'],
        maxConcurrentRequests: 1,
        timeoutMs: 180000,
        configSource: 'setting.json',
      ),
      configuredModel: const _ConfiguredModel(
        model: 'kimi-k2.6',
        connectionMessage: '连接测试通过',
      ),
      chapterSummaries: const [
        _ValidationChapterSummary(
          chapterId: 'chapter-01',
          chapterTitle: '第一章 雨夜码头',
          sceneCount: 2,
          sceneSummaries: ['码头交接：账本浮出水面', '旧仓追逐：证据险些失控'],
          actualLength: 1908,
          reviewPassed: true,
          fullRunRestarts: 0,
          proseRetryCount: 1,
          simulationMessageCount: 6,
        ),
      ],
      sourceRecovery: const _SourceRecoverySummary(
        chapterCount: 3,
        characterCount: 4,
        worldNodeCount: 5,
        aiHistoryCount: 3,
        versionCount: 3,
        simulationMessageCount: 18,
      ),
      exportResult: ProjectTransferResult(
        state: ProjectTransferState.exportSuccess,
        packagePath: package.path,
      ),
      importResult: ProjectTransferResult(
        state: ProjectTransferState.importSuccess,
        packagePath: package.path,
      ),
      importedOutlineChapterCount: 3,
      importedGenerationChapterCount: 3,
      importedSimulationMessageCount: 18,
      telemetryRows: 11,
      jsonlCount: 12,
    );

    expect(markdown, contains('- Provider: 云端 Ollama'));
    expect(markdown, contains('- Resolved model: kimi-k2.6'));
    expect(markdown, contains('- Export package path: `${package.path}`'));
    expect(markdown, contains('- Export package size: 128 bytes'));
    expect(markdown, contains('- Character count: 4'));
    expect(markdown, contains('- World node count: 5'));
    expect(markdown, contains('- AI history rows: 3'));
    expect(markdown, contains('- Version rows: 3'));
    expect(markdown, contains('- Telemetry rows: 11'));
    expect(markdown, contains('## Key Scene Summaries'));
    expect(markdown, contains('- 码头交接：账本浮出水面'));
    expect(markdown, contains('## Import Verification'));
    expect(markdown, contains('导入后复核通过'));
  });
}

Future<_RealValidationResult> _runRealThreeChapterValidation() async {
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

  final outputRoot = Directory(ArtifactRecorder.defaultRootPath);
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
    detail: 'Preparing repo-visible real validation workspace.',
  );
  final logsDirectory = Directory(sourcePaths.logsDirectoryPath);
  final telemetryDbPath = sourcePaths.telemetryDbPath;
  final eventLog = AppEventLog(
    storage: createTestAppEventLogStorage(
      sqlitePath: telemetryDbPath,
      logsDirectory: logsDirectory,
    ),
    sessionId: 'real-three-chapter-validation',
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
    await _writeSanitizedSettingsSnapshot(
      runtimeDirectory: sourceDirectory,
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
      detail:
          'Writing world bible and character profiles, then generating the real outline.',
    );
    await recorder.recordReport(
      relativePath: 'inputs/world_bible.md',
      content: _worldBibleMarkdown(),
    );
    await recorder.recordReport(
      relativePath: 'inputs/character_profiles.md',
      content: _characterProfilesMarkdown(_validationChapters),
    );
    final realOutlineMarkdown = await _generateRealThreeChapterOutline(
      settingsStore: settingsStore,
      chapters: _validationChapters,
    );
    await recorder.recordReport(
      relativePath: 'inputs/three_chapter_outline.md',
      content: realOutlineMarkdown,
    );
    await recorder.recordReport(
      relativePath: 'outline/three_chapter_outline.md',
      content: realOutlineMarkdown,
    );
    _applyChapterOutlineToWorkspaceStore(
      workspaceStore: workspaceStore,
      chapters: _validationChapters,
    );
    sceneContextStore.syncContext();
    expect(workspaceStore.scenes, hasLength(3));

    outlineStore.replaceSnapshot(
      StoryOutlineSnapshot(
        projectId: projectId,
        metadata: {
          'validationRun': 'real-three-chapter',
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
          'Exporting source package with outline and generation state.',
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

    expect(targetOutlineStore.snapshot.chapters, hasLength(3));
    expect(targetGenerationStore.snapshot.chapters, hasLength(3));
    expect(targetSimulationStore.snapshot.status, SimulationStatus.completed);
    expect(
      targetSimulationStore.snapshot.messages.length,
      greaterThanOrEqualTo(6),
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
      detail: 'Real three-chapter validation completed successfully.',
    );

    stdout.writeln('Real three-chapter validation passed.');
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

Future<_SourceRecoverySummary> _reopenAndVerifySourcePersistence({
  required _ValidationSourcePaths sourcePaths,
  required List<String> expectedChapterTitles,
}) async {
  final recoveredStores = await _openAndVerifyRecoveredSourceStores(
    sourcePaths: sourcePaths,
    expectedChapterTitles: expectedChapterTitles,
  );
  try {
    return recoveredStores.recovery;
  } finally {
    recoveredStores.dispose();
  }
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
      note: '真实验证角色：${cast.metadata['tag'] ?? cast.role}',
      need: '目标：推进 ${_participationSummary(cast.participation)}',
      summary: '风险与关系：参与三章真实生成验证，并约束正文行动连续性。',
      referenceSummary: '来源：真实三章验证角色构建阶段。',
    );
  }

  for (final nodeId in uniqueWorldNodeIds) {
    workspaceStore.createWorldNode();
    final node = workspaceStore.worldNodes.first;
    workspaceStore.updateWorldNode(
      nodeId: node.id,
      title: _worldNodeTitle(nodeId),
      location: '港区验证世界观',
      type: '真实验证节点',
      detail: '节点 `$nodeId` 用于约束三章大纲、角色行动和正文生成。',
      summary: '世界节点 `$nodeId` 已落入可恢复 source authoring.db。',
      ruleSummary: '正文必须遵守此节点的地点、风险和组织规则。',
      referenceSummary: '来源：真实三章验证世界观创建阶段。',
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
    'old-harbor' => '旧港雨夜规则',
    'customs-yard' => '海关货场封锁线',
    'archive-tower' => '港务档案楼',
    'maintenance-shaft' => '维护井暗线',
    'rooftop' => '天台交锋区',
    _ => '世界节点 $nodeId',
  };
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

Future<String> _generateRealThreeChapterOutline({
  required AppSettingsStore settingsStore,
  required List<_ValidationChapter> chapters,
}) async {
  final result = await settingsStore.requestAiCompletion(
    messages: [
      const AppLlmChatMessage(
        role: 'system',
        content: '你是长篇类型小说大纲编辑。输出必须具体、可执行，避免泛泛而谈。',
      ),
      AppLlmChatMessage(role: 'user', content: _realOutlinePrompt(chapters)),
    ],
  );
  if (!result.succeeded || (result.text ?? '').trim().isEmpty) {
    fail(
      'Phase 3 real outline generation failed: '
      '${result.failureKind} / ${result.detail}',
    );
  }

  return [
    '# 三章大纲规划',
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
    '请基于以下世界观和角色方向，真实规划一个中文类型小说前三章大纲。',
    '',
    '硬性要求：',
    '- 只规划三章，不要追加第四章或番外。',
    '- 每章必须包含四个字段：章节目标、主要冲突、转折点、结尾钩子。',
    '- 每章要能直接落成一个 AppWorkspaceStore 场景节点。',
    '- 保持悬疑港区、调查记者、账本证据、雨夜追逃的主线连续性。',
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
    '',
    '然后按同样格式输出第二章、第三章。',
  ].join('\n');
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
    rounds: 2,
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
      message.contains('timed out');
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
        : 'Ollama Cloud',
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
    configSource: settingFileSource(localConfig),
  );
}

String settingFileSource(Map<String, String> localConfig) {
  return localConfig.isEmpty ? 'environment-only' : 'setting.json';
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
      180000;
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

String _worldBibleMarkdown() {
  return [
    '# 世界设定',
    '',
    '- 时代气质：近未来沿海城市，灰蓝工业港与旧城区并存。',
    '- 核心秘密：一份走私航运账本同时牵动媒体、港务系统和地下清算链。',
    '- 主线冲突：柳溪想公开真相，沈渡想先活着带出证据。',
    '- 风格要求：中文网文节奏，场景清晰，人物动机明确，冲突持续升级。',
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

String _outlineMarkdown(List<_ValidationChapter> chapters) {
  final buffer = StringBuffer()
    ..writeln('# 三章验证大纲')
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
      importedOutlineChapterCount >= 3 &&
      importedGenerationChapterCount >= 3 &&
      importedSimulationMessageCount >= sourceRecovery.simulationMessageCount;
  final buffer = StringBuffer()
    ..writeln('# Real Three-Chapter Validation Report')
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

const List<_ValidationChapter> _validationChapters = [
  _ValidationChapter(
    id: 'chapter-01',
    title: '第一章 雨夜码头',
    summary: '柳溪在封港前夜抵达旧码头，必须从沈渡口中撬出账本去向。',
    targetLength: 1800,
    metadata: {'worldNode': 'old-harbor'},
    scenes: [
      _ValidationScene(
        id: 'scene-01',
        title: '抵达旧码头',
        targetLength: 450,
        summary:
            '柳溪赶在封港广播落下前冲到旧码头，先确认沈渡还没有带着账本线索离开；'
            '她必须在暴雨和警报声里把人拦下来。',
        targetBeat: '先建立压迫态势，明确柳溪不准备空手离开。',
        worldNodeIds: ['old-harbor', 'customs-yard'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '顶着风雨冲下栈桥，抢在封港前堵住人',
              interaction: '先切断沈渡退路，逼他停下来听她说话',
            ),
            metadata: {'tag': '主动推进者'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              dialogue: '嘴上说今晚没空，但脚步明显犹豫',
              interaction: '试探柳溪是不是已经掌握别的证据',
            ),
            metadata: {'tag': '掌握线索的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-02',
        title: '雨棚下的试探',
        targetLength: 450,
        summary:
            '人被拦住以后，柳溪不能立刻把问题全摊开，她得先试出沈渡的底线；'
            '沈渡则想判断她到底是来合作还是来送命。',
        targetBeat: '让双方各自亮出一张底牌，但谁都不把真相一次说透。',
        worldNodeIds: ['old-harbor'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '抛出她已经知道货单有缺口这一层情报',
              interaction: '逼沈渡选合作还是现在转身走人',
            ),
            metadata: {'tag': '主动推进者'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              dialogue: '只承认账本不是唯一证据',
              interaction: '试探柳溪敢不敢一起去更危险的地方取底册',
            ),
            metadata: {'tag': '掌握线索的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-03',
        title: '条件交换',
        targetLength: 450,
        summary:
            '试探过后，柳溪必须给出能让沈渡点头的交换条件；'
            '沈渡也要把自己的保命诉求讲清楚，不然这桩合作立不起来。',
        targetBeat: '达成脆弱合作，并把“先取档案楼底册”定成共同目标。',
        worldNodeIds: ['customs-yard'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '承诺拿到底册后先保护线人身份',
              interaction: '要求沈渡立刻给出能验证的地点和时间',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              dialogue: '提出必须在巡逻换岗前潜入档案楼',
              interaction: '用部分真情报换柳溪的暂时信任',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-04',
        title: '封港前的离场',
        targetLength: 450,
        summary:
            '合作刚刚立住，港区广播就再次催促清场；'
            '柳溪和沈渡必须在最短时间里分头准备，给下一章潜入档案楼留下钩子。',
        targetBeat: '收束本章冲突，并自然推到下一章行动。',
        worldNodeIds: ['old-harbor', 'customs-yard'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '收起录音笔和潮湿的采访本，准备离开码头',
              dialogue: '最后确认碰头地点与失败后的退路',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '趁清场前把人从货柜阴影里带出去',
              dialogue: '警告柳溪明晚开始就没有回头路',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
    ],
  ),
  _ValidationChapter(
    id: 'chapter-02',
    title: '第二章 档案楼暗门',
    summary: '柳溪与沈渡潜入港务档案楼，必须在巡查前拿到账本对应的旧航运底册。',
    targetLength: 1800,
    metadata: {'worldNode': 'archive-tower'},
    scenes: [
      _ValidationScene(
        id: 'scene-01',
        title: '侧门潜入',
        targetLength: 450,
        summary:
            '暴雨引发短时停电，柳溪和沈渡借着黑暗靠近档案楼侧门；'
            '第一步不是找证据，而是先无声潜进去。',
        targetBeat: '成功潜入，建立楼内高压静默氛围。',
        worldNodeIds: ['archive-tower', 'maintenance-shaft'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '借停电的掩护先摸到侧门和走廊拐角',
              interaction: '逼沈渡别再临时改计划',
            ),
            metadata: {'tag': '主动推进者'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '用旧钥匙撬开侧门并规避监控盲区',
              dialogue: '提醒柳溪楼里最危险的是静得过头',
            ),
            metadata: {'tag': '熟悉场地的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-02',
        title: '封存柜检索',
        targetLength: 450,
        summary:
            '两人进楼后必须快速锁定封存柜列，时间不允许他们大海捞针；'
            '柳溪负责检索，沈渡负责放哨和识别异常。',
        targetBeat: '把搜索目标从一堆旧档案缩到几本可疑底册。',
        worldNodeIds: ['archive-tower'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '借手机微光快速筛掉无关档案',
              dialogue: '用记下的航运编号逼近正确柜列',
            ),
            metadata: {'tag': '主动推进者'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '在走廊拐角望风并替柳溪确认旧编码体系',
              interaction: '压低声音指出有人提前翻动过目标柜列',
            ),
            metadata: {'tag': '熟悉场地的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-03',
        title: '发现被动过的底册',
        targetLength: 450,
        summary:
            '可疑底册终于找出来，但封签和纸张位置都不对；'
            '这意味着他们不是第一批来找账的人。',
        targetBeat: '确认有人抢先一步，并提升危机等级。',
        worldNodeIds: ['archive-tower', 'maintenance-shaft'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              interaction: '逼问沈渡还有谁知道这份底册的存在',
              dialogue: '指出封签错位证明这里已被动过',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              dialogue: '承认港区里至少还有另一拨人在追同一份证据',
              action: '催柳溪立刻复制关键信息后撤离',
            ),
            metadata: {'tag': '掌握线索的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-04',
        title: '撤离前的分歧',
        targetLength: 450,
        summary:
            '找到关键底册后，柳溪想继续翻更深一层的柜列，沈渡却坚持马上撤；'
            '两人的节奏第一次真正发生正面冲突。',
        targetBeat: '带着关键底册离开，但埋下第三章立刻爆雷的引线。',
        worldNodeIds: ['maintenance-shaft'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '坚持再多看一层也许能挖出幕后名单',
              interaction: '不愿让线索在自己眼前断掉',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '强行合上柜门，把柳溪往暗门方向推',
              dialogue: '告诉她再慢半分钟楼里就要来人',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
    ],
  ),
  _ValidationChapter(
    id: 'chapter-03',
    title: '第三章 天台交锋',
    summary: '证据到手后，柳溪与沈渡在旧楼天台遭遇追兵，必须决定先保命还是立刻公开真相。',
    targetLength: 1800,
    metadata: {'worldNode': 'rooftop'},
    scenes: [
      _ValidationScene(
        id: 'scene-01',
        title: '逼退到天台',
        targetLength: 450,
        summary:
            '档案楼里的追兵已经逼近，柳溪和沈渡只能一路后退到雨夜天台；'
            '第一步是先把门口争取来的几秒时间变成喘息空间。',
        targetBeat: '建立生死压迫感，把对峙推到无处可退。',
        worldNodeIds: ['rooftop', 'service-stair'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '退到天台边缘仍不肯松开那份底册',
              interaction: '逼沈渡给出立刻脱身的办法',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '顶住天台门口拖延破门声',
              dialogue: '先要求柳溪别在这个时候和他争路线',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-02',
        title: '公开还是潜伏',
        targetLength: 450,
        summary:
            '喘息只有片刻，柳溪和沈渡必须在天台上决定证据该马上公开，还是暂时转移保存；'
            '这一步决定他们之后是同路还是分道。',
        targetBeat: '把价值冲突说透，让两人的立场正面对撞。',
        worldNodeIds: ['rooftop'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              dialogue: '坚持证据再拖就会被人永远抹掉',
              interaction: '逼沈渡在公开和保命之间立刻表态',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              dialogue: '主张先把底册拆开转移，不给追兵一网打尽的机会',
              interaction: '试图说服柳溪接受延后公开',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-03',
        title: '分头计划',
        targetLength: 450,
        summary:
            '争执逼到极限后，两人终于得把方案落成可执行动作；'
            '再吵下去，门一破他们谁也走不了。',
        targetBeat: '形成分头带证与诱饵的计划，把冲突转成行动。',
        worldNodeIds: ['service-stair'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '把底册最关键页拆出塞进防水夹层',
              dialogue: '接受分头方案，但要求约定公开时点',
            ),
            metadata: {'tag': '主动推进者'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '主动认下带着诱饵引开追兵的危险动作',
              dialogue: '要求柳溪一旦脱身就立即去见可信编辑',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
      _ValidationScene(
        id: 'scene-04',
        title: '转折与余波',
        targetLength: 450,
        summary:
            '计划定下后，追兵已经逼近门口，柳溪和沈渡只能在雨夜里各自转身；'
            '这一幕要留下关系转折和后续长线悬念。',
        targetBeat: '完成本卷级的情感与目标转折，并留下继续追查的长钩子。',
        worldNodeIds: ['rooftop', 'service-stair'],
        cast: [
          _ValidationCast(
            characterId: 'liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: SceneCastParticipation(
              action: '攥紧夹层里的证据，准备从维修梯撤离',
              dialogue: '第一次正面承认自己会把真相公开到底',
            ),
            metadata: {'tag': '要真相的人'},
          ),
          _ValidationCast(
            characterId: 'shendu',
            name: '沈渡',
            role: '港区向导',
            participation: SceneCastParticipation(
              action: '转身去顶住门口，为柳溪争最后一线撤离时间',
              dialogue: '把下一步碰头规则交代得比以前更彻底',
            ),
            metadata: {'tag': '扛风险的人'},
          ),
        ],
      ),
    ],
  ),
];

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
