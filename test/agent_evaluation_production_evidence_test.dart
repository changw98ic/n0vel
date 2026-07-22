import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/llm/app_llm_call_trace.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_evidence.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_typed_evidence.dart';
import 'package:novel_writer/features/story_generation/data/generation_candidate_identity.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_receipt.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';

import 'test_support/generation_evidence_receipt_fixture.dart';

void main() {
  late Database db;
  late AgentEvaluationTrialContext context;

  setUp(() {
    db = sqlite3.openInMemory();
    _createProductionEvidenceTables(db);
    context = _context(db);
    _seedCommittedProductionRun(db, context.cell.generationBundleHash);
    _upgradeFixtureToV2(db, context.cell.generationBundleHash);
  });

  tearDown(() => db.dispose());

  test(
    'collects metered production proof and binds both run identities',
    () async {
      final result = const AgentEvaluationProductionEvidenceCollector().collect(
        context: context,
        storyRunId: context.runId,
        traces: <AppLlmCallTraceEntry>[_trace(context)],
        meterSnapshot: await _meterSnapshot(context),
        priceTable: _PriceTable(context.manifest.priceTableHash),
        qualityEvidence: _quality(),
        safetyVerifier: _SafetyVerifier(),
      );

      expect(result.productionStoryRunId, context.runId);
      expect(
        result.productionCandidateHash,
        _v2CandidateHash(context.cell.generationBundleHash),
      );
      expect(result.productionReceiptId, 'receipt-1');
      expect(result.usage!.promptTokens, 100);
      expect(result.usage!.completionTokens, 40);
      expect(result.usage!.costMicrousd, 180);
      expect(result.hardGateEvidence!.transactionPassed, isTrue);
      expect(
        result.hardGateEvidence!.transactionVerifierReleaseHash,
        AgentEvaluationProductionTransactionPolicy.releaseHash,
      );
    },
  );

  test('spoofed formal trace cannot be used as production evidence', () async {
    final meterSnapshot = await _meterSnapshot(context);
    expect(
      () => const AgentEvaluationProductionEvidenceCollector().collect(
        context: context,
        storyRunId: context.runId,
        traces: <AppLlmCallTraceEntry>[
          _trace(context, evaluationRunId: 'another-attempt'),
        ],
        meterSnapshot: meterSnapshot,
        priceTable: _PriceTable(context.manifest.priceTableHash),
        qualityEvidence: _quality(),
        safetyVerifier: _SafetyVerifier(),
      ),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test(
    'mismatched receipt fails even when caller supplies passing gates',
    () async {
      db.execute(
        "UPDATE story_generation_commit_receipts SET committed_candidate_hash = '${_prefixed('0')}'",
      );
      final meterSnapshot = await _meterSnapshot(context);

      expect(
        () => const AgentEvaluationProductionEvidenceCollector().collect(
          context: context,
          storyRunId: context.runId,
          traces: <AppLlmCallTraceEntry>[_trace(context)],
          meterSnapshot: meterSnapshot,
          priceTable: _PriceTable(context.manifest.priceTableHash),
          qualityEvidence: _quality(),
          safetyVerifier: _SafetyVerifier(),
        ),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
      );
    },
  );

  test('unfrozen price table cannot manufacture release cost', () async {
    final meterSnapshot = await _meterSnapshot(context);
    expect(
      () => const AgentEvaluationProductionEvidenceCollector().collect(
        context: context,
        storyRunId: context.runId,
        traces: <AppLlmCallTraceEntry>[_trace(context)],
        meterSnapshot: meterSnapshot,
        priceTable: _PriceTable(_digest('0')),
        qualityEvidence: _quality(),
        safetyVerifier: _SafetyVerifier(),
      ),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test(
    'current attempt cannot relabel a previous committed story run',
    () async {
      final meterSnapshot = await _meterSnapshot(context);
      expect(
        () => const AgentEvaluationProductionEvidenceCollector().collect(
          context: context,
          storyRunId: 'previous-story-run',
          traces: <AppLlmCallTraceEntry>[_trace(context)],
          meterSnapshot: meterSnapshot,
          priceTable: _PriceTable(context.manifest.priceTableHash),
          qualityEvidence: _quality(),
          safetyVerifier: _SafetyVerifier(),
        ),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
      );
    },
  );

  test('metered call omitted from formal traces is rejected', () async {
    final meterSnapshot = await _meterSnapshot(context, callCount: 2);
    expect(
      () => const AgentEvaluationProductionEvidenceCollector().collect(
        context: context,
        storyRunId: context.runId,
        traces: <AppLlmCallTraceEntry>[_trace(context)],
        meterSnapshot: meterSnapshot,
        priceTable: _PriceTable(context.manifest.priceTableHash),
        qualityEvidence: _quality(),
        safetyVerifier: _SafetyVerifier(),
      ),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test(
    'tampered authoritative draft is rejected despite intact receipt',
    () async {
      db.execute("UPDATE draft_documents SET text_body = '被事后篡改的正文'");
      final meterSnapshot = await _meterSnapshot(context);

      expect(
        () => const AgentEvaluationProductionEvidenceCollector().collect(
          context: context,
          storyRunId: context.runId,
          traces: <AppLlmCallTraceEntry>[_trace(context)],
          meterSnapshot: meterSnapshot,
          priceTable: _PriceTable(context.manifest.priceTableHash),
          qualityEvidence: _quality(),
          safetyVerifier: _SafetyVerifier(),
        ),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
      );
    },
  );

  test('proof and receipt cannot share a forged candidate hash', () async {
    db.execute(
      "UPDATE story_generation_candidate_proofs SET candidate_hash = '${_prefixed('0')}'",
    );
    db.execute(
      "UPDATE story_generation_commit_receipts SET committed_candidate_hash = '${_prefixed('0')}'",
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('V2 candidate proof is recomputed from every identity field', () async {
    final candidateHash = _v2CandidateHash(context.cell.generationBundleHash);
    final result = _collect(context, await _meterSnapshot(context));

    expect(result.productionCandidateHash, candidateHash);
  });

  test('tampered V2 identity field is rejected', () async {
    db.execute(
      'UPDATE story_generation_candidate_proofs '
      'SET effective_brief_digest = ?',
      <Object?>[_prefixed('f')],
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('unknown candidate proof identity version fails closed', () async {
    db.execute(
      'UPDATE story_generation_candidate_proofs '
      'SET proof_identity_version = ?',
      <Object?>['candidate-proof-v999'],
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('legacy V1 candidate proof cannot become release evidence', () async {
    final v1Hash = _candidateHash(context.cell.generationBundleHash);
    db.execute(
      '''UPDATE story_generation_candidate_proofs SET
        candidate_hash = ?, proof_identity_version = ?,
        prepared_brief_digest = NULL, effective_brief_digest = NULL,
        generation_evidence_mode = ?''',
      <Object?>[
        v1Hash,
        GenerationCandidateIdentity.v1,
        GenerationCandidateIdentity.legacyUnsealedMode,
      ],
    );
    db.execute(
      'UPDATE story_generation_commit_receipts '
      'SET committed_candidate_hash = ?',
      <Object?>[v1Hash],
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('adaptive V2 candidate rejects sealed-only evidence fields', () async {
    db.execute(
      'UPDATE story_generation_candidate_proofs '
      'SET generation_evidence_receipt_hash = ?',
      <Object?>[_prefixed('9')],
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('commit receipt scene scope must match its production run', () async {
    db.execute(
      "UPDATE story_generation_commit_receipts SET scene_scope_id = 'other'",
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test(
    'adaptive V2 consistent scene relabel cannot escape frozen fixture address',
    () async {
      _consistentlyRelabelScene(db);
      final meterSnapshot = await _meterSnapshot(context);

      expect(
        () => _collect(context, meterSnapshot),
        throwsA(
          isA<AgentEvaluationProductionEvidenceException>().having(
            (error) => error.message,
            'message',
            contains('scene address'),
          ),
        ),
      );
    },
  );

  test('runner DB authority rejects a consistent scene relabel', () async {
    final result = _collect(context, await _meterSnapshot(context));
    expect(
      AgentEvaluationProductionDatabaseAuthority.verify(
        context: context,
        result: result,
      ).attemptRunId,
      context.runId,
    );
    _consistentlyRelabelScene(db);

    expect(
      () => AgentEvaluationProductionDatabaseAuthority.verify(
        context: context,
        result: result,
      ),
      throwsA(
        isA<AgentEvaluationProductionEvidenceException>().having(
          (error) => error.message,
          'message',
          contains('scene address'),
        ),
      ),
    );
  });

  test('release collector requires canonical fixture scene fields', () async {
    for (final fixture in <Map<String, Object?>>[
      const <String, Object?>{'sceneScopeId': 'project-1::scene-1'},
      const <String, Object?>{
        'projectId': 'project-1',
        'sceneId': 1,
        'sceneScopeId': 'project-1::scene-1',
      },
      const <String, Object?>{
        'projectId': 'project-1',
        'sceneId': 'scene-1',
        'sceneScopeId': ' project-1::scene-1',
      },
    ]) {
      final invalidContext = _context(db, inputFixture: fixture);
      final meterSnapshot = await _meterSnapshot(invalidContext);
      expect(
        () => _collect(invalidContext, meterSnapshot),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
        reason: fixture.toString(),
      );
    }
  });

  test(
    'scenario release hash mismatch fails at both evidence boundaries',
    () async {
      final result = _collect(context, await _meterSnapshot(context));
      final mismatchedCell = AgentEvaluationCellManifest(
        generationBundleHash: context.cell.generationBundleHash,
        modelRouteHash: context.cell.modelRouteHash,
        scenarioReleaseHash: _digest('f'),
        decodingConfigHash: context.cell.decodingConfigHash,
      );
      final mismatchedContext = _copyContext(context, cell: mismatchedCell);
      final mismatchedMeterSnapshot = await _meterSnapshot(mismatchedContext);

      expect(
        () => _collect(mismatchedContext, mismatchedMeterSnapshot),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
      );
      expect(
        () => AgentEvaluationProductionDatabaseAuthority.verify(
          context: mismatchedContext,
          result: result,
        ),
        throwsA(isA<AgentEvaluationProductionEvidenceException>()),
      );
    },
  );

  test('successful production snapshot binds frozen scene address', () async {
    final safety = _CapturingSafetyVerifier();
    const AgentEvaluationProductionEvidenceCollector().collect(
      context: context,
      storyRunId: context.runId,
      traces: <AppLlmCallTraceEntry>[_trace(context)],
      meterSnapshot: await _meterSnapshot(context),
      priceTable: _PriceTable(context.manifest.priceTableHash),
      qualityEvidence: _quality(),
      safetyVerifier: safety,
    );

    expect(
      safety.productionProof['scenarioReleaseHash'],
      context.scenario.releaseHash,
    );
    expect(
      safety.productionProof['scenarioFixtureHash'],
      context.scenario.fixtureHash,
    );
    expect(safety.productionProof['sceneId'], 'scene-1');
    expect(safety.productionProof['sceneScopeId'], 'project-1::scene-1');
  });

  test('sealed V2 authority rehydrates canonical receipt identity', () async {
    final receipt = await _sealedReceipt();
    final verified = _verifySealedReceipt(receipt);

    expect(verified, isNotEmpty);
  });

  test('sealed V2 authority rejects mirror and replay attacks', () async {
    final receipt = await _sealedReceipt();
    expect(
      () => _verifySealedReceipt(receipt, payloadReceiptJson: '{}'),
      throwsA(isA<FormatException>()),
    );
    for (final mutation in <String>['run', 'scene', 'prose', 'bundle']) {
      expect(
        () => _verifySealedReceipt(receipt, mutation: mutation),
        throwsA(isA<FormatException>()),
        reason: mutation,
      );
    }
  });

  test('pending payload tampering is rejected with an unchanged hash', () async {
    db.execute(
      "UPDATE story_generation_pending_writes SET payload_json = '{\"kind\":\"tampered\"}'",
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('missing receipt-bound outbox is rejected', () async {
    db.execute('DELETE FROM story_generation_outbox');
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('pending outbox payload cannot impersonate completed indexing', () async {
    db.execute(
      "UPDATE story_generation_outbox SET state = 'pending', attempt_count = 0",
    );
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });

  test('failed outbox worker makes production evidence fail closed', () async {
    db.execute("""UPDATE story_generation_outbox
         SET state = 'failed', attempt_count = 1,
             last_error_code = 'derived_index_failed',
             next_attempt_at_ms = 999""");
    final meterSnapshot = await _meterSnapshot(context);

    expect(
      () => _collect(context, meterSnapshot),
      throwsA(isA<AgentEvaluationProductionEvidenceException>()),
    );
  });
}

AgentEvaluationTrialExecutionResult _collect(
  AgentEvaluationTrialContext context,
  AgentEvaluationMeterSnapshot meterSnapshot,
) => const AgentEvaluationProductionEvidenceCollector().collect(
  context: context,
  storyRunId: context.runId,
  traces: <AppLlmCallTraceEntry>[_trace(context)],
  meterSnapshot: meterSnapshot,
  priceTable: _PriceTable(context.manifest.priceTableHash),
  qualityEvidence: _quality(),
  safetyVerifier: _SafetyVerifier(),
  executorReleaseHash: _digest('e'),
);

AgentEvaluationTrialContext _context(
  Database db, {
  Map<String, Object?> inputFixture = const <String, Object?>{
    'projectId': 'project-1',
    'sceneId': 'scene-1',
    'sceneScopeId': 'project-1::scene-1',
  },
}) {
  final scenario = ScenarioRelease(
    scenarioId: 'scenario-1',
    version: '1.0.0',
    difficulty: 'release',
    inputFixture: inputFixture,
    fixtureHash: _digest('1'),
    isolationMode: 'independent',
    requiredCapabilities: const <String>['story-generation'],
    adversarialMutations: const <String>[],
    verifierReleaseRefs: const <String>['verifier-v1'],
    rubricReleaseRef: 'rubric-v1',
    expectedTerminalState: 'accepted',
    requiredFailureCodes: const <String>[],
    allowedAdditionalFailureCodes: const <String>[],
    forbiddenFailureCodes: const <String>[],
    outcomeComparatorReleaseRef: 'comparator-v1',
    forbiddenSideEffects: const <String>[],
    acceptExpected: true,
    referenceFacts: const <String, Object?>{'safe': true},
    maxBudget: const <String, Object?>{},
  );
  final set = ScenarioSetRelease(
    setId: 'set-1',
    version: '1.0.0',
    scenarios: <ScenarioRelease>[scenario],
    fixtureCount: 1,
    outlineSceneCount: 1,
    holdout: false,
    createdAtMs: 1,
  );
  final cell = AgentEvaluationCellManifest(
    generationBundleHash: _digest('b'),
    modelRouteHash: AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(
      'model',
    ),
    scenarioReleaseHash: scenario.releaseHash,
    decodingConfigHash: _digest('d'),
  );
  final manifest = ExperimentManifest(
    experimentId: 'experiment-1',
    scenarioSet: set,
    generationBundleHashes: <String>[cell.generationBundleHash],
    evaluationBundleHash: _digest('e'),
    modelRouteHashes: <String>[cell.modelRouteHash],
    decodingConfigHashes: <String>[cell.decodingConfigHash],
    cells: <AgentEvaluationCellManifest>[cell],
    pipelineConfigHash: _digest('1'),
    providerConfigHashWithoutSecrets: _digest('2'),
    providerApiRevision: 'provider-v1',
    sdkAdapterReleaseHash: _digest('3'),
    tokenizerReleaseHash: _digest('4'),
    priceTableHash: _digest('5'),
    codeCommit: 'deadbeef',
    sourceTreeHash: _digest('6'),
    buildArtifactHash: _digest('7'),
    runtimeReleaseHash: _digest('8'),
    trialsPerCell: 3,
    seedPolicy: const <String, Object?>{},
    trialIsolationPolicy: const <String, Object?>{},
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 1},
    performanceSamplingPolicy: const <String, Object?>{},
    qualityComparisonPolicyHash: _digest('9'),
    holdoutAccessPolicy: HoldoutAccessPolicy(
      policyHash: _digest('a'),
      accessBudget: 1,
      accessOrdinal: 0,
    ),
    budgets: const <String, Object?>{},
    qualityThresholds: const <String, Object?>{},
    createdAtMs: 1,
  );
  final lease = AgentEvaluationLease(
    trialSlotId: 'slot-1',
    executionId: 'execution-1',
    cellId: cell.cellId,
    trialNo: 1,
    epoch: 1,
    owner: 'runner-1',
    expiresAtMs: 1000,
    status: 'running',
  );
  return AgentEvaluationTrialContext(
    manifest: manifest,
    cell: cell,
    scenario: scenario,
    lease: lease,
    attemptNo: 1,
    runId: 'story-run-1',
    isolationTrialId: 'slot-1',
    database: db,
    sandboxDatabasePath: 'test-production-evidence.sqlite',
    reportStage: (_, {status = 'running'}) {},
    cancellationToken: AgentEvaluationCancellationToken(),
  );
}

AgentEvaluationTrialContext _copyContext(
  AgentEvaluationTrialContext source, {
  required AgentEvaluationCellManifest cell,
}) => AgentEvaluationTrialContext(
  manifest: source.manifest,
  cell: cell,
  scenario: source.scenario,
  lease: source.lease,
  attemptNo: source.attemptNo,
  runId: source.runId,
  isolationTrialId: source.isolationTrialId,
  database: source.database,
  sandboxDatabasePath: source.sandboxDatabasePath,
  reportStage: source.reportStage,
  cancellationToken: source.cancellationToken,
);

AppLlmCallTraceEntry _trace(
  AgentEvaluationTrialContext context, {
  String? evaluationRunId,
}) => AppLlmCallTraceEntry(
  timestampMs: 1,
  traceName: 'scene-editorial',
  model: 'model',
  host: 'provider.invalid',
  messageCount: 2,
  maxTokens: 100,
  succeeded: true,
  latencyMs: 10,
  promptTokens: 100,
  completionTokens: 40,
  totalTokens: 140,
  estimatedPromptTokens: 100,
  estimatedCompletionTokens: 40,
  promptChars: 400,
  completionChars: 160,
  metadata: <String, Object?>{
    'experimentId': context.manifest.experimentId,
    'executionId': context.lease.executionId,
    'runId': evaluationRunId ?? context.runId,
    'trialSlotId': context.lease.trialSlotId,
    'attemptNo': context.attemptNo,
  },
  promptReleaseRef: PromptReleaseRef(
    templateId: 'prompt',
    semanticVersion: '1.0.0',
    language: 'zh',
    contentHash: _prefixed('1'),
  ),
  stageId: 'editorial',
  callSiteId: 'scene-editorial-generator',
  variantId: 'zh',
  generationBundleHash: 'sha256:${context.cell.generationBundleHash}',
  renderedMessagesDigest: _prefixed('2'),
  resolvedVariablesDigest: _prefixed('3'),
);

Future<AgentEvaluationMeterSnapshot> _meterSnapshot(
  AgentEvaluationTrialContext context, {
  int callCount = 1,
}) async {
  final client = AgentEvaluationMeteredAppLlmClient(
    inner: const _MeterClient(),
    model: 'model',
    provider: AppLlmProvider.openaiCompatible,
    baseUrl: 'https://provider.invalid/v1',
  );
  client.beginAttempt(
    trialSlotId: context.lease.trialSlotId,
    attemptNo: context.attemptNo,
  );
  for (var index = 0; index < callCount; index += 1) {
    await client.chat(
      const AppLlmChatRequest(
        baseUrl: 'https://provider.invalid/v1',
        apiKey: 'secret',
        model: 'model',
        provider: AppLlmProvider.openaiCompatible,
        messages: <AppLlmChatMessage>[
          AppLlmChatMessage(role: 'user', content: 'test'),
        ],
      ),
    );
  }
  return client.finishAttempt();
}

final class _MeterClient implements AppLlmClient {
  const _MeterClient();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async =>
      const AppLlmChatResult.success(
        text: 'ok',
        promptTokens: 100,
        completionTokens: 40,
      );

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

AgentEvaluationQualityEvidence _quality() {
  final scores = <String, int>{
    for (final dimension in AgentEvaluationQualityDimensions.values)
      dimension: 99000000,
  };
  const prose = '一段已经提交并经过校验的正文。';
  final contentHash = AgentEvaluationHashes.domainHash(
    'eval-trial-content-v1',
    prose,
  );
  final judgeOutputHash = _digest('5');
  return AgentEvaluationQualityEvidence(
    scoreMicrosByDimension: scores,
    judgePromptReleaseHash: _digest('1'),
    judgeModelRouteHash: _digest('2'),
    rubricReleaseHash: _digest('3'),
    aggregatorReleaseHash: _digest('4'),
    evaluatedContentHash: contentHash,
    externalJudgeOutputHash: judgeOutputHash,
    externalEvaluationEvidenceHash:
        AgentEvaluationQualityEvidence.calculateExternalEvidenceHash(
          scoreMicrosByDimension: scores,
          judgePromptReleaseHash: _digest('1'),
          judgeModelRouteHash: _digest('2'),
          rubricReleaseHash: _digest('3'),
          aggregatorReleaseHash: _digest('4'),
          evaluatedContentHash: contentHash,
          externalJudgeOutputHash: judgeOutputHash,
        ),
  );
}

final class _PriceTable implements AgentEvaluationFrozenPriceTable {
  const _PriceTable(this.releaseHash);

  @override
  final String releaseHash;

  @override
  int costMicrousd(AgentEvaluationProviderCallEvidence call) =>
      call.promptTokens + call.completionTokens * 2;
}

final class _SafetyVerifier implements AgentEvaluationProductionSafetyVerifier {
  @override
  String get releaseHash => _digest('6');

  @override
  AgentEvaluationVerifierResult verify({
    required String prose,
    required Map<String, Object?> referenceFacts,
    required Map<String, Object?> productionProof,
  }) => AgentEvaluationVerifierResult(
    passed: referenceFacts['safe'] == true && prose.isNotEmpty,
    evidenceHash: AgentEvaluationHashes.domainHash('test-safety-v1', <Object?>[
      prose,
      referenceFacts,
      productionProof,
    ]),
  );
}

final class _CapturingSafetyVerifier
    implements AgentEvaluationProductionSafetyVerifier {
  late Map<String, Object?> productionProof;

  @override
  String get releaseHash => _digest('6');

  @override
  AgentEvaluationVerifierResult verify({
    required String prose,
    required Map<String, Object?> referenceFacts,
    required Map<String, Object?> productionProof,
  }) {
    this.productionProof = productionProof;
    return AgentEvaluationVerifierResult(
      passed: true,
      evidenceHash: AgentEvaluationHashes.domainHash(
        'capturing-safety-v1',
        productionProof,
      ),
    );
  }
}

void _consistentlyRelabelScene(Database db) {
  db.execute('''UPDATE story_generation_runs SET scene_id = 'scene-relabeled',
       scene_scope_id = 'project-1::scene-relabeled' ''');
  db.execute('''UPDATE story_generation_candidate_proofs
       SET scene_id = 'scene-relabeled' ''');
  db.execute('''UPDATE story_generation_commit_receipts
       SET scene_scope_id = 'project-1::scene-relabeled' ''');
  db.execute(
    '''UPDATE draft_documents SET project_id = 'project-1::scene-relabeled' ''',
  );
  db.execute(
    '''UPDATE version_entries SET project_id = 'project-1::scene-relabeled' ''',
  );
}

void _createProductionEvidenceTables(Database db) {
  db.execute('''CREATE TABLE story_generation_runs (
    run_id TEXT PRIMARY KEY, status TEXT, current_candidate_revision INTEGER,
    committed_at_ms INTEGER, scene_id TEXT, scene_scope_id TEXT)''');
  db.execute('''CREATE TABLE story_generation_candidate_proofs (
    run_id TEXT, candidate_revision INTEGER, source_prose_revision INTEGER,
    candidate_hash TEXT, final_prose_hash TEXT,
    deterministic_gate_evidence_hash TEXT, final_council_evidence_hash TEXT,
    quality_evidence_hash TEXT, pending_write_set_hash TEXT,
    material_digest TEXT, input_digest TEXT, scene_id TEXT,
    proof_identity_version TEXT NOT NULL DEFAULT 'candidate-proof-v1',
    prepared_brief_digest TEXT, effective_brief_digest TEXT,
    generation_evidence_mode TEXT NOT NULL DEFAULT 'legacy-unsealed-v1',
    generation_evidence_receipt_hash TEXT,
    attempt_evidence_envelope_digest TEXT,
    generation_fingerprint_set_digest TEXT,
    generation_evidence_receipt_json TEXT)''');
  db.execute('''CREATE TABLE story_generation_working_prose_revisions (
    run_id TEXT, prose_revision INTEGER, prose_text TEXT, prose_hash TEXT)''');
  db.execute('''CREATE TABLE story_generation_commit_receipts (
    run_id TEXT, candidate_revision INTEGER, receipt_id TEXT,
    committed_candidate_hash TEXT, committed_draft_hash TEXT,
    version_content_hash TEXT, pending_write_set_hash TEXT,
    outbox_set_hash TEXT, scene_scope_id TEXT, version_id TEXT,
    committed_at_ms INTEGER)''');
  db.execute('''CREATE TABLE story_generation_run_bundles (
    run_id TEXT, bundle_hash TEXT)''');
  db.execute('''CREATE TABLE story_generation_pending_writes (
    run_id TEXT, candidate_revision INTEGER, write_id TEXT,
    payload_hash TEXT, payload_json TEXT, state TEXT,
    committed_at_ms INTEGER)''');
  db.execute('''CREATE TABLE story_generation_candidate_payloads (
    run_id TEXT, candidate_revision INTEGER, final_prose TEXT,
    pending_write_manifest_json TEXT,
    generation_evidence_receipt_json TEXT)''');
  db.execute('''CREATE TABLE draft_documents (
    project_id TEXT, text_body TEXT)''');
  db.execute('''CREATE TABLE version_entries (
    project_id TEXT, sequence_no INTEGER, content TEXT)''');
  db.execute('''CREATE TABLE story_generation_outbox (
    operation_key TEXT, run_id TEXT, payload_json TEXT,
    source_receipt_id TEXT, state TEXT, attempt_count INTEGER,
    lease_owner TEXT, lease_expires_at_ms INTEGER,
    next_attempt_at_ms INTEGER, last_error_code TEXT,
    last_error_summary TEXT)''');
}

void _seedCommittedProductionRun(Database db, String bundleHash) {
  const prose = '一段已经提交并经过校验的正文。';
  final proseHash = GenerationCommitDigest.text(prose);
  const pendingPayloadJson = '{"kind":"memory"}';
  final pendingPayloadHash = GenerationCommitDigest.text(pendingPayloadJson);
  final pendingManifest = <Map<String, Object?>>[
    <String, Object?>{'writeId': 'write-1', 'payloadHash': pendingPayloadHash},
  ];
  final pendingManifestJson = GenerationLedgerDigest.canonicalJson(
    pendingManifest,
  );
  final pendingWriteSetHash = GenerationLedgerDigest.object(pendingManifest);
  final candidateHash = _candidateHash(bundleHash);
  db.execute('''INSERT INTO story_generation_runs VALUES
      ('story-run-1','committed',1,10,'scene-1','project-1::scene-1')''');
  db.execute(
    '''INSERT INTO story_generation_candidate_proofs (
      run_id, candidate_revision, source_prose_revision, candidate_hash,
      final_prose_hash, deterministic_gate_evidence_hash,
      final_council_evidence_hash, quality_evidence_hash,
      pending_write_set_hash, material_digest, input_digest, scene_id
    ) VALUES (
      'story-run-1',1,1,?,?,?,?,?,?,?,?,?)''',
    <Object?>[
      candidateHash,
      proseHash,
      _prefixed('b'),
      _prefixed('c'),
      _prefixed('d'),
      pendingWriteSetHash,
      _prefixed('7'),
      _prefixed('8'),
      'scene-1',
    ],
  );
  db.execute(
    "INSERT INTO story_generation_working_prose_revisions VALUES ('story-run-1',1,?,?)",
    <Object?>[prose, proseHash],
  );
  db.execute(
    '''INSERT INTO story_generation_commit_receipts VALUES (
      'story-run-1',1,'receipt-1',?,?,?,?,?,'project-1::scene-1',
      'version:story-run-1:1',10)''',
    <Object?>[
      candidateHash,
      proseHash,
      proseHash,
      pendingWriteSetHash,
      'outbox:story-run-1:1',
    ],
  );
  db.execute(
    "INSERT INTO story_generation_run_bundles VALUES ('story-run-1',?)",
    <Object?>['sha256:$bundleHash'],
  );
  db.execute(
    '''INSERT INTO story_generation_pending_writes VALUES
       ('story-run-1',1,'write-1',?,?,'committed',10)''',
    <Object?>[pendingPayloadHash, pendingPayloadJson],
  );
  db.execute(
    '''INSERT INTO story_generation_candidate_payloads VALUES
       ('story-run-1',1,?,?,'{}')''',
    <Object?>[prose, pendingManifestJson],
  );
  db.execute(
    "INSERT INTO draft_documents VALUES ('project-1::scene-1',?)",
    <Object?>[prose],
  );
  db.execute(
    "INSERT INTO version_entries VALUES ('project-1::scene-1',0,?)",
    <Object?>[prose],
  );
  db.execute(
    '''INSERT INTO story_generation_outbox VALUES
       ('index:receipt-1','story-run-1',?,'receipt-1','completed',1,'',0,0,NULL,NULL)''',
    <Object?>[
      jsonEncode(<String, Object?>{
        'runId': 'story-run-1',
        'candidateRevision': 1,
        'receiptId': 'receipt-1',
        'writeIds': <String>['write-1'],
      }),
    ],
  );
}

String _upgradeFixtureToV2(Database db, String bundleHash) {
  final preparedBriefDigest = _prefixed('a');
  final effectiveBriefDigest = _prefixed('e');
  final candidateHash = GenerationCandidateIdentity.computeV2(
    runId: 'story-run-1',
    candidateRevision: 1,
    finalProseHash: GenerationCommitDigest.text('一段已经提交并经过校验的正文。'),
    deterministicGateEvidenceHash: _prefixed('b'),
    finalCouncilEvidenceHash: _prefixed('c'),
    qualityEvidenceHash: _prefixed('d'),
    pendingWriteSetHash: GenerationLedgerDigest.object(<Object?>[
      <String, Object?>{
        'writeId': 'write-1',
        'payloadHash': GenerationCommitDigest.text('{"kind":"memory"}'),
      },
    ]),
    materialDigest: _prefixed('7'),
    effectiveInputDigest: _prefixed('8'),
    preparedBriefDigest: preparedBriefDigest,
    effectiveBriefDigest: effectiveBriefDigest,
    generationBundleHash: 'sha256:$bundleHash',
    generationEvidenceMode: GenerationCandidateIdentity.adaptiveUnsealedMode,
  );
  db.execute(
    '''UPDATE story_generation_candidate_proofs SET
      candidate_hash = ?, proof_identity_version = ?,
      prepared_brief_digest = ?, effective_brief_digest = ?,
      generation_evidence_mode = ?''',
    <Object?>[
      candidateHash,
      GenerationCandidateIdentity.v2,
      preparedBriefDigest,
      effectiveBriefDigest,
      GenerationCandidateIdentity.adaptiveUnsealedMode,
    ],
  );
  db.execute(
    'UPDATE story_generation_commit_receipts '
    'SET committed_candidate_hash = ?',
    <Object?>[candidateHash],
  );
  return candidateHash;
}

String _v2CandidateHash(String bundleHash) =>
    GenerationCandidateIdentity.computeV2(
      runId: 'story-run-1',
      candidateRevision: 1,
      finalProseHash: GenerationCommitDigest.text('一段已经提交并经过校验的正文。'),
      deterministicGateEvidenceHash: _prefixed('b'),
      finalCouncilEvidenceHash: _prefixed('c'),
      qualityEvidenceHash: _prefixed('d'),
      pendingWriteSetHash: GenerationLedgerDigest.object(<Object?>[
        <String, Object?>{
          'writeId': 'write-1',
          'payloadHash': GenerationCommitDigest.text('{"kind":"memory"}'),
        },
      ]),
      materialDigest: _prefixed('7'),
      effectiveInputDigest: _prefixed('8'),
      preparedBriefDigest: _prefixed('a'),
      effectiveBriefDigest: _prefixed('e'),
      generationBundleHash: 'sha256:$bundleHash',
      generationEvidenceMode: GenerationCandidateIdentity.adaptiveUnsealedMode,
    );

var _sealedReceiptSerial = 0;

Future<GenerationEvidenceReceipt> _sealedReceipt() =>
    buildGenerationEvidenceReceiptFixture(
      evidenceRunId:
          'production-evidence-sealed-run-${_sealedReceiptSerial += 1}',
      sceneId: 'production-evidence-sealed-scene-$_sealedReceiptSerial',
      generationArmPolicy: 'sealed-arm-v1',
      preparedBriefDigest: _prefixed('1'),
      generationBundleHash: generationEvidenceReceiptFixtureBundleHash,
      artifactText: 'sealed prose',
    );

String _verifySealedReceipt(
  GenerationEvidenceReceipt receipt, {
  String? payloadReceiptJson,
  String? mutation,
}) => AgentEvaluationCandidateProofAuthority.verifyV2(
  proofIdentityVersion: GenerationCandidateIdentity.v2,
  runId: mutation == 'run' ? 'replayed-run' : receipt.evidenceRunId,
  sceneId: mutation == 'scene' ? 'replayed-scene' : receipt.sceneId,
  finalProse: mutation == 'prose' ? 'replayed prose' : 'sealed prose',
  generationBundleHash: mutation == 'bundle'
      ? _prefixed('3')
      : generationEvidenceReceiptFixtureBundleHash,
  candidateRevision: 1,
  finalProseHash: GenerationCommitDigest.text('sealed prose'),
  deterministicGateEvidenceHash: _prefixed('4'),
  finalCouncilEvidenceHash: _prefixed('5'),
  qualityEvidenceHash: _prefixed('6'),
  pendingWriteSetHash: _prefixed('7'),
  materialDigest: _prefixed('8'),
  effectiveInputDigest: _prefixed('9'),
  preparedBriefDigest: _prefixed('1'),
  effectiveBriefDigest: _prefixed('1'),
  generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
  generationEvidenceReceiptHash: receipt.receiptHash,
  attemptEvidenceEnvelopeDigest: receipt.attemptEvidenceEnvelopeDigest,
  generationFingerprintSetDigest: receipt.generationFingerprintSetDigest,
  generationEvidenceReceiptJson: receipt.canonicalJson,
  payloadGenerationEvidenceReceiptJson:
      payloadReceiptJson ?? receipt.canonicalJson,
);

String _candidateHash(String bundleHash) =>
    GenerationLedgerDigest.object(<String, Object?>{
      'runId': 'story-run-1',
      'candidateRevision': 1,
      'finalProseHash': GenerationCommitDigest.text('一段已经提交并经过校验的正文。'),
      'deterministicGateEvidenceHash': _prefixed('b'),
      'finalCouncilEvidenceHash': _prefixed('c'),
      'qualityEvidenceHash': _prefixed('d'),
      'pendingWriteSetHash': GenerationLedgerDigest.object(<Object?>[
        <String, Object?>{
          'writeId': 'write-1',
          'payloadHash': GenerationCommitDigest.text('{"kind":"memory"}'),
        },
      ]),
      'materialDigest': _prefixed('7'),
      'inputDigest': _prefixed('8'),
      'generationBundleHash': 'sha256:$bundleHash',
    });

String _digest(String character) => List<String>.filled(64, character).join();
String _prefixed(String character) => 'sha256:${_digest(character)}';
