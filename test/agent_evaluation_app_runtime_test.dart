import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/state/app_draft_storage_io.dart';
import 'package:novel_writer/app/state/app_scene_context_storage_io.dart';
import 'package:novel_writer/app/state/app_version_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/state/story_generation_storage_io.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage_io.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage_io.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_app_runtime.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_execution_budget.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_evidence.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trace_context.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';

void main() {
  test(
    'app runtime hydrates sentinel input state from its sandbox clone',
    () async {
      final directory = Directory.systemTemp.createTempSync('eval-hydration-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final databasePath = '${directory.path}/trial.sqlite';
      final database = sqlite3.sqlite3.open(databasePath);
      addTearDown(database.dispose);
      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(database);

      const projectId = 'project-fixture-sentinel';
      const sceneId = 'scene-fixture-sentinel';
      const sceneScopeId = '$projectId::$sceneId';
      await SqliteAppWorkspaceStorage(dbPath: databasePath).save(
        const <String, Object?>{
          'projects': <Object?>[
            <String, Object?>{
              'id': projectId,
              'sceneId': sceneId,
              'title': 'SENTINEL-WORKSPACE',
              'genre': '悬疑',
              'summary': 'fixture summary',
              'recentLocation': '第一章 / 码头',
              'lastOpenedAtMs': 123,
            },
          ],
          'charactersByProject': <String, Object?>{
            projectId: <Object?>[
              <String, Object?>{
                'id': 'character-sentinel',
                'name': 'SENTINEL-CHARACTER',
                'role': '调查者',
              },
            ],
          },
          'scenesByProject': <String, Object?>{
            projectId: <Object?>[
              <String, Object?>{
                'id': sceneId,
                'chapterLabel': '第一章',
                'title': 'SENTINEL-SCENE',
                'summary': 'scene fixture summary',
              },
            ],
          },
          'worldNodesByProject': <String, Object?>{},
          'auditIssuesByProject': <String, Object?>{},
          'projectStyles': <String, Object?>{},
          'projectAuditStates': <String, Object?>{},
          'projectTransferState': '',
          'currentProjectId': projectId,
        },
      );
      await SqliteAppDraftStorage(
        dbPath: databasePath,
      ).save(const {'text': 'SENTINEL-DRAFT'}, projectId: sceneScopeId);
      await SqliteAppVersionStorage(dbPath: databasePath).save(const {
        'entries': <Object?>[
          <String, Object?>{
            'label': 'SENTINEL-VERSION',
            'content': 'fixture version body',
          },
        ],
      }, projectId: sceneScopeId);
      await SqliteStoryOutlineStorage(dbPath: databasePath).save(const {
        'projectId': projectId,
        'chapters': <Object?>[
          <String, Object?>{
            'id': 'chapter-sentinel',
            'title': 'SENTINEL-OUTLINE',
            'summary': 'fixture outline summary',
            'scenes': <Object?>[],
          },
        ],
        'metadata': <String, Object?>{},
      }, projectId: projectId);
      await SqliteStoryGenerationStorage(dbPath: databasePath).save(
        StoryGenerationSnapshot.empty(projectId).toJson(),
        projectId: projectId,
      );
      await SqliteAppSceneContextStorage(dbPath: databasePath).save(const {
        'sceneSummary': 'SENTINEL-SCENE-CONTEXT',
        'characterSummary': 'SENTINEL-CHARACTER-CONTEXT',
        'worldSummary': 'SENTINEL-WORLD-CONTEXT',
      }, projectId: sceneScopeId);
      await SqliteAuthorFeedbackStorage(
        dbPath: databasePath,
      ).save(const {'items': <Object?>[]}, projectId: projectId);
      await SqliteReviewTaskStorage(
        dbPath: databasePath,
      ).save(const {'tasks': <Object?>[]}, projectId: projectId);

      final promptRegistry = StoryPromptRegistry.current();
      final bundleHash = _raw(promptRegistry.generationBundle.bundleHash);
      final route = AgentEvaluationProductionRouteRelease(
        model: 'glm-hydration-test',
        provider: AppLlmProvider.zhipu,
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        apiKey: 'test-key',
        timeout: const AppLlmTimeoutConfig.uniform(30000),
        providerApiRevision: 'test-api-v1',
        sdkAdapterReleaseHash: _digest('3'),
      );
      final decoding = AgentEvaluationProductionDecodingRelease.standard();
      final manifest = _manifest(
        bundleHash: bundleHash,
        modelRouteHash: route.modelRouteHash,
        decodingConfigHash: decoding.decodingConfigHash,
        providerConfigHashWithoutSecrets:
            route.providerConfigHashWithoutSecrets,
      );
      final sandboxOwners = <String>{'runner-main'};
      final shortConnectionOwners = <String>[];
      final context = AgentEvaluationTrialContext(
        manifest: manifest,
        cell: manifest.cells.single,
        scenario: manifest.scenarioSet.scenarios.single,
        lease: AgentEvaluationLease(
          trialSlotId: 'slot-hydration-1',
          executionId: 'execution-hydration-1',
          cellId: manifest.cells.single.cellId,
          trialNo: 1,
          epoch: 1,
          owner: 'worker-hydration-1',
          expiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
          status: 'running',
        ),
        attemptNo: 1,
        runId: 'slot-hydration-1-attempt-1',
        isolationTrialId: 'slot-hydration-1',
        database: database,
        sandboxDatabasePath: databasePath,
        acquireSandboxConnectionOwner: (ownerId) {
          expect(sandboxOwners.add(ownerId), isTrue);
          if (ownerId.startsWith('short-sqlite:')) {
            shortConnectionOwners.add(ownerId);
          }
        },
        releaseSandboxConnectionOwner: (ownerId) {
          expect(sandboxOwners.remove(ownerId), isTrue);
        },
        sandboxConnectionOwnerCount: () => sandboxOwners.length,
        reportStage: (_, {status = 'running'}) {},
        cancellationToken: AgentEvaluationCancellationToken(),
      );
      final releaseBudget = AgentEvaluationExecutionBudgetGuard(
        nowMs: () => DateTime.now().millisecondsSinceEpoch,
        policy: AgentEvaluationExecutionBudgetPolicy(
          budgetId: 'app-runtime-cap-test',
          maxCalls: 1,
          maxPromptTokens: 100000,
          maxCompletionTokens: 4096,
          maxTotalTokens: 104096,
          maxCostMicrousd: 1000,
          deadlineAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
          routes: <AgentEvaluationBudgetRoute>[
            AgentEvaluationBudgetRoute(
              modelRouteHash: route.modelRouteHash,
              model: route.model,
              maxPromptTokensPerCall: 100000,
              promptMicrousdPerMillionTokens: 1,
              completionMicrousdPerMillionTokens: 1,
            ),
          ],
        ),
      );
      await expectLater(
        AgentEvaluationAppRuntimeFactory(
          executionBudget: releaseBudget,
          maxTokensPerCall: 4096,
        ).open(
          context: context,
          promptRegistry: promptRegistry,
          route: route,
          decoding: decoding,
          providerClient: const _NoCallClient(),
        ),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
      );
      expect(sandboxOwners, <String>{'runner-main'});
      final runtime = await const AgentEvaluationAppRuntimeFactory().open(
        context: context,
        promptRegistry: promptRegistry,
        route: route,
        decoding: decoding,
        providerClient: const _NoCallClient(),
      );
      expect(shortConnectionOwners, isNotEmpty);
      expect(
        shortConnectionOwners.toSet(),
        hasLength(shortConnectionOwners.length),
      );
      expect(sandboxOwners, hasLength(2));

      await AgentEvaluationTraceContext.run(
        AgentEvaluationTraceContext(
          experimentId: manifest.experimentId,
          executionId: context.lease.executionId,
          cellId: context.lease.cellId,
          trialSlotId: context.lease.trialSlotId,
          attemptNo: context.attemptNo,
          runId: context.runId,
          leaseEpoch: context.lease.epoch,
          leaseOwner: context.lease.owner,
          isolationTrialId: context.isolationTrialId,
          generationBundleHash: 'sha256:$bundleHash',
          evaluationBundleHash: 'sha256:${manifest.evaluationBundleHash}',
        ),
        () => runtime.prepare(context),
      );
      await runtime.dispose();
      expect(sandboxOwners, <String>{'runner-main'});
    },
  );
}

ExperimentManifest _manifest({
  required String bundleHash,
  required String modelRouteHash,
  required String decodingConfigHash,
  required String providerConfigHashWithoutSecrets,
}) {
  const fixture = <String, Object?>{
    'prompt': '使用克隆数据库里的 sentinel 状态生成场景。',
    'projectId': 'project-fixture-sentinel',
    'sceneId': 'scene-fixture-sentinel',
    'sceneScopeId': 'project-fixture-sentinel::scene-fixture-sentinel',
  };
  final scenario = ScenarioRelease(
    scenarioId: 'hydration-scene-1',
    version: '1.0.0',
    difficulty: 'release',
    inputFixture: fixture,
    fixtureHash: _digest('1'),
    isolationMode: 'independent',
    requiredCapabilities: const <String>['story-generation'],
    adversarialMutations: const <String>[],
    verifierReleaseRefs: const <String>['safety-v1'],
    rubricReleaseRef: 'rubric-v1',
    expectedTerminalState: 'accepted',
    requiredFailureCodes: const <String>[],
    allowedAdditionalFailureCodes: const <String>[],
    forbiddenFailureCodes: const <String>[],
    outcomeComparatorReleaseRef: 'comparator-v1',
    forbiddenSideEffects: const <String>[],
    acceptExpected: true,
    referenceFacts: const <String, Object?>{'safe': true},
    maxBudget: const <String, Object?>{'calls': 1},
  );
  final set = ScenarioSetRelease(
    setId: 'hydration-set',
    version: '1.0.0',
    scenarios: <ScenarioRelease>[scenario],
    fixtureCount: 1,
    outlineSceneCount: 1,
    holdout: false,
    createdAtMs: 1,
  );
  final cell = AgentEvaluationCellManifest(
    generationBundleHash: bundleHash,
    modelRouteHash: modelRouteHash,
    scenarioReleaseHash: scenario.releaseHash,
    decodingConfigHash: decodingConfigHash,
  );
  return ExperimentManifest(
    experimentId: 'hydration-experiment-1',
    scenarioSet: set,
    generationBundleHashes: <String>[bundleHash],
    evaluationBundleHash: _digest('e'),
    modelRouteHashes: <String>[modelRouteHash],
    decodingConfigHashes: <String>[cell.decodingConfigHash],
    cells: <AgentEvaluationCellManifest>[cell],
    pipelineConfigHash: _digest('5'),
    providerConfigHashWithoutSecrets: providerConfigHashWithoutSecrets,
    providerApiRevision: 'test-api-v1',
    sdkAdapterReleaseHash: _digest('3'),
    tokenizerReleaseHash: _digest('6'),
    priceTableHash: _digest('7'),
    codeCommit: 'test-commit',
    sourceTreeHash: _digest('8'),
    buildArtifactHash: _digest('9'),
    runtimeReleaseHash: _digest('a'),
    trialsPerCell: 1,
    seedPolicy: const <String, Object?>{'mode': 'recorded'},
    trialIsolationPolicy: const <String, Object?>{'mode': 'independent-db'},
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 1},
    performanceSamplingPolicy: const <String, Object?>{},
    qualityComparisonPolicyHash: _digest('b'),
    holdoutAccessPolicy: HoldoutAccessPolicy(
      policyHash: _digest('c'),
      accessBudget: 1,
      accessOrdinal: 0,
    ),
    budgets: const <String, Object?>{'calls': 1},
    qualityThresholds: const <String, Object?>{},
    createdAtMs: 1,
  );
}

final class _NoCallClient implements AppLlmClient {
  const _NoCallClient();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) =>
      throw StateError('hydration must not call the provider');

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw StateError('hydration must not call the provider');
}

String _raw(String value) =>
    value.startsWith('sha256:') ? value.substring(7) : value;
String _digest(String character) => List<String>.filled(64, character).join();
