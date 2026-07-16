import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_promotion_performance_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/agent_evaluation_production_protocol_client.dart';

void main() {
  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync(
      'agent-evaluation-promotion-performance-',
    );
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'sealed production evidence rejects 16 percent cost and promotes 15 percent',
    () async {
      final attack = await _runBoundary(
        root: Directory('${root.path}/attack'),
        executionId: 'promotion-performance-attack',
        variant: AgentEvaluationPromotionPerformanceAuthority.attackVariant,
        challengerTokensPerCall:
            AgentEvaluationPromotionPerformanceScenario.challengerTokensPerCall(
              AgentEvaluationPromotionPerformanceAuthority.attackVariant,
            ),
      );
      final control = await _runBoundary(
        root: Directory('${root.path}/control'),
        executionId: 'promotion-performance-control',
        variant: AgentEvaluationPromotionPerformanceAuthority.controlVariant,
        challengerTokensPerCall:
            AgentEvaluationPromotionPerformanceScenario.challengerTokensPerCall(
              AgentEvaluationPromotionPerformanceAuthority.controlVariant,
            ),
      );

      expect(attack.status, 'reject');
      expect(attack.reasons, <String>['costRegression']);
      expect(attack.costRegressionBasisPoints, greaterThan(1500));
      expect(control.status, 'promote');
      expect(control.reasons, isEmpty);
      expect(control.costRegressionBasisPoints, lessThanOrEqualTo(1500));
      expect(control.costRegressionBasisPoints, greaterThanOrEqualTo(1490));
      expect(attack.performanceSampleCount, greaterThanOrEqualTo(20));
      expect(control.performanceSampleCount, greaterThanOrEqualTo(20));
      expect(attack.minimumQualityMeanDeltaMicros, greaterThanOrEqualTo(0));
      expect(control.minimumQualityMeanDeltaMicros, greaterThanOrEqualTo(0));
      expect(attack.maximumQualityMeanDeltaMicros, greaterThan(0));
      expect(control.maximumQualityMeanDeltaMicros, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<AgentEvaluationPromotionPerformanceProjection> _runBoundary({
  required Directory root,
  required String executionId,
  required String variant,
  required int challengerTokensPerCall,
}) async {
  final sut = _PerformanceBoundarySutClient(
    challengerTokensPerCall: challengerTokensPerCall,
  );
  final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
    configuration: AgentEvaluationPromotionPerformanceScenario.configuration(
      executionId,
    ),
    sutClient: sut,
    judgeClient: _PerformanceBoundaryJudgeClient(),
    outputDirectory: Directory('${root.path}/reports'),
    workDirectory: Directory('${root.path}/work'),
    runnerNowMs:
        AgentEvaluationPromotionPerformanceScenario.deterministicRunnerClock(),
  );
  late final AgentEvaluationRealReleaseResult result;
  try {
    result = await harness.run();
  } finally {
    harness.dispose();
  }
  expect(result.realProviderEvidence, isFalse);
  expect(result.releaseEligible, isFalse);
  expect(sut.baselineCalls + sut.pricedChallengerCalls, 540);
  expect(sut.baselineCalls, greaterThan(0));
  expect(sut.pricedChallengerCalls, greaterThan(0));

  final db = sqlite3.open(result.authorityDatabasePath);
  try {
    final partition = result.partitions.single;
    final expectedStatus =
        variant == AgentEvaluationPromotionPerformanceAuthority.attackVariant
        ? 'reject'
        : 'promote';
    final verdict = db.select(
      'SELECT * FROM eval_release_gate_verdicts WHERE verdict_hash = ?',
      <Object?>[partition.regressionVerdictHash],
    ).single;
    final diagnosticProjection = AgentEvaluationReleaseStore(db: db)
        .rederiveGateAuthorityProjection(
          experimentId: verdict['experiment_id'] as String,
          executionId: verdict['execution_id'] as String,
          scorecardHash: verdict['scorecard_hash'] as String,
          championBundleHash: verdict['champion_bundle_hash'] as String,
          challengerBundleHash: verdict['challenger_bundle_hash'] as String,
        );
    expect(
      partition.regressionStatus,
      expectedStatus,
      reason: diagnosticProjection.toCanonicalMap().toString(),
    );
    expect(
      db.select("SELECT * FROM eval_executions WHERE status = 'completed'"),
      hasLength(1),
    );
    expect(db.select('SELECT * FROM eval_trial_slots'), hasLength(60));
    expect(
      db.select(
        "SELECT * FROM eval_observations WHERE stage_id = 'performance' "
        "AND kind = 'usage'",
      ),
      hasLength(60),
    );
    expect(
      db.select(
        "SELECT * FROM eval_observations WHERE stage_id = 'production' "
        "AND kind = 'receipt'",
      ),
      hasLength(60),
    );
    expect(
      db.select('SELECT * FROM eval_production_authority_receipts'),
      hasLength(60),
    );
    expect(db.select('SELECT * FROM eval_price_table_releases'), hasLength(1));
    expect(db.select('SELECT * FROM eval_release_gate_verdicts'), hasLength(1));
    expect(
      db.select('SELECT * FROM eval_release_gate_derivations'),
      hasLength(1),
    );

    final projection = AgentEvaluationPromotionPerformanceAuthority.read(
      db: db,
      verdictHash: partition.regressionVerdictHash,
      variant: variant,
    );
    final reportMap = projection.toReportMap();
    final reportReadback =
        AgentEvaluationPromotionPerformanceAuthority.verifyReportMap(
          db: db,
          reportMap: reportMap,
        );
    expect(reportReadback.projectionHash, projection.projectionHash);

    final repeated = AgentEvaluationReleaseStore(db: db)
        .evaluateAndRecordGateVerdict(
          verdictKind: 'regression',
          experimentId: verdict['experiment_id'] as String,
          executionId: verdict['execution_id'] as String,
          scorecardHash: verdict['scorecard_hash'] as String,
          championBundleHash: verdict['champion_bundle_hash'] as String,
          challengerBundleHash: verdict['challenger_bundle_hash'] as String,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        );
    expect(repeated.verdictHash, partition.regressionVerdictHash);
    expect(
      db.select('SELECT * FROM eval_release_gate_derivations'),
      hasLength(1),
    );

    final tampered = <String, Object?>{
      ...reportMap,
      'status': projection.status == 'promote' ? 'reject' : 'promote',
    };
    expect(
      () => AgentEvaluationPromotionPerformanceAuthority.verifyReportMap(
        db: db,
        reportMap: tampered,
      ),
      throwsA(isA<AgentEvaluationPromotionPerformanceAuthorityException>()),
    );
    return projection;
  } finally {
    db.dispose();
  }
}

final class _PerformanceBoundarySutClient implements AppLlmClient {
  _PerformanceBoundarySutClient({required this.challengerTokensPerCall});

  final int challengerTokensPerCall;
  final PurposeBuiltProductionProtocolClient _inner =
      PurposeBuiltProductionProtocolClient();
  var baselineCalls = 0;
  var pricedChallengerCalls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final result = await _inner.chat(request);
    if (!result.succeeded) return result;
    final challenger = request.messages.any(
      (message) =>
          message.content.contains('causal bridge in order') ||
          message.content.contains(_challengerReplacement),
    );
    final pricedChallenger =
        AgentEvaluationPromotionPerformanceScenario.isPricedChallenger(
          request.messages.map((message) => message.content),
        );
    if (pricedChallenger) {
      pricedChallengerCalls += 1;
    } else {
      baselineCalls += 1;
    }
    final prose =
        request.messages.first.content.contains('scene editor') ||
        request.messages.last.content.contains('任务：language_polish');
    final totalTokens = pricedChallenger
        ? challengerTokensPerCall
        : AgentEvaluationPromotionPerformanceScenario.baselineTokensPerCall;
    final promptTokens = totalTokens ~/ 2;
    final completionTokens = totalTokens - promptTokens;
    return AppLlmChatResult.success(
      text: challenger && prose
          ? result.text!.replaceAll(_challengerSource, _challengerReplacement)
          : result.text,
      latencyMs: result.latencyMs,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

final class _PerformanceBoundaryJudgeClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final challenger = request.messages.any(
      (message) => message.content.contains(_challengerReplacement),
    );
    final score = challenger ? 100 : 96;
    return AppLlmChatResult.success(
      text:
          '{"scores":{"proseReadability":$score,'
          '"plotCausality":$score},"summary":"blind comparison"}',
      latencyMs: 3,
      promptTokens: 30,
      completionTokens: 12,
      totalTokens: 42,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release judge disables streaming');
}

const _challengerSource = '真正的编号刻在仓门内侧';
const _challengerReplacement =
    AgentEvaluationPromotionPerformanceScenario.challengerMarker;
