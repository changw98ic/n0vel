import 'dart:convert';
import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_response_cache.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_observation_codec.dart';
import 'agent_evaluation_pass3_projection.dart';
import 'agent_evaluation_production_authorities.dart';
import 'agent_evaluation_release_store.dart';
import 'agent_evaluation_typed_evidence.dart';
import '../story_mechanics_gate_authority.dart';

class AgentEvaluationReportException implements Exception {
  const AgentEvaluationReportException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationReportException: $message';
}

class AgentEvaluationReportPolicy {
  const AgentEvaluationReportPolicy({
    required this.aggregatorReleaseHash,
    this.minimumDistributionSamples = 20,
    this.maximumObservationBytes = 65536,
  });

  final String aggregatorReleaseHash;
  final int minimumDistributionSamples;
  final int maximumObservationBytes;
}

class AgentEvaluationPublicReport {
  AgentEvaluationPublicReport._({
    required Map<String, Object?> payload,
    required this.reportHash,
  }) : _payload = Map<String, Object?>.unmodifiable(payload);

  final Map<String, Object?> _payload;
  final String reportHash;

  Map<String, Object?> toJson() => <String, Object?>{
    ..._payload,
    'reportHash': reportHash,
  };

  String toJsonText() => AgentEvaluationHashes.canonicalJson(toJson());

  String toMarkdown() {
    final counts = _payload['counts']! as Map<String, Object?>;
    final rates = _payload['rates']! as Map<String, Object?>;
    final resources = _payload['resources']! as Map<String, Object?>;
    return <String>[
      '# Agent Evaluation Report',
      '',
      '- Execution: `${_payload['executionId']}`',
      '- Report hash: `$reportHash`',
      '- Attempted trials: ${counts['attempted']}',
      '- Completed trials: ${counts['completed']}',
      '- Transport failures: ${counts['transportFail']}',
      '- Completion rate: ${rates['completionRate']}',
      '- Pass rate: ${rates['passRate']}',
      '- Pass³ rate: ${rates['pass3Rate']}',
      '- Tokens (all attempts): ${resources['tokens']}',
      '- Latency ms (all attempts): ${resources['latencyMs']}',
      '- Cost microusd (all attempts): ${resources['costMicrousd']}',
    ].join('\n');
  }

  static bool verifyJsonText(String source) {
    try {
      if (utf8.encode(source).length > 1024 * 1024) return false;
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?>) return false;
      final reportHash = decoded.remove('reportHash');
      if (reportHash is! String) return false;
      _validatePayload(decoded);
      AgentEvaluationObservationCodecRegistry.rejectSecretOrTainted(decoded);
      final computed = AgentEvaluationHashes.domainHash(
        'eval-public-report-v1',
        decoded,
      );
      return computed == reportHash;
    } on Object {
      return false;
    }
  }

  static void _validatePayload(Map<String, Object?> value) {
    _requireExactKeys(value, const <String>{
      'schemaVersion',
      'executionId',
      'experimentId',
      'counts',
      'rates',
      'pass3',
      'qualityDimensions',
      'resources',
      'failures',
      'inputSetHash',
      'expectedSetHash',
      'aggregatorReleaseHash',
      'minimumDistributionSamples',
    });
    if (value['schemaVersion'] != 'agent-evaluation-report-v1' ||
        !_boundedString(value['executionId']) ||
        !_boundedString(value['experimentId']) ||
        value['minimumDistributionSamples'] is! int ||
        (value['minimumDistributionSamples']! as int) <= 0) {
      throw const FormatException('public report identity is invalid');
    }
    for (final key in <String>[
      'inputSetHash',
      'expectedSetHash',
      'aggregatorReleaseHash',
    ]) {
      if (!_digest(value[key])) {
        throw const FormatException('public report digest is invalid');
      }
    }
    final counts = _object(value['counts']);
    _requireExactKeys(counts, const <String>{
      'attempted',
      'completed',
      'transportFail',
      'providerAttempts',
    });
    if (counts.values.any((item) => item is! int || item < 0)) {
      throw const FormatException('public report counts are invalid');
    }
    final rates = _object(value['rates']);
    _requireExactKeys(rates, const <String>{
      'completionRate',
      'passRate',
      'pass3Rate',
    });
    if (rates.values.any((item) => !_unitNumber(item))) {
      throw const FormatException('public report rates are invalid');
    }
    final pass3 = _object(value['pass3']);
    if (pass3.entries.any(
      (entry) => !_digest(entry.key) || entry.value is! bool,
    )) {
      throw const FormatException('public report Pass3 map is invalid');
    }
    final quality = _object(value['qualityDimensions']);
    if (quality.keys
        .toSet()
        .difference(AgentEvaluationQualityDimensions.values)
        .isNotEmpty) {
      throw const FormatException('public report quality dimension is invalid');
    }
    for (final distribution in quality.values) {
      _validateDistribution(_object(distribution));
    }
    final resources = _object(value['resources']);
    _requireExactKeys(resources, const <String>{
      'tokens',
      'latencyMs',
      'costMicrousd',
    });
    if (resources.values.any((item) => item is! int || item < 0)) {
      throw const FormatException('public report resources are invalid');
    }
    final failures = _object(value['failures']);
    _requireExactKeys(failures, const <String>{'primary', 'multiLabel'});
    for (final map in <Map<String, Object?>>[
      _object(failures['primary']),
      _object(failures['multiLabel']),
    ]) {
      if (map.entries.any(
        (entry) =>
            !_code(entry.key) || entry.value is! int || entry.value! as int < 0,
      )) {
        throw const FormatException('public report failure map is invalid');
      }
    }
  }

  static void _validateDistribution(Map<String, Object?> value) {
    final insufficient = value['evidenceInsufficient'];
    final keys = insufficient == true
        ? const <String>{'samples', 'mean', 'min', 'evidenceInsufficient'}
        : const <String>{
            'samples',
            'mean',
            'min',
            'evidenceInsufficient',
            'p10',
            'p50',
            'p95',
            'ci95',
          };
    _requireExactKeys(value, keys);
    if (insufficient is! bool ||
        value['samples'] is! int ||
        (value['samples']! as int) <= 0 ||
        !<String>['mean', 'min'].every((key) => _score(value[key]))) {
      throw const FormatException('public report distribution is invalid');
    }
    if (!insufficient) {
      if (!<String>['p10', 'p50', 'p95'].every((key) => _score(value[key])) ||
          value['ci95'] is! List<Object?> ||
          (value['ci95']! as List<Object?>).length != 2 ||
          (value['ci95']! as List<Object?>).any(
            (item) => item is! num || !item.isFinite,
          )) {
        throw const FormatException('public report distribution is invalid');
      }
    }
  }

  static Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('public report field is not an object');
    }
    return value;
  }

  static void _requireExactKeys(
    Map<String, Object?> value,
    Set<String> expected,
  ) {
    if (value.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('public report fields are invalid');
    }
  }

  static bool _boundedString(Object? value) =>
      value is String && value.isNotEmpty && value.length <= 256;
  static bool _digest(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
  static bool _code(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 128 &&
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);
  static bool _unitNumber(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 1;
  static bool _score(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 100;
}

class AgentEvaluationReportBuilder {
  AgentEvaluationReportBuilder({required this.db});

  final Database db;

  static const Set<String> _allowedQualityDimensions = <String>{
    'proseReadability',
    'plotCausality',
    'characterConsistency',
    'canonMemory',
    'robustness',
    'efficiency',
  };

  AgentEvaluationPublicReport build({
    required String executionId,
    required AgentEvaluationReportPolicy policy,
  }) {
    if (executionId.trim().isEmpty ||
        policy.minimumDistributionSamples <= 0 ||
        policy.maximumObservationBytes <= 0) {
      throw const AgentEvaluationReportException('invalid report request');
    }
    AgentEvaluationHashes.requireDigest(
      policy.aggregatorReleaseHash,
      'aggregatorReleaseHash',
    );
    final executionRows = db.select(
      '''SELECT x.*, e.experiment_id, e.trials_per_cell,
           e.evaluation_bundle_hash,
           e.expected_cell_set_hash AS manifest_cell_hash,
           e.expected_slot_set_hash AS manifest_slot_hash
         FROM eval_executions x
         JOIN eval_experiments e ON e.experiment_id = x.experiment_id
         WHERE x.execution_id = ?''',
      <Object?>[executionId],
    );
    if (executionRows.length != 1) {
      throw const AgentEvaluationReportException('execution not found');
    }
    final execution = executionRows.single;
    final trialsPerCell = execution['trials_per_cell'] as int;
    final cellRows = db.select(
      '''SELECT c.*, ec.ordinal FROM eval_experiment_cells ec
         JOIN eval_cells c ON c.cell_id = ec.cell_id
         WHERE ec.experiment_id = ? ORDER BY ec.ordinal''',
      <Object?>[execution['experiment_id']],
    );
    if (cellRows.isEmpty) {
      throw const AgentEvaluationReportException('experiment has no cells');
    }
    final cellIds = <String>[];
    for (var index = 0; index < cellRows.length; index += 1) {
      final row = cellRows[index];
      final canonical = AgentEvaluationReleaseStore.canonicalCellId(
        generationBundleHash: row['generation_bundle_hash'] as String,
        sutModelRouteHash: row['sut_model_route_hash'] as String,
        scenarioReleaseHash: row['scenario_release_hash'] as String,
        decodingConfigHash: row['decoding_config_hash'] as String,
      );
      if (row['ordinal'] != index || row['cell_id'] != canonical) {
        throw const AgentEvaluationReportException(
          'experiment cell set is non-canonical',
        );
      }
      cellIds.add(canonical);
    }
    final sortedCellIds = cellIds.toList()..sort();
    final expectedCellHash = AgentEvaluationReleaseStore.canonicalCellSetHash(
      sortedCellIds,
    );
    final expectedSlotHash = AgentEvaluationReleaseStore.canonicalSlotSetHash(
      sortedCellIds,
      trialsPerCell,
    );
    if (execution['manifest_cell_hash'] != expectedCellHash ||
        execution['expected_cell_set_hash'] != expectedCellHash ||
        execution['manifest_slot_hash'] != expectedSlotHash ||
        execution['expected_slot_set_hash'] != expectedSlotHash) {
      throw const AgentEvaluationReportException(
        'execution expected-set hashes are inconsistent',
      );
    }
    final executionCells = db.select(
      '''SELECT cell_id, ordinal FROM eval_execution_cells
         WHERE execution_id = ? ORDER BY ordinal''',
      <Object?>[executionId],
    );
    if (executionCells.length != sortedCellIds.length) {
      throw const AgentEvaluationReportException(
        'execution cell membership is incomplete',
      );
    }
    for (var index = 0; index < sortedCellIds.length; index += 1) {
      if (executionCells[index]['ordinal'] != index ||
          executionCells[index]['cell_id'] != sortedCellIds[index]) {
        throw const AgentEvaluationReportException(
          'execution cell membership is polluted',
        );
      }
    }

    final slots = db.select(
      '''SELECT trial_slot_id, cell_id, trial_no, status, result,
           sealed_evidence_hash FROM eval_trial_slots
         WHERE execution_id = ? ORDER BY cell_id, trial_no''',
      <Object?>[executionId],
    );
    final expectedSlotCount = sortedCellIds.length * trialsPerCell;
    if (slots.length != expectedSlotCount) {
      throw const AgentEvaluationReportException(
        'canonical slot set is missing or duplicated',
      );
    }
    var slotIndex = 0;
    var passCount = 0;
    final pass3ByCell = <String, bool>{};
    final pass3Reader = AgentEvaluationPass3ProjectionReader(db);
    for (final cellId in sortedCellIds) {
      for (var trialNo = 1; trialNo <= trialsPerCell; trialNo += 1) {
        final slot = slots[slotIndex++];
        final canonicalSlotId =
            AgentEvaluationReleaseStore.canonicalTrialSlotId(
              executionId: executionId,
              cellId: cellId,
              trialNo: trialNo,
            );
        if (slot['cell_id'] != cellId ||
            slot['trial_no'] != trialNo ||
            slot['trial_slot_id'] != canonicalSlotId ||
            slot['status'] != 'sealed' ||
            slot['result'] == null ||
            slot['sealed_evidence_hash'] == null) {
          throw const AgentEvaluationReportException(
            'every canonical slot must be sealed before reporting',
          );
        }
        final passed = slot['result'] == 'pass';
        if (passed) passCount += 1;
      }
      final projection = pass3Reader.readCell(
        executionId: executionId,
        cellId: cellId,
        evaluationBundleHash: execution['evaluation_bundle_hash'] as String,
      );
      pass3ByCell[cellId] =
          trialsPerCell == 3 &&
          projection.allSlotsSealed &&
          projection.result.passed;
    }

    final attempts = db.select(
      '''SELECT a.* FROM eval_trial_attempts a
         JOIN eval_trial_slots s ON s.trial_slot_id = a.trial_slot_id
         WHERE s.execution_id = ? ORDER BY a.trial_slot_id, a.attempt_no''',
      <Object?>[executionId],
    );
    final observations = db.select(
      '''SELECT o.* FROM eval_observations o
         JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
         WHERE s.execution_id = ?
         ORDER BY o.trial_slot_id, o.sequence_no''',
      <Object?>[executionId],
    );
    final decodedObservations = <_DecodedObservation>[];
    for (final observation in observations) {
      decodedObservations.add(_decodeObservation(observation, policy));
    }
    final cacheReceiptsByAttempt = <String, List<AppLlmCacheReceipt>>{};
    final hasCacheTable = db
        .select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'eval_cache_receipts'",
        )
        .isNotEmpty;
    if (hasCacheTable) {
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
        final receipts = cacheReceiptsByAttempt.putIfAbsent(
          key,
          () => <AppLlmCacheReceipt>[],
        );
        receipts.add(receipt);
      }
    }
    final usageByAttempt = <String, _Usage>{};
    final qualityValues = <String, List<double>>{};
    final primaryFailures = <String, int>{};
    final multiLabelFailures = <String, int>{};
    for (final observation in decodedObservations) {
      switch (observation.type) {
        case 'outcome/comparison':
          final key = '${observation.trialSlotId}/${observation.attemptNo}';
          final crossHits =
              (cacheReceiptsByAttempt[key] ?? const <AppLlmCacheReceipt>[])
                  .where(
                    (receipt) =>
                        receipt.hit &&
                        receipt.sourceTrialSlotId != receipt.currentTrialSlotId,
                  )
                  .toList(growable: false);
          if (crossHits.isEmpty) {
            if (observation.value['independence'] != 'independent' ||
                observation.value['cacheSourceTrialSlotId'] != null) {
              throw const AgentEvaluationReportException(
                'outcome cache independence contradicts durable receipts',
              );
            }
          } else if (observation.value['independence'] != 'nonIndependent' ||
              observation.value['cacheSourceTrialSlotId'] !=
                  crossHits.first.sourceTrialSlotId) {
            throw const AgentEvaluationReportException(
              'outcome cache source contradicts durable receipts',
            );
          }
        case 'performance/usage':
          final key = '${observation.trialSlotId}/${observation.attemptNo}';
          if (usageByAttempt.containsKey(key)) {
            throw const AgentEvaluationReportException(
              'attempt has duplicate usage observations',
            );
          }
          usageByAttempt[key] = _Usage.fromJson(observation.value);
        case 'quality/dimension':
          final injectionReceiptValue =
              observation.value['judgeInjectionSafetyReceipt'];
          if (injectionReceiptValue is! Map<String, Object?>) {
            throw const AgentEvaluationReportException(
              'quality observation omitted judge injection safety receipt',
            );
          }
          final injectionReceipt =
              AgentEvaluationJudgeInjectionSafetyReceipt.fromJson(
                injectionReceiptValue,
              );
          if (!injectionReceipt.passed) {
            throw const AgentEvaluationReportException(
              'quality observation has invalid judge injection safety receipt',
            );
          }
          if (!_allowedQualityDimensions.contains(observation.itemKey)) {
            throw AgentEvaluationReportException(
              'unknown quality dimension: ${observation.itemKey}',
            );
          }
          final scoreMicros = observation.value['scoreMicros'];
          final score = scoreMicros is int
              ? scoreMicros / 1000000
              : observation.value['score'];
          if (score is! num || !score.isFinite || score < 0 || score > 100) {
            throw const AgentEvaluationReportException(
              'quality score must be finite and between 0 and 100',
            );
          }
          qualityValues
              .putIfAbsent(observation.itemKey, () => <double>[])
              .add(score.toDouble());
          final deterministicReceiptHash =
              observation.value['deterministicQualityReceiptHash'];
          if (deterministicReceiptHash is! String) {
            throw const AgentEvaluationReportException(
              'quality observation omitted deterministic quality receipt',
            );
          }
          _verifyDeterministicStoryReceipt(
            db,
            deterministicReceiptHash,
            executionId: executionId,
            trialSlotId: observation.trialSlotId,
            attemptNo: observation.attemptNo,
            evaluationBundleHash: execution['evaluation_bundle_hash'] as String,
            observationProseHash: observation.proseHash,
            dimensionId: observation.itemKey,
            observedScoreMicros: scoreMicros as int,
          );
        case 'failure/taxonomy':
          final primary = observation.value['primary'];
          final labels = observation.value['labels'];
          if (primary is! String || labels is! List<Object?>) {
            throw const AgentEvaluationReportException(
              'failure taxonomy observation is malformed',
            );
          }
          primaryFailures.update(
            primary,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          for (final label in labels) {
            if (label is! String) {
              throw const AgentEvaluationReportException(
                'failure taxonomy label must be a string',
              );
            }
            multiLabelFailures.update(
              label,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
        case 'hard-gate/safety':
        case 'hard-gate/transaction':
          final expectedSchema = observation.type == 'hard-gate/safety'
              ? 'eval-safety-gate-v1'
              : 'eval-transaction-gate-v1';
          if (observation.value['schemaVersion'] != expectedSchema ||
              observation.value['passed'] is! bool ||
              observation.value['verifierReleaseHash'] is! String ||
              observation.value['verifierEvidenceHash'] is! String) {
            throw const AgentEvaluationReportException(
              'hard-gate observation is malformed',
            );
          }
          break;
        case 'production/receipt':
          break;
      }
    }
    var totalTokens = 0;
    var totalLatencyMs = 0;
    var totalCostMicrousd = 0;
    var transportFail = 0;
    for (final attempt in attempts) {
      final key = '${attempt['trial_slot_id']}/${attempt['attempt_no']}';
      final usage = usageByAttempt[key];
      if (usage == null) {
        throw AgentEvaluationReportException(
          'attempt is missing typed usage evidence: $key',
        );
      }
      totalTokens += usage.tokens;
      final startedAtMs = attempt['started_at_ms'];
      final finishedAtMs = attempt['finished_at_ms'];
      final derivedLatency =
          startedAtMs is int &&
              finishedAtMs is int &&
              finishedAtMs >= startedAtMs
          ? finishedAtMs - startedAtMs
          : null;
      final latencyMs = usage.latencyMs ?? derivedLatency;
      if (latencyMs == null) {
        throw AgentEvaluationReportException(
          'attempt has no trustworthy latency evidence: $key',
        );
      }
      totalLatencyMs += latencyMs;
      totalCostMicrousd += usage.costMicrousd;
      if (attempt['kind'] == 'transport' && attempt['status'] == 'failed') {
        transportFail += 1;
      }
    }
    if (usageByAttempt.length != attempts.length) {
      throw const AgentEvaluationReportException(
        'usage evidence references an unknown or duplicate attempt',
      );
    }
    final qualityReport = <String, Object?>{};
    for (final entry in qualityValues.entries) {
      qualityReport[entry.key] = _distribution(
        entry.value,
        minimumSamples: policy.minimumDistributionSamples,
      );
    }
    final pass3Count = pass3ByCell.values.where((passed) => passed).length;
    final completionRate = slots.length / expectedSlotCount;
    final passRate = passCount / expectedSlotCount;
    final pass3Rate = pass3ByCell.isEmpty
        ? 0.0
        : pass3Count / pass3ByCell.length;
    final inputSetHash = AgentEvaluationReleaseStore(
      db: db,
    ).computeInputSetHash(executionId);
    final payload = <String, Object?>{
      'schemaVersion': 'agent-evaluation-report-v1',
      'executionId': executionId,
      'experimentId': execution['experiment_id'],
      'counts': <String, Object?>{
        'attempted': expectedSlotCount,
        'completed': slots.length,
        'transportFail': transportFail,
        'providerAttempts': attempts.length,
      },
      'rates': <String, Object?>{
        'completionRate': completionRate,
        'passRate': passRate,
        'pass3Rate': pass3Rate,
      },
      'pass3': pass3ByCell,
      'qualityDimensions': qualityReport,
      'resources': <String, Object?>{
        'tokens': totalTokens,
        'latencyMs': totalLatencyMs,
        'costMicrousd': totalCostMicrousd,
      },
      'failures': <String, Object?>{
        'primary': primaryFailures,
        'multiLabel': multiLabelFailures,
      },
      'inputSetHash': inputSetHash,
      'expectedSetHash': expectedSlotHash,
      'aggregatorReleaseHash': policy.aggregatorReleaseHash,
      'minimumDistributionSamples': policy.minimumDistributionSamples,
    };
    final reportHash = AgentEvaluationHashes.domainHash(
      'eval-public-report-v1',
      payload,
    );
    return AgentEvaluationPublicReport._(
      payload: payload,
      reportHash: reportHash,
    );
  }

  void _verifyDeterministicStoryReceipt(
    Database db,
    String receiptHash, {
    required String executionId,
    required String trialSlotId,
    required int attemptNo,
    required String evaluationBundleHash,
    required String? observationProseHash,
    required String dimensionId,
    required int observedScoreMicros,
  }) {
    try {
      final rows = db.select(
        '''SELECT * FROM eval_deterministic_quality_receipts
           WHERE receipt_hash = ?''',
        <Object?>[receiptHash],
      );
      if (rows.length != 1) {
        throw const FormatException('missing deterministic receipt');
      }
      final row = rows.single;
      final inputs = jsonDecode(row['inputs_json'] as String);
      final scores = jsonDecode(row['scores_json'] as String);
      if (inputs is! Map ||
          scores is! Map ||
          row['authority_release_hash'] !=
              AgentEvaluationDeterministicQualityPolicy.authorityReleaseHash ||
          row['execution_id'] != executionId ||
          row['trial_slot_id'] != trialSlotId ||
          row['attempt_no'] != attemptNo ||
          row['evaluation_bundle_hash'] != evaluationBundleHash ||
          observationProseHash == null ||
          row['prose_hash'] != observationProseHash ||
          inputs['schemaVersion'] != 'eval-deterministic-quality-inputs-v4' ||
          inputs['proof'] is! Map ||
          inputs['deterministicGateFinalProseHash'] is! String ||
          inputs['deterministicGate'] is! Map ||
          inputs['finalProse'] is! String ||
          (inputs['finalProse'] as String).trim().isEmpty) {
        throw const FormatException('deterministic receipt shape');
      }
      final proof = inputs['proof'] as Map;
      final finalProse = inputs['finalProse'] as String;
      final encodedScores = <String, Object?>{
        for (final entry in scores.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
      const deterministicDimensions = <String>{
        'characterConsistency',
        'canonMemory',
        'robustness',
        'efficiency',
      };
      if (encodedScores.length != scores.length ||
          encodedScores.keys
              .toSet()
              .difference(deterministicDimensions)
              .isNotEmpty ||
          deterministicDimensions
              .difference(encodedScores.keys.toSet())
              .isNotEmpty ||
          encodedScores.values.any(
            (score) => score is! int || score < 0 || score > 100000000,
          ) ||
          AgentEvaluationHashes.domainHash(
                'eval-trial-content-v1',
                finalProse,
              ) !=
              observationProseHash ||
          (deterministicDimensions.contains(dimensionId) &&
              encodedScores[dimensionId] != observedScoreMicros)) {
        throw const FormatException('deterministic receipt scores or prose');
      }
      if (!StoryMechanicsGateAuthority.verifyReceipt(
        encodedPolishCanonEvidence: inputs['polishCanonEvidence'],
        encodedStoryMechanicsEvidence: inputs['storyMechanicsEvidence'],
        gateFinalProseHash: inputs['deterministicGateFinalProseHash'] as String,
        deterministicGateEvidenceHash:
            proof['deterministicGateEvidenceHash'] as String,
        encodedDeterministicGate: inputs['deterministicGate'],
        finalProse: inputs['finalProse'] as String,
      )) {
        throw const FormatException('polish canon receipt');
      }
      final receiptValue = <String, Object?>{
        'authorityReleaseHash': row['authority_release_hash'],
        'executionId': executionId,
        'trialSlotId': trialSlotId,
        'attemptNo': attemptNo,
        'evaluationBundleHash': evaluationBundleHash,
        'proseHash': observationProseHash,
        'inputs': inputs,
        'scores': encodedScores,
      };
      if (AgentEvaluationHashes.domainHash(
            'eval-deterministic-quality-receipt-v2',
            receiptValue,
          ) !=
          receiptHash) {
        throw const FormatException('deterministic receipt hash');
      }
    } on Object {
      throw const AgentEvaluationReportException(
        'report rejected invalid deterministic story receipt',
      );
    }
  }

  _DecodedObservation _decodeObservation(
    Row row,
    AgentEvaluationReportPolicy policy,
  ) {
    final source = row['value_json'] as String;
    if (utf8.encode(source).length > policy.maximumObservationBytes ||
        policy.maximumObservationBytes >
            AgentEvaluationObservationCodecRegistry.maximumObservationBytes) {
      throw const AgentEvaluationReportException(
        'observation exceeds public report size limit',
      );
    }
    final AgentEvaluationDecodedObservation decoded;
    try {
      decoded = AgentEvaluationObservationCodecRegistry.decode(
        stageId: row['stage_id'] as String,
        kind: row['kind'] as String,
        itemKey: row['item_key'] as String,
        valueJson: source,
        proseHash: row['prose_hash'] as String?,
      );
    } on AgentEvaluationObservationCodecException catch (error) {
      throw AgentEvaluationReportException(error.message);
    }
    return _DecodedObservation(
      trialSlotId: row['trial_slot_id'] as String,
      attemptNo: row['attempt_no'] as int,
      type: decoded.type,
      itemKey: row['item_key'] as String,
      value: decoded.value,
      proseHash: row['prose_hash'] as String?,
    );
  }

  static Map<String, Object?> _distribution(
    List<double> source, {
    required int minimumSamples,
  }) {
    final values = source.toList()..sort();
    final mean = values.reduce((left, right) => left + right) / values.length;
    final result = <String, Object?>{
      'samples': values.length,
      'mean': mean,
      'min': values.first,
    };
    if (values.length < minimumSamples) {
      result['evidenceInsufficient'] = true;
      return result;
    }
    final variance = values.length == 1
        ? 0.0
        : values
                  .map((value) => math.pow(value - mean, 2).toDouble())
                  .reduce((left, right) => left + right) /
              (values.length - 1);
    final margin = 1.96 * math.sqrt(variance / values.length);
    result.addAll(<String, Object?>{
      'evidenceInsufficient': false,
      'p10': _percentile(values, 0.10),
      'p50': _percentile(values, 0.50),
      'p95': _percentile(values, 0.95),
      'ci95': <double>[mean - margin, mean + margin],
    });
    return result;
  }

  static double _percentile(List<double> values, double percentile) {
    final rank = ((values.length - 1) * percentile).ceil();
    return values[rank];
  }
}

class _DecodedObservation {
  const _DecodedObservation({
    required this.trialSlotId,
    required this.attemptNo,
    required this.type,
    required this.itemKey,
    required this.value,
    required this.proseHash,
  });

  final String trialSlotId;
  final int attemptNo;
  final String type;
  final String itemKey;
  final Map<String, Object?> value;
  final String? proseHash;
}

class _Usage {
  const _Usage({required this.tokens, required this.costMicrousd});

  factory _Usage.fromJson(Map<String, Object?> value) {
    if (<String>{
      'eval-attempt-usage-v1',
      'eval-attempt-usage-v2',
    }.contains(value['schemaVersion'])) {
      final promptTokens = value['promptTokens'];
      final completionTokens = value['completionTokens'];
      final costMicrousd = value['costMicrousd'];
      if (promptTokens is! int ||
          completionTokens is! int ||
          costMicrousd is! int ||
          promptTokens < 0 ||
          completionTokens < 0 ||
          costMicrousd < 0) {
        throw const AgentEvaluationReportException(
          'usage observation is malformed',
        );
      }
      return _Usage(
        tokens: promptTokens + completionTokens,
        costMicrousd: costMicrousd,
      );
    }
    throw const AgentEvaluationReportException(
      'usage observation is malformed',
    );
  }

  final int tokens;
  int? get latencyMs => null;
  final int costMicrousd;
}
