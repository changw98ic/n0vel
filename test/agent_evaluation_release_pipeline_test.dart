import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release_store.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_authorities.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_report.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_typed_evidence.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/outcome_evaluation.dart';

void main() {
  test(
    'synthetic typed evidence cannot impersonate a production release',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'agent-release-pipeline-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final db = sqlite3.open('${directory.path}/authority.sqlite');
      addTearDown(db.dispose);
      db.execute('PRAGMA foreign_keys = ON');
      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final champion = StoryPromptRegistry.current();
      final challenger = StoryPromptRegistry.causalityChallenger();
      final promptStore = AppLlmPromptReleaseStore(db: db);
      champion.publishTo(promptStore);
      challenger.publishTo(promptStore);

      final judgeRelease = _judgeRelease();
      promptStore.putPromptRelease(judgeRelease);
      final judgeModel = _prefixed('8');
      final rubric = _prefixed('9');
      final aggregator = _prefixed('a');
      final evaluationBundle = EvaluationBundle(
        evaluatorBundleId: 'release-pipeline-evaluator-v1',
        deterministicVerifierReleases: <String>[_prefixed('e'), _prefixed('f')],
        judgePromptReleases: <PromptReleaseRef>[judgeRelease.ref],
        judgeModelRoutes: <String>[judgeModel],
        rubricReleaseHash: rubric,
        aggregatorReleaseHash: aggregator,
        failureTaxonomyHash: _prefixed('b'),
        blindingPolicyVersion: 'opaque-candidate-v1',
      );
      promptStore.putEvaluationBundle(evaluationBundle);

      final fixture = sqlite3.open('${directory.path}/fixture.sqlite');
      fixture.execute('CREATE TABLE state (value TEXT)');
      fixture.dispose();
      sqlite3.open('${directory.path}/production.sqlite').dispose();
      final sandbox = AgentEvaluationFixtureSandbox.create(
        fixtureDatabasePath: '${directory.path}/fixture.sqlite',
        productionDatabasePath: '${directory.path}/production.sqlite',
        temporaryParent: directory,
      );
      addTearDown(sandbox.dispose);

      final manifest = _manifest(
        championBundleHash: _raw(champion.generationBundle.bundleHash),
        challengerBundleHash: _raw(challenger.generationBundle.bundleHash),
        evaluationBundleHash: _raw(evaluationBundle.evaluatorBundleHash),
      );
      var clock = 1000;
      final runner = AgentEvaluationRunner(
        manifestStore: AgentEvaluationManifestStore(db: db),
        ledger: AgentEvaluationLedger(db: db),
        fixtureSandbox: sandbox,
        nowMs: () => clock++,
      );
      final registries = <String, StoryPromptRegistry>{
        _raw(champion.generationBundle.bundleHash): champion,
        _raw(challenger.generationBundle.bundleHash): challenger,
      };
      final renderedDigests = <String, Set<String>>{};
      final report = await runner.run(
        manifest: manifest,
        executionId: 'release-pipeline-execution',
        workerId: 'trusted-release-runner',
        actualBuildArtifactHash: manifest.buildArtifactHash,
        verifierExists: (_) => true,
        requireGateEvidence: true,
        cancellationToken: AgentEvaluationCancellationToken(),
        onProgress: (_) {},
        trialExecutor: (context) async {
          final registry = registries[context.cell.generationBundleHash]!;
          final invocation = registry.invocation(
            stageId: 'editorial',
            callSiteId: 'scene-editorial-generator',
          );
          final resolvedVariables = _resolvedVariables(
            invocation.release,
            context.scenario.scenarioId,
          );
          final messages = invocation.render(resolvedVariables).messages;
          final invocationEvidence = invocation.evidence(
            messages,
            resolvedVariables: resolvedVariables,
          );
          (renderedDigests[context.cell.generationBundleHash] ??= <String>{})
              .add(invocationEvidence.renderedMessagesDigest);
          final evaluatedContent =
              '${invocationEvidence.renderedMessagesDigest}:'
              '${context.lease.trialSlotId}';
          final evaluatedContentHash = AgentEvaluationHashes.domainHash(
            'eval-trial-content-v1',
            evaluatedContent,
          );
          final scores = <String, int>{
            for (final dimension in AgentEvaluationQualityDimensions.values)
              dimension: 99000000,
          };
          final judgeOutputHash = _raw(_prefixed('0'));
          final injectionSafetyReceipt =
              AgentEvaluationJudgeInjectionSafetyVerifier.verify(
                prose: evaluatedContent,
                candidateJson: AgentEvaluationHashes.canonicalJson(
                  <String, Object?>{'candidate': evaluatedContent},
                ),
                invocation: invocationEvidence,
                judgePromptReleaseHash: _raw(judgeRelease.contentHash),
                judgeModelRouteHash: _raw(judgeModel),
                rubricReleaseHash: _raw(rubric),
                aggregatorReleaseHash: _raw(aggregator),
                rawResponse:
                    '{"scores":{"proseReadability":99,"plotCausality":99},"summary":"bounded"}',
                parsedScores: const <String, double>{
                  'proseReadability': 99,
                  'plotCausality': 99,
                },
                parsedSummary: 'bounded',
              );
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.accepted,
              accepted: true,
              evidenceComplete: true,
            ),
            evaluatedContent: evaluatedContent,
            usage: AgentEvaluationAttemptUsage(
              promptTokens: 100,
              completionTokens: 100,
              costMicrousd: 100,
            ),
            qualityEvidence: AgentEvaluationQualityEvidence(
              scoreMicrosByDimension: scores,
              judgePromptReleaseHash: _raw(judgeRelease.contentHash),
              judgeModelRouteHash: _raw(judgeModel),
              rubricReleaseHash: _raw(rubric),
              aggregatorReleaseHash: _raw(aggregator),
              evaluatedContentHash: evaluatedContentHash,
              externalJudgeOutputHash: judgeOutputHash,
              judgeInjectionSafetyReceipt: injectionSafetyReceipt,
              externalEvaluationEvidenceHash:
                  AgentEvaluationQualityEvidence.calculateExternalEvidenceHash(
                    scoreMicrosByDimension: scores,
                    judgePromptReleaseHash: _raw(judgeRelease.contentHash),
                    judgeModelRouteHash: _raw(judgeModel),
                    rubricReleaseHash: _raw(rubric),
                    aggregatorReleaseHash: _raw(aggregator),
                    evaluatedContentHash: evaluatedContentHash,
                    externalJudgeOutputHash: judgeOutputHash,
                    judgeInjectionSafetyReceiptHash:
                        injectionSafetyReceipt.receiptHash,
                  ),
            ),
            hardGateEvidence: AgentEvaluationHardGateEvidence(
              safetyPassed: true,
              transactionPassed: true,
              safetyVerifierReleaseHash: _raw(_prefixed('e')),
              transactionVerifierReleaseHash: _raw(_prefixed('f')),
              safetyEvidenceHash: _raw(_prefixed('1')),
              transactionEvidenceHash: _raw(_prefixed('2')),
            ),
          );
        },
      );

      expect(report.cellPass3, hasLength(14));
      expect(report.cellPass3.every((cell) => cell.passed), isTrue);
      expect(renderedDigests, hasLength(2));
      expect(
        renderedDigests.values.first.intersection(renderedDigests.values.last),
        isEmpty,
      );

      expect(
        () => AgentEvaluationReportBuilder(db: db).build(
          executionId: 'release-pipeline-execution',
          policy: AgentEvaluationReportPolicy(
            aggregatorReleaseHash: _raw(aggregator),
            minimumDistributionSamples: 20,
          ),
        ),
        throwsA(
          isA<AgentEvaluationReportException>().having(
            (error) => error.message,
            'message',
            contains('deterministic quality receipt'),
          ),
        ),
      );
      expect(db.select('SELECT * FROM eval_scorecards'), isEmpty);
      expect(db.select('SELECT * FROM eval_release_gate_derivations'), isEmpty);
    },
  );
}

ExperimentManifest _manifest({
  required String championBundleHash,
  required String challengerBundleHash,
  required String evaluationBundleHash,
}) {
  final scenarios = <ScenarioRelease>[
    for (var index = 1; index <= 7; index += 1)
      ScenarioRelease(
        scenarioId: 'release-scenario-$index',
        version: '1.0.0',
        difficulty: 'release',
        inputFixture: <String, Object?>{'scene': index},
        fixtureHash: AgentEvaluationHashes.domainHash('fixture-v1', index),
        isolationMode: 'independent',
        requiredCapabilities: const <String>['story-generation'],
        adversarialMutations: const <String>['causal-transition'],
        verifierReleaseRefs: const <String>['verifier-v1'],
        rubricReleaseRef: 'rubric-v1',
        expectedTerminalState: 'accepted',
        requiredFailureCodes: const <String>[],
        allowedAdditionalFailureCodes: const <String>[],
        forbiddenFailureCodes: const <String>[],
        outcomeComparatorReleaseRef: 'comparator-v1',
        forbiddenSideEffects: const <String>['production-write'],
        acceptExpected: true,
        referenceFacts: <String, Object?>{'scene': index},
        maxBudget: const <String, Object?>{'calls': 48},
      ),
  ];
  final scenarioSet = ScenarioSetRelease(
    setId: 'release-pipeline-set',
    version: '1.0.0',
    scenarios: scenarios,
    fixtureCount: scenarios.length,
    outlineSceneCount: scenarios.length,
    holdout: false,
    createdAtMs: 1,
  );
  final bundles = <String>[championBundleHash, challengerBundleHash];
  final model = _raw(_prefixed('c'));
  final decoding = _raw(_prefixed('d'));
  return ExperimentManifest(
    experimentId: 'release-pipeline-experiment',
    scenarioSet: scenarioSet,
    generationBundleHashes: bundles,
    evaluationBundleHash: evaluationBundleHash,
    modelRouteHashes: <String>[model],
    decodingConfigHashes: <String>[decoding],
    cells: ExperimentManifest.expandCanonicalCells(
      generationBundleHashes: bundles,
      modelRouteHashes: <String>[model],
      scenarios: scenarios,
      decodingConfigHashes: <String>[decoding],
    ),
    pipelineConfigHash: _raw(_prefixed('1')),
    providerConfigHashWithoutSecrets: _raw(_prefixed('2')),
    providerApiRevision: 'test-double-v1',
    sdkAdapterReleaseHash: _raw(_prefixed('3')),
    tokenizerReleaseHash: _raw(_prefixed('4')),
    priceTableHash: _raw(_prefixed('5')),
    codeCommit: 'test-commit',
    sourceTreeHash: _raw(_prefixed('6')),
    buildArtifactHash: _raw(_prefixed('7')),
    runtimeReleaseHash: _raw(_prefixed('8')),
    trialsPerCell: 3,
    seedPolicy: const <String, Object?>{'mode': 'recorded'},
    trialIsolationPolicy: const <String, Object?>{'mode': 'independent-db'},
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 1},
    performanceSamplingPolicy: const <String, Object?>{
      'pairing': 'canonical-by-model-scenario-decoding-trial-v1',
      'order': 'interleaved-randomized-v1',
      'minimumPairedSamples': 20,
    },
    qualityComparisonPolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
    holdoutAccessPolicy: HoldoutAccessPolicy(
      policyHash: _raw(_prefixed('9')),
      accessBudget: 1,
      accessOrdinal: 0,
    ),
    budgets: const <String, Object?>{'calls': 42},
    qualityThresholds: const <String, Object?>{
      'claimScope': 'real-provider-release',
    },
    createdAtMs: 1,
  );
}

PromptRelease _judgeRelease() => PromptRelease(
  templateId: 'release-pipeline-judge',
  semanticVersion: '1.0.0',
  language: 'zh',
  systemTemplate: 'Blindly score the supplied candidate.',
  userTemplate: 'candidate={candidate}',
  variablesSchemaSnapshot: const <String, Object?>{},
  outputSchemaSnapshot: const <String, Object?>{},
  rendererRelease: 'judge-renderer-v1',
  parserRelease: 'judge-parser-v1',
  repairPolicySnapshot: const <String, Object?>{},
  owner: 'evaluation',
  changeNote: 'Frozen test judge.',
  createdAt: DateTime.utc(2026, 7, 12),
);

String _prefixed(String character) =>
    'sha256:${List<String>.filled(64, character).join()}';
String _raw(String digest) =>
    digest.startsWith('sha256:') ? digest.substring('sha256:'.length) : digest;

Map<String, Object?> _resolvedVariables(PromptRelease release, String fixture) {
  final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch ((entry.value as Map<String, Object?>)['type']) {
        'string' => 'fixture=$fixture; field=${entry.key}',
        'integer' => 1,
        'number' => 1.0,
        'boolean' => true,
        _ => throw StateError('unsupported fixture variable: ${entry.key}'),
      },
  };
}
