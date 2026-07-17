import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_client_types.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_executor.dart';
import 'agent_evaluation_real_release_harness.dart';
import 'agent_evaluation_release_store.dart';

class AgentEvaluationPromotionPerformanceAuthorityException
    implements Exception {
  const AgentEvaluationPromotionPerformanceAuthorityException(this.message);

  final String message;

  @override
  String toString() =>
      'AgentEvaluationPromotionPerformanceAuthorityException: $message';
}

/// Canonical purpose-built production matrix for the 15% promotion boundary.
/// Tests and archived adapters share this release instead of copying token
/// magic, routes, prices, or expected boundary semantics.
abstract final class AgentEvaluationPromotionPerformanceScenario {
  static const slotCount = 60;
  // Director + stage narration + beat resolution + editorial, followed by
  // four preliminary reviewers, the same four final reviewers, and quality.
  static const expectedSutCallsPerSlot = 13;
  static const expectedSutProviderCallCount =
      slotCount * expectedSutCallsPerSlot;
  static const expectedPricedChallengerCallCount = (slotCount ~/ 2) * 9;
  static const expectedBaselineCallCount =
      expectedSutProviderCallCount - expectedPricedChallengerCallCount;
  // Four calls precede challenger prose; the remaining nine are prose-bound.
  // SUT-only totals are 1615/1500 basis points. Equal per-slot judge charges
  // make the sealed projections 1614/1499 while preserving the same boundary.
  static const attackChallengerTokensPerCall = 296;
  static const controlChallengerTokensPerCall = 292;
  static const baselineTokensPerCall = 240;
  static const challengerMarker = '真正的编号刻在仓门内侧，门框上还留着一道新鲜划痕';

  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-promotion-performance-scenario-v1',
    <String, Object?>{
      'sutRoute': 'glm-performance-sut/zhipu/purpose-performance-v1',
      'judgeRoute': 'glm-performance-judge/zhipu/purpose-performance-v1',
      'baselineTokensPerCall': baselineTokensPerCall,
      'attackChallengerTokensPerCall': attackChallengerTokensPerCall,
      'controlChallengerTokensPerCall': controlChallengerTokensPerCall,
      'pricedCall': 'request-contains-frozen-challenger-marker-v1',
      'promptMicrousdPerMillionTokens': 1000000,
      'completionMicrousdPerMillionTokens': 1000000,
      'attackBoundary': 'strictly-above-1500-basis-points',
      'controlBoundary': '1490-through-1500-basis-points-inclusive',
      'slots': slotCount,
      'expectedSutCallsPerSlot': expectedSutCallsPerSlot,
      'expectedSutProviderCallCount': expectedSutProviderCallCount,
      'expectedPricedChallengerCallCount': expectedPricedChallengerCallCount,
      'expectedBaselineCallCount': expectedBaselineCallCount,
      'runnerClock': 'monotonic-10ms-per-ledger-event-v1',
    },
  );

  static int challengerTokensPerCall(String variant) => switch (variant) {
    AgentEvaluationPromotionPerformanceAuthority.attackVariant =>
      attackChallengerTokensPerCall,
    AgentEvaluationPromotionPerformanceAuthority.controlVariant =>
      controlChallengerTokensPerCall,
    _ => throw ArgumentError.value(variant, 'variant'),
  };

  static bool isPricedChallenger(Iterable<String> renderedMessages) =>
      renderedMessages.any((message) => message.contains(challengerMarker));

  static int Function() deterministicRunnerClock({int? originMs}) {
    final origin = originMs ?? DateTime.now().millisecondsSinceEpoch;
    var ticks = 0;
    return () => origin + (ticks++ * 10);
  }

  static AgentEvaluationRealReleaseConfiguration configuration(
    String executionId,
  ) {
    final sutRoute = AgentEvaluationProductionRouteRelease(
      model: 'glm-performance-sut',
      provider: AppLlmProvider.zhipu,
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      apiKey: 'purpose-performance-sut-key',
      timeout: const AppLlmTimeoutConfig.uniform(30000),
      providerApiRevision: 'purpose-performance-v1',
      sdkAdapterReleaseHash: _digest('1'),
    );
    final judgeRoute = AgentEvaluationProductionRouteRelease(
      model: 'glm-performance-judge',
      provider: AppLlmProvider.zhipu,
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      apiKey: 'purpose-performance-judge-key',
      timeout: const AppLlmTimeoutConfig.uniform(30000),
      providerApiRevision: 'purpose-performance-v1',
      sdkAdapterReleaseHash: _digest('1'),
    );
    return AgentEvaluationRealReleaseConfiguration(
      executionId: executionId,
      sutRoutes: <AgentEvaluationProductionRouteRelease>[sutRoute],
      judgeRoute: judgeRoute,
      decoding: AgentEvaluationProductionDecodingRelease.standard(),
      maxAttemptsPerTrial: 1,
      maxCallsPerTrial: 64,
      maxTokensPerTrial: 10000000,
      maxPromptTokensPerCall: 100000,
      maxCompletionTokensPerCall: 4096,
      maxProviderCalls: 100000,
      maxTotalTokens: 1000000000,
      maxTotalCostMicrousd: 1000000000,
      evaluatorMaxCalls: 60,
      evaluatorMaxTokens: 10000000,
      evaluatorMaxCostMicrousd: 1000000,
      evaluatorTokensPerCall: 4096,
      evaluatorCostMicrousdPerCall: 1000,
      promptMicrousdPerMillionTokens: 1000000,
      completionMicrousdPerMillionTokens: 1000000,
      judgePromptMicrousdPerMillionTokens: 1,
      judgeCompletionMicrousdPerMillionTokens: 1,
      deadline: const Duration(minutes: 5),
      holdoutAccessBudget: 1,
      codeCommit: 'purpose-built-performance-commit',
      sourceTreeHash: _digest('2'),
      buildArtifactHash: _digest('3'),
      runtimeReleaseHash: _digest('4'),
      tokenizerReleaseHash: _digest('5'),
    );
  }

  static String _digest(String character) =>
      List<String>.filled(64, character).join();
}

abstract final class AgentEvaluationPromotionPerformanceAuthority {
  static const attackVariant = 'cost-regression-attack';
  static const controlVariant = 'cost-boundary-control';

  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-promotion-performance-authority-v1',
    <String, Object?>{
      'source': 'sealed-db-gate-authority-projection-v1',
      'decision': 'standard-gate-policy-no-caller-aggregate-v1',
      'attack': 'quality-noninferior-cost-above-15-percent-reject',
      'control': 'quality-noninferior-cost-at-or-below-15-percent-promote',
      'minimumPairedSamples':
          AgentEvaluationStandardGatePolicy.minimumPerformancePairs,
      'maximumCostRegression':
          AgentEvaluationStandardGatePolicy.maximumCostRegression,
      'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
      'gateReleaseHash': AgentEvaluationStandardGatePolicy.gateReleaseHash,
      'scenarioReleaseHash':
          AgentEvaluationPromotionPerformanceScenario.releaseHash,
    },
  );

  static AgentEvaluationPromotionPerformanceProjection read({
    required Database db,
    required String verdictHash,
    required String variant,
  }) {
    AgentEvaluationHashes.requireDigest(verdictHash, 'verdictHash');
    if (!const <String>{attackVariant, controlVariant}.contains(variant)) {
      throw const AgentEvaluationPromotionPerformanceAuthorityException(
        'promotion performance variant is invalid',
      );
    }
    final rows = db.select(
      '''SELECT v.*, d.projection_hash, d.authority_release_hash,
           x.status AS execution_status
         FROM eval_release_gate_verdicts v
         JOIN eval_release_gate_derivations d
           ON d.verdict_hash = v.verdict_hash
         JOIN eval_executions x ON x.execution_id = v.execution_id
         WHERE v.verdict_hash = ? AND v.verdict_kind = 'regression' ''',
      <Object?>[verdictHash],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationPromotionPerformanceAuthorityException(
        'promotion performance verdict authority is missing or ambiguous',
      );
    }
    final row = rows.single;
    final store = AgentEvaluationReleaseStore(db: db);
    final rederived = store.rederiveGateAuthorityProjection(
      experimentId: row['experiment_id'] as String,
      executionId: row['execution_id'] as String,
      scorecardHash: row['scorecard_hash'] as String,
      championBundleHash: row['champion_bundle_hash'] as String,
      challengerBundleHash: row['challenger_bundle_hash'] as String,
    );
    final storedReasons = _stringList(row['reasons_json'] as String);
    final expectedStatus = variant == attackVariant ? 'reject' : 'promote';
    final expectedReasons = variant == attackVariant
        ? const <String>['costRegression']
        : const <String>[];
    final aboveCostBoundary =
        rederived.challengerTotalCostMicrousd * 100 >
        rederived.championTotalCostMicrousd * 115;
    if (row['execution_status'] != 'completed' ||
        row['status'] != expectedStatus ||
        rederived.status != expectedStatus ||
        AgentEvaluationHashes.canonicalJson(storedReasons) !=
            AgentEvaluationHashes.canonicalJson(expectedReasons) ||
        AgentEvaluationHashes.canonicalJson(rederived.reasons) !=
            AgentEvaluationHashes.canonicalJson(expectedReasons) ||
        row['comparison_input_set_hash'] != rederived.comparisonInputSetHash ||
        row['expected_pair_set_hash'] != rederived.expectedPairSetHash ||
        row['policy_hash'] != AgentEvaluationStandardGatePolicy.policyHash ||
        row['gate_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash ||
        row['projection_hash'] != rederived.projectionHash ||
        row['authority_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash ||
        rederived.performanceSampleCount <
            AgentEvaluationStandardGatePolicy.minimumPerformancePairs ||
        rederived.minimumQualityMeanDeltaMicros == null ||
        rederived.maximumQualityMeanDeltaMicros == null ||
        rederived.minimumQualityMeanDeltaMicros! < 0 ||
        rederived.maximumQualityMeanDeltaMicros! <= 0 ||
        (variant == attackVariant && !aboveCostBoundary) ||
        (variant == controlVariant && aboveCostBoundary)) {
      throw const AgentEvaluationPromotionPerformanceAuthorityException(
        'promotion performance verdict contradicts sealed DB evidence',
      );
    }
    return AgentEvaluationPromotionPerformanceProjection._(
      variant: variant,
      verdictHash: verdictHash,
      experimentId: row['experiment_id'] as String,
      executionId: row['execution_id'] as String,
      scorecardHash: row['scorecard_hash'] as String,
      championBundleHash: row['champion_bundle_hash'] as String,
      challengerBundleHash: row['challenger_bundle_hash'] as String,
      status: rederived.status,
      reasons: rederived.reasons,
      comparisonInputSetHash: rederived.comparisonInputSetHash,
      expectedPairSetHash: rederived.expectedPairSetHash,
      gateProjectionHash: rederived.projectionHash,
      championTotalCostMicrousd: rederived.championTotalCostMicrousd,
      challengerTotalCostMicrousd: rederived.challengerTotalCostMicrousd,
      performanceSampleCount: rederived.performanceSampleCount,
      minimumQualityMeanDeltaMicros: rederived.minimumQualityMeanDeltaMicros!,
      maximumQualityMeanDeltaMicros: rederived.maximumQualityMeanDeltaMicros!,
    );
  }

  static AgentEvaluationPromotionPerformanceProjection verifyReportMap({
    required Database db,
    required Map<String, Object?> reportMap,
  }) {
    final verdictHash = reportMap['verdictHash'];
    final variant = reportMap['variant'];
    if (reportMap.keys.toSet().difference(_reportKeys).isNotEmpty ||
        _reportKeys.difference(reportMap.keys.toSet()).isNotEmpty ||
        reportMap['schemaVersion'] !=
            'agent-evaluation-promotion-performance-projection-v1' ||
        reportMap['authorityReleaseHash'] != releaseHash ||
        verdictHash is! String ||
        variant is! String) {
      throw const AgentEvaluationPromotionPerformanceAuthorityException(
        'promotion performance report projection is invalid',
      );
    }
    final rederived = read(db: db, verdictHash: verdictHash, variant: variant);
    if (AgentEvaluationHashes.canonicalJson(rederived.toReportMap()) !=
        AgentEvaluationHashes.canonicalJson(reportMap)) {
      throw const AgentEvaluationPromotionPerformanceAuthorityException(
        'promotion performance report cannot be rederived',
      );
    }
    return rederived;
  }

  static List<String> _stringList(String source) {
    final value = jsonDecode(source);
    if (value is! List<Object?> ||
        value.any((item) => item is! String) ||
        AgentEvaluationHashes.canonicalJson(value) != source) {
      throw const AgentEvaluationPromotionPerformanceAuthorityException(
        'promotion performance reasons are malformed',
      );
    }
    return value.cast<String>()..sort();
  }

  static const _reportKeys = <String>{
    'schemaVersion',
    'authorityReleaseHash',
    'variant',
    'verdictHash',
    'experimentIdHash',
    'executionIdHash',
    'scorecardHash',
    'championBundleHash',
    'challengerBundleHash',
    'status',
    'reasons',
    'comparisonInputSetHash',
    'expectedPairSetHash',
    'gateProjectionHash',
    'championTotalCostMicrousd',
    'challengerTotalCostMicrousd',
    'costRegressionBasisPoints',
    'performanceSampleCount',
    'minimumQualityMeanDeltaMicros',
    'maximumQualityMeanDeltaMicros',
    'purposeBuiltTransport',
    'realProviderEvidence',
    'projectionHash',
  };
}

final class AgentEvaluationPromotionPerformanceProjection {
  AgentEvaluationPromotionPerformanceProjection._({
    required this.variant,
    required this.verdictHash,
    required this.experimentId,
    required this.executionId,
    required this.scorecardHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.status,
    required this.reasons,
    required this.comparisonInputSetHash,
    required this.expectedPairSetHash,
    required this.gateProjectionHash,
    required this.championTotalCostMicrousd,
    required this.challengerTotalCostMicrousd,
    required this.performanceSampleCount,
    required this.minimumQualityMeanDeltaMicros,
    required this.maximumQualityMeanDeltaMicros,
  });

  final String variant;
  final String verdictHash;
  final String experimentId;
  final String executionId;
  final String scorecardHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String status;
  final List<String> reasons;
  final String comparisonInputSetHash;
  final String expectedPairSetHash;
  final String gateProjectionHash;
  final int championTotalCostMicrousd;
  final int challengerTotalCostMicrousd;
  final int performanceSampleCount;
  final int minimumQualityMeanDeltaMicros;
  final int maximumQualityMeanDeltaMicros;

  int get costRegressionBasisPoints =>
      ((challengerTotalCostMicrousd - championTotalCostMicrousd) * 10000) ~/
      championTotalCostMicrousd;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-promotion-performance-projection-v1',
    'authorityReleaseHash':
        AgentEvaluationPromotionPerformanceAuthority.releaseHash,
    'variant': variant,
    'verdictHash': verdictHash,
    'experimentIdHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-promotion-performance-experiment-v1',
      experimentId,
    ),
    'executionIdHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-promotion-performance-execution-v1',
      executionId,
    ),
    'scorecardHash': scorecardHash,
    'championBundleHash': championBundleHash,
    'challengerBundleHash': challengerBundleHash,
    'status': status,
    'reasons': reasons,
    'comparisonInputSetHash': comparisonInputSetHash,
    'expectedPairSetHash': expectedPairSetHash,
    'gateProjectionHash': gateProjectionHash,
    'championTotalCostMicrousd': championTotalCostMicrousd,
    'challengerTotalCostMicrousd': challengerTotalCostMicrousd,
    'costRegressionBasisPoints': costRegressionBasisPoints,
    'performanceSampleCount': performanceSampleCount,
    'minimumQualityMeanDeltaMicros': minimumQualityMeanDeltaMicros,
    'maximumQualityMeanDeltaMicros': maximumQualityMeanDeltaMicros,
    'purposeBuiltTransport': true,
    'realProviderEvidence': false,
  };

  String get projectionHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-promotion-performance-projection-v1',
    toCanonicalMap(),
  );

  Map<String, Object?> toReportMap() => <String, Object?>{
    ...toCanonicalMap(),
    'projectionHash': projectionHash,
  };
}
