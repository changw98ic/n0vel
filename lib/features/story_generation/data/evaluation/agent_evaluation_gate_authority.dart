part of 'agent_evaluation_release_store.dart';

/// Frozen organization-wide release policy. Experiments may be stricter, but
/// they cannot replace these mechanics or thresholds with caller-selected
/// values at verdict time.
abstract final class AgentEvaluationStandardGatePolicy {
  static const requiredQualityDimensions =
      AgentEvaluationQualityDimensions.values;
  static const minimumQualityPairs = 20;
  static const minimumPerformancePairs = 20;
  static const maximumCostRegression = 0.15;
  static const maximumP95LatencyRegression = 0.10;
  static const familyWiseAlpha = 0.05;
  static const multiplicityMethodIdentity = 'bonferroni-normal-z3-v1';
  static const confidenceZ = 3.0;

  static Map<String, Object?> get canonicalSnapshot => <String, Object?>{
    'requiredQualityDimensions': requiredQualityDimensions.toList()..sort(),
    'minimumQualityPairs': minimumQualityPairs,
    'minimumPerformancePairs': minimumPerformancePairs,
    'maximumCostRegression': maximumCostRegression,
    'maximumP95LatencyRegression': maximumP95LatencyRegression,
    'familyWiseAlpha': familyWiseAlpha,
    'multiplicityMethodIdentity': multiplicityMethodIdentity,
    'confidenceZ': confidenceZ,
    'pairing': 'canonical-by-model-scenario-decoding-trial-v1',
    'missingPairPolicy': 'insufficientEvidence',
  };

  static String get policyHash => AgentEvaluationHashes.domainHash(
    'eval-standard-release-gate-policy-v1',
    canonicalSnapshot,
  );

  static Map<String, Object?> get gateReleaseSnapshot => <String, Object?>{
    'policyHash': policyHash,
    'algorithm': 'sealed-db-dispatch-production-authority-projection-v4',
    'deterministicQualityAuthorityReleaseHash':
        AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash,
    'deterministicQualityReceiptContractReleaseHash':
        AgentEvaluationDeterministicQualityPolicy.receiptContractReleaseHash,
  };

  static String get gateReleaseHash => AgentEvaluationHashes.domainHash(
    'eval-release-gate-implementation-v2',
    gateReleaseSnapshot,
  );
}

String? _rawProductionDigest(Object? value) {
  if (value is! String) return null;
  return value.startsWith('sha256:') ? value.substring(7) : value;
}

extension AgentEvaluationReleaseGateAuthority on AgentEvaluationReleaseStore {
  AgentEvaluationGateAuthorityProjectionRecord rederiveGateAuthorityProjection({
    required String experimentId,
    required String executionId,
    required String scorecardHash,
    required String championBundleHash,
    required String challengerBundleHash,
  }) {
    final authority = _DbGateAuthorityProjection.read(
      db: db,
      experimentId: experimentId,
      executionId: executionId,
      scorecardHash: scorecardHash,
      championBundleHash: championBundleHash,
      challengerBundleHash: challengerBundleHash,
    );
    return AgentEvaluationGateAuthorityProjectionRecord._(
      result: authority.result,
      comparisonInputSetHash: authority.comparisonInputSetHash,
      expectedPairSetHash: authority.expectedPairSetHash,
      projectionHash: authority.projectionHash,
      minimumQualityMeanDeltaMicros: authority.minimumQualityMeanDeltaMicros,
      maximumQualityMeanDeltaMicros: authority.maximumQualityMeanDeltaMicros,
    );
  }

  /// Recomputes the release decision from the complete sealed execution.
  /// Callers choose only the compared identities; they cannot supply aggregate
  /// statistics, pair IDs, status, reasons, LCB, p95, or resource totals.
  AgentEvaluationGateVerdictRecord evaluateAndRecordGateVerdict({
    required String verdictKind,
    required String experimentId,
    required String executionId,
    required String scorecardHash,
    required String championBundleHash,
    required String challengerBundleHash,
    required int createdAtMs,
  }) {
    if (!<String>{'regression', 'holdout'}.contains(verdictKind) ||
        createdAtMs < 0) {
      throw const AgentEvaluationPromotionConflict(
        'invalid derived gate request',
      );
    }
    AgentEvaluationReleaseStore._requireIdentity(experimentId, 'experimentId');
    AgentEvaluationReleaseStore._requireIdentity(executionId, 'executionId');
    for (final value in <(String, String)>[
      (scorecardHash, 'scorecardHash'),
      (championBundleHash, 'championBundleHash'),
      (challengerBundleHash, 'challengerBundleHash'),
    ]) {
      AgentEvaluationReleaseStore._requireDigest(value.$1, value.$2);
    }
    if (championBundleHash == challengerBundleHash) {
      throw const AgentEvaluationPromotionConflict(
        'champion and challenger must differ',
      );
    }

    final authority = rederiveGateAuthorityProjection(
      experimentId: experimentId,
      executionId: executionId,
      scorecardHash: scorecardHash,
      championBundleHash: championBundleHash,
      challengerBundleHash: challengerBundleHash,
    );
    final verdict = _persistGateVerdict(
      verdictKind: verdictKind,
      experimentId: experimentId,
      executionId: executionId,
      scorecardHash: scorecardHash,
      championBundleHash: championBundleHash,
      challengerBundleHash: challengerBundleHash,
      status: authority.status,
      reasons: authority.reasons,
      comparisonInputSetHash: authority.comparisonInputSetHash,
      expectedPairSetHash: authority.expectedPairSetHash,
      policyHash: AgentEvaluationStandardGatePolicy.policyHash,
      gateReleaseHash: AgentEvaluationStandardGatePolicy.gateReleaseHash,
      createdAtMs: createdAtMs,
    );
    db.execute(
      '''INSERT OR IGNORE INTO eval_release_gate_derivations (
           verdict_hash, projection_hash, authority_release_hash, created_at_ms
         ) VALUES (?, ?, ?, ?)''',
      <Object?>[
        verdict.verdictHash,
        authority.projectionHash,
        AgentEvaluationStandardGatePolicy.gateReleaseHash,
        createdAtMs,
      ],
    );
    final derivations = db.select(
      'SELECT * FROM eval_release_gate_derivations WHERE verdict_hash = ?',
      <Object?>[verdict.verdictHash],
    );
    if (derivations.length != 1 ||
        derivations.single['projection_hash'] != authority.projectionHash ||
        derivations.single['authority_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash) {
      throw const AgentEvaluationPromotionConflict(
        'derived gate authorization was not persisted',
      );
    }
    return verdict;
  }
}

final class AgentEvaluationGateAuthorityProjectionRecord {
  const AgentEvaluationGateAuthorityProjectionRecord._({
    required ReleaseGateResult result,
    required this.comparisonInputSetHash,
    required this.expectedPairSetHash,
    required this.projectionHash,
    required this.minimumQualityMeanDeltaMicros,
    required this.maximumQualityMeanDeltaMicros,
  }) : _result = result;

  final ReleaseGateResult _result;
  final String comparisonInputSetHash;
  final String expectedPairSetHash;
  final String projectionHash;
  final int? minimumQualityMeanDeltaMicros;
  final int? maximumQualityMeanDeltaMicros;

  String get status => _result.status.name;
  List<String> get reasons =>
      _result.reasons.map((reason) => reason.name).toList()..sort();
  int get championTotalCostMicrousd => _result.championTotalCostMicrousd;
  int get challengerTotalCostMicrousd => _result.challengerTotalCostMicrousd;
  int get performanceSampleCount => _result.performanceSampleCount;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-gate-authority-projection-v1',
    'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
    'gateReleaseHash': AgentEvaluationStandardGatePolicy.gateReleaseHash,
    'comparisonInputSetHash': comparisonInputSetHash,
    'expectedPairSetHash': expectedPairSetHash,
    'projectionHash': projectionHash,
    'status': status,
    'reasons': reasons,
    'championTotalCostMicrousd': championTotalCostMicrousd,
    'challengerTotalCostMicrousd': challengerTotalCostMicrousd,
    'performanceSampleCount': performanceSampleCount,
    'minimumQualityMeanDeltaMicros': minimumQualityMeanDeltaMicros,
    'maximumQualityMeanDeltaMicros': maximumQualityMeanDeltaMicros,
  };
}

final class _DbGateAuthorityProjection {
  const _DbGateAuthorityProjection({
    required this.result,
    required this.comparisonInputSetHash,
    required this.expectedPairSetHash,
    required this.projectionHash,
    required this.minimumQualityMeanDeltaMicros,
    required this.maximumQualityMeanDeltaMicros,
  });

  final ReleaseGateResult result;
  final String comparisonInputSetHash;
  final String expectedPairSetHash;
  final String projectionHash;
  final int? minimumQualityMeanDeltaMicros;
  final int? maximumQualityMeanDeltaMicros;

  static _DbGateAuthorityProjection read({
    required Database db,
    required String experimentId,
    required String executionId,
    required String scorecardHash,
    required String championBundleHash,
    required String challengerBundleHash,
  }) {
    final roots = db.select(
      '''SELECT e.*, x.status AS execution_status,
           x.expected_cell_set_hash AS execution_cell_set_hash,
           x.expected_slot_set_hash AS execution_slot_set_hash,
           s.scope, s.scope_key, s.input_set_hash, s.expected_set_hash,
           s.aggregator_release_hash AS scorecard_aggregator_release_hash,
           b.rubric_release_hash, b.aggregator_release_hash,
           b.evaluation_bundle_hash, b.judges_json, b.verifiers_json
         FROM eval_experiments e
         JOIN eval_executions x ON x.experiment_id = e.experiment_id
         JOIN eval_scorecards s ON s.execution_id = x.execution_id
         JOIN evaluation_bundles b
           ON b.evaluation_bundle_hash = e.evaluation_bundle_hash
         WHERE e.experiment_id = ? AND x.execution_id = ?
           AND s.scorecard_hash = ?''',
      <Object?>[experimentId, executionId, scorecardHash],
    );
    if (roots.length != 1) {
      throw const AgentEvaluationPromotionConflict(
        'derived gate root is missing or ambiguous',
      );
    }
    final root = roots.single;
    final manifest = _jsonObject(root['manifest_json'], 'experiment manifest');
    final manifestPriceTableHash = manifest['priceTableHash'];
    if (manifestPriceTableHash is! String) {
      throw const AgentEvaluationPromotionConflict(
        'experiment manifest omitted the frozen price table',
      );
    }
    late final AgentEvaluationFrozenProviderPriceTable priceTable;
    try {
      priceTable = AgentEvaluationFrozenProviderPriceTable.load(
        db,
        releaseHash: manifestPriceTableHash,
      );
    } on AgentEvaluationProductionEvidenceException {
      throw const AgentEvaluationPromotionConflict(
        'frozen price table authority is missing or invalid',
      );
    }
    final judgeIdentities = _frozenJudgeIdentities(root['judges_json']);
    final performancePolicy = manifest['performanceSamplingPolicy'];
    final thresholds = manifest['qualityThresholds'];
    if (root['execution_status'] != 'completed' ||
        root['scope'] != 'execution' ||
        root['scope_key'] != executionId ||
        root['scorecard_aggregator_release_hash'] !=
            root['aggregator_release_hash'] ||
        manifest['qualityComparisonPolicyHash'] !=
            AgentEvaluationStandardGatePolicy.policyHash ||
        performancePolicy is! Map<String, Object?> ||
        performancePolicy['pairing'] !=
            'canonical-by-model-scenario-decoding-trial-v1' ||
        performancePolicy['order'] != 'interleaved-randomized-v1' ||
        performancePolicy['minimumPairedSamples'] !=
            AgentEvaluationStandardGatePolicy.minimumPerformancePairs ||
        thresholds is! Map<String, Object?> ||
        thresholds['claimScope'] != 'real-provider-release') {
      throw const AgentEvaluationPromotionConflict(
        'experiment did not preregister the standard release policy',
      );
    }
    late final AgentEvaluationDispatchReplayResult dispatch;
    try {
      dispatch = AgentEvaluationDispatchReplay.verify(
        db: db,
        executionId: executionId,
      );
    } on AgentEvaluationDispatchReplayException catch (error) {
      throw AgentEvaluationPromotionConflict(
        'dispatch authority replay failed: ${error.message}',
      );
    }

    final cells = db.select(
      '''SELECT c.* FROM eval_experiment_cells ec
         JOIN eval_cells c ON c.cell_id = ec.cell_id
         WHERE ec.experiment_id = ? ORDER BY c.cell_id''',
      <Object?>[experimentId],
    );
    final championCells = _cellsForArm(cells, championBundleHash);
    final challengerCells = _cellsForArm(cells, challengerBundleHash);
    if (championCells.isEmpty ||
        !_sameKeySet(championCells.keys, challengerCells.keys)) {
      throw const AgentEvaluationPromotionConflict(
        'champion/challenger canonical pair set is incomplete',
      );
    }
    final allArmCells = <String>{
      ...championCells.values.map((row) => row['cell_id'] as String),
      ...challengerCells.values.map((row) => row['cell_id'] as String),
    };
    if (allArmCells.length != cells.length) {
      throw const AgentEvaluationPromotionConflict(
        'release experiment must contain exactly the compared arms',
      );
    }
    final trialsPerCell = root['trials_per_cell'] as int;
    if (trialsPerCell != 3) {
      throw const AgentEvaluationPromotionConflict(
        'release gate requires exactly three slots per cell',
      );
    }

    final pairIds = <String>[];
    final pairDefinitions = <_PairDefinition>[];
    final logicalKeys = championCells.keys.toList()..sort();
    for (final logicalKey in logicalKeys) {
      for (var trialNo = 1; trialNo <= trialsPerCell; trialNo += 1) {
        final pairId = AgentEvaluationHashes.domainHash(
          'eval-release-pair-v1',
          <Object?>[logicalKey, trialNo],
        );
        pairIds.add(pairId);
        pairDefinitions.add(
          _PairDefinition(
            pairId: pairId,
            championCellId: championCells[logicalKey]!['cell_id'] as String,
            challengerCellId: challengerCells[logicalKey]!['cell_id'] as String,
            trialNo: trialNo,
          ),
        );
      }
    }
    pairIds.sort();
    final expectedPairSetHash = AgentEvaluationHashes.domainHash(
      'eval-release-pair-set-v1',
      pairIds,
    );

    final slots = db.select(
      '''SELECT * FROM eval_trial_slots WHERE execution_id = ?
         ORDER BY cell_id, trial_no''',
      <Object?>[executionId],
    );
    if (slots.length != pairDefinitions.length * 2 ||
        slots.any(
          (slot) =>
              slot['status'] != 'sealed' ||
              slot['result'] == null ||
              slot['sealed_evidence_hash'] == null,
        )) {
      throw const AgentEvaluationPromotionConflict(
        'derived gate requires every canonical slot to be sealed',
      );
    }
    final slotsByKey = <String, Row>{
      for (final slot in slots)
        _slotKey(slot['cell_id'] as String, slot['trial_no'] as int): slot,
    };
    if (slotsByKey.length != slots.length) {
      throw const AgentEvaluationPromotionConflict(
        'derived gate slot set is duplicated',
      );
    }
    for (final pair in pairDefinitions) {
      if (!slotsByKey.containsKey(
            _slotKey(pair.championCellId, pair.trialNo),
          ) ||
          !slotsByKey.containsKey(
            _slotKey(pair.challengerCellId, pair.trialNo),
          )) {
        throw const AgentEvaluationPromotionConflict(
          'derived gate canonical pair is missing a slot',
        );
      }
    }

    final projection = AgentEvaluationPass3ProjectionReader(db);
    bool armPass3(Iterable<Row> armCells) => armCells.every(
      (cell) => projection
          .readCell(
            executionId: executionId,
            cellId: cell['cell_id'] as String,
            evaluationBundleHash: root['evaluation_bundle_hash'] as String,
          )
          .result
          .passed,
    );
    final attempts = db.select(
      '''SELECT a.* FROM eval_trial_attempts a
         JOIN eval_trial_slots s ON s.trial_slot_id = a.trial_slot_id
         WHERE s.execution_id = ? ORDER BY a.trial_slot_id, a.attempt_no''',
      <Object?>[executionId],
    );
    final usageRows = db.select(
      '''SELECT o.* FROM eval_observations o
         JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
         WHERE s.execution_id = ? AND o.stage_id = 'performance'
           AND o.kind = 'usage' ORDER BY o.trial_slot_id, o.attempt_no''',
      <Object?>[executionId],
    );
    final usageByAttempt = <String, _GateUsage>{};
    var usageMalformed = false;
    for (final row in usageRows) {
      final key = _attemptKey(
        row['trial_slot_id'] as String,
        row['attempt_no'] as int,
      );
      try {
        final value = _jsonObject(row['value_json'], 'usage observation');
        final expectedEvidenceHash = AgentEvaluationHashes.domainHash(
          'eval-attempt-usage-observation-v1',
          <String, Object?>{
            'trialSlotId': row['trial_slot_id'],
            'attemptNo': row['attempt_no'],
            'value': value,
          },
        );
        if (row['evidence_hash'] != expectedEvidenceHash) {
          usageMalformed = true;
          continue;
        }
        final usage = _GateUsage.fromJson(
          value,
          expectedPriceTableHash: priceTable.releaseHash,
          priceTable: priceTable,
        );
        if (usageByAttempt.containsKey(key)) usageMalformed = true;
        usageByAttempt[key] = usage;
      } on Object {
        usageMalformed = true;
      }
    }
    final cellBundle = <String, String>{
      for (final cell in cells)
        cell['cell_id'] as String: cell['generation_bundle_hash'] as String,
    };
    final cellRoute = <String, String>{
      for (final cell in cells)
        cell['cell_id'] as String: cell['sut_model_route_hash'] as String,
    };
    final slotById = <String, Row>{
      for (final slot in slots) slot['trial_slot_id'] as String: slot,
    };
    final championAttempts = <TrialAttemptObservation>[];
    final challengerAttempts = <TrialAttemptObservation>[];
    final completedContentUsage = <String, _GateUsage>{};
    final completedContentLatency = <String, int>{};
    for (final attempt in attempts) {
      final slotId = attempt['trial_slot_id'] as String;
      final usage =
          usageByAttempt[_attemptKey(slotId, attempt['attempt_no'] as int)];
      if (usage == null) {
        usageMalformed = true;
        continue;
      }
      final slot = slotById[slotId];
      final expectedRoute = slot == null
          ? null
          : cellRoute[slot['cell_id'] as String];
      if (expectedRoute == null ||
          usage.sutModelRouteHashes.length != 1 ||
          usage.sutModelRouteHashes.single != expectedRoute ||
          !_sameKeySet(
            usage.externalJudgeModelRouteHashes,
            judgeIdentities.modelRouteHashes,
          )) {
        usageMalformed = true;
        continue;
      }
      final startedAtMs = attempt['started_at_ms'];
      final finishedAtMs = attempt['finished_at_ms'];
      if (startedAtMs is! int ||
          finishedAtMs is! int ||
          finishedAtMs < startedAtMs) {
        usageMalformed = true;
        continue;
      }
      final latencyMs = finishedAtMs - startedAtMs;
      final observation = TrialAttemptObservation(
        attemptId: '${attempt['run_id']}',
        kind: attempt['kind'] == 'content'
            ? TrialAttemptKind.content
            : TrialAttemptKind.transport,
        succeeded:
            attempt['kind'] == 'content' && attempt['status'] == 'completed',
        latencyMs: latencyMs,
        promptTokens: usage.promptTokens,
        completionTokens: usage.completionTokens,
        costMicrousd: usage.costMicrousd,
      );
      final bundle = cellBundle[slotById[slotId]!['cell_id']];
      if (bundle == championBundleHash) {
        championAttempts.add(observation);
      } else if (bundle == challengerBundleHash) {
        challengerAttempts.add(observation);
      }
      if (observation.succeeded) {
        completedContentUsage[slotId] = usage;
        completedContentLatency[slotId] = latencyMs;
      }
    }
    if (usageByAttempt.length != attempts.length) usageMalformed = true;
    final executionBudgets = manifest['budgets'];
    if (executionBudgets is! Map<String, Object?>) {
      usageMalformed = true;
    } else {
      final maxEvaluatorCalls = executionBudgets['evaluatorCalls'];
      final maxEvaluatorTokens = executionBudgets['evaluatorTokens'];
      final maxEvaluatorCost = executionBudgets['evaluatorCostMicrousd'];
      final evaluatorCalls = usageByAttempt.values.fold<int>(
        0,
        (sum, usage) => sum + usage.externalJudgeCallCount,
      );
      final evaluatorTokens = usageByAttempt.values.fold<int>(
        0,
        (sum, usage) => sum + usage.externalJudgeTokens,
      );
      final evaluatorCost = usageByAttempt.values.fold<int>(
        0,
        (sum, usage) => sum + usage.externalJudgeCostMicrousd,
      );
      if (maxEvaluatorCalls is! int ||
          maxEvaluatorTokens is! int ||
          maxEvaluatorCost is! int ||
          evaluatorCalls > maxEvaluatorCalls ||
          evaluatorTokens > maxEvaluatorTokens ||
          evaluatorCost > maxEvaluatorCost) {
        usageMalformed = true;
      }
    }

    final performancePairs = <PairedPerformanceObservation>[];
    for (final pair in pairDefinitions) {
      final championSlot =
          slotsByKey[_slotKey(pair.championCellId, pair.trialNo)]!;
      final challengerSlot =
          slotsByKey[_slotKey(pair.challengerCellId, pair.trialNo)]!;
      final championUsage =
          completedContentUsage[championSlot['trial_slot_id'] as String];
      final challengerUsage =
          completedContentUsage[challengerSlot['trial_slot_id'] as String];
      final championLatency =
          completedContentLatency[championSlot['trial_slot_id'] as String];
      final challengerLatency =
          completedContentLatency[challengerSlot['trial_slot_id'] as String];
      if (championUsage != null &&
          challengerUsage != null &&
          championLatency != null &&
          challengerLatency != null) {
        performancePairs.add(
          PairedPerformanceObservation(
            pairId: pair.pairId,
            championLatencyMs: championLatency,
            challengerLatencyMs: challengerLatency,
          ),
        );
      }
    }
    if (performancePairs.length != pairDefinitions.length) {
      performancePairs.clear();
    }

    final qualityRows = db.select(
      '''SELECT o.* FROM eval_observations o
         JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
         WHERE s.execution_id = ? AND o.stage_id = 'quality'
           AND o.kind = 'dimension' ORDER BY o.trial_slot_id, o.item_key''',
      <Object?>[executionId],
    );
    final qualityBySlotDimension = <String, double>{};
    final qualityScoreMicrosBySlot = <String, Map<String, int>>{};
    final qualityProvenanceBySlot = <String, Map<String, String>>{};
    final qualityAttemptBySlot = <String, int>{};
    var qualityMalformed = false;
    final outcomeRows = db.select(
      '''SELECT o.* FROM eval_observations o
         JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
         WHERE s.execution_id = ? AND o.stage_id = 'outcome'
           AND o.kind = 'comparison' AND o.item_key = 'singleton' ''',
      <Object?>[executionId],
    );
    final outcomeProseBySlot = <String, String>{};
    for (final row in outcomeRows) {
      final slotId = row['trial_slot_id'];
      final proseHash = row['prose_hash'];
      if (slotId is! String ||
          proseHash is! String ||
          outcomeProseBySlot.containsKey(slotId)) {
        qualityMalformed = true;
        continue;
      }
      outcomeProseBySlot[slotId] = proseHash;
    }
    final cacheTableExists = db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'eval_cache_receipts'",
        )
        .isNotEmpty;
    final cacheReceiptsByAttempt = <String, List<AppLlmCacheReceipt>>{};
    if (cacheTableExists) {
      for (final row in db.select(
        '''SELECT receipt_json FROM eval_cache_receipts
           WHERE current_execution_id = ? ORDER BY rowid''',
        <Object?>[executionId],
      )) {
        final receipt = AppLlmCacheReceipt.fromJson(
          jsonDecode(row['receipt_json']! as String) as Map<String, Object?>,
        );
        final value = receipt.toJson();
        final key =
            '${receipt.currentTrialSlotId}/${value['currentAttemptNo']}';
        cacheReceiptsByAttempt
            .putIfAbsent(key, () => <AppLlmCacheReceipt>[])
            .add(receipt);
      }
    }
    for (final row in outcomeRows) {
      try {
        final value = _jsonObject(row['value_json'], 'outcome observation');
        final key = '${row['trial_slot_id']}/${row['attempt_no']}';
        final crossHits =
            (cacheReceiptsByAttempt[key] ?? const <AppLlmCacheReceipt>[])
                .where(
                  (receipt) =>
                      receipt.hit &&
                      receipt.sourceTrialSlotId != receipt.currentTrialSlotId,
                )
                .toList(growable: false);
        if (crossHits.isEmpty) {
          if (value['independence'] != 'independent' ||
              value['cacheSourceTrialSlotId'] != null) {
            qualityMalformed = true;
          }
        } else if (value['independence'] != 'nonIndependent' ||
            value['cacheSourceTrialSlotId'] !=
                crossHits.first.sourceTrialSlotId) {
          qualityMalformed = true;
        }
      } on Object {
        qualityMalformed = true;
      }
    }
    if (outcomeProseBySlot.length != slots.length) qualityMalformed = true;

    final productionRows = db.select(
      '''SELECT o.*, a.run_id AS attempt_run_id,
           c.generation_bundle_hash,
           authority.authority_receipt_hash,
           authority.authority_release_hash,
           authority.attempt_run_id AS authority_attempt_run_id,
           authority.candidate_hash AS authority_candidate_hash,
           authority.commit_receipt_id AS authority_commit_receipt_id,
           authority.transaction_evidence_hash
             AS authority_transaction_evidence_hash,
           authority.prose_hash AS authority_prose_hash,
           authority.generation_bundle_hash
             AS authority_generation_bundle_hash,
           authority.executor_release_hash AS authority_executor_release_hash
         FROM eval_observations o
         JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
         JOIN eval_cells c ON c.cell_id = s.cell_id
         JOIN eval_trial_attempts a ON a.trial_slot_id = o.trial_slot_id
           AND a.attempt_no = o.attempt_no
         JOIN eval_production_authority_receipts authority
           ON authority.execution_id = s.execution_id
          AND authority.trial_slot_id = o.trial_slot_id
          AND authority.attempt_no = o.attempt_no
         WHERE s.execution_id = ? AND o.stage_id = 'production'
           AND o.kind = 'receipt' AND o.item_key = 'singleton' ''',
      <Object?>[executionId],
    );
    var productionMalformed = productionRows.length != slots.length;
    final productionBySlot = <String>{};
    final productionCandidateBySlot = <String, String>{};
    for (final row in productionRows) {
      try {
        final slotId = row['trial_slot_id'] as String;
        final proseHash = row['prose_hash'] as String;
        final value = _jsonObject(
          row['value_json'],
          'production receipt observation',
        );
        final candidateHash = value['candidateHash'];
        final transactionHash = value['transactionEvidenceHash'];
        final executorReleaseHash = value['executorReleaseHash'];
        final storyRunId = value['storyRunId'];
        final attemptRunId = value['attemptRunId'];
        final receiptId = value['receiptId'];
        final generationBundleHash = value['generationBundleHash'];
        final authorityReceiptHash = value['authorityReceiptHash'];
        final authorityReleaseHash = value['authorityReleaseHash'];
        if (!productionBySlot.add(slotId) ||
            row['evaluation_bundle_hash'] != root['evaluation_bundle_hash'] ||
            proseHash != outcomeProseBySlot[slotId] ||
            value['schemaVersion'] != 'eval-production-receipt-v2' ||
            value['proseHash'] != proseHash ||
            storyRunId != row['attempt_run_id'] ||
            attemptRunId != row['attempt_run_id'] ||
            generationBundleHash != row['generation_bundle_hash'] ||
            executorReleaseHash !=
                AgentEvaluationProductionExecutorPolicy.releaseHash ||
            authorityReleaseHash !=
                AgentEvaluationProductionDatabaseAuthority.releaseHash ||
            authorityReceiptHash != row['authority_receipt_hash'] ||
            authorityReleaseHash != row['authority_release_hash'] ||
            storyRunId != row['authority_attempt_run_id'] ||
            _rawProductionDigest(candidateHash) !=
                row['authority_candidate_hash'] ||
            receiptId != row['authority_commit_receipt_id'] ||
            transactionHash != row['authority_transaction_evidence_hash'] ||
            proseHash != row['authority_prose_hash'] ||
            generationBundleHash != row['authority_generation_bundle_hash'] ||
            _rawProductionDigest(executorReleaseHash) !=
                row['authority_executor_release_hash'] ||
            receiptId is! String ||
            receiptId.trim().isEmpty ||
            candidateHash is! String ||
            transactionHash is! String) {
          productionMalformed = true;
          continue;
        }
        productionCandidateBySlot[slotId] =
            _rawProductionDigest(candidateHash) as String;
        AgentEvaluationReleaseStore._requireDigest(
          candidateHash.startsWith('sha256:')
              ? candidateHash.substring(7)
              : candidateHash,
          'productionCandidateHash',
        );
        AgentEvaluationReleaseStore._requireDigest(
          transactionHash,
          'productionTransactionEvidenceHash',
        );
        final expectedEvidenceHash = AgentEvaluationHashes.domainHash(
          'eval-production-receipt-observation-v2',
          <String, Object?>{
            'trialSlotId': slotId,
            'attemptNo': row['attempt_no'],
            'value': value,
          },
        );
        if (row['evidence_hash'] != expectedEvidenceHash) {
          productionMalformed = true;
        }
      } on Object {
        productionMalformed = true;
      }
    }
    if (productionMalformed) {
      throw const AgentEvaluationPromotionConflict(
        'release execution lacks authoritative production receipt evidence',
      );
    }

    final frozenVerifiers = _frozenVerifierIdentities(root['verifiers_json']);
    if (!frozenVerifiers.contains(
          AgentEvaluationProductionTransactionPolicy.releaseHash,
        ) ||
        !frozenVerifiers.containsAll(
          AgentEvaluationDeterministicQualityPolicy
              .verifierReleaseHashes
              .values,
        )) {
      throw const AgentEvaluationPromotionConflict(
        'evaluation bundle omitted required deterministic verifiers',
      );
    }
    final hardGateRows = db.select(
      '''SELECT o.* FROM eval_observations o
         JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
         WHERE s.execution_id = ? AND o.stage_id = 'hard-gate'
           AND o.item_key = 'singleton'
         ORDER BY o.trial_slot_id, o.kind''',
      <Object?>[executionId],
    );
    final safetyBySlot = <String, bool>{};
    final transactionBySlot = <String, bool>{};
    var hardGateMalformed = false;
    for (final row in hardGateRows) {
      try {
        final kind = row['kind'];
        if (kind != 'safety' && kind != 'transaction') {
          hardGateMalformed = true;
          continue;
        }
        final slotId = row['trial_slot_id'] as String;
        final proseHash = row['prose_hash'];
        final value = _jsonObject(row['value_json'], '$kind observation');
        final passed = value['passed'];
        final verifier = value['verifierReleaseHash'];
        final verifierEvidence = value['verifierEvidenceHash'];
        final expectedSchema = kind == 'safety'
            ? 'eval-safety-gate-v1'
            : 'eval-transaction-gate-v1';
        if (row['evaluation_bundle_hash'] != root['evaluation_bundle_hash'] ||
            proseHash != outcomeProseBySlot[slotId] ||
            value['schemaVersion'] != expectedSchema ||
            passed is! bool ||
            verifier is! String ||
            verifierEvidence is! String ||
            !frozenVerifiers.contains(verifier)) {
          hardGateMalformed = true;
          continue;
        }
        AgentEvaluationReleaseStore._requireDigest(
          verifierEvidence,
          'verifierEvidenceHash',
        );
        final expectedEvidenceHash = AgentEvaluationHashes.domainHash(
          'eval-hard-gate-observation-v1',
          <String, Object?>{
            'trialSlotId': slotId,
            'attemptNo': row['attempt_no'],
            'gateKind': kind,
            'proseHash': proseHash,
            'evaluationBundleHash': row['evaluation_bundle_hash'],
            'value': value,
          },
        );
        if (row['evidence_hash'] != expectedEvidenceHash) {
          hardGateMalformed = true;
          continue;
        }
        final target = kind == 'safety' ? safetyBySlot : transactionBySlot;
        if (target.containsKey(slotId)) hardGateMalformed = true;
        target[slotId] = passed;
      } on Object {
        hardGateMalformed = true;
      }
    }
    if (safetyBySlot.length != slots.length ||
        transactionBySlot.length != slots.length) {
      hardGateMalformed = true;
    }
    for (final row in qualityRows) {
      try {
        if (row['evaluation_bundle_hash'] != root['evaluation_bundle_hash'] ||
            row['prose_hash'] == null ||
            outcomeProseBySlot[row['trial_slot_id']] != row['prose_hash']) {
          qualityMalformed = true;
          continue;
        }
        final value = _jsonObject(row['value_json'], 'quality observation');
        final scoreMicros = value['scoreMicros'];
        if (value['schemaVersion'] != 'eval-quality-dimension-v1' ||
            scoreMicros is! int ||
            scoreMicros < 0 ||
            scoreMicros > 100000000 ||
            value['rubricReleaseHash'] != root['rubric_release_hash'] ||
            value['aggregatorReleaseHash'] != root['aggregator_release_hash']) {
          qualityMalformed = true;
          continue;
        }
        AgentEvaluationReleaseStore._requireDigest(
          value['judgePromptReleaseHash'] as String,
          'judgePromptReleaseHash',
        );
        AgentEvaluationReleaseStore._requireDigest(
          value['judgeModelRouteHash'] as String,
          'judgeModelRouteHash',
        );
        AgentEvaluationReleaseStore._requireDigest(
          value['externalEvaluationEvidenceHash'] as String,
          'externalEvaluationEvidenceHash',
        );
        AgentEvaluationReleaseStore._requireDigest(
          value['externalJudgeOutputHash'] as String,
          'externalJudgeOutputHash',
        );
        AgentEvaluationReleaseStore._requireDigest(
          value['deterministicQualityReceiptHash'] as String,
          'deterministicQualityReceiptHash',
        );
        final injectionReceipt =
            AgentEvaluationJudgeInjectionSafetyReceipt.fromJson(
              value['judgeInjectionSafetyReceipt'] as Map<String, Object?>,
            );
        if (!injectionReceipt.passed ||
            injectionReceipt.verifierReleaseHash !=
                AgentEvaluationJudgeInjectionSafetyVerifier.releaseHash ||
            injectionReceipt.evaluatedContentHash != row['prose_hash'] ||
            injectionReceipt.judgePromptReleaseHash !=
                value['judgePromptReleaseHash'] ||
            injectionReceipt.judgeModelRouteHash !=
                value['judgeModelRouteHash'] ||
            injectionReceipt.rubricReleaseHash != value['rubricReleaseHash'] ||
            injectionReceipt.aggregatorReleaseHash !=
                value['aggregatorReleaseHash']) {
          qualityMalformed = true;
          continue;
        }
        if (value['evaluatedContentHash'] != row['prose_hash']) {
          qualityMalformed = true;
          continue;
        }
        if (!judgeIdentities.promptHashes.contains(
              value['judgePromptReleaseHash'],
            ) ||
            !judgeIdentities.modelRouteHashes.contains(
              value['judgeModelRouteHash'],
            )) {
          qualityMalformed = true;
          continue;
        }
        final expectedEvidenceHash = AgentEvaluationHashes.domainHash(
          'eval-quality-dimension-observation-v1',
          <String, Object?>{
            'trialSlotId': row['trial_slot_id'],
            'attemptNo': row['attempt_no'],
            'dimensionId': row['item_key'],
            'proseHash': row['prose_hash'],
            'evaluationBundleHash': row['evaluation_bundle_hash'],
            'value': value,
          },
        );
        if (row['evidence_hash'] != expectedEvidenceHash) {
          qualityMalformed = true;
          continue;
        }
        final key = _qualityKey(
          row['trial_slot_id'] as String,
          row['item_key'] as String,
        );
        if (qualityBySlotDimension.containsKey(key)) qualityMalformed = true;
        qualityBySlotDimension[key] = scoreMicros / 1000000;
        final slotId = row['trial_slot_id'] as String;
        final qualityAttemptNo = row['attempt_no'] as int;
        final scores = qualityScoreMicrosBySlot.putIfAbsent(
          slotId,
          () => <String, int>{},
        );
        scores[row['item_key'] as String] = scoreMicros;
        final provenance = <String, String>{
          'judgePromptReleaseHash': value['judgePromptReleaseHash'] as String,
          'judgeModelRouteHash': value['judgeModelRouteHash'] as String,
          'rubricReleaseHash': value['rubricReleaseHash'] as String,
          'aggregatorReleaseHash': value['aggregatorReleaseHash'] as String,
          'evaluatedContentHash': value['evaluatedContentHash'] as String,
          'externalJudgeOutputHash': value['externalJudgeOutputHash'] as String,
          'externalEvaluationEvidenceHash':
              value['externalEvaluationEvidenceHash'] as String,
          'deterministicQualityReceiptHash':
              value['deterministicQualityReceiptHash'] as String,
          'judgeInjectionSafetyReceiptHash': injectionReceipt.receiptHash,
        };
        final existingProvenance = qualityProvenanceBySlot[slotId];
        if (existingProvenance != null &&
            AgentEvaluationHashes.canonicalJson(existingProvenance) !=
                AgentEvaluationHashes.canonicalJson(provenance)) {
          qualityMalformed = true;
        } else {
          qualityProvenanceBySlot[slotId] = provenance;
        }
        final existingAttempt = qualityAttemptBySlot[slotId];
        if (existingAttempt != null && existingAttempt != qualityAttemptNo) {
          qualityMalformed = true;
        } else {
          qualityAttemptBySlot[slotId] = qualityAttemptNo;
        }
      } on Object {
        qualityMalformed = true;
      }
    }
    for (final slot in slots) {
      final slotId = slot['trial_slot_id'] as String;
      final scores = qualityScoreMicrosBySlot[slotId];
      final provenance = qualityProvenanceBySlot[slotId];
      final qualityAttemptNo = qualityAttemptBySlot[slotId];
      if (scores == null ||
          provenance == null ||
          qualityAttemptNo == null ||
          scores.keys
              .toSet()
              .difference(AgentEvaluationQualityDimensions.values)
              .isNotEmpty ||
          AgentEvaluationQualityDimensions.values
              .difference(scores.keys.toSet())
              .isNotEmpty) {
        qualityMalformed = true;
        continue;
      }
      final expectedExternalEvidenceHash =
          AgentEvaluationQualityEvidence.calculateExternalEvidenceHash(
            scoreMicrosByDimension: scores,
            judgePromptReleaseHash: provenance['judgePromptReleaseHash']!,
            judgeModelRouteHash: provenance['judgeModelRouteHash']!,
            rubricReleaseHash: provenance['rubricReleaseHash']!,
            aggregatorReleaseHash: provenance['aggregatorReleaseHash']!,
            evaluatedContentHash: provenance['evaluatedContentHash']!,
            externalJudgeOutputHash: provenance['externalJudgeOutputHash']!,
            deterministicQualityReceiptHash:
                provenance['deterministicQualityReceiptHash'],
            judgeInjectionSafetyReceiptHash:
                provenance['judgeInjectionSafetyReceiptHash'],
          );
      if (provenance['externalEvaluationEvidenceHash'] !=
          expectedExternalEvidenceHash) {
        qualityMalformed = true;
      }
      final slotCell = cells.singleWhere(
        (cell) => cell['cell_id'] == slot['cell_id'],
      );
      final usage = completedContentUsage[slotId];
      final productionCandidate = productionCandidateBySlot[slotId];
      if (usage == null ||
          productionCandidate == null ||
          !_validateDeterministicQualityReceipt(
            db: db,
            executionId: executionId,
            slotId: slotId,
            attemptNo: qualityAttemptNo,
            scenarioReleaseHash: slotCell['scenario_release_hash'] as String,
            evaluationBundleHash: root['evaluation_bundle_hash'] as String,
            proseHash: outcomeProseBySlot[slotId]!,
            productionCandidateHash: productionCandidate,
            usage: usage,
            observedScores: scores,
            receiptHash: provenance['deterministicQualityReceiptHash']!,
          )) {
        qualityMalformed = true;
      }
    }

    final dimensions = <QualityDimensionComparison>[];
    final sortedDimensions =
        AgentEvaluationStandardGatePolicy.requiredQualityDimensions.toList()
          ..sort();
    for (final dimension in sortedDimensions) {
      final championValues = <double>[];
      final challengerValues = <double>[];
      final differences = <double>[];
      for (final pair in pairDefinitions) {
        final championSlot =
            slotsByKey[_slotKey(pair.championCellId, pair.trialNo)]!;
        final challengerSlot =
            slotsByKey[_slotKey(pair.challengerCellId, pair.trialNo)]!;
        final champion =
            qualityBySlotDimension[_qualityKey(
              championSlot['trial_slot_id'] as String,
              dimension,
            )];
        final challenger =
            qualityBySlotDimension[_qualityKey(
              challengerSlot['trial_slot_id'] as String,
              dimension,
            )];
        if (champion != null && challenger != null) {
          championValues.add(champion);
          challengerValues.add(challenger);
          differences.add(challenger - champion);
        }
      }
      final complete =
          !qualityMalformed && differences.length == pairDefinitions.length;
      dimensions.add(
        QualityDimensionComparison(
          dimensionId: dimension,
          pairCount: complete ? differences.length : 0,
          championMean: _mean(championValues),
          challengerMean: _mean(challengerValues),
          championP10: _nearestRank(championValues, 0.10),
          challengerP10: _nearestRank(challengerValues, 0.10),
          championMin: championValues.isEmpty
              ? double.nan
              : championValues.reduce(math.min),
          challengerMin: challengerValues.isEmpty
              ? double.nan
              : challengerValues.reduce(math.min),
          nonInferiorityLowerConfidenceBound: complete
              ? _lowerConfidenceBound(differences)
              : null,
        ),
      );
    }

    ReleaseArmEvidence armEvidence({
      required bool pass3,
      required bool safetyPassed,
      required bool transactionPassed,
      required List<TrialAttemptObservation> values,
    }) => ReleaseArmEvidence(
      pass3Passed: pass3,
      safetyPassed: !hardGateMalformed && safetyPassed,
      transactionPassed: !hardGateMalformed && transactionPassed,
      expectedAttemptCount: values.isEmpty || usageMalformed
          ? values.length + 1
          : values.length,
      attempts: values,
    );
    final result = const ChampionChallengerReleaseGate().evaluate(
      champion: armEvidence(
        pass3: armPass3(championCells.values),
        safetyPassed: pairDefinitions.every((pair) {
          final slot = slotsByKey[_slotKey(pair.championCellId, pair.trialNo)]!;
          return safetyBySlot[slot['trial_slot_id']] == true;
        }),
        transactionPassed: pairDefinitions.every((pair) {
          final slot = slotsByKey[_slotKey(pair.championCellId, pair.trialNo)]!;
          return transactionBySlot[slot['trial_slot_id']] == true;
        }),
        values: championAttempts,
      ),
      challenger: armEvidence(
        pass3: armPass3(challengerCells.values),
        safetyPassed: pairDefinitions.every((pair) {
          final slot =
              slotsByKey[_slotKey(pair.challengerCellId, pair.trialNo)]!;
          return safetyBySlot[slot['trial_slot_id']] == true;
        }),
        transactionPassed: pairDefinitions.every((pair) {
          final slot =
              slotsByKey[_slotKey(pair.challengerCellId, pair.trialNo)]!;
          return transactionBySlot[slot['trial_slot_id']] == true;
        }),
        values: challengerAttempts,
      ),
      qualityComparison: QualityComparisonEvidence(
        policy: QualityComparisonPolicy(
          requiredDimensions:
              AgentEvaluationStandardGatePolicy.requiredQualityDimensions,
          minimumPairCounts: <String, int>{
            for (final dimension in sortedDimensions)
              dimension: AgentEvaluationStandardGatePolicy.minimumQualityPairs,
          },
          nonInferiorityMargins: <String, double>{
            for (final dimension in sortedDimensions) dimension: 0,
          },
          familyWiseAlpha: AgentEvaluationStandardGatePolicy.familyWiseAlpha,
          multiplicityMethodIdentity:
              AgentEvaluationStandardGatePolicy.multiplicityMethodIdentity,
        ),
        dimensions: dimensions,
      ),
      performancePairs: performancePairs,
    );
    final sortedEvidenceRoots =
        slots.map((slot) => slot['sealed_evidence_hash'] as String).toList()
          ..sort();
    final projectionHash = AgentEvaluationHashes.domainHash(
      'eval-release-gate-projection-v1',
      <String, Object?>{
        'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
        'comparisonInputSetHash': root['input_set_hash'],
        'expectedPairSetHash': expectedPairSetHash,
        'sealedEvidenceRoots': sortedEvidenceRoots,
        'dispatchPlanHash': dispatch.planHash,
        'dispatchPolicyReleaseHash': dispatch.policyReleaseHash,
        'dispatchEventRootHash': dispatch.eventRootHash,
        'dispatchEventCount': dispatch.eventCount,
        'status': result.status.name,
        'reasons': result.reasons.map((reason) => reason.name).toList()..sort(),
        'championTotalCostMicrousd': result.championTotalCostMicrousd,
        'challengerTotalCostMicrousd': result.challengerTotalCostMicrousd,
        'performanceSampleCount': result.performanceSampleCount,
      },
    );
    return _DbGateAuthorityProjection(
      result: result,
      comparisonInputSetHash: root['input_set_hash'] as String,
      expectedPairSetHash: expectedPairSetHash,
      projectionHash: projectionHash,
      minimumQualityMeanDeltaMicros: _qualityMeanDeltaMicros(
        dimensions,
      )?.reduce(math.min),
      maximumQualityMeanDeltaMicros: _qualityMeanDeltaMicros(
        dimensions,
      )?.reduce(math.max),
    );
  }
}

final class _FrozenJudgeIdentities {
  const _FrozenJudgeIdentities({
    required this.promptHashes,
    required this.modelRouteHashes,
  });

  final Set<String> promptHashes;
  final Set<String> modelRouteHashes;
}

_FrozenJudgeIdentities _frozenJudgeIdentities(Object? source) {
  try {
    final value = _jsonObject(source, 'evaluation bundle judges');
    final prompts = value['judgePromptReleases'];
    final models = value['judgeModelRoutes'];
    if (prompts is! List ||
        models is! List ||
        prompts.isEmpty ||
        models.isEmpty) {
      throw const FormatException('frozen judge inventory is empty');
    }
    String rawDigest(Object? value) {
      if (value is! String) throw const FormatException('invalid judge digest');
      final raw = value.startsWith('sha256:') ? value.substring(7) : value;
      AgentEvaluationHashes.requireDigest(raw, 'judge identity');
      return raw;
    }

    final promptHashes = <String>{
      for (final prompt in prompts) rawDigest((prompt as Map)['contentHash']),
    };
    final modelHashes = <String>{for (final model in models) rawDigest(model)};
    if (promptHashes.length != prompts.length ||
        modelHashes.length != models.length) {
      throw const FormatException('duplicate frozen judge identity');
    }
    return _FrozenJudgeIdentities(
      promptHashes: promptHashes,
      modelRouteHashes: modelHashes,
    );
  } on Object {
    return const _FrozenJudgeIdentities(
      promptHashes: <String>{},
      modelRouteHashes: <String>{},
    );
  }
}

Set<String> _frozenVerifierIdentities(Object? source) {
  try {
    final values = jsonDecode(source as String);
    if (values is! List || values.isEmpty) return const <String>{};
    final result = <String>{};
    for (final value in values) {
      if (value is! String) return const <String>{};
      final raw = value.startsWith('sha256:') ? value.substring(7) : value;
      AgentEvaluationHashes.requireDigest(raw, 'verifier identity');
      if (!result.add(raw)) return const <String>{};
    }
    return result;
  } on Object {
    return const <String>{};
  }
}

final class _PairDefinition {
  const _PairDefinition({
    required this.pairId,
    required this.championCellId,
    required this.challengerCellId,
    required this.trialNo,
  });

  final String pairId;
  final String championCellId;
  final String challengerCellId;
  final int trialNo;
}

final class _GateUsage {
  const _GateUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.costMicrousd,
    required this.sutModelRouteHashes,
    required this.externalJudgeModelRouteHashes,
    required this.sutCallCount,
    required this.sutTokens,
    required this.externalJudgeCallCount,
    required this.externalJudgeTokens,
    required this.externalJudgeCostMicrousd,
  });

  final int promptTokens;
  final int completionTokens;
  final int costMicrousd;
  final Set<String> sutModelRouteHashes;
  final Set<String> externalJudgeModelRouteHashes;
  final int sutCallCount;
  final int sutTokens;
  final int externalJudgeCallCount;
  final int externalJudgeTokens;
  final int externalJudgeCostMicrousd;

  factory _GateUsage.fromJson(
    Map<String, Object?> value, {
    required String expectedPriceTableHash,
    required AgentEvaluationFrozenProviderPriceTable priceTable,
  }) {
    final prompt = value['promptTokens'];
    final completion = value['completionTokens'];
    final cost = value['costMicrousd'];
    final priceTableHash = value['priceTableHash'];
    final encodedCalls = value['providerCalls'];
    if (value['schemaVersion'] != 'eval-attempt-usage-v2' ||
        prompt is! int ||
        completion is! int ||
        cost is! int ||
        priceTableHash != expectedPriceTableHash ||
        encodedCalls is! List ||
        encodedCalls.isEmpty ||
        prompt < 0 ||
        completion < 0 ||
        cost < 0) {
      throw const AgentEvaluationPromotionConflict(
        'usage observation is malformed',
      );
    }
    final calls = <AgentEvaluationPricedProviderCall>[];
    for (final encoded in encodedCalls) {
      if (encoded is! Map) {
        throw const AgentEvaluationPromotionConflict(
          'priced provider call is malformed',
        );
      }
      final call = <String, Object?>{
        for (final entry in encoded.entries) entry.key.toString(): entry.value,
      };
      calls.add(
        AgentEvaluationPricedProviderCall(
          sequenceNo: call['sequenceNo'] as int,
          modelRouteHash: call['modelRouteHash'] as String,
          model: call['model'] as String,
          promptTokens: call['promptTokens'] as int,
          completionTokens: call['completionTokens'] as int,
          succeeded: call['succeeded'] as bool,
          costMicrousd: call['costMicrousd'] as int,
          purpose: call['purpose'] as String? ?? 'sut',
        ),
      );
    }
    for (final call in calls) {
      final recomputedCallCost = priceTable.costMicrousd(
        AgentEvaluationProviderCallEvidence(
          sequenceNo: call.sequenceNo,
          modelRouteHash: call.modelRouteHash,
          model: call.model,
          promptTokens: call.promptTokens,
          completionTokens: call.completionTokens,
          succeeded: call.succeeded,
        ),
      );
      if (recomputedCallCost != call.costMicrousd) {
        throw const AgentEvaluationPromotionConflict(
          'usage cost does not match the frozen price table',
        );
      }
    }
    final recomputed = AgentEvaluationAttemptUsage.frozen(
      priceTableHash: priceTableHash as String,
      providerCalls: calls,
    );
    if (recomputed.promptTokens != prompt ||
        recomputed.completionTokens != completion ||
        recomputed.costMicrousd != cost ||
        recomputed.providerCallSetHash != value['providerCallSetHash'] ||
        recomputed.costEvidenceHash != value['costEvidenceHash']) {
      throw const AgentEvaluationPromotionConflict(
        'usage price/call-set evidence cannot be recomputed',
      );
    }
    return _GateUsage(
      promptTokens: prompt,
      completionTokens: completion,
      costMicrousd: cost,
      sutModelRouteHashes: Set<String>.unmodifiable(
        calls
            .where((call) => call.purpose == 'sut')
            .map((call) => call.modelRouteHash),
      ),
      externalJudgeModelRouteHashes: Set<String>.unmodifiable(
        calls
            .where((call) => call.purpose == 'externalJudge')
            .map((call) => call.modelRouteHash),
      ),
      sutCallCount: calls.where((call) => call.purpose == 'sut').length,
      sutTokens: calls
          .where((call) => call.purpose == 'sut')
          .fold<int>(
            0,
            (sum, call) => sum + call.promptTokens + call.completionTokens,
          ),
      externalJudgeCallCount: calls
          .where((call) => call.purpose == 'externalJudge')
          .length,
      externalJudgeTokens: calls
          .where((call) => call.purpose == 'externalJudge')
          .fold<int>(
            0,
            (sum, call) => sum + call.promptTokens + call.completionTokens,
          ),
      externalJudgeCostMicrousd: calls
          .where((call) => call.purpose == 'externalJudge')
          .fold<int>(0, (sum, call) => sum + call.costMicrousd),
    );
  }
}

bool _validateDeterministicQualityReceipt({
  required Database db,
  required String executionId,
  required String slotId,
  required int attemptNo,
  required String scenarioReleaseHash,
  required String evaluationBundleHash,
  required String proseHash,
  required String productionCandidateHash,
  required _GateUsage usage,
  required Map<String, int> observedScores,
  required String receiptHash,
}) {
  try {
    final rows = db.select(
      '''SELECT * FROM eval_deterministic_quality_receipts
         WHERE receipt_hash = ? AND execution_id = ?
           AND trial_slot_id = ? AND attempt_no = ?''',
      <Object?>[receiptHash, executionId, slotId, attemptNo],
    );
    final scenarios = db.select(
      '''SELECT scenario_json FROM eval_scenarios
         WHERE scenario_release_hash = ?''',
      <Object?>[scenarioReleaseHash],
    );
    if (rows.length != 1 || scenarios.length != 1) return false;
    final row = rows.single;
    final inputs = _jsonObject(
      row['inputs_json'],
      'deterministic quality inputs',
    );
    final encodedScores = _jsonObject(
      row['scores_json'],
      'deterministic quality scores',
    );
    final scenario = _jsonObject(
      scenarios.single['scenario_json'],
      'deterministic quality scenario',
    );
    final proof = inputs['proof'];
    final characterEvidence = inputs['characterEvidence'];
    final canonEvidence = inputs['canonEvidence'];
    final polishCanonEvidence = inputs['polishCanonEvidence'];
    final storyMechanicsEvidence = inputs['storyMechanicsEvidence'];
    final deterministicGateFinalProseHash =
        inputs['deterministicGateFinalProseHash'];
    final deterministicGate = inputs['deterministicGate'];
    final finalProse = inputs['finalProse'];
    final usageInput = inputs['usage'];
    final mutations = scenario['adversarialMutations'];
    final referenceFacts = scenario['referenceFacts'];
    final maxBudget = scenario['maxBudget'];
    if (row['authority_release_hash'] !=
            AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash ||
        row['evaluation_bundle_hash'] != evaluationBundleHash ||
        row['prose_hash'] != proseHash ||
        inputs['schemaVersion'] != 'eval-deterministic-quality-inputs-v4' ||
        inputs['scenarioReleaseHash'] != scenarioReleaseHash ||
        proof is! Map ||
        characterEvidence is! Map ||
        canonEvidence is! Map ||
        polishCanonEvidence is! Map ||
        storyMechanicsEvidence is! Map ||
        !_isGateDigest(deterministicGateFinalProseHash) ||
        deterministicGate is! Map ||
        finalProse is! String ||
        finalProse.trim().isEmpty ||
        AgentEvaluationHashes.domainHash('eval-trial-content-v1', finalProse) !=
            row['prose_hash'] ||
        usageInput is! Map ||
        mutations is! List ||
        referenceFacts is! Map ||
        maxBudget is! Map) {
      return false;
    }
    final characterScore = _receiptCoverageScore(
      characterEvidence,
      requiredKey: 'requiredNameHashes',
      matchedKey: 'matchedNameHashes',
      rootKey: 'structuredStateRootHash',
    );
    final canonScore = _receiptCoverageScore(
      canonEvidence,
      requiredKey: 'requiredRootSourceIdHashes',
      matchedKey: 'matchedRootSourceIdHashes',
      rootKey: 'committedProvenanceRootHash',
    );
    if (characterScore == null || canonScore == null) return false;
    final proofMap = <String, Object?>{
      for (final entry in proof.entries) entry.key.toString(): entry.value,
    };
    if (_rawProductionDigest(proofMap['candidateHash']) !=
            productionCandidateHash ||
        !_isGateDigest(proofMap['deterministicGateEvidenceHash']) ||
        !_isGateDigest(proofMap['finalCouncilEvidenceHash']) ||
        !_isGateDigest(proofMap['qualityEvidenceHash'])) {
      return false;
    }
    if (!_validateDeterministicStoryReceiptEvidence(
      encodedPolishCanonEvidence: polishCanonEvidence,
      encodedStoryMechanicsEvidence: storyMechanicsEvidence,
      gateFinalProseHash: deterministicGateFinalProseHash as String,
      deterministicGateEvidenceHash:
          proofMap['deterministicGateEvidenceHash'] as String,
      encodedDeterministicGate: deterministicGate,
      finalProse: finalProse,
    )) {
      return false;
    }
    final sortedMutations = mutations.map((value) => value as String).toList()
      ..sort();
    if (AgentEvaluationHashes.canonicalJson(inputs['adversarialMutations']) !=
        AgentEvaluationHashes.canonicalJson(sortedMutations)) {
      return false;
    }
    final recoverySensitive = sortedMutations.any((mutation) {
      final normalized = mutation.toLowerCase();
      return normalized.contains('crash') ||
          normalized.contains('recover') ||
          normalized.contains('lease');
    });
    final recoveryRows = recoverySensitive
        ? db.select(
            '''SELECT event_hash FROM eval_dispatch_events
               WHERE execution_id = ? AND trial_slot_id = ?
                 AND event_type IN ('expired', 'reclaimed')
               ORDER BY event_ordinal''',
            <Object?>[executionId, slotId],
          )
        : const <Row>[];
    final recoveryHashes = <Object?>[
      for (final event in recoveryRows) event['event_hash'],
    ];
    if (AgentEvaluationHashes.canonicalJson(inputs['recoveryEventHashes']) !=
        AgentEvaluationHashes.canonicalJson(recoveryHashes)) {
      return false;
    }
    final maxCalls = maxBudget['calls'];
    final maxTokens = maxBudget['maxTokens'] ?? maxBudget['tokens'];
    if (maxCalls is! int ||
        maxTokens is! int ||
        maxCalls <= 0 ||
        maxTokens <= 0 ||
        usageInput['calls'] != usage.sutCallCount ||
        usageInput['tokens'] != usage.sutTokens ||
        usageInput['maxCalls'] != maxCalls ||
        usageInput['maxTokens'] != maxTokens ||
        inputs['referenceFactsHash'] !=
            AgentEvaluationHashes.domainHash(
              'eval-quality-reference-facts-v1',
              referenceFacts,
            ) ||
        AgentEvaluationHashes.canonicalJson(inputs['verifierReleaseHashes']) !=
            AgentEvaluationHashes.canonicalJson(
              AgentEvaluationDeterministicQualityPolicy.verifierReleaseHashes,
            )) {
      return false;
    }
    final utilization = math.max(
      usage.sutCallCount / maxCalls,
      usage.sutTokens / maxTokens,
    );
    final robustness = sortedMutations.isEmpty
        ? 0
        : recoverySensitive && recoveryRows.isEmpty
        ? 0
        : 100000000;
    final expectedScores = <String, int>{
      'characterConsistency': characterScore,
      'canonMemory': canonScore,
      'robustness': robustness,
      'efficiency': ((100 - 50 * utilization).clamp(0, 100) * 1000000).round(),
    };
    if (AgentEvaluationHashes.canonicalJson(encodedScores) !=
            AgentEvaluationHashes.canonicalJson(expectedScores) ||
        expectedScores.entries.any(
          (entry) => observedScores[entry.key] != entry.value,
        )) {
      return false;
    }
    final receiptValue = <String, Object?>{
      'authorityReleaseHash': row['authority_release_hash'],
      'executionId': executionId,
      'trialSlotId': slotId,
      'attemptNo': attemptNo,
      'evaluationBundleHash': evaluationBundleHash,
      'proseHash': proseHash,
      'inputs': inputs,
      'scores': expectedScores,
    };
    return AgentEvaluationHashes.domainHash(
          'eval-deterministic-quality-receipt-v2',
          receiptValue,
        ) ==
        receiptHash;
  } on Object {
    return false;
  }
}

bool _validateDeterministicStoryReceiptEvidence({
  required Map<dynamic, dynamic> encodedPolishCanonEvidence,
  required Map<dynamic, dynamic> encodedStoryMechanicsEvidence,
  required String gateFinalProseHash,
  required String deterministicGateEvidenceHash,
  required Map<dynamic, dynamic> encodedDeterministicGate,
  required String finalProse,
}) {
  return StoryMechanicsGateAuthority.verifyReceipt(
    encodedPolishCanonEvidence: encodedPolishCanonEvidence,
    encodedStoryMechanicsEvidence: encodedStoryMechanicsEvidence,
    gateFinalProseHash: gateFinalProseHash,
    deterministicGateEvidenceHash: deterministicGateEvidenceHash,
    encodedDeterministicGate: encodedDeterministicGate,
    finalProse: finalProse,
  );
}

bool _isGateDigest(Object? value) =>
    value is String && RegExp(r'^(sha256:)?[a-f0-9]{64}$').hasMatch(value);

int? _receiptCoverageScore(
  Map<dynamic, dynamic> evidence, {
  required String requiredKey,
  required String matchedKey,
  required String rootKey,
}) {
  try {
    final required = (evidence[requiredKey] as List).cast<String>();
    final matched = (evidence[matchedKey] as List).cast<String>();
    final requiredSet = required.toSet();
    final matchedSet = matched.toSet();
    if (!_isGateDigest(evidence[rootKey]) ||
        requiredSet.length != required.length ||
        matchedSet.length != matched.length ||
        !requiredSet.containsAll(matchedSet) ||
        required.any((value) => !_isGateDigest(value)) ||
        matched.any((value) => !_isGateDigest(value))) {
      return null;
    }
    return required.isEmpty
        ? 0
        : (matched.length * 100000000 / required.length).round();
  } on Object {
    return null;
  }
}

Map<String, Row> _cellsForArm(List<Row> cells, String bundleHash) {
  final result = <String, Row>{};
  for (final cell in cells.where(
    (row) => row['generation_bundle_hash'] == bundleHash,
  )) {
    final logicalKey = AgentEvaluationHashes.domainHash(
      'eval-release-logical-cell-v1',
      <Object?>[
        cell['sut_model_route_hash'],
        cell['scenario_release_hash'],
        cell['decoding_config_hash'],
      ],
    );
    if (result.containsKey(logicalKey)) {
      throw const AgentEvaluationPromotionConflict(
        'release arm has a duplicate logical cell',
      );
    }
    result[logicalKey] = cell;
  }
  return result;
}

Map<String, Object?> _jsonObject(Object? source, String label) {
  try {
    final decoded = jsonDecode(source as String);
    if (decoded is Map<String, Object?>) return decoded;
  } on Object {
    // Normalized below.
  }
  throw AgentEvaluationPromotionConflict('$label is not a JSON object');
}

String _slotKey(String cellId, int trialNo) => '$cellId/$trialNo';
String _attemptKey(String slotId, int attemptNo) => '$slotId/$attemptNo';
String _qualityKey(String slotId, String dimension) => '$slotId/$dimension';

bool _sameKeySet(Iterable<String> left, Iterable<String> right) {
  final leftSet = left.toSet();
  final rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

double _mean(List<double> values) => values.isEmpty
    ? double.nan
    : values.reduce((left, right) => left + right) / values.length;

List<int>? _qualityMeanDeltaMicros(
  List<QualityDimensionComparison> dimensions,
) {
  final deltas = <int>[];
  for (final dimension in dimensions) {
    final delta = dimension.challengerMean - dimension.championMean;
    if (!delta.isFinite) return null;
    deltas.add((delta * 1000000).round());
  }
  return deltas.isEmpty ? null : deltas;
}

double _nearestRank(List<double> values, double percentile) {
  if (values.isEmpty) return double.nan;
  final sorted = values.toList()..sort();
  final rank = math.max(1, (sorted.length * percentile).ceil());
  return sorted[rank - 1];
}

double _lowerConfidenceBound(List<double> differences) {
  final mean = _mean(differences);
  if (differences.length < 2) return mean;
  final squared = differences.fold<double>(
    0,
    (total, value) => total + math.pow(value - mean, 2).toDouble(),
  );
  final sampleVariance = squared / (differences.length - 1);
  final standardError = math.sqrt(sampleVariance / differences.length);
  return mean - AgentEvaluationStandardGatePolicy.confidenceZ * standardError;
}
