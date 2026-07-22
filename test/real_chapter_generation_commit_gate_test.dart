// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/service_registration.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/story_generation/data/story_pipeline_factory.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_execution_budget.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_non_release_canary_client.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Real-provider production gate for Spec AC-17 / #17.
///
/// This suite is intentionally skipped unless both a run switch and an
/// explicit cost acknowledgement are supplied.  It never writes provider
/// credentials or request text to artifacts or test output.
const _runSwitch = 'RUN_NON_RELEASE_GLM_PRODUCTION_CANARY';
const _costAck = 'NON_RELEASE_GLM_CANARY_ACK';
const _requiredCostAck = 'I_ACCEPT_REAL_PROVIDER_COSTS';
const _costMode = 'NON_RELEASE_GLM_CANARY_COST_MODE';
const _requiredCostMode = 'UNBOUNDED_BY_USER_AUTHORIZATION';
const _expectedModel = 'glm-5.2';
const _expectedBaseUrl = 'https://open.bigmodel.cn/api/anthropic';
const _maxProviderCalls = 145;
const _maxTotalTokens = 500000;
const _maxDurationMs = 45 * 60 * 1000;
const _representativeSceneIndexes = <int>[0, 4, 9];

/// The historical test entry point remains permanently network-closed.
void main() {
  final decision = AgentEvaluationRealProviderEntryGate.legacyDecision(
    entryPoint: 'test/real_chapter_generation_commit_gate_test.dart',
    environment: Platform.environment,
  );
  test('legacy real chapter gate remains coordinator-only', () {
    expect(decision.authorized, isFalse);
    expect(decision.denialReason, contains('formally signed runtime'));
  });
}

/// Registers the separately authorized, explicitly non-release GLM canary.
///
/// This function is invoked only by
/// `test/non_release_glm_production_canary_test.dart`; importing this library
/// does not weaken the historical entry point above.
void registerNonReleaseGlmProductionCanaryTests() {
  final gate = _RealProviderGate.fromEnvironment(Platform.environment);

  test('real chapter commit gate is network-disabled without both opt-ins', () {
    expect(
      _RealProviderGate.fromValues(
        runEnabled: false,
        costAcknowledged: false,
        providerName: 'OpenAI compatible',
        baseUrl: '',
        model: '',
        apiKey: '',
      ).skipReason,
      isNotNull,
    );
    expect(
      _RealProviderGate.fromValues(
        runEnabled: true,
        costAcknowledged: false,
        providerName: 'OpenAI compatible',
        baseUrl: 'https://provider.invalid/v1',
        model: 'model',
        apiKey: 'secret',
      ).skipReason,
      contains(_costAck),
    );
  });

  test('non-release canary requires explicit unbounded-cost authorization', () {
    final base = <String, String>{
      _runSwitch: '1',
      _costAck: _requiredCostAck,
      'REAL_PROVIDER_BASE_URL': _expectedBaseUrl,
      'REAL_PROVIDER_MODEL': _expectedModel,
      'REAL_PROVIDER_API_KEY': 'test-only',
      'PRODUCTION_CANARY_MAX_PROVIDER_CALLS': '145',
      'PRODUCTION_CANARY_MAX_TOTAL_TOKENS': '500000',
      'PRODUCTION_CANARY_MAX_DURATION_MS': '2700000',
    };

    expect(
      _RealProviderGate.fromEnvironment(base).skipReason,
      contains(_costMode),
    );
    expect(
      _RealProviderGate.fromEnvironment({
        ...base,
        _costMode: 'ZERO_COST_ONLY',
      }).skipReason,
      contains(_costMode),
    );
    expect(
      _RealProviderGate.fromEnvironment({
        ...base,
        _costMode: _requiredCostMode,
      }).skipReason,
      isNull,
    );
  });

  test('production canary report is non-release and secret-free', () {
    final output = Directory.systemTemp.createTempSync('production-canary-');
    addTearDown(() => output.deleteSync(recursive: true));
    final paths = _writeSafeProductionCanaryReport(
      gate: _RealProviderGate.fromValues(
        runEnabled: true,
        costAcknowledged: true,
        providerName: '智谱 GLM (Anthropic protocol)',
        baseUrl: 'https://example.invalid/api/anthropic',
        model: 'glm-test',
        apiKey: 'must-not-leak',
      ),
      startedAt: DateTime.utc(2026, 7, 12),
      completedAt: DateTime.utc(2026, 7, 12, 0, 1),
      sceneEvidence: const [
        {
          'fixtureId': 'scene-1',
          'quality': {'overall': 96},
          'sanitizedProse': 'Bearer [REDACTED]，章节正文。',
        },
      ],
      candidateProofCount: 1,
      receiptCount: 1,
      summaryHeadCount: 1,
      outputDirectory: output,
    );

    final report = File(paths.$1).readAsStringSync();
    expect(report, contains('"releaseEligible": false'));
    expect(report, contains('"codingPlanEndpointUsed": true'));
    expect(report, isNot(contains('codingPlanCreditsUsed')));
    expect(report, contains('"reportHash"'));
    expect(report, isNot(contains('must-not-leak')));
    expect(report, isNot(contains('example.invalid')));
    expect(report, isNot(contains('Authorization: Bearer')));
    expect(report, isNot(contains('Reply with pong.')));
  });

  test('failed canary report preserves every sanitized draft checkpoint', () {
    const apiKey = 'draft-secret-key';
    final db = sqlite3.sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('''
      CREATE TABLE story_generation_stage_checkpoints (
        run_id TEXT NOT NULL,
        prose_revision INTEGER NOT NULL,
        ordinal INTEGER NOT NULL,
        stage_id TEXT NOT NULL,
        stage_attempt INTEGER NOT NULL,
        status TEXT NOT NULL,
        artifact_digest TEXT NOT NULL,
        artifact_json TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        completed_at_ms INTEGER
      )
    ''');
    void insertDraft({
      required int ordinal,
      required String stageId,
      required int stageAttempt,
      required int attempt,
      required String prose,
    }) {
      db.execute(
        '''
        INSERT INTO story_generation_stage_checkpoints (
          run_id, prose_revision, ordinal, stage_id, stage_attempt, status,
          artifact_digest, artifact_json, created_at_ms, completed_at_ms
        ) VALUES (?, 0, ?, ?, ?, 'completed', ?, ?, ?, ?)
        ''',
        [
          'failed-run',
          ordinal,
          stageId,
          stageAttempt,
          'sha256:draft-$stageAttempt',
          jsonEncode({
            'codec': 'generation-stage-artifact',
            'version': 2,
            'ordinal': ordinal,
            'stageId': stageId,
            'artifactType': ordinal == 5 ? 'proseDraft' : 'polishedProse',
            'payload': {
              'attempt': attempt,
              'draftAttempt': attempt,
              'draftText': prose,
              'proseText': prose,
              'rawRequest': 'Reply with pong.',
            },
          }),
          stageAttempt * 10,
          stageAttempt * 10 + 1,
        ],
      );
    }

    insertDraft(
      ordinal: 5,
      stageId: 'editorial',
      stageAttempt: 1,
      attempt: 1,
      prose: '第一轮草稿包含 $apiKey。',
    );
    insertDraft(
      ordinal: 7,
      stageId: 'polish',
      stageAttempt: 1,
      attempt: 1,
      prose: '第一轮润色包含 Authorization: Bearer provider-token。',
    );
    insertDraft(
      ordinal: 5,
      stageId: 'editorial',
      stageAttempt: 4,
      attempt: 2,
      prose: '第二轮草稿正文。',
    );

    final drafts = _collectSanitizedCanaryDrafts(
      db: db,
      runId: 'failed-run',
      apiKey: apiKey,
    );
    expect(drafts.map((draft) => draft['stage']), [
      'editorial',
      'polish',
      'editorial',
    ]);
    expect(drafts.map((draft) => draft['attempt']), [1, 1, 2]);

    final output = Directory.systemTemp.createTempSync('canary-drafts-');
    addTearDown(() => output.deleteSync(recursive: true));
    final paths = _writeSafeProductionCanaryReport(
      gate: _RealProviderGate.fromValues(
        runEnabled: true,
        costAcknowledged: true,
        providerName: '智谱 GLM (Anthropic protocol)',
        baseUrl: 'https://example.invalid/api/anthropic',
        model: 'glm-test',
        apiKey: apiKey,
      ),
      startedAt: DateTime.utc(2026, 7, 15),
      completedAt: DateTime.utc(2026, 7, 15, 0, 1),
      status: 'failed',
      failureCode: 'QualityGateFailure',
      sceneEvidence: [
        {'fixtureId': 'scene-1', 'runId': 'failed-run', 'drafts': drafts},
      ],
      candidateProofCount: 0,
      receiptCount: 0,
      summaryHeadCount: 0,
      outputDirectory: output,
    );

    final report = File(paths.$1).readAsStringSync();
    final decoded = jsonDecode(report) as Map<String, Object?>;
    expect(decoded['status'], 'failed');
    expect(decoded['releaseEligible'], isFalse);
    expect(decoded['draftCount'], 3);
    expect(report, contains('第一轮草稿'));
    expect(report, contains('第一轮润色'));
    expect(report, contains('第二轮草稿'));
    expect(report, contains('[REDACTED_API_KEY]'));
    expect(report, contains('Authorization: [REDACTED]'));
    expect(report, isNot(contains(apiKey)));
    expect(report, isNot(contains('provider-token')));
    expect(report, isNot(contains('Reply with pong.')));
    expect(report, isNot(contains('example.invalid')));
  });

  test(
    'real preflight is inside the same hard global canary budget',
    () async {
      if (gate.skipReason != null) return;
      expect(gate.maxCalls, _maxProviderCalls);
      expect(gate.maxTotalTokens, _maxTotalTokens);
      expect(gate.maxDurationMs, _maxDurationMs);
      expect(gate.unboundedCostAuthorized, isTrue);
      expect(_fixtures, hasLength(3));
      final harness = await _ProductionHarness.create(gate);
      addTearDown(harness.dispose);
      expect(harness.canaryClient.budgetSnapshot.calls, 0);
      final journal = File(
        '${gate.outputDirectory.path}/production-canary-budget.json',
      ).readAsStringSync();
      expect(journal, isNot(contains(gate.apiKey)));
      expect(journal, isNot(contains(gate.baseUrl)));
      expect(journal, isNot(contains('Authorization')));
      expect(journal, isNot(contains('Reply with pong.')));
    },
    skip: gate.skipReason,
  );

  test(
    'chapter recovery production gate',
    () async {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        gate.startedAtMs,
        isUtc: true,
      );
      final sceneEvidence = <Map<String, Object?>>[];
      final harness = await _ProductionHarness.create(gate);
      addTearDown(harness.dispose);
      var status = 'failed';
      String? failureCode;
      var activeFixtureId = '';
      try {
        expect(
          harness.workspace.scenes.length,
          3,
          reason: 'real canary must provision exactly three scenes',
        );
        await harness.runMeteredPreflight();
        expect(
          harness.canaryClient.budgetSnapshot.calls,
          1,
          reason:
              'the identity preflight must be the first globally metered call',
        );

        // Three independent author-initiated production scene runs. There is
        // no benchmark-only parent/batch runner in this test.
        for (var index = 0; index < _fixtures.length; index += 1) {
          final fixture = _fixtures[index];
          final scene = harness.workspace.scenes[index];
          activeFixtureId = fixture.id;
          print('real canary: ${fixture.id} (${index + 1}/3)');
          harness.workspace.updateCurrentScene(
            sceneId: scene.id,
            recentLocation: scene.displayLocation,
          );
          await harness.runStore.runCurrentScene(rulesOverride: fixture.intent);
          final candidate = harness.runStore.snapshot;
          expect(
            candidate.hasDurableCandidateProof,
            isTrue,
            reason:
                '${fixture.id}: candidate proof/payload is required before accept; '
                'status=${candidate.status.name}, phase=${candidate.phase.name}, '
                'detail=${candidate.errorDetail}, feedback='
                '${candidate.messages.map((message) => message.body).join(' | ')}, '
                'review=${_reviewDiagnostic(harness.db, candidate.runId)}',
          );
          final qualityScore = await _assertQualityAndIndependentReview(
            db: harness.db,
            runId: candidate.runId,
            fixtureId: fixture.id,
          );
          await _assertBudgetCeilings(
            db: harness.db,
            runId: candidate.runId,
            fixtureId: fixture.id,
          );
          final sanitizedProse = _sanitizeCanaryText(
            candidate.candidateProse,
            apiKey: gate.apiKey,
          );
          final drafts = _collectSanitizedCanaryDrafts(
            db: harness.db,
            runId: candidate.runId,
            apiKey: gate.apiKey,
          );

          await harness.runStore.acceptCurrentCandidate();
          expect(
            harness.runStore.snapshot.phase.name,
            'commit',
            reason:
                '${fixture.id}: UI/run projection may report commit only after coordinator success',
          );
          expect(
            harness.db.select(
              'SELECT 1 FROM story_generation_commit_receipts WHERE run_id = ?',
              [candidate.runId],
            ),
            hasLength(1),
            reason:
                '${fixture.id}: every accepted scene needs one durable receipt',
          );
          final receipt = harness.db.select(
            '''SELECT receipt_id FROM story_generation_commit_receipts
               WHERE run_id = ?''',
            [candidate.runId],
          );
          sceneEvidence.add({
            'fixtureId': fixture.id,
            'runId': candidate.runId,
            'candidateHash': candidate.candidateHash,
            'generationBundleHash': candidate.candidateGenerationBundleHash,
            'quality': qualityScore,
            'sanitizedProse': sanitizedProse,
            'drafts': drafts,
            'receiptId': receipt.single['receipt_id'],
          });
        }

        expect(
          harness.db.select('SELECT 1 FROM story_generation_candidate_proofs'),
          hasLength(3),
        );
        expect(
          harness.db.select('SELECT 1 FROM story_generation_commit_receipts'),
          hasLength(3),
        );
        final summaryHeads = harness.db.select('''
          SELECT name FROM sqlite_master
          WHERE type = 'table' AND name = 'story_generation_summary_revisions'
        ''');
        expect(
          summaryHeads,
          hasLength(1),
          reason: 'summary revision table is required',
        );
        expect(
          harness.db.select('SELECT 1 FROM story_generation_summary_heads'),
          isNotEmpty,
          reason: 'accepted scenes must advance an authoritative summary head',
        );
        await harness.runStore.waitForPendingOutboxDrains();
        final budget = harness.canaryClient.budgetSnapshot;
        expect(budget.calls, lessThanOrEqualTo(_maxProviderCalls));
        expect(budget.totalTokens, lessThanOrEqualTo(_maxTotalTokens));
        expect(budget.activeReservations, 0);
        if (DateTime.now().millisecondsSinceEpoch >= gate.deadlineAtMs) {
          throw const AgentEvaluationNonReleaseCanaryException(
            'canary-wall-deadline-exhausted',
            'canary did not finish within the authorized wall-clock limit',
          );
        }
        status = 'passed';
      } on Object catch (error) {
        failureCode = _safeCanaryFailureCode(error);
        rethrow;
      } finally {
        final failedSnapshot = harness.runStore.snapshot;
        if (activeFixtureId.isNotEmpty &&
            !sceneEvidence.any(
              (evidence) => evidence['fixtureId'] == activeFixtureId,
            )) {
          final drafts = _collectSanitizedCanaryDrafts(
            db: harness.db,
            runId: failedSnapshot.runId,
            apiKey: gate.apiKey,
          );
          sceneEvidence.add({
            'fixtureId': activeFixtureId,
            'runId': failedSnapshot.runId,
            'status': status,
            'candidateHash': failedSnapshot.candidateHash,
            'generationBundleHash':
                failedSnapshot.candidateGenerationBundleHash,
            if (failedSnapshot.candidateProse.trim().isNotEmpty)
              'sanitizedProse': _sanitizeCanaryText(
                failedSnapshot.candidateProse,
                apiKey: gate.apiKey,
              ),
            'drafts': drafts,
          });
        }
        final completedAt = DateTime.now().toUtc();
        final reportPaths = _writeSafeProductionCanaryReport(
          gate: gate,
          startedAt: startedAt,
          completedAt: completedAt,
          status: status,
          failureCode: failureCode,
          sceneEvidence: sceneEvidence,
          candidateProofCount: harness.db
              .select('SELECT 1 FROM story_generation_candidate_proofs')
              .length,
          receiptCount: harness.db
              .select('SELECT 1 FROM story_generation_commit_receipts')
              .length,
          summaryHeadCount: harness.db
              .select('SELECT 1 FROM story_generation_summary_heads')
              .length,
          budgetSnapshot: harness.canaryClient.budgetSnapshot,
          providerCalls: harness.canaryClient.calls,
          traceEntries: harness.traceSink.entries,
          outputDirectory: gate.outputDirectory,
        );
        print('production canary json report: ${reportPaths.$1}');
        print('production canary markdown report: ${reportPaths.$2}');
      }
    },
    timeout: const Timeout(Duration(milliseconds: _maxDurationMs)),
    skip: gate.skipReason,
  );
}

class _RealProviderGate {
  const _RealProviderGate({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    required this.maxCalls,
    required this.maxTotalTokens,
    required this.maxDurationMs,
    required this.unboundedCostAuthorized,
    required this.startedAtMs,
    required this.skipReason,
  });

  factory _RealProviderGate.fromEnvironment(Map<String, String> environment) {
    final baseUrl =
        environment['REAL_PROVIDER_BASE_URL'] ??
        environment['ZHIPU_BASE_URL'] ??
        _expectedBaseUrl;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return _RealProviderGate.fromValues(
      runEnabled: environment[_runSwitch] == '1',
      costAcknowledged: environment[_costAck] == _requiredCostAck,
      providerName: '智谱 GLM (Anthropic protocol)',
      baseUrl: baseUrl,
      model:
          environment['REAL_PROVIDER_MODEL'] ??
          environment['ZHIPU_MODEL'] ??
          '',
      apiKey:
          environment['REAL_PROVIDER_API_KEY'] ??
          environment['ZHIPU_API_KEY'] ??
          '',
      maxCalls: int.tryParse(
        environment['PRODUCTION_CANARY_MAX_PROVIDER_CALLS'] ?? '',
      ),
      maxTotalTokens: int.tryParse(
        environment['PRODUCTION_CANARY_MAX_TOTAL_TOKENS'] ?? '',
      ),
      maxDurationMs: int.tryParse(
        environment['PRODUCTION_CANARY_MAX_DURATION_MS'] ?? '',
      ),
      unboundedCostAuthorized: environment[_costMode] == _requiredCostMode,
      nowMs: nowMs,
    );
  }

  factory _RealProviderGate.fromValues({
    required bool runEnabled,
    required bool costAcknowledged,
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    int? maxCalls = _maxProviderCalls,
    int? maxTotalTokens = _maxTotalTokens,
    int? maxDurationMs = _maxDurationMs,
    bool unboundedCostAuthorized = true,
    int? nowMs,
  }) {
    final observedNowMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    String? skipReason;
    if (!runEnabled) {
      skipReason = 'Set $_runSwitch=1 to authorize a real-provider run.';
    } else if (!costAcknowledged) {
      skipReason =
          'Set $_costAck=$_requiredCostAck to acknowledge provider cost.';
    } else if (baseUrl.trim().isEmpty ||
        model.trim().isEmpty ||
        apiKey.isEmpty) {
      skipReason =
          'REAL_PROVIDER_BASE_URL, REAL_PROVIDER_MODEL, and REAL_PROVIDER_API_KEY are required.';
    } else if (canonicalAgentEvaluationBaseUrl(baseUrl) != _expectedBaseUrl ||
        model.trim() != _expectedModel) {
      skipReason =
          'The canary route must be exactly $_expectedBaseUrl / $_expectedModel.';
    } else if (maxCalls != _maxProviderCalls ||
        maxTotalTokens != _maxTotalTokens ||
        maxDurationMs != _maxDurationMs) {
      skipReason =
          'The canary hard budget must be exactly 145 calls, 500000 tokens, and 2700000 ms.';
    } else if (!unboundedCostAuthorized) {
      skipReason =
          'Set $_costMode=$_requiredCostMode to record explicit removal of the cost ceiling.';
    }
    return _RealProviderGate(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      maxCalls: maxCalls ?? 0,
      maxTotalTokens: maxTotalTokens ?? 0,
      maxDurationMs: maxDurationMs ?? 0,
      unboundedCostAuthorized: unboundedCostAuthorized,
      startedAtMs: observedNowMs,
      skipReason: skipReason,
    );
  }

  final String baseUrl;
  final String providerName;
  final String model;
  final String apiKey;
  final int maxCalls;
  final int maxTotalTokens;
  final int maxDurationMs;
  final bool unboundedCostAuthorized;
  final int startedAtMs;
  final String? skipReason;

  int get deadlineAtMs => startedAtMs + maxDurationMs;

  AppLlmProvider get provider => providerName.toAppLlmProvider();

  String get modelRouteHash => AgentEvaluationHashes.domainHash(
    'non-release-canary-route-v1',
    <String, Object?>{
      'provider': provider.name,
      'baseUrl': canonicalAgentEvaluationBaseUrl(baseUrl),
      'model': model.trim(),
    },
  );

  Directory get outputDirectory => Directory(
    Platform.environment['PRODUCTION_CANARY_OUTPUT_DIR'] ??
        '${Directory.current.path}/.omx/evidence',
  );
}

class _ProductionHarness {
  _ProductionHarness._({
    required this.registry,
    required this.db,
    required this.workspace,
    required this.runStore,
    required this.canaryClient,
    required this.traceSink,
    required this.gate,
  });

  final ServiceRegistry registry;
  final sqlite3.Database db;
  final AppWorkspaceStore workspace;
  final StoryGenerationRunStore runStore;
  final AgentEvaluationNonReleaseCanaryClient canaryClient;
  final _CanaryTraceSink traceSink;
  final _RealProviderGate gate;

  static Future<_ProductionHarness> create(_RealProviderGate gate) async {
    final registry = ServiceRegistry();
    gate.outputDirectory.createSync(recursive: true);
    final budgetPolicy = AgentEvaluationExecutionBudgetPolicy(
      budgetId: 'glm-production-canary-${gate.startedAtMs}',
      maxCalls: gate.maxCalls,
      maxPromptTokens: gate.maxTotalTokens,
      maxCompletionTokens: gate.maxTotalTokens,
      maxTotalTokens: gate.maxTotalTokens,
      maxCostMicrousd: 0,
      deadlineAtMs: gate.deadlineAtMs,
      costEnforcement: AgentEvaluationCostEnforcement.disabled,
      routes: [
        AgentEvaluationBudgetRoute(
          modelRouteHash: gate.modelRouteHash,
          model: gate.model,
          maxPromptTokensPerCall: gate.maxTotalTokens,
          promptMicrousdPerMillionTokens: 0,
          completionMicrousdPerMillionTokens: 0,
        ),
      ],
    );
    final budget = AgentEvaluationExecutionBudgetGuard(
      policy: budgetPolicy,
      journalFile: File(
        '${gate.outputDirectory.path}/production-canary-budget.json',
      ),
    );
    final canaryClient = AgentEvaluationNonReleaseCanaryClient(
      inner: createDefaultAppLlmClient(),
      budget: budget,
      expectedModel: gate.model,
      expectedProvider: gate.provider,
      expectedBaseUrl: gate.baseUrl,
      frozenApiKey: gate.apiKey,
      modelRouteHash: gate.modelRouteHash,
      enforceZeroCost: false,
    );
    final traceSink = _CanaryTraceSink();
    final eventLog = AppEventLog(
      storage: _DiscardingCanaryEventLogStorage(),
      sessionId: 'non-release-glm-canary',
    );
    final db = sqlite3.sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    final eventBus = AppEventBus();
    final workspace = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
      eventBus: eventBus,
    );
    workspace.createProject(projectName: '真实 Provider 提交门禁');
    workspace.createCharacter();
    final liuxi = workspace.characters.first;
    workspace.updateCharacter(
      characterId: liuxi.id,
      name: '柳溪',
      role: '调查记者',
      need: '拿到门禁篡改的可验证证据，逼出地下库房线索。',
      note: '当前谈判位势：柳溪掌握时间戳证据，持续逼问并主导行动。',
      summary:
          '柳溪是调查记者而非警察；本场 POV 不能无故放弃证据优势或改为被保安主导，'
          '禁止使用“柳队”“警官”等警务称谓或无依据的执法身份。',
    );
    workspace.createCharacter();
    final guard = workspace.characters.last;
    workspace.updateCharacter(
      characterId: guard.id,
      name: '傅行舟',
      role: '旧港保安',
      need: '掩盖自己对篡改记录的知情程度，同时避免承担责任。',
      note: '当前谈判位势：傅行舟被柳溪拿住时间戳矛盾，先推诿后被迫交代。',
      summary: '傅行舟在本场是被逼问的一方；可以反抗或隐瞒，不能无因取得主导。',
    );
    for (var index = 1; index <= _fixtures.length; index += 1) {
      workspace.createScene('第 $index 场');
    }

    final settings = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: canaryClient,
      llmTraceSink: traceSink,
      eventLog: eventLog,
    );
    await settings.save(
      providerName: gate.providerName,
      baseUrl: gate.baseUrl,
      model: gate.model,
      apiKey: gate.apiKey,
      timeoutMs: 90000,
      maxConcurrentRequests: 1,
      maxTokens: 4096,
    );
    final draft = AppDraftStore(
      storage: InMemoryAppDraftStorage(),
      workspaceStore: workspace,
      eventBus: eventBus,
    );
    final generation = StoryGenerationStore(
      storage: InMemoryStoryGenerationStorage(),
      workspaceStore: workspace,
      eventBus: eventBus,
    );
    await generation.waitUntilReady();
    final outline = StoryOutlineStore(
      storage: InMemoryStoryOutlineStorage(),
      workspaceStore: workspace,
      eventBus: eventBus,
    );
    outline.replaceSnapshot(
      _productionOutline(workspace, liuxiId: liuxi.id, guardId: guard.id),
    );

    registry
      ..registerSingleton<sqlite3.Database>(db)
      ..registerSingleton<AppEventBus>(eventBus)
      ..registerSingleton<AppEventLog>(eventLog, owned: false)
      ..registerSingleton<AppLlmClient>(canaryClient, owned: false)
      ..registerSingleton<AppWorkspaceStore>(workspace)
      ..registerSingleton<AppSettingsStore>(settings)
      ..registerSingleton<AppDraftStore>(draft)
      ..registerSingleton<StoryGenerationStore>(generation)
      ..registerSingleton<AppSceneContextStore>(
        AppSceneContextStore(
          storage: InMemoryAppSceneContextStorage(),
          workspaceStore: workspace,
          eventBus: eventBus,
        ),
      )
      ..registerSingleton<StoryOutlineStore>(outline)
      ..registerSingleton<AuthorFeedbackStore>(
        AuthorFeedbackStore(
          storage: InMemoryAuthorFeedbackStorage(),
          workspaceStore: workspace,
          eventBus: eventBus,
        ),
      )
      ..registerSingleton<ReviewTaskStore>(
        ReviewTaskStore(
          storage: InMemoryReviewTaskStorage(),
          workspaceStore: workspace,
          eventBus: eventBus,
        ),
      );
    registerAppServices(registry);

    // Resolve the factory explicitly before the run-store to prove the test
    // takes the registered production construction path.
    expect(registry.resolve<StoryPipelineFactory>(), isNotNull);
    final runStore = registry.resolve<StoryGenerationRunStore>();
    await runStore.ready;
    return _ProductionHarness._(
      registry: registry,
      db: db,
      workspace: workspace,
      runStore: runStore,
      canaryClient: canaryClient,
      traceSink: traceSink,
      gate: gate,
    );
  }

  Future<void> runMeteredPreflight() async {
    final result = await canaryClient.chat(
      AppLlmChatRequest(
        baseUrl: gate.baseUrl,
        model: gate.model,
        apiKey: gate.apiKey,
        provider: gate.provider,
        timeout: const AppLlmTimeoutConfig.uniform(90000),
        maxTokens: 4096,
        physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
        dispatchEvidenceNonce:
            'sha256:${AgentEvaluationHashes.domainHash('production-canary-preflight-attempt-v1', <String, Object?>{'budgetId': 'glm-production-canary-${gate.startedAtMs}', 'modelRouteHash': gate.modelRouteHash})}',
        messages: const [
          AppLlmChatMessage(role: 'user', content: 'Reply with pong.'),
        ],
      ),
    );
    expect(result.succeeded, isTrue);
    expect(result.providerModel, _expectedModel);
  }

  void dispose() => registry.disposeAll();
}

Future<Map<String, Object?>> _assertQualityAndIndependentReview({
  required sqlite3.Database db,
  required String runId,
  required String fixtureId,
}) async {
  final reviewRows = db.select(
    '''
    SELECT ordinal FROM story_generation_stage_checkpoints
    WHERE run_id = ? AND ordinal IN (6, 9) AND status = 'completed'
  ''',
    [runId],
  );
  expect(
    reviewRows.map((row) => row['ordinal']).toSet(),
    {6, 9},
    reason:
        '$fixtureId: preliminary and final reviews must both be independent checkpoints',
  );
  final qualityRows = db.select(
    '''
    SELECT artifact_json FROM story_generation_stage_checkpoints
    WHERE run_id = ? AND ordinal = 11 AND status = 'completed'
  ''',
    [runId],
  );
  expect(
    qualityRows,
    hasLength(1),
    reason: '$fixtureId: quality evidence is required',
  );
  final score = _findScore(
    jsonDecode(qualityRows.single['artifact_json'] as String),
  );
  expect(
    score,
    isNotNull,
    reason: '$fixtureId: quality checkpoint must contain a scorecard',
  );
  expect(_scoreValue(score!, 'overall'), greaterThanOrEqualTo(95));
  for (final dimension in [
    'prose',
    'coherence',
    'character',
    'completeness',
    'style',
    'imagery',
    'rhythm',
    'faithfulness',
  ]) {
    expect(
      _scoreValue(score, dimension),
      greaterThanOrEqualTo(90),
      reason: '$fixtureId: $dimension is a critical quality dimension',
    );
  }
  return Map<String, Object?>.unmodifiable(score);
}

(String, String) _writeSafeProductionCanaryReport({
  required _RealProviderGate gate,
  required DateTime startedAt,
  required DateTime completedAt,
  String status = 'passed',
  String? failureCode,
  required List<Map<String, Object?>> sceneEvidence,
  required int candidateProofCount,
  required int receiptCount,
  required int summaryHeadCount,
  AgentEvaluationExecutionBudgetSnapshot? budgetSnapshot,
  List<AgentEvaluationNonReleaseCanaryCall> providerCalls = const [],
  List<AppLlmCallTraceEntry> traceEntries = const [],
  Directory? outputDirectory,
}) {
  final targetDirectory =
      outputDirectory ??
      Directory(
        Platform.environment['PRODUCTION_CANARY_OUTPUT_DIR'] ??
            '${Directory.current.path}/.omx/evidence',
      );
  targetDirectory.createSync(recursive: true);
  final sourceTreeHash =
      Platform.environment['REAL_PROVIDER_SOURCE_TREE_HASH'] ?? 'unrecorded';
  final draftCount = sceneEvidence.fold<int>(
    0,
    (total, scene) =>
        total +
        (scene['drafts'] is List ? (scene['drafts'] as List).length : 0),
  );
  final payload = <String, Object?>{
    'reportType': 'real-provider-production-canary',
    'reportSchemaVersion': 2,
    'claimScope': 'production-pipeline-canary',
    'releaseEligible': false,
    'realProviderEvidence': true,
    'status': status,
    'failureCode': ?failureCode,
    'providerProtocol': gate.providerName,
    'model': gate.model,
    'costAuthorization': <String, Object?>{
      'mode': 'unbounded',
      'accounting': 'disabled',
      'authorizedBy': 'explicit-user-authorization',
      'endpointClass': 'coding-plan-anthropic',
      'codingPlanEndpointUsed': true,
    },
    'authorizedBudget': <String, Object?>{
      'maxProviderCalls': gate.maxCalls,
      'maxTotalTokens': gate.maxTotalTokens,
      'maxDurationMs': gate.maxDurationMs,
      'maxCostMicrousd': null,
    },
    if (budgetSnapshot != null) 'budget': _safeBudgetEvidence(budgetSnapshot),
    'providerCalls': [for (final call in providerCalls) call.toJson()],
    'promptVersions': _promptVersionEvidence(traceEntries),
    'callTraces': [for (final entry in traceEntries) _safeTraceEvidence(entry)],
    'sourceTreeHash': sourceTreeHash,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'durationMs': completedAt.difference(startedAt).inMilliseconds,
    'sceneCount': sceneEvidence.length,
    'draftCount': draftCount,
    'candidateProofCount': candidateProofCount,
    'receiptCount': receiptCount,
    'summaryHeadCount': summaryHeadCount,
    'scenes': sceneEvidence,
  };
  final reportHash = AgentEvaluationHashes.domainHash(
    'real-provider-production-canary-report-v2',
    payload,
  );
  final report = <String, Object?>{...payload, 'reportHash': reportHash};
  final suffix = completedAt.microsecondsSinceEpoch;
  final jsonPath = '${targetDirectory.path}/production-canary-$suffix.json';
  final markdownPath = '${targetDirectory.path}/production-canary-$suffix.md';
  File(
    jsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  File(markdownPath).writeAsStringSync(
    <String>[
      '# Real Provider Production Canary',
      '',
      '- Claim scope: production pipeline canary',
      '- Release eligible: false',
      '- Status: $status',
      '- Model: ${gate.model}',
      '- Cost ceiling: none (explicitly authorized)',
      '- Cost accounting: disabled',
      '- Endpoint class: Coding Plan Anthropic API',
      '- Scenes: ${sceneEvidence.length}',
      '- Saved drafts: $draftCount',
      '- Candidate proofs: $candidateProofCount',
      '- Commit receipts: $receiptCount',
      '- Summary heads: $summaryHeadCount',
      '- Source tree hash: `$sourceTreeHash`',
      '- Report hash: `$reportHash`',
      '- Duration ms: ${completedAt.difference(startedAt).inMilliseconds}',
      '- Provider calls: ${budgetSnapshot?.calls ?? providerCalls.length}',
      '- Total tokens: ${budgetSnapshot?.totalTokens ?? 0}',
      if (failureCode != null) '- Failure code: $failureCode',
    ].join('\n'),
  );
  _chmod0600(jsonPath);
  _chmod0600(markdownPath);
  return (jsonPath, markdownPath);
}

Map<String, Object?> _safeBudgetEvidence(
  AgentEvaluationExecutionBudgetSnapshot snapshot,
) => <String, Object?>{
  'policyHash': snapshot.policyHash,
  'calls': snapshot.calls,
  'promptTokens': snapshot.promptTokens,
  'completionTokens': snapshot.completionTokens,
  'totalTokens': snapshot.totalTokens,
  'costAccounting': 'disabled',
  'succeededCalls': snapshot.succeededCalls,
  'failedCalls': snapshot.failedCalls,
  'activeReservations': snapshot.activeReservations,
  'breached': snapshot.breached,
  'snapshotHash': snapshot.snapshotHash,
};

Map<String, Object?> _safeTraceEvidence(AppLlmCallTraceEntry entry) =>
    <String, Object?>{
      'model': entry.model,
      'succeeded': entry.succeeded,
      if (entry.latencyMs != null) 'latencyMs': entry.latencyMs,
      if (entry.promptTokens != null) 'promptTokens': entry.promptTokens,
      if (entry.completionTokens != null)
        'completionTokens': entry.completionTokens,
      if (entry.totalTokens != null) 'totalTokens': entry.totalTokens,
      if (entry.failureKind != null) 'failureKind': entry.failureKind,
      if (entry.promptReleaseRef != null)
        'promptReleaseRef': entry.promptReleaseRef!.toJson(),
      if (entry.promptVersion != null)
        'promptVersion': entry.promptVersion!.toJson(),
      if (entry.stageId != null) 'stageId': entry.stageId,
      if (entry.callSiteId != null) 'callSiteId': entry.callSiteId,
      if (entry.variantId != null) 'variantId': entry.variantId,
      if (entry.generationBundleHash != null)
        'generationBundleHash': entry.generationBundleHash,
    };

List<Map<String, Object?>> _promptVersionEvidence(
  List<AppLlmCallTraceEntry> entries,
) {
  final byIdentity = <String, Map<String, Object?>>{};
  for (final entry in entries) {
    final release = entry.promptReleaseRef;
    final version = entry.promptVersion;
    if (release == null && version == null) continue;
    final evidence = <String, Object?>{
      if (release != null) ...release.toJson(),
      if (release == null && version != null) ...version.toJson(),
    };
    byIdentity[jsonEncode(evidence)] = evidence;
  }
  final result = byIdentity.values.toList(growable: false)
    ..sort(
      (left, right) => left['templateId'].toString().compareTo(
        right['templateId'].toString(),
      ),
    );
  return result;
}

List<Map<String, Object?>> _collectSanitizedCanaryDrafts({
  required sqlite3.Database db,
  required String runId,
  required String apiKey,
}) {
  if (runId.trim().isEmpty) return const [];
  final rows = db.select(
    '''
    SELECT prose_revision, ordinal, stage_id, stage_attempt, artifact_json,
           created_at_ms, completed_at_ms
    FROM story_generation_stage_checkpoints
    WHERE run_id = ? AND ordinal IN (5, 7) AND status = 'completed'
    ORDER BY completed_at_ms ASC, ordinal ASC, stage_attempt ASC
    ''',
    [runId],
  );
  final drafts = <Map<String, Object?>>[];
  for (final row in rows) {
    final ordinal = row['ordinal'] as int;
    final expectedStageId = ordinal == 5 ? 'editorial' : 'polish';
    final base = <String, Object?>{
      'sequence': drafts.length + 1,
      'stage': expectedStageId,
      'ordinal': ordinal,
      'stageAttempt': row['stage_attempt'],
      'proseRevision': row['prose_revision'],
      'createdAtMs': row['created_at_ms'],
      if (row['completed_at_ms'] != null)
        'completedAtMs': row['completed_at_ms'],
    };
    if (row['stage_id'] != expectedStageId) {
      drafts.add({
        ...base,
        'status': 'unreadable',
        'failureCode': 'checkpoint-stage-mismatch',
      });
      continue;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(row['artifact_json'] as String);
    } on FormatException {
      drafts.add({
        ...base,
        'status': 'unreadable',
        'failureCode': 'checkpoint-json-malformed',
      });
      continue;
    }
    if (decoded is! Map || decoded['payload'] is! Map) {
      drafts.add({
        ...base,
        'status': 'unreadable',
        'failureCode': 'checkpoint-payload-missing',
      });
      continue;
    }
    final payload = decoded['payload'] as Map;
    final rawText = payload['proseText'] ?? payload['draftText'];
    if (rawText is! String || rawText.trim().isEmpty) {
      drafts.add({
        ...base,
        'status': 'unreadable',
        'failureCode': 'checkpoint-prose-missing',
      });
      continue;
    }
    final sanitizedText = _sanitizeCanaryText(rawText, apiKey: apiKey);
    final attempt = payload['attempt'] ?? payload['draftAttempt'];
    drafts.add({
      ...base,
      'status': 'saved',
      if (attempt is int) 'attempt': attempt,
      'characterCount': sanitizedText.length,
      'textHash': AgentEvaluationHashes.domainHash(
        'real-provider-canary-sanitized-draft-v1',
        {'stage': expectedStageId, 'text': sanitizedText},
      ),
      'sanitizedProse': sanitizedText,
    });
  }
  return List<Map<String, Object?>>.unmodifiable(drafts);
}

String _sanitizeCanaryText(String value, {required String apiKey}) {
  var sanitized = value;
  if (apiKey.isNotEmpty) {
    sanitized = sanitized.replaceAll(apiKey, '[REDACTED_API_KEY]');
  }
  sanitized = sanitized.replaceAll(
    RegExp(
      r'authorization\s*[:=]\s*(?:bearer\s+)?[^\s，。\r\n]+',
      caseSensitive: false,
    ),
    'Authorization: [REDACTED]',
  );
  sanitized = sanitized.replaceAll(
    RegExp(r'bearer\s+[a-z0-9._~+/=-]+', caseSensitive: false),
    'Bearer [REDACTED]',
  );
  if (apiKey.isNotEmpty && sanitized.contains(apiKey)) {
    throw StateError('canary prose redaction failed');
  }
  return sanitized;
}

String _safeCanaryFailureCode(Object error) => switch (error) {
  AgentEvaluationNonReleaseCanaryException(:final code) => code,
  AgentEvaluationBudgetException(:final code) => code,
  _ => error.runtimeType.toString(),
};

void _chmod0600(String path) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', ['600', path]);
  if (result.exitCode != 0) {
    throw StateError('failed to restrict canary artifact permissions');
  }
}

final class _CanaryTraceSink implements AppLlmCallTraceSink {
  final List<AppLlmCallTraceEntry> _entries = <AppLlmCallTraceEntry>[];

  List<AppLlmCallTraceEntry> get entries =>
      List<AppLlmCallTraceEntry>.unmodifiable(_entries);

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    _entries.add(entry);
  }
}

final class _DiscardingCanaryEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}

Future<void> _assertBudgetCeilings({
  required sqlite3.Database db,
  required String runId,
  required String fixtureId,
}) async {
  final rows = db.select(
    'SELECT * FROM story_generation_run_budgets WHERE run_id = ?',
    [runId],
  );
  expect(
    rows,
    hasLength(1),
    reason: '$fixtureId: run budget ledger is required',
  );
  final row = rows.single;
  expect(row['max_calls'], 48);
  expect(row['max_tokens'], 160000);
  expect(row['max_cost_microusd'], 5000000);
}

Map<String, Object?>? _findScore(Object? value) {
  if (value is Map) {
    final map = <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
    if (map.containsKey('overall') && map.containsKey('prose')) return map;
    for (final nested in map.values) {
      final found = _findScore(nested);
      if (found != null) return found;
    }
  }
  if (value is List) {
    for (final nested in value) {
      final found = _findScore(nested);
      if (found != null) return found;
    }
  }
  return null;
}

String _reviewDiagnostic(sqlite3.Database db, String runId) {
  final rows = db.select(
    '''
    SELECT ordinal, stage_attempt, artifact_json
    FROM story_generation_stage_checkpoints
    WHERE run_id = ? AND ordinal IN (6, 9) AND status = 'completed'
    ORDER BY ordinal, stage_attempt
  ''',
    [runId],
  );
  if (rows.isEmpty) return 'no completed preliminary/final review checkpoint';
  final entries = rows.map((row) {
    final decoded = jsonDecode(row['artifact_json'] as String);
    final payload = decoded is Map ? decoded['payload'] : null;
    final text = jsonEncode(payload);
    final excerpt = text.length <= 500 ? text : '${text.substring(0, 500)}…';
    return 'ordinal=${row['ordinal']}, attempt=${row['stage_attempt']}: $excerpt';
  });
  return entries.join(' || ');
}

num _scoreValue(Map<String, Object?> score, String key) =>
    num.tryParse(score[key]?.toString() ?? '') ?? double.nan;

class _Fixture {
  const _Fixture(this.id, this.intent, this.sceneSpec, this.sourceSceneNumber);

  final String id;
  final String intent;
  final _CanarySceneSpec sceneSpec;
  final int sourceSceneNumber;
}

class _CanarySceneSpec {
  const _CanarySceneSpec(this.title, this.summary, this.beat);

  final String title;
  final String summary;
  final String beat;
}

const _canaryScenes = <_CanarySceneSpec>[
  _CanarySceneSpec(
    '门禁时间戳',
    '柳溪用两条错位门禁时间戳逼问傅行舟；傅行舟先推诿，后承认地下库房有原始备份。',
    '必须用时间戳的具体矛盾逼问，傅行舟先推诿后交代地下库房。',
  ),
  _CanarySceneSpec(
    '库房钥匙',
    '柳溪要求傅行舟交出地下库房钥匙；傅行舟以暴雨和巡逻逼近拖延，最后被迫交钥匙。',
    '必须围绕实体钥匙的交付和傅行舟的拖延推进，结尾发现库房门已被破拆。',
  ),
  _CanarySceneSpec(
    '破拆门锁',
    '两人到达地下库房，发现门锁被第三人暴力破拆；柳溪从油渍和工具痕迹判断有人抢先进入。',
    '必须写清破拆痕迹和油渍证据，不能使用同一人两地时间戳的不可能推理。',
  ),
  _CanarySceneSpec(
    '原始备份',
    '库房内的原始备份显示失踪者最后一次刷卡并非自愿；傅行舟承认曾替人删除报警记录。',
    '必须用备份记录与删除报警记录形成因果，傅行舟仍是被追问的一方。',
  ),
  _CanarySceneSpec(
    '失踪名单',
    '柳溪在备份中找到三名失踪者的共同货运编号；未知来电要求她立刻离开旧港。',
    '必须从三人共同货运编号推出新线索，来电只制造威胁不得直接解决案件。',
  ),
  _CanarySceneSpec(
    '货运仓单',
    '柳溪核对货运仓单，发现编号对应一艘凌晨离港的维修船；傅行舟提供了泊位号作为赎罪。',
    '必须通过仓单和泊位号推进，不能让傅行舟突然掌控柳溪或无因转为同盟。',
  ),
  _CanarySceneSpec(
    '维修船泊位',
    '两人赶到泊位，只找到刚熄火的维修船和一只沾盐水的录音笔；录音笔里有失踪者的求救。',
    '必须用录音笔的可播放内容提供证据，维修船已离开，留下追踪压力。',
  ),
  _CanarySceneSpec(
    '求救录音',
    '柳溪听完录音，确认失踪者被送往外海浮标站；傅行舟坦白自己收过封口费。',
    '必须让录音内容与浮标站形成明确下一步，封口费是傅行舟的被动坦白。',
  ),
  _CanarySceneSpec(
    '浮标站坐标',
    '柳溪从录音背景的航标声推算浮标站坐标；海事频道警告风暴将封锁航道。',
    '必须通过航标声和海事警告形成可行动坐标与时间压力，不能凭空瞬移。',
  ),
  _CanarySceneSpec(
    '风暴前出港',
    '柳溪决定在风暴封航前登船前往浮标站，傅行舟交出备用电台；远处船灯突然熄灭。',
    '必须以备用电台和封航倒计时收束，留下船灯熄灭的未决威胁。',
  ),
];

final _fixtures = [
  for (final index in _representativeSceneIndexes)
    _Fixture(
      'scene-${index + 1}',
      '完成本场指定证据链，并保留下一场压力。',
      _canaryScenes[index],
      index + 1,
    ),
];

StoryOutlineSnapshot _productionOutline(
  AppWorkspaceStore workspace, {
  required String liuxiId,
  required String guardId,
}) {
  const chapterPlanId = 'real-provider-chapter-plan';
  final scenes = <ScenePlan>[
    for (var index = 0; index < workspace.scenes.length; index += 1)
      ScenePlan(
        id: workspace.scenes[index].id,
        chapterPlanId: chapterPlanId,
        title: _fixtures[index].sceneSpec.title,
        summary:
            '${_fixtures[index].sceneSpec.summary} 本场必须以至少8轮实质「」对白推进，'
            '每轮对白改变一个事实、选择、关系或压力；对白累计至少占正文35%。',
        // The canary requires six substantive dialogue turns plus a full
        // goal → obstacle → consequence scene turn. 2200 Chinese characters
        // gives the scene room to establish, turn, and land the local event;
        // the extended rubric is mandatory for this formal provider run.
        targetLength: 2200,
        povCharacterId: liuxiId,
        castIds: [liuxiId, guardId],
        beats: [
          BeatPlan(
            id: 'real-beat-${_fixtures[index].sourceSceneNumber}',
            scenePlanId: workspace.scenes[index].id,
            sequence: 1,
            beatType: 'dialogue',
            content:
                '${_fixtures[index].sceneSpec.beat} 用至少8轮有因果回应的对白完成，'
                '禁止以连续旁白替代逼问、推诿、选择和信息交付。',
          ),
        ],
        narrativeArc: '门禁篡改背后有人持续掩盖失踪案，风险逐场升级。',
        metadata: const {'requireExtendedQualityRubric': true},
      ),
  ];
  return StoryOutlineSnapshot(
    projectId: workspace.currentProjectId,
    executablePlan: NovelPlan(
      id: 'real-provider-plan',
      projectId: workspace.currentProjectId,
      title: '旧港失踪案',
      premise: '柳溪追查一批被篡改的门禁记录，发现失踪案背后有人操控旧港。',
      targetChapterCount: 1,
      chapters: [
        ChapterPlan(
          id: chapterPlanId,
          novelPlanId: 'real-provider-plan',
          title: '第一章：旧港门禁',
          summary: '柳溪从异常门禁记录切入，逐步逼近失踪案核心。',
          targetSceneCount: scenes.length,
          scenes: scenes,
        ),
      ],
    ),
  );
}
