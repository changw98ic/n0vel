import 'dart:convert';
import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_canonical_hash.dart';
import '../../../../app/llm/app_llm_response_cache.dart';
import '../story_mechanics_gate_authority.dart';
import '../../domain/evaluation/pass3_evaluation.dart';
import '../../domain/evaluation/release_gate.dart';
import 'agent_evaluation_dispatch.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_metered_client.dart';
import 'agent_evaluation_pass3_projection.dart';
import 'agent_evaluation_private_holdout.dart';
import 'agent_evaluation_production_authority.dart';
import 'agent_evaluation_production_authorities.dart';
import 'agent_evaluation_production_evidence.dart';
import 'agent_evaluation_production_executor.dart';
import 'agent_evaluation_typed_evidence.dart';
import 'agent_evaluation_trusted_holdout.dart';

part 'agent_evaluation_gate_authority.dart';

class AgentEvaluationReleaseException implements Exception {
  const AgentEvaluationReleaseException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationReleaseException: $message';
}

class AgentEvaluationScorecardConflict extends AgentEvaluationReleaseException {
  const AgentEvaluationScorecardConflict(super.message);
}

class AgentEvaluationPromotionConflict extends AgentEvaluationReleaseException {
  const AgentEvaluationPromotionConflict(super.message);
}

class AgentEvaluationScorecardRecord {
  const AgentEvaluationScorecardRecord({
    required this.scorecardHash,
    required this.executionId,
    required this.scope,
    required this.scopeKey,
    required this.aggregateJson,
    required this.inputSetHash,
    required this.expectedSetHash,
    required this.aggregatorReleaseHash,
    required this.createdAtMs,
  });

  final String scorecardHash;
  final String executionId;
  final String scope;
  final String scopeKey;
  final String aggregateJson;
  final String inputSetHash;
  final String expectedSetHash;
  final String aggregatorReleaseHash;
  final int createdAtMs;
}

class AgentEvaluationGateVerdictRecord {
  const AgentEvaluationGateVerdictRecord({
    required this.verdictHash,
    required this.verdictKind,
    required this.experimentId,
    required this.executionId,
    required this.scorecardHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.status,
    required this.reasonsJson,
    required this.comparisonInputSetHash,
    required this.expectedPairSetHash,
    required this.policyHash,
    required this.gateReleaseHash,
    required this.createdAtMs,
  });

  final String verdictHash;
  final String verdictKind;
  final String experimentId;
  final String executionId;
  final String scorecardHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String status;
  final String reasonsJson;
  final String comparisonInputSetHash;
  final String expectedPairSetHash;
  final String policyHash;
  final String gateReleaseHash;
  final int createdAtMs;
}

class PromptChannelHeadRecord {
  const PromptChannelHeadRecord({
    required this.channel,
    required this.bundleHash,
    required this.epoch,
    required this.updatedAtMs,
  });

  final String channel;
  final String bundleHash;
  final int epoch;
  final int updatedAtMs;
}

final class AgentEvaluationPromotionRollbackResult {
  const AgentEvaluationPromotionRollbackResult({
    required this.promoted,
    required this.rolledBack,
  });

  final PromptChannelHeadRecord promoted;
  final PromptChannelHeadRecord rolledBack;
}

class PromptReleaseDecisionRecord {
  const PromptReleaseDecisionRecord({
    required this.decisionId,
    required this.channel,
    required this.action,
    required this.fromBundleHash,
    required this.toBundleHash,
    required this.fromEpoch,
    required this.toEpoch,
    required this.experimentId,
    required this.scorecardHash,
    required this.approver,
    required this.createdAtMs,
  });

  final String decisionId;
  final String channel;
  final String action;
  final String fromBundleHash;
  final String toBundleHash;
  final int fromEpoch;
  final int toEpoch;
  final String experimentId;
  final String scorecardHash;
  final String approver;
  final int createdAtMs;
}

/// SQLite authority for immutable scorecards and prompt channel decisions.
/// Scorecards are derived only from the complete frozen slot set; channel-head
/// changes and their decision records commit atomically under expected-state
/// compare-and-swap.
class AgentEvaluationReleaseStore {
  AgentEvaluationReleaseStore({required this.db, this.trustedHoldoutVerifier});

  final Database db;
  final AgentEvaluationTrustedHoldoutVerifier? trustedHoldoutVerifier;

  static final String channelHeadCasReleaseHash =
      AppLlmCanonicalHash.domainHash(
        'eval-channel-head-cas-release-v1',
        const <String, Object?>{
          'initialEpoch': 0,
          'write': 'begin-immediate-insert-or-exact-readback',
          'conflict': 'different-bundle-or-nonzero-initial-epoch',
        },
      );

  static String canonicalCellId({
    required String generationBundleHash,
    required String sutModelRouteHash,
    required String scenarioReleaseHash,
    required String decodingConfigHash,
  }) {
    for (final digest in <String>[
      generationBundleHash,
      sutModelRouteHash,
      scenarioReleaseHash,
      decodingConfigHash,
    ]) {
      _requireDigest(digest, 'cell component');
    }
    return _domainHash('eval-cell-v1', <String>[
      generationBundleHash,
      sutModelRouteHash,
      scenarioReleaseHash,
      decodingConfigHash,
    ]);
  }

  static String canonicalCellSetHash(Iterable<String> cellIds) {
    final sorted = cellIds.toList()..sort();
    _requireUnique(sorted, 'cell set');
    for (final cellId in sorted) {
      _requireDigest(cellId, 'cellId');
    }
    return _domainHash('eval-cell-set-v1', sorted);
  }

  static String canonicalSlotSetHash(
    Iterable<String> cellIds,
    int trialsPerCell,
  ) {
    if (trialsPerCell <= 0) {
      throw const AgentEvaluationReleaseException(
        'trialsPerCell must be positive',
      );
    }
    final sorted = cellIds.toList()..sort();
    _requireUnique(sorted, 'slot cell set');
    final logicalSlots = <List<Object>>[];
    for (final cellId in sorted) {
      _requireDigest(cellId, 'cellId');
      for (var trialNo = 1; trialNo <= trialsPerCell; trialNo += 1) {
        logicalSlots.add(<Object>[cellId, trialNo]);
      }
    }
    return _domainHash('eval-slot-set-v1', logicalSlots);
  }

  static String canonicalTrialSlotId({
    required String executionId,
    required String cellId,
    required int trialNo,
  }) {
    _requireIdentity(executionId, 'executionId');
    _requireDigest(cellId, 'cellId');
    if (trialNo <= 0) {
      throw const AgentEvaluationReleaseException('trialNo must be positive');
    }
    return _domainHash('eval-trial-slot-v1', <Object>[
      executionId,
      cellId,
      trialNo,
    ]);
  }

  AgentEvaluationScorecardRecord writeScorecard({
    required String executionId,
    required String scope,
    required String scopeKey,
    required String aggregateJson,
    required String aggregatorReleaseHash,
    required String expectedInputSetHash,
    required int createdAtMs,
  }) {
    _requireIdentity(executionId, 'executionId');
    _requireIdentity(scopeKey, 'scopeKey');
    _requireDigest(aggregatorReleaseHash, 'aggregatorReleaseHash');
    _requireDigest(expectedInputSetHash, 'expectedInputSetHash');
    if (!<String>{'execution', 'cell', 'scenario', 'bundle'}.contains(scope) ||
        createdAtMs < 0) {
      throw const AgentEvaluationReleaseException('invalid scorecard request');
    }
    final canonicalAggregate = _canonicalJsonText(aggregateJson);
    return _inImmediateTransaction(() {
      final executionRows = db.select(
        '''SELECT x.*, e.trials_per_cell, e.expected_cell_set_hash AS manifest_cell_hash,
             e.expected_slot_set_hash AS manifest_slot_hash, e.experiment_id
           FROM eval_executions x
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           WHERE x.execution_id = ?''',
        <Object?>[executionId],
      );
      if (executionRows.length != 1) {
        throw const AgentEvaluationScorecardConflict('execution not found');
      }
      final execution = executionRows.single;
      final trialsPerCell = execution['trials_per_cell'] as int;
      final cells = db.select(
        '''SELECT c.*, ec.ordinal
           FROM eval_experiment_cells ec
           JOIN eval_cells c ON c.cell_id = ec.cell_id
           WHERE ec.experiment_id = ? ORDER BY ec.ordinal''',
        <Object?>[execution['experiment_id']],
      );
      if (cells.isEmpty) {
        throw const AgentEvaluationScorecardConflict(
          'experiment has no canonical cells',
        );
      }
      final cellIds = <String>[];
      for (var ordinal = 0; ordinal < cells.length; ordinal += 1) {
        final cell = cells[ordinal];
        final computed = canonicalCellId(
          generationBundleHash: cell['generation_bundle_hash'] as String,
          sutModelRouteHash: cell['sut_model_route_hash'] as String,
          scenarioReleaseHash: cell['scenario_release_hash'] as String,
          decodingConfigHash: cell['decoding_config_hash'] as String,
        );
        if (cell['ordinal'] != ordinal || cell['cell_id'] != computed) {
          throw const AgentEvaluationScorecardConflict(
            'experiment cell set is not canonical',
          );
        }
        cellIds.add(computed);
      }
      final sortedCellIds = cellIds.toList()..sort();
      final cellSetHash = canonicalCellSetHash(sortedCellIds);
      final slotSetHash = canonicalSlotSetHash(sortedCellIds, trialsPerCell);
      if (execution['manifest_cell_hash'] != cellSetHash ||
          execution['expected_cell_set_hash'] != cellSetHash ||
          execution['manifest_slot_hash'] != slotSetHash ||
          execution['expected_slot_set_hash'] != slotSetHash) {
        throw const AgentEvaluationScorecardConflict(
          'execution expected set does not match its frozen manifest',
        );
      }
      final executionCells = db.select(
        '''SELECT cell_id, ordinal FROM eval_execution_cells
           WHERE execution_id = ? ORDER BY ordinal''',
        <Object?>[executionId],
      );
      if (executionCells.length != sortedCellIds.length) {
        throw const AgentEvaluationScorecardConflict(
          'execution cell membership is incomplete',
        );
      }
      for (var ordinal = 0; ordinal < sortedCellIds.length; ordinal += 1) {
        if (executionCells[ordinal]['ordinal'] != ordinal ||
            executionCells[ordinal]['cell_id'] != sortedCellIds[ordinal]) {
          throw const AgentEvaluationScorecardConflict(
            'execution cell membership is polluted',
          );
        }
      }

      final slots = db.select(
        '''SELECT trial_slot_id, cell_id, trial_no, status, result,
             sealed_evidence_hash
           FROM eval_trial_slots WHERE execution_id = ?
           ORDER BY cell_id, trial_no''',
        <Object?>[executionId],
      );
      final expectedCount = sortedCellIds.length * trialsPerCell;
      if (slots.length != expectedCount) {
        throw const AgentEvaluationScorecardConflict(
          'execution slot set is missing or duplicated',
        );
      }
      final inputs = <Map<String, Object?>>[];
      var index = 0;
      for (final cellId in sortedCellIds) {
        for (var trialNo = 1; trialNo <= trialsPerCell; trialNo += 1) {
          final slot = slots[index++];
          final expectedSlotId = canonicalTrialSlotId(
            executionId: executionId,
            cellId: cellId,
            trialNo: trialNo,
          );
          if (slot['cell_id'] != cellId ||
              slot['trial_no'] != trialNo ||
              slot['trial_slot_id'] != expectedSlotId ||
              slot['status'] != 'sealed' ||
              slot['result'] == null ||
              slot['sealed_evidence_hash'] == null) {
            throw const AgentEvaluationScorecardConflict(
              'all canonical slots must be sealed with immutable evidence',
            );
          }
          final evidenceHash = slot['sealed_evidence_hash'] as String;
          _requireDigest(evidenceHash, 'sealedEvidenceHash');
          inputs.add(<String, Object?>{
            'trialSlotId': expectedSlotId,
            'cellId': cellId,
            'trialNo': trialNo,
            'result': slot['result'],
            'evidenceHash': evidenceHash,
          });
        }
      }
      final inputSetHash = _domainHash('eval-scorecard-input-v1', inputs);
      if (inputSetHash != expectedInputSetHash) {
        throw const AgentEvaluationScorecardConflict(
          'caller input set hash does not match sealed trial evidence',
        );
      }
      final scorecardHash = _domainHash('eval-scorecard-v1', <String, Object?>{
        'executionId': executionId,
        'scope': scope,
        'scopeKey': scopeKey,
        'aggregate': jsonDecode(canonicalAggregate),
        'inputSetHash': inputSetHash,
        'expectedSetHash': slotSetHash,
        'aggregatorReleaseHash': aggregatorReleaseHash,
      });
      final existing = db.select(
        'SELECT * FROM eval_scorecards WHERE scorecard_hash = ?',
        <Object?>[scorecardHash],
      );
      if (existing.isNotEmpty) return _scorecardFromRow(existing.single);

      db.execute(
        '''UPDATE eval_executions
           SET status = 'completed', started_at_ms = COALESCE(started_at_ms, created_at_ms),
             finished_at_ms = ?
           WHERE execution_id = ? AND status NOT IN ('cancelled', 'failed')''',
        <Object?>[createdAtMs, executionId],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationScorecardConflict(
          'execution is not eligible for completion',
        );
      }
      try {
        db.execute(
          '''INSERT INTO eval_scorecards (
               scorecard_hash, execution_id, scope, scope_key, aggregate_json,
               input_set_hash, expected_set_hash, aggregator_release_hash,
               created_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          <Object?>[
            scorecardHash,
            executionId,
            scope,
            scopeKey,
            canonicalAggregate,
            inputSetHash,
            slotSetHash,
            aggregatorReleaseHash,
            createdAtMs,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationScorecardConflict(
          'scorecard insert conflict: $error',
        );
      }
      return AgentEvaluationScorecardRecord(
        scorecardHash: scorecardHash,
        executionId: executionId,
        scope: scope,
        scopeKey: scopeKey,
        aggregateJson: canonicalAggregate,
        inputSetHash: inputSetHash,
        expectedSetHash: slotSetHash,
        aggregatorReleaseHash: aggregatorReleaseHash,
        createdAtMs: createdAtMs,
      );
    });
  }

  String computeInputSetHash(String executionId) {
    _requireIdentity(executionId, 'executionId');
    final slots = db.select(
      '''SELECT trial_slot_id, cell_id, trial_no, result, sealed_evidence_hash
         FROM eval_trial_slots WHERE execution_id = ? AND status = 'sealed'
         ORDER BY cell_id, trial_no''',
      <Object?>[executionId],
    );
    return _domainHash(
      'eval-scorecard-input-v1',
      slots
          .map(
            (slot) => <String, Object?>{
              'trialSlotId': slot['trial_slot_id'],
              'cellId': slot['cell_id'],
              'trialNo': slot['trial_no'],
              'result': slot['result'],
              'evidenceHash': slot['sealed_evidence_hash'],
            },
          )
          .toList(growable: false),
    );
  }

  AgentEvaluationGateVerdictRecord recordGateVerdict({
    required String verdictKind,
    required String experimentId,
    required String executionId,
    required String scorecardHash,
    required String championBundleHash,
    required String challengerBundleHash,
    required String status,
    required List<String> reasons,
    required String comparisonInputSetHash,
    required String expectedPairSetHash,
    required String policyHash,
    required String gateReleaseHash,
    required int createdAtMs,
  }) => throw const AgentEvaluationPromotionConflict(
    'caller-supplied gate verdicts are disabled; use evaluateAndRecordGateVerdict',
  );

  /// Persists a decision already recomputed by the DB authority in the sibling
  /// part file. Keeping this private prevents callers from selecting status,
  /// LCB, p95, reasons, or the comparison pair set.
  AgentEvaluationGateVerdictRecord _persistGateVerdict({
    required String verdictKind,
    required String experimentId,
    required String executionId,
    required String scorecardHash,
    required String championBundleHash,
    required String challengerBundleHash,
    required String status,
    required List<String> reasons,
    required String comparisonInputSetHash,
    required String expectedPairSetHash,
    required String policyHash,
    required String gateReleaseHash,
    required int createdAtMs,
  }) {
    if (!<String>{'regression', 'holdout'}.contains(verdictKind) ||
        !<String>{
          'promote',
          'reject',
          'insufficientEvidence',
        }.contains(status) ||
        createdAtMs < 0) {
      throw const AgentEvaluationPromotionConflict('invalid gate verdict');
    }
    for (final value in <(String, String)>[
      (experimentId, 'experimentId'),
      (executionId, 'executionId'),
    ]) {
      _requireIdentity(value.$1, value.$2);
    }
    for (final value in <(String, String)>[
      (scorecardHash, 'scorecardHash'),
      (championBundleHash, 'championBundleHash'),
      (challengerBundleHash, 'challengerBundleHash'),
      (comparisonInputSetHash, 'comparisonInputSetHash'),
      (expectedPairSetHash, 'expectedPairSetHash'),
      (policyHash, 'policyHash'),
      (gateReleaseHash, 'gateReleaseHash'),
    ]) {
      _requireDigest(value.$1, value.$2);
    }
    if (championBundleHash == challengerBundleHash ||
        reasons.any((reason) => reason.trim().isEmpty)) {
      throw const AgentEvaluationPromotionConflict(
        'gate verdict arm or reason identity is invalid',
      );
    }
    final canonicalReasons = reasons.toSet().toList()..sort();
    return _inImmediateTransaction(() {
      final scorecards = db.select(
        '''SELECT s.*, x.experiment_id, x.status AS execution_status
           FROM eval_scorecards s
           JOIN eval_executions x ON x.execution_id = s.execution_id
           WHERE s.scorecard_hash = ? AND s.execution_id = ?
             AND x.experiment_id = ?''',
        <Object?>[scorecardHash, executionId, experimentId],
      );
      if (scorecards.length != 1) {
        throw const AgentEvaluationPromotionConflict(
          'gate verdict scorecard is not in the experiment',
        );
      }
      final scorecard = scorecards.single;
      if (scorecard['execution_status'] != 'completed' ||
          scorecard['scope'] != 'execution' ||
          scorecard['scope_key'] != executionId ||
          scorecard['input_set_hash'] != comparisonInputSetHash) {
        throw const AgentEvaluationPromotionConflict(
          'gate verdict is not bound to the complete execution scorecard',
        );
      }
      final arms = db
          .select(
            '''SELECT DISTINCT c.generation_bundle_hash
               FROM eval_experiment_cells ec
               JOIN eval_cells c ON c.cell_id = ec.cell_id
               WHERE ec.experiment_id = ?''',
            <Object?>[experimentId],
          )
          .map((row) => row['generation_bundle_hash'] as String)
          .toSet();
      if (!arms.contains(championBundleHash) ||
          !arms.contains(challengerBundleHash)) {
        throw const AgentEvaluationPromotionConflict(
          'gate verdict arms are not both present in the experiment',
        );
      }
      final reasonsJson = _canonicalJsonText(jsonEncode(canonicalReasons));
      final verdictHash =
          _domainHash('eval-release-gate-verdict-v1', <String, Object?>{
            'kind': verdictKind,
            'experimentId': experimentId,
            'executionId': executionId,
            'scorecardHash': scorecardHash,
            'championBundleHash': championBundleHash,
            'challengerBundleHash': challengerBundleHash,
            'status': status,
            'reasons': canonicalReasons,
            'comparisonInputSetHash': comparisonInputSetHash,
            'expectedPairSetHash': expectedPairSetHash,
            'policyHash': policyHash,
            'gateReleaseHash': gateReleaseHash,
          });
      db.execute(
        '''INSERT OR IGNORE INTO eval_release_gate_verdicts (
             verdict_hash, verdict_kind, experiment_id, execution_id,
             scorecard_hash, champion_bundle_hash, challenger_bundle_hash,
             status, reasons_json, comparison_input_set_hash,
             expected_pair_set_hash, policy_hash, gate_release_hash,
             created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          verdictHash,
          verdictKind,
          experimentId,
          executionId,
          scorecardHash,
          championBundleHash,
          challengerBundleHash,
          status,
          reasonsJson,
          comparisonInputSetHash,
          expectedPairSetHash,
          policyHash,
          gateReleaseHash,
          createdAtMs,
        ],
      );
      final rows = db.select(
        'SELECT * FROM eval_release_gate_verdicts WHERE verdict_hash = ?',
        <Object?>[verdictHash],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationPromotionConflict(
          'gate verdict was not persisted',
        );
      }
      return _gateVerdictFromRow(rows.single);
    });
  }

  PromptChannelHeadRecord promote({
    required String decisionId,
    required String channel,
    required String expectedBundleHash,
    required int expectedEpoch,
    required String challengerBundleHash,
    required String experimentId,
    required String scorecardHash,
    required String approver,
    required int createdAtMs,
  }) => throw const AgentEvaluationPromotionConflict(
    'unverified promotion is disabled; use promoteVerified',
  );

  Future<PromptChannelHeadRecord> promoteVerified({
    required String decisionId,
    required String channel,
    required String expectedBundleHash,
    required int expectedEpoch,
    required String challengerBundleHash,
    required String experimentId,
    required String regressionVerdictHash,
    String? productionHoldoutClaimHash,
    String? holdoutConfirmationId,
    required String approver,
    required int createdAtMs,
  }) async {
    for (final value in <(String, String)>[
      (decisionId, 'decisionId'),
      (channel, 'channel'),
      (experimentId, 'experimentId'),
      (approver, 'approver'),
    ]) {
      _requireIdentity(value.$1, value.$2);
    }
    for (final value in <(String, String)>[
      (expectedBundleHash, 'expectedBundleHash'),
      (challengerBundleHash, 'challengerBundleHash'),
      (regressionVerdictHash, 'regressionVerdictHash'),
    ]) {
      _requireDigest(value.$1, value.$2);
    }
    if (expectedEpoch < 0 || createdAtMs < 0) {
      throw const AgentEvaluationReleaseException('invalid promotion request');
    }
    if (productionHoldoutClaimHash == null) {
      throw const AgentEvaluationPromotionConflict(
        'V1 exact-reference holdout confirmations are not release eligible; '
        'promotion requires a production-attestation-v2 claim',
      );
    }
    _requireDigest(productionHoldoutClaimHash, 'productionHoldoutClaimHash');
    final verifier = trustedHoldoutVerifier;
    if (verifier == null) {
      throw const AgentEvaluationPromotionConflict(
        'promotion requires an external trusted-holdout verification root',
      );
    }
    final trustedNowMs = DateTime.now().millisecondsSinceEpoch;
    final claimRows = db.select(
      '''SELECT * FROM eval_production_holdout_claims
         WHERE claim_hash = ?''',
      <Object?>[productionHoldoutClaimHash],
    );
    if (claimRows.length != 1) {
      throw const AgentEvaluationPromotionConflict(
        'signed production holdout claim is missing',
      );
    }
    late final AgentEvaluationProductionHoldoutAttestation attestation;
    try {
      final row = claimRows.single;
      attestation = AgentEvaluationProductionHoldoutAttestation.fromStorage(
        payloadJson: row['payload_json'] as String,
        signatureBase64: row['signature_base64'] as String,
      );
      final importedAtMs = row['imported_at_ms'];
      if (attestation.claimHash != row['claim_hash'] ||
          importedAtMs is! int ||
          row['issued_at_ms'] != attestation.issuedAtMs ||
          row['expires_at_ms'] != attestation.expiresAtMs ||
          importedAtMs < attestation.issuedAtMs ||
          importedAtMs >= attestation.expiresAtMs ||
          !_productionClaimColumnsMatch(row, attestation) ||
          !await verifier.verifyProductionSignature(attestation)) {
        throw const FormatException('signature or hash mismatch');
      }
    } on Object {
      throw const AgentEvaluationPromotionConflict(
        'signed production holdout claim is malformed or unverifiable',
      );
    }
    return _inImmediateTransaction(() {
      final verdicts = db.select(
        '''SELECT v.*, s.scorecard_hash, d.projection_hash
           FROM eval_release_gate_verdicts v
           JOIN eval_scorecards s ON s.scorecard_hash = v.scorecard_hash
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
           WHERE v.verdict_hash = ? AND v.verdict_kind = 'regression'
             AND v.status = 'promote' AND v.experiment_id = ?
             AND v.champion_bundle_hash = ?
             AND v.challenger_bundle_hash = ?
             AND v.policy_hash = ? AND v.gate_release_hash = ?
             AND d.authority_release_hash = ?''',
        <Object?>[
          regressionVerdictHash,
          experimentId,
          expectedBundleHash,
          challengerBundleHash,
          AgentEvaluationStandardGatePolicy.policyHash,
          AgentEvaluationStandardGatePolicy.gateReleaseHash,
          AgentEvaluationStandardGatePolicy.gateReleaseHash,
        ],
      );
      if (verdicts.length != 1) {
        throw const AgentEvaluationPromotionConflict(
          'regression verdict does not authorize this challenger',
        );
      }
      final claims = db.select(
        '''SELECT c.*, a.state AS access_state,
             a.imported_at_ms AS access_imported_at_ms,
             f.scenario_set_release_hash AS family_regression_scenario_set_hash,
             f.opaque_holdout_scenario_set_hash AS family_opaque_scenario_set_hash,
             f.private_plan_hash AS family_private_plan_hash,
             f.holdout_access_policy_hash,
             e.scenario_set_release_hash AS regression_scenario_set_hash
           FROM eval_production_holdout_claims c
           JOIN eval_production_holdout_accesses a
             ON a.access_id = c.access_id AND a.token_id = c.token_id
             AND a.family_id = c.family_id
             AND a.challenger_bundle_hash = c.challenger_bundle_hash
           JOIN eval_experiment_families f ON f.family_id = c.family_id
           JOIN eval_release_gate_verdicts rv
             ON rv.verdict_hash = c.regression_verdict_hash
           JOIN eval_executions rx ON rx.execution_id = rv.execution_id
           JOIN eval_experiments e ON e.experiment_id = rx.experiment_id
           WHERE c.claim_hash = ? AND c.result = 'pass'
             AND a.state = 'imported'
             AND c.regression_verdict_hash = ?
             AND c.champion_bundle_hash = ?
             AND c.challenger_bundle_hash = ?''',
        <Object?>[
          productionHoldoutClaimHash,
          regressionVerdictHash,
          expectedBundleHash,
          challengerBundleHash,
        ],
      );
      if (claims.length != 1 ||
          claims.single['access_imported_at_ms'] !=
              claims.single['imported_at_ms'] ||
          (claims.single['imported_at_ms'] as int) < attestation.issuedAtMs ||
          (claims.single['imported_at_ms'] as int) >= attestation.expiresAtMs ||
          claims.single['holdout_access_policy_hash'] !=
              verifier.trustPolicyHash ||
          attestation.challengerBundleHash != challengerBundleHash ||
          attestation.championBundleHash != expectedBundleHash ||
          attestation.regressionVerdictHash != regressionVerdictHash ||
          attestation.regressionScenarioSetHash !=
              claims.single['regression_scenario_set_hash'] ||
          attestation.regressionScenarioSetHash !=
              claims.single['family_regression_scenario_set_hash'] ||
          attestation.opaqueHoldoutScenarioSetHash !=
              claims.single['family_opaque_scenario_set_hash'] ||
          attestation.privatePlanHash !=
              claims.single['family_private_plan_hash']) {
        throw const AgentEvaluationPromotionConflict(
          'production holdout claim does not authorize this challenger',
        );
      }
      final head = _moveHeadInCurrentTransaction(
        decisionId: decisionId,
        channel: channel,
        action: 'promote',
        expectedBundleHash: expectedBundleHash,
        expectedEpoch: expectedEpoch,
        targetBundleHash: challengerBundleHash,
        experimentId: experimentId,
        scorecardHash: verdicts.single['scorecard_hash'] as String,
        approver: approver,
        createdAtMs: trustedNowMs,
      );
      try {
        db.execute(
          '''INSERT INTO prompt_release_decision_production_authorizations (
               decision_id, regression_verdict_hash,
               production_holdout_claim_hash, created_at_ms
             ) VALUES (?, ?, ?, ?)''',
          <Object?>[
            decisionId,
            regressionVerdictHash,
            productionHoldoutClaimHash,
            trustedNowMs,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationPromotionConflict(
          'promotion authorization conflict: $error',
        );
      }
      return head;
    });
  }

  PromptChannelHeadRecord rollback({
    required String decisionId,
    required String channel,
    required String expectedBundleHash,
    required int expectedEpoch,
    required String rollbackBundleHash,
    required String experimentId,
    required String scorecardHash,
    required String approver,
    required int createdAtMs,
  }) => throw const AgentEvaluationPromotionConflict(
    'caller-selected rollback is disabled; use rollbackVerified',
  );

  PromptChannelHeadRecord rollbackVerified({
    required String decisionId,
    required String channel,
    required String expectedBundleHash,
    required int expectedEpoch,
    required String promotionDecisionId,
    required String approver,
    required int createdAtMs,
  }) {
    for (final value in <(String, String)>[
      (decisionId, 'decisionId'),
      (channel, 'channel'),
      (promotionDecisionId, 'promotionDecisionId'),
      (approver, 'approver'),
    ]) {
      _requireIdentity(value.$1, value.$2);
    }
    _requireDigest(expectedBundleHash, 'expectedBundleHash');
    if (expectedEpoch <= 0 || createdAtMs < 0) {
      throw const AgentEvaluationReleaseException('invalid rollback request');
    }
    return _inImmediateTransaction(() {
      final promotions = db.select(
        '''SELECT d.* FROM prompt_release_decisions d
           WHERE d.decision_id = ? AND d.channel = ?
             AND d.action = 'promote' AND d.to_bundle_hash = ?
             AND d.to_epoch = ?
             AND EXISTS (
               SELECT 1
               FROM prompt_release_decision_production_authorizations a
               WHERE a.decision_id = d.decision_id
             )''',
        <Object?>[
          promotionDecisionId,
          channel,
          expectedBundleHash,
          expectedEpoch,
        ],
      );
      if (promotions.length != 1) {
        throw const AgentEvaluationPromotionConflict(
          'rollback target is not the predecessor of this authorized promotion',
        );
      }
      final promotion = promotions.single;
      return _moveHeadInCurrentTransaction(
        decisionId: decisionId,
        channel: channel,
        action: 'rollback',
        expectedBundleHash: expectedBundleHash,
        expectedEpoch: expectedEpoch,
        targetBundleHash: promotion['from_bundle_hash'] as String,
        experimentId: promotion['experiment_id'] as String,
        scorecardHash: promotion['scorecard_hash'] as String,
        approver: approver,
        createdAtMs: createdAtMs,
      );
    });
  }

  /// Executes the release drill as one SQLite transaction. The epoch-one
  /// promotion, its production authorization, and the epoch-two rollback are
  /// either all durable or all absent. This prevents crashes or rollback
  /// conflicts from leaving a partially promoted channel head.
  Future<AgentEvaluationPromotionRollbackResult>
  exercisePromoteThenRollbackVerified({
    required String promotionDecisionId,
    required String rollbackDecisionId,
    required String channel,
    required String expectedBundleHash,
    required int expectedEpoch,
    required String challengerBundleHash,
    required String experimentId,
    required String regressionVerdictHash,
    required String productionHoldoutClaimHash,
    required String approver,
    required int createdAtMs,
  }) async {
    db.execute('BEGIN IMMEDIATE');
    try {
      final promoted = await promoteVerified(
        decisionId: promotionDecisionId,
        channel: channel,
        expectedBundleHash: expectedBundleHash,
        expectedEpoch: expectedEpoch,
        challengerBundleHash: challengerBundleHash,
        experimentId: experimentId,
        regressionVerdictHash: regressionVerdictHash,
        productionHoldoutClaimHash: productionHoldoutClaimHash,
        approver: approver,
        createdAtMs: createdAtMs,
      );
      final rolledBack = rollbackVerified(
        decisionId: rollbackDecisionId,
        channel: channel,
        expectedBundleHash: challengerBundleHash,
        expectedEpoch: promoted.epoch,
        promotionDecisionId: promotionDecisionId,
        approver: approver,
        createdAtMs: createdAtMs,
      );
      db.execute('COMMIT');
      return AgentEvaluationPromotionRollbackResult(
        promoted: promoted,
        rolledBack: rolledBack,
      );
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Idempotently creates the epoch-zero authority head. Existing state is
  /// accepted only when it is the exact same bundle at epoch zero; callers
  /// cannot use initialization to overwrite or rewind a channel.
  PromptChannelHeadRecord initializeChannelHead({
    required String channel,
    required String bundleHash,
    required int createdAtMs,
  }) {
    _requireIdentity(channel, 'channel');
    _requireDigest(bundleHash, 'bundleHash');
    if (createdAtMs < 0) {
      throw const AgentEvaluationReleaseException(
        'invalid channel head initialization time',
      );
    }
    return _inImmediateTransaction(() {
      db.execute(
        '''INSERT OR IGNORE INTO prompt_channel_heads (
             channel, bundle_hash, epoch, updated_at_ms
           ) VALUES (?, ?, 0, ?)''',
        <Object?>[channel, bundleHash, createdAtMs],
      );
      final rows = db.select(
        'SELECT * FROM prompt_channel_heads WHERE channel = ?',
        <Object?>[channel],
      );
      if (rows.length != 1 ||
          rows.single['bundle_hash'] != bundleHash ||
          rows.single['epoch'] != 0) {
        throw const AgentEvaluationPromotionConflict(
          'channel head initialization conflicts with existing authority',
        );
      }
      return _channelHeadFromRow(rows.single);
    });
  }

  PromptChannelHeadRecord readChannelHead(String channel) {
    _requireIdentity(channel, 'channel');
    final rows = db.select(
      'SELECT * FROM prompt_channel_heads WHERE channel = ?',
      <Object?>[channel],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationPromotionConflict(
        'channel head is missing or ambiguous',
      );
    }
    return _channelHeadFromRow(rows.single);
  }

  List<PromptReleaseDecisionRecord> readDecisions(String channel) {
    _requireIdentity(channel, 'channel');
    return db
        .select(
          '''SELECT * FROM prompt_release_decisions
             WHERE channel = ? ORDER BY to_epoch''',
          <Object?>[channel],
        )
        .map(_decisionFromRow)
        .toList(growable: false);
  }

  PromptChannelHeadRecord _moveHeadInCurrentTransaction({
    required String decisionId,
    required String channel,
    required String action,
    required String expectedBundleHash,
    required int expectedEpoch,
    required String targetBundleHash,
    required String experimentId,
    required String scorecardHash,
    required String approver,
    required int createdAtMs,
  }) {
    db.execute(
      '''UPDATE prompt_channel_heads
         SET bundle_hash = ?, epoch = ?, updated_at_ms = ?
         WHERE channel = ? AND bundle_hash = ? AND epoch = ?''',
      <Object?>[
        targetBundleHash,
        expectedEpoch + 1,
        createdAtMs,
        channel,
        expectedBundleHash,
        expectedEpoch,
      ],
    );
    if (db.updatedRows != 1) {
      throw const AgentEvaluationPromotionConflict(
        'channel head compare-and-swap failed',
      );
    }
    try {
      db.execute(
        '''INSERT INTO prompt_release_decisions (
             decision_id, channel, action, from_bundle_hash, to_bundle_hash,
             from_epoch, to_epoch, experiment_id, scorecard_hash, approver,
             created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          decisionId,
          channel,
          action,
          expectedBundleHash,
          targetBundleHash,
          expectedEpoch,
          expectedEpoch + 1,
          experimentId,
          scorecardHash,
          approver,
          createdAtMs,
        ],
      );
    } on SqliteException catch (error) {
      throw AgentEvaluationPromotionConflict(
        'promotion decision conflict: $error',
      );
    }
    return PromptChannelHeadRecord(
      channel: channel,
      bundleHash: targetBundleHash,
      epoch: expectedEpoch + 1,
      updatedAtMs: createdAtMs,
    );
  }

  static bool _productionClaimColumnsMatch(
    Row row,
    AgentEvaluationProductionHoldoutAttestation attestation,
  ) => <(Object?, Object?)>[
    (row['family_id'], attestation.familyId),
    (row['token_id'], attestation.tokenId),
    (row['access_id'], attestation.accessId),
    (row['regression_verdict_hash'], attestation.regressionVerdictHash),
    (row['champion_bundle_hash'], attestation.championBundleHash),
    (row['challenger_bundle_hash'], attestation.challengerBundleHash),
    (
      row['regression_scenario_set_hash'],
      attestation.regressionScenarioSetHash,
    ),
    (
      row['opaque_holdout_scenario_set_hash'],
      attestation.opaqueHoldoutScenarioSetHash,
    ),
    (row['private_plan_hash'], attestation.privatePlanHash),
    (row['production_manifest_hash'], attestation.productionManifestHash),
    (
      row['private_execution_summary_hash'],
      attestation.privateExecutionSummaryHash,
    ),
    (
      row['redacted_execution_summary_hash'],
      attestation.redactedExecutionSummaryHash,
    ),
    (row['private_scorecard_hash'], attestation.privateScorecardHash),
    (row['redacted_scorecard_hash'], attestation.redactedScorecardHash),
    (row['private_gate_verdict_hash'], attestation.privateGateVerdictHash),
    (row['redacted_gate_verdict_hash'], attestation.redactedGateVerdictHash),
    (row['private_projection_hash'], attestation.privateProjectionHash),
    (row['expected_cell_set_hash'], attestation.expectedCellSetHash),
    (row['expected_slot_set_hash'], attestation.expectedSlotSetHash),
    (
      row['execution_budget_policy_hash'],
      attestation.executionBudgetPolicyHash,
    ),
    (row['executor_release_hash'], attestation.executorReleaseHash),
    (row['evaluation_bundle_hash'], attestation.evaluationBundleHash),
    (row['price_table_hash'], attestation.priceTableHash),
    (row['gate_policy_hash'], attestation.gatePolicyHash),
    (row['audit_root_hash'], attestation.auditRootHash),
    (row['result'], attestation.result),
    (row['key_id'], attestation.keyId),
    (row['runner_release_hash'], attestation.runnerReleaseHash),
    (row['resolver_release_hash'], attestation.resolverReleaseHash),
  ].every((binding) => binding.$1 == binding.$2);

  static PromptChannelHeadRecord _channelHeadFromRow(Row row) =>
      PromptChannelHeadRecord(
        channel: row['channel'] as String,
        bundleHash: row['bundle_hash'] as String,
        epoch: row['epoch'] as int,
        updatedAtMs: row['updated_at_ms'] as int,
      );

  static AgentEvaluationScorecardRecord _scorecardFromRow(Row row) =>
      AgentEvaluationScorecardRecord(
        scorecardHash: row['scorecard_hash'] as String,
        executionId: row['execution_id'] as String,
        scope: row['scope'] as String,
        scopeKey: row['scope_key'] as String,
        aggregateJson: row['aggregate_json'] as String,
        inputSetHash: row['input_set_hash'] as String,
        expectedSetHash: row['expected_set_hash'] as String,
        aggregatorReleaseHash: row['aggregator_release_hash'] as String,
        createdAtMs: row['created_at_ms'] as int,
      );

  static AgentEvaluationGateVerdictRecord _gateVerdictFromRow(Row row) =>
      AgentEvaluationGateVerdictRecord(
        verdictHash: row['verdict_hash'] as String,
        verdictKind: row['verdict_kind'] as String,
        experimentId: row['experiment_id'] as String,
        executionId: row['execution_id'] as String,
        scorecardHash: row['scorecard_hash'] as String,
        championBundleHash: row['champion_bundle_hash'] as String,
        challengerBundleHash: row['challenger_bundle_hash'] as String,
        status: row['status'] as String,
        reasonsJson: row['reasons_json'] as String,
        comparisonInputSetHash: row['comparison_input_set_hash'] as String,
        expectedPairSetHash: row['expected_pair_set_hash'] as String,
        policyHash: row['policy_hash'] as String,
        gateReleaseHash: row['gate_release_hash'] as String,
        createdAtMs: row['created_at_ms'] as int,
      );

  static PromptReleaseDecisionRecord _decisionFromRow(Row row) =>
      PromptReleaseDecisionRecord(
        decisionId: row['decision_id'] as String,
        channel: row['channel'] as String,
        action: row['action'] as String,
        fromBundleHash: row['from_bundle_hash'] as String,
        toBundleHash: row['to_bundle_hash'] as String,
        fromEpoch: row['from_epoch'] as int,
        toEpoch: row['to_epoch'] as int,
        experimentId: row['experiment_id'] as String,
        scorecardHash: row['scorecard_hash'] as String,
        approver: row['approver'] as String,
        createdAtMs: row['created_at_ms'] as int,
      );

  T _inImmediateTransaction<T>(T Function() body) {
    if (!db.autocommit) {
      const savepoint = 'agent_evaluation_release_nested';
      db.execute('SAVEPOINT $savepoint');
      try {
        final result = body();
        db.execute('RELEASE SAVEPOINT $savepoint');
        return result;
      } catch (_) {
        db.execute('ROLLBACK TO SAVEPOINT $savepoint');
        db.execute('RELEASE SAVEPOINT $savepoint');
        rethrow;
      }
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static String _canonicalJsonText(String source) {
    try {
      return AppLlmCanonicalHash.canonicalJson(jsonDecode(source));
    } on Object catch (error) {
      throw AgentEvaluationReleaseException(
        'aggregateJson must be canonicalizable JSON: $error',
      );
    }
  }

  static String _domainHash(String domainTag, Object? value) {
    final prefixed = AppLlmCanonicalHash.domainHash(domainTag, value);
    return prefixed.substring('sha256:'.length);
  }

  static void _requireIdentity(String value, String field) {
    if (value.trim().isEmpty) {
      throw AgentEvaluationReleaseException('$field is required');
    }
  }

  static void _requireDigest(String value, String field) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw AgentEvaluationReleaseException(
        '$field must be canonical lowercase SHA-256 hex',
      );
    }
  }

  static void _requireUnique(List<String> values, String field) {
    if (values.toSet().length != values.length) {
      throw AgentEvaluationScorecardConflict('$field contains duplicates');
    }
  }
}
