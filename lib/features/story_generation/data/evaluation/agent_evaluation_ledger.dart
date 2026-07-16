import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_canonical_hash.dart';
import 'agent_evaluation_dispatch.dart';
import 'agent_evaluation_observation_codec.dart';

class AgentEvaluationLedgerException implements Exception {
  const AgentEvaluationLedgerException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationLedgerException: $message';
}

class AgentEvaluationConflict extends AgentEvaluationLedgerException {
  const AgentEvaluationConflict(super.message);
}

class AgentEvaluationLeaseLost extends AgentEvaluationLedgerException {
  const AgentEvaluationLeaseLost(super.message);
}

class AgentEvaluationCellDefinition {
  const AgentEvaluationCellDefinition({
    required this.generationBundleHash,
    required this.sutModelRouteHash,
    required this.scenarioReleaseHash,
    required this.decodingConfigHash,
  });

  final String generationBundleHash;
  final String sutModelRouteHash;
  final String scenarioReleaseHash;
  final String decodingConfigHash;

  String get cellId => AgentEvaluationLedger.canonicalCellId(this);
}

class AgentEvaluationExecution {
  const AgentEvaluationExecution({
    required this.executionId,
    required this.experimentId,
    required this.cellIds,
    required this.trialSlotIds,
    required this.status,
  });

  final String executionId;
  final String experimentId;
  final List<String> cellIds;
  final List<String> trialSlotIds;
  final String status;
}

class AgentEvaluationLease {
  const AgentEvaluationLease({
    required this.trialSlotId,
    required this.executionId,
    required this.cellId,
    required this.trialNo,
    required this.epoch,
    required this.owner,
    required this.expiresAtMs,
    required this.status,
  });

  final String trialSlotId;
  final String executionId;
  final String cellId;
  final int trialNo;
  final int epoch;
  final String owner;
  final int expiresAtMs;
  final String status;
}

class AgentEvaluationAttempt {
  const AgentEvaluationAttempt({
    required this.trialSlotId,
    required this.attemptNo,
    required this.runId,
    required this.kind,
    required this.status,
    required this.leaseEpoch,
    required this.leaseOwner,
    required this.startedAtMs,
    this.finishedAtMs,
  });

  final String trialSlotId;
  final int attemptNo;
  final String runId;
  final String kind;
  final String status;
  final int leaseEpoch;
  final String leaseOwner;
  final int startedAtMs;
  final int? finishedAtMs;
}

class AgentEvaluationObservationInput {
  const AgentEvaluationObservationInput({
    required this.observationId,
    required this.attemptNo,
    required this.sequenceNo,
    required this.stageId,
    required this.kind,
    required this.itemKey,
    required this.valueJson,
    required this.evidenceHash,
    required this.evaluationBundleHash,
    required this.createdAtMs,
    this.proseHash,
  });

  final String observationId;
  final int attemptNo;
  final int sequenceNo;
  final String stageId;
  final String kind;
  final String itemKey;
  final String valueJson;
  final String evidenceHash;
  final String evaluationBundleHash;
  final String? proseHash;
  final int createdAtMs;

  AgentEvaluationEvidenceKey get evidenceKey => AgentEvaluationEvidenceKey(
    attemptNo: attemptNo,
    stageId: stageId,
    kind: kind,
    itemKey: itemKey,
  );
}

class AgentEvaluationObservation {
  const AgentEvaluationObservation({
    required this.observationId,
    required this.trialSlotId,
    required this.input,
    required this.leaseEpoch,
    required this.leaseOwner,
  });

  final String observationId;
  final String trialSlotId;
  final AgentEvaluationObservationInput input;
  final int leaseEpoch;
  final String leaseOwner;
}

class AgentEvaluationEvidenceKey {
  const AgentEvaluationEvidenceKey({
    required this.attemptNo,
    required this.stageId,
    required this.kind,
    required this.itemKey,
  });

  final int attemptNo;
  final String stageId;
  final String kind;
  final String itemKey;

  String get canonicalKey =>
      '$attemptNo\u001f$stageId\u001f$kind\u001f$itemKey';
}

class AgentEvaluationSealedResult {
  const AgentEvaluationSealedResult({
    required this.trialSlotId,
    required this.result,
    required this.evidenceHash,
    required this.sealedAtMs,
  });

  final String trialSlotId;
  final String result;
  final String evidenceHash;
  final int sealedAtMs;
}

class AgentEvaluationSandboxGeneration {
  const AgentEvaluationSandboxGeneration({
    required this.generationHash,
    required this.executionId,
    required this.isolationTrialId,
    required this.generationNo,
    required this.sourceTrialSlotId,
    required this.baseGenerationHash,
    required this.isolationMode,
    required this.databasePath,
    required this.databaseFileHash,
    required this.leaseEpoch,
    required this.leaseOwner,
    required this.createdAtMs,
  });

  final String generationHash;
  final String executionId;
  final String isolationTrialId;
  final int generationNo;
  final String sourceTrialSlotId;
  final String? baseGenerationHash;
  final String isolationMode;
  final String databasePath;
  final String databaseFileHash;
  final int leaseEpoch;
  final String leaseOwner;
  final int createdAtMs;
}

class AgentEvaluationSandboxCommit {
  const AgentEvaluationSandboxCommit({
    required this.isolationTrialId,
    required this.isolationMode,
    required this.databasePath,
    required this.databaseFileHash,
    required this.baseGenerationHash,
  });

  final String isolationTrialId;
  final String isolationMode;
  final String databasePath;
  final String databaseFileHash;
  final String? baseGenerationHash;
}

class AgentEvaluationSandboxRecoveryCheckpoint {
  const AgentEvaluationSandboxRecoveryCheckpoint({
    required this.checkpointHash,
    required this.executionId,
    required this.trialSlotId,
    required this.attemptNo,
    required this.attemptRunId,
    required this.originalLeaseEpoch,
    required this.originalLeaseOwner,
    required this.writerLeaseEpoch,
    required this.writerLeaseOwner,
    required this.cellId,
    required this.manifestHash,
    required this.isolationTrialId,
    required this.isolationMode,
    required this.checkpointNo,
    required this.stage,
    required this.candidateHash,
    required this.databasePath,
    required this.databaseFileHash,
    required this.databaseFileSize,
    required this.stateProjectionHash,
    required this.createdAtMs,
    this.baseCheckpointHash,
  });

  final String checkpointHash;
  final String executionId;
  final String trialSlotId;
  final int attemptNo;
  final String attemptRunId;
  final int originalLeaseEpoch;
  final String originalLeaseOwner;
  final int writerLeaseEpoch;
  final String writerLeaseOwner;
  final String cellId;
  final String manifestHash;
  final String isolationTrialId;
  final String isolationMode;
  final int checkpointNo;
  final String stage;
  final String candidateHash;
  final String databasePath;
  final String databaseFileHash;
  final int databaseFileSize;
  final String stateProjectionHash;
  final String? baseCheckpointHash;
  final int createdAtMs;
}

/// SQLite authority for evaluation execution, lease fencing, and immutable
/// trial evidence. Every lease-sensitive mutation validates the fencing token
/// and performs its write under the same `BEGIN IMMEDIATE` transaction.
class AgentEvaluationLedger {
  AgentEvaluationLedger({required this.db});

  static final String releaseHash = AppLlmCanonicalHash.domainHash(
    'agent-evaluation-ledger-release-v1',
    const <String, Object?>{
      'leaseFence':
          'attempt-observation-checkpoint-candidate-sandbox-accept-and-seal',
      'transaction': 'sqlite-begin-immediate-active-epoch-owner-check',
    },
  );

  final Database db;

  static const Map<String, int> sandboxRecoveryStageOrdinals = <String, int>{
    'prepared': 1,
    'accepted': 2,
    'outboxCompleted': 3,
    'finalPersisted': 4,
  };

  static String canonicalCellId(AgentEvaluationCellDefinition cell) {
    for (final digest in <String>[
      cell.generationBundleHash,
      cell.sutModelRouteHash,
      cell.scenarioReleaseHash,
      cell.decodingConfigHash,
    ]) {
      _requireDigest(digest, 'cell component');
    }
    return _domainHash('eval-cell-v1', <String>[
      cell.generationBundleHash,
      cell.sutModelRouteHash,
      cell.scenarioReleaseHash,
      cell.decodingConfigHash,
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
      throw const AgentEvaluationLedgerException(
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
      throw const AgentEvaluationLedgerException('trialNo must be positive');
    }
    return _domainHash('eval-trial-slot-v1', <Object>[
      executionId,
      cellId,
      trialNo,
    ]);
  }

  AgentEvaluationExecution createOrValidateExecution({
    required String executionId,
    required String experimentId,
    required List<AgentEvaluationCellDefinition> cells,
    required int createdAtMs,
  }) {
    _requireIdentity(executionId, 'executionId');
    _requireIdentity(experimentId, 'experimentId');
    if (cells.isEmpty || createdAtMs < 0) {
      throw const AgentEvaluationLedgerException(
        'execution cells and timestamp are required',
      );
    }
    return _inImmediateTransaction(() {
      final experiments = db.select(
        'SELECT * FROM eval_experiments WHERE experiment_id = ?',
        <Object?>[experimentId],
      );
      if (experiments.length != 1) {
        throw const AgentEvaluationLedgerException('experiment not found');
      }
      final experiment = experiments.single;
      final trialsPerCell = experiment['trials_per_cell'] as int;
      final cellIds = <String>[];
      for (final cell in cells) {
        final cellId = cell.cellId;
        if (cellIds.contains(cellId)) {
          throw const AgentEvaluationConflict('duplicate canonical cell');
        }
        cellIds.add(cellId);
        db.execute(
          '''INSERT OR IGNORE INTO eval_cells (
               cell_id, generation_bundle_hash, sut_model_route_hash,
               scenario_release_hash, decoding_config_hash, created_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?)''',
          <Object?>[
            cellId,
            cell.generationBundleHash,
            cell.sutModelRouteHash,
            cell.scenarioReleaseHash,
            cell.decodingConfigHash,
            createdAtMs,
          ],
        );
        final stored = db.select(
          '''SELECT * FROM eval_cells
             WHERE generation_bundle_hash = ? AND sut_model_route_hash = ?
               AND scenario_release_hash = ? AND decoding_config_hash = ?''',
          <Object?>[
            cell.generationBundleHash,
            cell.sutModelRouteHash,
            cell.scenarioReleaseHash,
            cell.decodingConfigHash,
          ],
        );
        if (stored.length != 1 || stored.single['cell_id'] != cellId) {
          throw const AgentEvaluationConflict(
            'stored cell does not match its canonical identity',
          );
        }
      }
      final sortedCellIds = cellIds.toList()..sort();
      final expectedCellSetHash = canonicalCellSetHash(sortedCellIds);
      final expectedSlotSetHash = canonicalSlotSetHash(
        sortedCellIds,
        trialsPerCell,
      );
      if (experiment['expected_cell_set_hash'] != expectedCellSetHash ||
          experiment['expected_slot_set_hash'] != expectedSlotSetHash) {
        throw const AgentEvaluationConflict(
          'execution cells do not match the frozen experiment manifest',
        );
      }

      _createOrValidateCellMembership(
        table: 'eval_experiment_cells',
        ownerColumn: 'experiment_id',
        ownerId: experimentId,
        cellIds: sortedCellIds,
      );
      final existingExecutions = db.select(
        'SELECT * FROM eval_executions WHERE execution_id = ?',
        <Object?>[executionId],
      );
      if (existingExecutions.isEmpty) {
        db.execute(
          '''INSERT INTO eval_executions (
               execution_id, experiment_id, status, expected_cell_set_hash,
               expected_slot_set_hash, created_at_ms
             ) VALUES (?, ?, 'created', ?, ?, ?)''',
          <Object?>[
            executionId,
            experimentId,
            expectedCellSetHash,
            expectedSlotSetHash,
            createdAtMs,
          ],
        );
      } else {
        final execution = existingExecutions.single;
        if (execution['experiment_id'] != experimentId ||
            execution['expected_cell_set_hash'] != expectedCellSetHash ||
            execution['expected_slot_set_hash'] != expectedSlotSetHash) {
          throw const AgentEvaluationConflict(
            'execution identity is already bound to another manifest',
          );
        }
      }
      _createOrValidateCellMembership(
        table: 'eval_execution_cells',
        ownerColumn: 'execution_id',
        ownerId: executionId,
        cellIds: sortedCellIds,
      );

      final expectedSlots = <({String slotId, String cellId, int trialNo})>[];
      for (final cellId in sortedCellIds) {
        for (var trialNo = 1; trialNo <= trialsPerCell; trialNo += 1) {
          expectedSlots.add((
            slotId: canonicalTrialSlotId(
              executionId: executionId,
              cellId: cellId,
              trialNo: trialNo,
            ),
            cellId: cellId,
            trialNo: trialNo,
          ));
        }
      }
      final storedSlots = db.select(
        '''SELECT trial_slot_id, cell_id, trial_no FROM eval_trial_slots
           WHERE execution_id = ? ORDER BY cell_id, trial_no''',
        <Object?>[executionId],
      );
      if (storedSlots.isEmpty) {
        for (final slot in expectedSlots) {
          db.execute(
            '''INSERT INTO eval_trial_slots (
                 trial_slot_id, execution_id, cell_id, trial_no, status,
                 lease_epoch, created_at_ms, updated_at_ms
               ) VALUES (?, ?, ?, ?, 'queued', 0, ?, ?)''',
            <Object?>[
              slot.slotId,
              executionId,
              slot.cellId,
              slot.trialNo,
              createdAtMs,
              createdAtMs,
            ],
          );
        }
      } else {
        if (storedSlots.length != expectedSlots.length) {
          throw const AgentEvaluationConflict(
            'execution trial set is polluted',
          );
        }
        for (var index = 0; index < expectedSlots.length; index += 1) {
          final actual = storedSlots[index];
          final expected = expectedSlots[index];
          if (actual['trial_slot_id'] != expected.slotId ||
              actual['cell_id'] != expected.cellId ||
              actual['trial_no'] != expected.trialNo) {
            throw const AgentEvaluationConflict(
              'execution trial set is not canonical',
            );
          }
        }
      }
      _createOrValidateDispatchPlan(
        executionId: executionId,
        experimentId: experimentId,
        manifestHash: experiment['manifest_hash'] as String,
        manifestJson: experiment['manifest_json'] as String,
        expectedSlotSetHash: expectedSlotSetHash,
        createdAtMs: createdAtMs,
      );
      final execution = db.select(
        'SELECT status FROM eval_executions WHERE execution_id = ?',
        <Object?>[executionId],
      ).single;
      return AgentEvaluationExecution(
        executionId: executionId,
        experimentId: experimentId,
        cellIds: List<String>.unmodifiable(sortedCellIds),
        trialSlotIds: List<String>.unmodifiable(
          expectedSlots.map((slot) => slot.slotId),
        ),
        status: execution['status'] as String,
      );
    });
  }

  AgentEvaluationLease? claimNextSlot({
    required String executionId,
    required String owner,
    required int nowMs,
    required int leaseDurationMs,
  }) {
    _requireIdentity(executionId, 'executionId');
    _requireIdentity(owner, 'owner');
    if (nowMs < 0 || leaseDurationMs <= 0) {
      throw const AgentEvaluationLedgerException('invalid lease timing');
    }
    return _inImmediateTransaction(() {
      final executionRows = db.select(
        'SELECT status FROM eval_executions WHERE execution_id = ?',
        <Object?>[executionId],
      );
      if (executionRows.length != 1) {
        throw const AgentEvaluationLedgerException('execution not found');
      }
      final executionStatus = executionRows.single['status'] as String;
      if (<String>{
        'cancelled',
        'completed',
        'failed',
      }.contains(executionStatus)) {
        return null;
      }
      final alreadyOwned = db.select(
        '''SELECT s.* FROM eval_trial_slots s
           JOIN eval_dispatch_entries d
             ON d.execution_id = s.execution_id
            AND d.trial_slot_id = s.trial_slot_id
           WHERE s.execution_id = ? AND s.lease_owner = ?
             AND status IN ('leased', 'running') AND lease_expires_at_ms > ?
           ORDER BY d.dispatch_ordinal LIMIT 1''',
        <Object?>[executionId, owner, nowMs],
      );
      if (alreadyOwned.isNotEmpty) {
        return _leaseFromRow(alreadyOwned.single);
      }
      final candidates = db.select(
        '''SELECT s.*, d.dispatch_ordinal FROM eval_trial_slots s
           JOIN eval_dispatch_entries d
             ON d.execution_id = s.execution_id
            AND d.trial_slot_id = s.trial_slot_id
           JOIN eval_cells c ON c.cell_id = s.cell_id
           JOIN eval_scenarios scenario
             ON scenario.scenario_release_hash = c.scenario_release_hash
           WHERE s.execution_id = ? AND (
             s.status = 'queued'
             OR (s.status IN ('leased', 'running')
                 AND s.lease_expires_at_ms <= ?)
           ) AND (
             scenario.isolation_mode = 'independent'
             OR NOT EXISTS (
               SELECT 1 FROM eval_trial_slots predecessor
               JOIN eval_cells predecessor_cell
                 ON predecessor_cell.cell_id = predecessor.cell_id
               JOIN eval_scenarios predecessor_scenario
                 ON predecessor_scenario.scenario_release_hash =
                    predecessor_cell.scenario_release_hash
               WHERE predecessor.execution_id = s.execution_id
                 AND predecessor.trial_no = s.trial_no
                 AND predecessor_cell.generation_bundle_hash =
                    c.generation_bundle_hash
                 AND predecessor_cell.sut_model_route_hash =
                    c.sut_model_route_hash
                 AND predecessor_cell.decoding_config_hash =
                    c.decoding_config_hash
                 AND predecessor_scenario.episode_id = scenario.episode_id
                 AND predecessor_scenario.episode_step < scenario.episode_step
               AND predecessor.status <> 'sealed'
             )
           ) AND NOT EXISTS (
             SELECT 1 FROM eval_dispatch_entries earlier
             WHERE earlier.execution_id = d.execution_id
               AND earlier.dispatch_ordinal < d.dispatch_ordinal
               AND NOT EXISTS (
                 SELECT 1 FROM eval_dispatch_events started
                 WHERE started.execution_id = earlier.execution_id
                   AND started.trial_slot_id = earlier.trial_slot_id
                   AND started.event_type = 'attemptStarted'
               )
           )
           ORDER BY CASE s.status WHEN 'queued' THEN 1 ELSE 0 END,
             d.dispatch_ordinal
           LIMIT 1''',
        <Object?>[executionId, nowMs],
      );
      if (candidates.isEmpty) return null;
      final candidate = candidates.single;
      final nextEpoch = (candidate['lease_epoch'] as int) + 1;
      final expiresAtMs = nowMs + leaseDurationMs;
      db.execute(
        '''UPDATE eval_trial_slots
           SET status = 'leased', lease_epoch = ?, lease_owner = ?,
             lease_expires_at_ms = ?, updated_at_ms = ?
           WHERE trial_slot_id = ? AND lease_epoch = ? AND (
             status = 'queued'
             OR (status IN ('leased', 'running') AND lease_expires_at_ms <= ?)
           )''',
        <Object?>[
          nextEpoch,
          owner,
          expiresAtMs,
          nowMs,
          candidate['trial_slot_id'],
          candidate['lease_epoch'],
          nowMs,
        ],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationConflict('slot claim raced');
      }
      _appendDispatchEvent(
        executionId: executionId,
        trialSlotId: candidate['trial_slot_id'] as String,
        eventType: candidate['status'] == 'queued' ? 'claimed' : 'reclaimed',
        leaseEpoch: nextEpoch,
        leaseOwner: owner,
        leaseExpiresAtMs: expiresAtMs,
        occurredAtMs: nowMs,
      );
      if (executionStatus == 'created' || executionStatus == 'ready') {
        db.execute(
          '''UPDATE eval_executions
             SET status = 'running', started_at_ms = COALESCE(started_at_ms, ?)
             WHERE execution_id = ? AND status IN ('created', 'ready')''',
          <Object?>[nowMs, executionId],
        );
      }
      return AgentEvaluationLease(
        trialSlotId: candidate['trial_slot_id'] as String,
        executionId: executionId,
        cellId: candidate['cell_id'] as String,
        trialNo: candidate['trial_no'] as int,
        epoch: nextEpoch,
        owner: owner,
        expiresAtMs: expiresAtMs,
        status: 'leased',
      );
    });
  }

  AgentEvaluationLease renewLease({
    required AgentEvaluationLease lease,
    required int nowMs,
    required int leaseDurationMs,
  }) {
    if (nowMs < 0 || leaseDurationMs <= 0) {
      throw const AgentEvaluationLedgerException('invalid lease timing');
    }
    return _inImmediateTransaction(() {
      final active = _requireActiveLease(lease, nowMs);
      final currentExpiry = active['lease_expires_at_ms'] as int;
      final requestedExpiry = nowMs + leaseDurationMs;
      final expiresAtMs = requestedExpiry > currentExpiry
          ? requestedExpiry
          : currentExpiry;
      db.execute(
        '''UPDATE eval_trial_slots SET lease_expires_at_ms = ?, updated_at_ms = ?
           WHERE trial_slot_id = ? AND lease_epoch = ? AND lease_owner = ?
             AND status IN ('leased', 'running') AND lease_expires_at_ms > ?''',
        <Object?>[
          expiresAtMs,
          nowMs,
          lease.trialSlotId,
          lease.epoch,
          lease.owner,
          nowMs,
        ],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationLeaseLost('lease renewal lost fencing race');
      }
      _appendDispatchEvent(
        executionId: active['execution_id'] as String,
        trialSlotId: lease.trialSlotId,
        eventType: 'renewed',
        leaseEpoch: lease.epoch,
        leaseOwner: lease.owner,
        leaseExpiresAtMs: expiresAtMs,
        occurredAtMs: nowMs,
      );
      return AgentEvaluationLease(
        trialSlotId: lease.trialSlotId,
        executionId: active['execution_id'] as String,
        cellId: active['cell_id'] as String,
        trialNo: active['trial_no'] as int,
        epoch: lease.epoch,
        owner: lease.owner,
        expiresAtMs: expiresAtMs,
        status: active['status'] as String,
      );
    });
  }

  AgentEvaluationAttempt startAttempt({
    required AgentEvaluationLease lease,
    required int attemptNo,
    required String runId,
    required String kind,
    required int startedAtMs,
  }) {
    _requireIdentity(runId, 'runId');
    if (attemptNo <= 0 || !<String>{'content', 'transport'}.contains(kind)) {
      throw const AgentEvaluationLedgerException('invalid trial attempt');
    }
    return _inImmediateTransaction(() {
      _requireActiveLease(lease, startedAtMs);
      final existing = db.select(
        '''SELECT * FROM eval_trial_attempts
           WHERE trial_slot_id = ? AND attempt_no = ?''',
        <Object?>[lease.trialSlotId, attemptNo],
      );
      if (existing.isNotEmpty) {
        final attempt = _attemptFromRow(existing.single);
        if (attempt.runId == runId &&
            attempt.kind == kind &&
            attempt.leaseEpoch == lease.epoch &&
            attempt.leaseOwner == lease.owner) {
          _appendAttemptStartedEventIfMissing(
            lease: lease,
            attemptNo: attemptNo,
            runId: runId,
            occurredAtMs: startedAtMs,
          );
          return attempt;
        }
        if (attempt.runId == runId &&
            attempt.kind == kind &&
            attempt.status == 'started' &&
            attempt.leaseEpoch < lease.epoch) {
          db.execute(
            '''UPDATE eval_trial_attempts
               SET lease_epoch = ?, lease_owner = ?
               WHERE trial_slot_id = ? AND attempt_no = ? AND status = 'started'
                 AND lease_epoch = ? AND lease_owner = ?''',
            <Object?>[
              lease.epoch,
              lease.owner,
              lease.trialSlotId,
              attemptNo,
              attempt.leaseEpoch,
              attempt.leaseOwner,
            ],
          );
          if (db.updatedRows != 1) {
            throw const AgentEvaluationConflict('attempt recovery raced');
          }
          _appendAttemptStartedEventIfMissing(
            lease: lease,
            attemptNo: attemptNo,
            runId: runId,
            occurredAtMs: startedAtMs,
          );
          return AgentEvaluationAttempt(
            trialSlotId: attempt.trialSlotId,
            attemptNo: attempt.attemptNo,
            runId: attempt.runId,
            kind: attempt.kind,
            status: attempt.status,
            leaseEpoch: lease.epoch,
            leaseOwner: lease.owner,
            startedAtMs: attempt.startedAtMs,
          );
        }
        throw const AgentEvaluationConflict(
          'attempt identity is already occupied',
        );
      }
      try {
        db.execute(
          '''INSERT INTO eval_trial_attempts (
               trial_slot_id, attempt_no, run_id, kind, status, lease_epoch,
               lease_owner, started_at_ms
             ) VALUES (?, ?, ?, ?, 'started', ?, ?, ?)''',
          <Object?>[
            lease.trialSlotId,
            attemptNo,
            runId,
            kind,
            lease.epoch,
            lease.owner,
            startedAtMs,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationConflict('attempt insert conflict: $error');
      }
      db.execute(
        '''UPDATE eval_trial_slots SET status = 'running', updated_at_ms = ?
           WHERE trial_slot_id = ? AND lease_epoch = ? AND lease_owner = ?
             AND status IN ('leased', 'running') AND lease_expires_at_ms > ?''',
        <Object?>[
          startedAtMs,
          lease.trialSlotId,
          lease.epoch,
          lease.owner,
          startedAtMs,
        ],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationLeaseLost('attempt lost slot lease');
      }
      _appendAttemptStartedEventIfMissing(
        lease: lease,
        attemptNo: attemptNo,
        runId: runId,
        occurredAtMs: startedAtMs,
      );
      return AgentEvaluationAttempt(
        trialSlotId: lease.trialSlotId,
        attemptNo: attemptNo,
        runId: runId,
        kind: kind,
        status: 'started',
        leaseEpoch: lease.epoch,
        leaseOwner: lease.owner,
        startedAtMs: startedAtMs,
      );
    });
  }

  AgentEvaluationAttempt finishAttempt({
    required AgentEvaluationLease lease,
    required int attemptNo,
    required String status,
    required String finalKind,
    required int finishedAtMs,
  }) {
    if (!<String>{'completed', 'failed', 'cancelled'}.contains(status)) {
      throw const AgentEvaluationLedgerException(
        'invalid terminal attempt status',
      );
    }
    if (!<String>{'content', 'transport'}.contains(finalKind)) {
      throw const AgentEvaluationLedgerException(
        'invalid terminal attempt kind',
      );
    }
    return _inImmediateTransaction(() {
      _requireActiveLease(lease, finishedAtMs);
      final rows = db.select(
        '''SELECT * FROM eval_trial_attempts
           WHERE trial_slot_id = ? AND attempt_no = ?''',
        <Object?>[lease.trialSlotId, attemptNo],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationLedgerException('attempt not found');
      }
      final attempt = _attemptFromRow(rows.single);
      if (attempt.leaseEpoch != lease.epoch ||
          attempt.leaseOwner != lease.owner) {
        throw const AgentEvaluationLeaseLost(
          'attempt belongs to a previous lease epoch',
        );
      }
      if (attempt.status != 'started') {
        if (attempt.status == status &&
            attempt.kind == finalKind &&
            attempt.finishedAtMs == finishedAtMs) {
          return attempt;
        }
        throw const AgentEvaluationConflict('attempt is already terminal');
      }
      db.execute(
        '''UPDATE eval_trial_attempts
           SET status = ?, kind = ?, finished_at_ms = ?
           WHERE trial_slot_id = ? AND attempt_no = ? AND status = 'started'
             AND lease_epoch = ? AND lease_owner = ?''',
        <Object?>[
          status,
          finalKind,
          finishedAtMs,
          lease.trialSlotId,
          attemptNo,
          lease.epoch,
          lease.owner,
        ],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationConflict('attempt completion raced');
      }
      return AgentEvaluationAttempt(
        trialSlotId: attempt.trialSlotId,
        attemptNo: attempt.attemptNo,
        runId: attempt.runId,
        kind: finalKind,
        status: status,
        leaseEpoch: attempt.leaseEpoch,
        leaseOwner: attempt.leaseOwner,
        startedAtMs: attempt.startedAtMs,
        finishedAtMs: finishedAtMs,
      );
    });
  }

  AgentEvaluationObservation appendObservation({
    required AgentEvaluationLease lease,
    required AgentEvaluationObservationInput observation,
  }) {
    _validateObservation(observation);
    try {
      AgentEvaluationObservationCodecRegistry.decode(
        stageId: observation.stageId,
        kind: observation.kind,
        itemKey: observation.itemKey,
        valueJson: observation.valueJson,
        proseHash: observation.proseHash,
      );
    } on AgentEvaluationObservationCodecException catch (error) {
      throw AgentEvaluationLedgerException(
        'typed observation rejected: ${error.message}',
      );
    }
    return _inImmediateTransaction(() {
      _requireActiveLease(lease, observation.createdAtMs);
      final existing = db.select(
        '''SELECT * FROM eval_observations
           WHERE trial_slot_id = ? AND stage_id = ? AND kind = ?
             AND attempt_no = ? AND item_key = ?''',
        <Object?>[
          lease.trialSlotId,
          observation.stageId,
          observation.kind,
          observation.attemptNo,
          observation.itemKey,
        ],
      );
      if (existing.isNotEmpty) {
        final row = existing.single;
        if (row['evidence_hash'] == observation.evidenceHash &&
            row['value_json'] == observation.valueJson &&
            row['evaluation_bundle_hash'] == observation.evaluationBundleHash &&
            row['prose_hash'] == observation.proseHash) {
          return _observationFromRow(row);
        }
        throw const AgentEvaluationConflict(
          'logical observation already has different evidence',
        );
      }
      try {
        db.execute(
          '''INSERT INTO eval_observations (
               observation_id, trial_slot_id, attempt_no, sequence_no,
               stage_id, kind, item_key, value_json, evidence_hash,
               evaluation_bundle_hash, prose_hash, lease_epoch, lease_owner,
               created_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          <Object?>[
            observation.observationId,
            lease.trialSlotId,
            observation.attemptNo,
            observation.sequenceNo,
            observation.stageId,
            observation.kind,
            observation.itemKey,
            observation.valueJson,
            observation.evidenceHash,
            observation.evaluationBundleHash,
            observation.proseHash,
            lease.epoch,
            lease.owner,
            observation.createdAtMs,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationConflict('observation insert conflict: $error');
      }
      return AgentEvaluationObservation(
        observationId: observation.observationId,
        trialSlotId: lease.trialSlotId,
        input: observation,
        leaseEpoch: lease.epoch,
        leaseOwner: lease.owner,
      );
    });
  }

  /// Persists the runner-owned bridge between a formal attempt and the
  /// normal production commit transaction. Caller-returned JSON cannot create
  /// this row; the runner first recomputes the sandbox proof independently.
  void appendProductionAuthorityReceipt({
    required AgentEvaluationLease lease,
    required int attemptNo,
    required String authorityReceiptHash,
    required String authorityReleaseHash,
    required String attemptRunId,
    required String sandboxDatabasePath,
    required String candidateHash,
    required String commitReceiptId,
    required String transactionEvidenceHash,
    required String proseHash,
    required String generationBundleHash,
    required String executorReleaseHash,
    required int createdAtMs,
  }) {
    for (final entry in <MapEntry<String, String>>[
      MapEntry('authorityReceiptHash', authorityReceiptHash),
      MapEntry('authorityReleaseHash', authorityReleaseHash),
      MapEntry('candidateHash', candidateHash),
      MapEntry('transactionEvidenceHash', transactionEvidenceHash),
      MapEntry('proseHash', proseHash),
      MapEntry('generationBundleHash', generationBundleHash),
      MapEntry('executorReleaseHash', executorReleaseHash),
    ]) {
      _requireDigest(entry.value, entry.key);
    }
    _requireIdentity(attemptRunId, 'attemptRunId');
    _requireIdentity(sandboxDatabasePath, 'sandboxDatabasePath');
    _requireIdentity(commitReceiptId, 'commitReceiptId');
    if (attemptNo <= 0 || createdAtMs < 0) {
      throw const AgentEvaluationLedgerException(
        'production authority attempt and time are invalid',
      );
    }
    _inImmediateTransaction(() {
      _requireActiveLease(lease, createdAtMs);
      final attempts = db.select(
        '''SELECT run_id, lease_epoch, lease_owner
           FROM eval_trial_attempts
           WHERE trial_slot_id = ? AND attempt_no = ?''',
        <Object?>[lease.trialSlotId, attemptNo],
      );
      if (attempts.length != 1 ||
          attempts.single['run_id'] != attemptRunId ||
          attempts.single['lease_epoch'] != lease.epoch ||
          attempts.single['lease_owner'] != lease.owner) {
        throw const AgentEvaluationConflict(
          'production authority receipt belongs to another attempt',
        );
      }
      final existing = db.select(
        '''SELECT * FROM eval_production_authority_receipts
           WHERE trial_slot_id = ? AND attempt_no = ?''',
        <Object?>[lease.trialSlotId, attemptNo],
      );
      if (existing.isNotEmpty) {
        final row = existing.single;
        if (row['authority_receipt_hash'] == authorityReceiptHash &&
            row['attempt_run_id'] == attemptRunId &&
            row['candidate_hash'] == candidateHash &&
            row['commit_receipt_id'] == commitReceiptId &&
            row['transaction_evidence_hash'] == transactionEvidenceHash &&
            row['prose_hash'] == proseHash &&
            row['generation_bundle_hash'] == generationBundleHash &&
            row['executor_release_hash'] == executorReleaseHash) {
          return;
        }
        throw const AgentEvaluationConflict(
          'production authority receipt already has different evidence',
        );
      }
      db.execute(
        '''INSERT INTO eval_production_authority_receipts (
             authority_receipt_hash, authority_release_hash, execution_id,
             trial_slot_id, attempt_no, attempt_run_id,
             sandbox_database_path, candidate_hash, commit_receipt_id,
             transaction_evidence_hash, prose_hash, generation_bundle_hash,
             executor_release_hash, lease_epoch, lease_owner, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          authorityReceiptHash,
          authorityReleaseHash,
          lease.executionId,
          lease.trialSlotId,
          attemptNo,
          attemptRunId,
          sandboxDatabasePath,
          candidateHash,
          commitReceiptId,
          transactionEvidenceHash,
          proseHash,
          generationBundleHash,
          executorReleaseHash,
          lease.epoch,
          lease.owner,
          createdAtMs,
        ],
      );
    });
  }

  AgentEvaluationSandboxRecoveryCheckpoint appendSandboxRecoveryCheckpoint({
    required AgentEvaluationLease lease,
    required int attemptNo,
    required String attemptRunId,
    required String cellId,
    required String manifestHash,
    required String isolationTrialId,
    required String isolationMode,
    required String stage,
    required String candidateHash,
    required String databasePath,
    required String databaseFileHash,
    required int databaseFileSize,
    required String stateProjectionHash,
    required int createdAtMs,
  }) {
    final checkpointNo = sandboxRecoveryStageOrdinals[stage];
    if (checkpointNo == null ||
        attemptNo <= 0 ||
        databaseFileSize <= 0 ||
        createdAtMs < 0) {
      throw const AgentEvaluationLedgerException(
        'invalid sandbox recovery checkpoint metadata',
      );
    }
    for (final entry in <MapEntry<String, String>>[
      MapEntry('cellId', cellId),
      MapEntry('manifestHash', manifestHash),
      MapEntry('candidateHash', candidateHash),
      MapEntry('databaseFileHash', databaseFileHash),
      MapEntry('stateProjectionHash', stateProjectionHash),
    ]) {
      _requireDigest(entry.value, entry.key);
    }
    for (final entry in <MapEntry<String, String>>[
      MapEntry('attemptRunId', attemptRunId),
      MapEntry('isolationTrialId', isolationTrialId),
      MapEntry('databasePath', databasePath),
    ]) {
      _requireIdentity(entry.value, entry.key);
    }
    if (!<String>{'independent', 'episode'}.contains(isolationMode)) {
      throw const AgentEvaluationLedgerException(
        'invalid sandbox recovery isolation mode',
      );
    }
    return _inImmediateTransaction(() {
      _requireActiveLease(lease, createdAtMs);
      final attemptRows = db.select(
        '''SELECT run_id, status, lease_epoch, lease_owner
           FROM eval_trial_attempts
           WHERE trial_slot_id = ? AND attempt_no = ?''',
        <Object?>[lease.trialSlotId, attemptNo],
      );
      if (attemptRows.length != 1 ||
          attemptRows.single['run_id'] != attemptRunId ||
          attemptRows.single['status'] != 'started' ||
          attemptRows.single['lease_epoch'] != lease.epoch ||
          attemptRows.single['lease_owner'] != lease.owner) {
        throw const AgentEvaluationConflict(
          'sandbox recovery checkpoint belongs to another attempt lease',
        );
      }
      final chain = _readAndVerifySandboxRecoveryChain(
        trialSlotId: lease.trialSlotId,
        attemptNo: attemptNo,
      );
      if (chain.length >= checkpointNo) {
        final existing = chain[checkpointNo - 1];
        if (existing.stage == stage &&
            existing.attemptRunId == attemptRunId &&
            existing.cellId == cellId &&
            existing.manifestHash == manifestHash &&
            existing.isolationTrialId == isolationTrialId &&
            existing.isolationMode == isolationMode &&
            existing.candidateHash == candidateHash) {
          return existing;
        }
        throw const AgentEvaluationConflict(
          'sandbox recovery stage is already bound differently',
        );
      }
      if (chain.length + 1 != checkpointNo) {
        throw const AgentEvaluationConflict(
          'sandbox recovery stages must be appended in order',
        );
      }
      final previous = chain.isEmpty ? null : chain.last;
      final originalLeaseEpoch = previous?.originalLeaseEpoch ?? lease.epoch;
      final originalLeaseOwner = previous?.originalLeaseOwner ?? lease.owner;
      final baseCheckpointHash = previous?.checkpointHash;
      final checkpointValue = _sandboxRecoveryCheckpointValue(
        executionId: lease.executionId,
        trialSlotId: lease.trialSlotId,
        attemptNo: attemptNo,
        attemptRunId: attemptRunId,
        originalLeaseEpoch: originalLeaseEpoch,
        originalLeaseOwner: originalLeaseOwner,
        writerLeaseEpoch: lease.epoch,
        writerLeaseOwner: lease.owner,
        cellId: cellId,
        manifestHash: manifestHash,
        isolationTrialId: isolationTrialId,
        isolationMode: isolationMode,
        checkpointNo: checkpointNo,
        stage: stage,
        candidateHash: candidateHash,
        databasePath: databasePath,
        databaseFileHash: databaseFileHash,
        databaseFileSize: databaseFileSize,
        stateProjectionHash: stateProjectionHash,
        baseCheckpointHash: baseCheckpointHash,
        createdAtMs: createdAtMs,
      );
      final checkpointHash = _domainHash(
        'eval-sandbox-recovery-checkpoint-v1',
        checkpointValue,
      );
      try {
        db.execute(
          '''INSERT INTO eval_sandbox_recovery_checkpoints (
               checkpoint_hash, execution_id, trial_slot_id, attempt_no,
               attempt_run_id, original_lease_epoch, original_lease_owner,
               writer_lease_epoch, writer_lease_owner, cell_id, manifest_hash,
               isolation_trial_id, isolation_mode, checkpoint_no, stage,
               candidate_hash, database_path, database_file_hash,
               database_file_size, state_projection_hash,
               base_checkpoint_hash, created_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          <Object?>[
            checkpointHash,
            lease.executionId,
            lease.trialSlotId,
            attemptNo,
            attemptRunId,
            originalLeaseEpoch,
            originalLeaseOwner,
            lease.epoch,
            lease.owner,
            cellId,
            manifestHash,
            isolationTrialId,
            isolationMode,
            checkpointNo,
            stage,
            candidateHash,
            databasePath,
            databaseFileHash,
            databaseFileSize,
            stateProjectionHash,
            baseCheckpointHash,
            createdAtMs,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationConflict(
          'sandbox recovery checkpoint insert conflict: $error',
        );
      }
      return AgentEvaluationSandboxRecoveryCheckpoint(
        checkpointHash: checkpointHash,
        executionId: lease.executionId,
        trialSlotId: lease.trialSlotId,
        attemptNo: attemptNo,
        attemptRunId: attemptRunId,
        originalLeaseEpoch: originalLeaseEpoch,
        originalLeaseOwner: originalLeaseOwner,
        writerLeaseEpoch: lease.epoch,
        writerLeaseOwner: lease.owner,
        cellId: cellId,
        manifestHash: manifestHash,
        isolationTrialId: isolationTrialId,
        isolationMode: isolationMode,
        checkpointNo: checkpointNo,
        stage: stage,
        candidateHash: candidateHash,
        databasePath: databasePath,
        databaseFileHash: databaseFileHash,
        databaseFileSize: databaseFileSize,
        stateProjectionHash: stateProjectionHash,
        baseCheckpointHash: baseCheckpointHash,
        createdAtMs: createdAtMs,
      );
    });
  }

  AgentEvaluationSandboxRecoveryCheckpoint?
  readLatestSandboxRecoveryCheckpoint({
    required String executionId,
    required String trialSlotId,
    required int attemptNo,
    required String attemptRunId,
    required String cellId,
    required String manifestHash,
    required String isolationTrialId,
    required String isolationMode,
  }) {
    final chain = _readAndVerifySandboxRecoveryChain(
      trialSlotId: trialSlotId,
      attemptNo: attemptNo,
    );
    if (chain.isEmpty) return null;
    final head = chain.last;
    if (head.executionId != executionId ||
        head.attemptRunId != attemptRunId ||
        head.cellId != cellId ||
        head.manifestHash != manifestHash ||
        head.isolationTrialId != isolationTrialId ||
        head.isolationMode != isolationMode) {
      throw const AgentEvaluationConflict(
        'sandbox recovery checkpoint contradicts the claimed slot',
      );
    }
    return head;
  }

  List<String> readTerminalSandboxRecoverySnapshotPaths({
    required String executionId,
    required String trialSlotId,
  }) {
    _requireIdentity(executionId, 'executionId');
    _requireIdentity(trialSlotId, 'trialSlotId');
    final slotRows = db.select(
      '''SELECT execution_id, status FROM eval_trial_slots
         WHERE trial_slot_id = ?''',
      <Object?>[trialSlotId],
    );
    if (slotRows.length != 1 ||
        slotRows.single['execution_id'] != executionId ||
        slotRows.single['status'] != 'sealed') {
      throw const AgentEvaluationConflict(
        'sandbox recovery cleanup requires the exact terminal slot',
      );
    }
    final paths = db
        .select(
          '''SELECT database_path FROM eval_sandbox_recovery_checkpoints
             WHERE execution_id = ? AND trial_slot_id = ?
             ORDER BY attempt_no, checkpoint_no''',
          <Object?>[executionId, trialSlotId],
        )
        .map((row) => row['database_path'] as String)
        .toList(growable: false);
    return List<String>.unmodifiable(paths);
  }

  /// Runs a candidate/checkpoint-like database write under the same fencing
  /// transaction as lease validation. Callers must not retain [Database] or
  /// start another transaction inside [mutation].
  T performFencedMutation<T>({
    required AgentEvaluationLease lease,
    required int nowMs,
    required T Function(Database database) mutation,
  }) {
    return _inImmediateTransaction(() {
      _requireActiveLease(lease, nowMs);
      return mutation(db);
    });
  }

  AgentEvaluationSealedResult sealSlot({
    required AgentEvaluationLease lease,
    required String result,
    required List<AgentEvaluationEvidenceKey> expectedEvidence,
    required int sealedAtMs,
    AgentEvaluationSandboxCommit? sandboxCommit,
    int? completeContentAttemptNo,
  }) {
    if (!<String>{'pass', 'fail', 'insufficientEvidence'}.contains(result) ||
        expectedEvidence.isEmpty) {
      throw const AgentEvaluationLedgerException('invalid slot seal request');
    }
    final expectedKeys =
        expectedEvidence.map((evidence) => evidence.canonicalKey).toList()
          ..sort();
    _requireUnique(expectedKeys, 'expected evidence');
    return _inImmediateTransaction(() {
      _requireActiveLease(lease, sealedAtMs);
      if (completeContentAttemptNo != null) {
        final rows = db.select(
          '''SELECT kind, status, lease_epoch, lease_owner
             FROM eval_trial_attempts
             WHERE trial_slot_id = ? AND attempt_no = ?''',
          <Object?>[lease.trialSlotId, completeContentAttemptNo],
        );
        if (rows.length != 1 ||
            rows.single['kind'] != 'content' ||
            rows.single['status'] != 'started' ||
            rows.single['lease_epoch'] != lease.epoch ||
            rows.single['lease_owner'] != lease.owner) {
          throw const AgentEvaluationConflict(
            'slot seal cannot complete the requested content attempt',
          );
        }
        db.execute(
          '''UPDATE eval_trial_attempts
             SET status = 'completed', finished_at_ms = ?
             WHERE trial_slot_id = ? AND attempt_no = ? AND kind = 'content'
               AND status = 'started' AND lease_epoch = ?
               AND lease_owner = ?''',
          <Object?>[
            sealedAtMs,
            lease.trialSlotId,
            completeContentAttemptNo,
            lease.epoch,
            lease.owner,
          ],
        );
        if (db.updatedRows != 1) {
          throw const AgentEvaluationConflict(
            'content completion raced with slot seal',
          );
        }
      }
      AgentEvaluationSandboxGeneration? committedSandbox;
      if (sandboxCommit != null) {
        committedSandbox = _commitSandboxGeneration(
          lease: lease,
          commit: sandboxCommit,
          createdAtMs: sealedAtMs,
        );
      }
      final recoveryChain = completeContentAttemptNo == null
          ? const <AgentEvaluationSandboxRecoveryCheckpoint>[]
          : _readAndVerifySandboxRecoveryChain(
              trialSlotId: lease.trialSlotId,
              attemptNo: completeContentAttemptNo,
            );
      final recoveryHead = recoveryChain.isEmpty ? null : recoveryChain.last;
      if (recoveryHead != null && committedSandbox == null) {
        throw const AgentEvaluationConflict(
          'recoverable sandbox attempt cannot seal without a generation',
        );
      }
      final attempts = db.select(
        '''SELECT * FROM eval_trial_attempts
           WHERE trial_slot_id = ? ORDER BY attempt_no''',
        <Object?>[lease.trialSlotId],
      );
      final contentAttempts = attempts
          .where((row) => row['kind'] == 'content')
          .toList(growable: false);
      final transportAttempts = attempts
          .where((row) => row['kind'] == 'transport')
          .toList(growable: false);
      if (contentAttempts.length > 1 ||
          (contentAttempts.length == 1 &&
              contentAttempts.single['status'] != 'completed')) {
        throw const AgentEvaluationConflict(
          'slot has an invalid content attempt set',
        );
      }
      if (result == 'pass' && contentAttempts.length != 1) {
        throw const AgentEvaluationConflict(
          'passing slot requires one completed content attempt',
        );
      }
      if (contentAttempts.isEmpty &&
          (result == 'pass' ||
              transportAttempts.isEmpty ||
              transportAttempts.any((row) => row['status'] == 'started'))) {
        throw const AgentEvaluationConflict(
          'contentless slot requires terminal transport evidence',
        );
      }
      final observations = db.select(
        '''SELECT * FROM eval_observations WHERE trial_slot_id = ?
           ORDER BY attempt_no, stage_id, kind, item_key''',
        <Object?>[lease.trialSlotId],
      );
      final actualKeys =
          observations
              .map(
                (row) => AgentEvaluationEvidenceKey(
                  attemptNo: row['attempt_no'] as int,
                  stageId: row['stage_id'] as String,
                  kind: row['kind'] as String,
                  itemKey: row['item_key'] as String,
                ).canonicalKey,
              )
              .toList()
            ..sort();
      if (!_sameList(actualKeys, expectedKeys)) {
        throw const AgentEvaluationConflict(
          'slot evidence does not match expected cardinality and keys',
        );
      }
      final evidenceHash = _domainHash(
        'eval-sealed-evidence-v1',
        <String, Object?>{
          'slotId': lease.trialSlotId,
          'sandboxGenerationHash': committedSandbox?.generationHash,
          'sandboxRecoveryCheckpointHash': recoveryHead?.checkpointHash,
          'contentAttempt': contentAttempts.isEmpty
              ? null
              : <String, Object?>{
                  'attemptNo': contentAttempts.single['attempt_no'],
                  'runId': contentAttempts.single['run_id'],
                  'status': contentAttempts.single['status'],
                },
          'attempts': attempts
              .map(
                (row) => <String, Object?>{
                  'attemptNo': row['attempt_no'],
                  'runId': row['run_id'],
                  'kind': row['kind'],
                  'status': row['status'],
                  'leaseEpoch': row['lease_epoch'],
                  'leaseOwner': row['lease_owner'],
                  'startedAtMs': row['started_at_ms'],
                  'finishedAtMs': row['finished_at_ms'],
                },
              )
              .toList(growable: false),
          'observations': observations
              .map(
                (row) => <String, Object?>{
                  'attemptNo': row['attempt_no'],
                  'stageId': row['stage_id'],
                  'kind': row['kind'],
                  'itemKey': row['item_key'],
                  'evidenceHash': row['evidence_hash'],
                  'evaluationBundleHash': row['evaluation_bundle_hash'],
                  'proseHash': row['prose_hash'],
                },
              )
              .toList(growable: false),
        },
      );
      db.execute(
        '''UPDATE eval_trial_slots
           SET status = 'sealed', result = ?, lease_owner = NULL,
             lease_expires_at_ms = NULL, sealed_evidence_hash = ?,
             updated_at_ms = ?, sealed_at_ms = ?
           WHERE trial_slot_id = ? AND lease_epoch = ? AND lease_owner = ?
             AND status IN ('leased', 'running') AND lease_expires_at_ms > ?''',
        <Object?>[
          result,
          evidenceHash,
          sealedAtMs,
          sealedAtMs,
          lease.trialSlotId,
          lease.epoch,
          lease.owner,
          sealedAtMs,
        ],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationLeaseLost('slot seal lost fencing race');
      }
      _appendDispatchEvent(
        executionId: lease.executionId,
        trialSlotId: lease.trialSlotId,
        eventType: 'sealed',
        leaseEpoch: lease.epoch,
        leaseOwner: lease.owner,
        sealedEvidenceHash: evidenceHash,
        occurredAtMs: sealedAtMs,
      );
      if (recoveryHead != null && committedSandbox != null) {
        db.execute(
          '''INSERT INTO eval_sandbox_recovery_seals (
               trial_slot_id, checkpoint_hash, generation_hash,
               sealed_evidence_hash, created_at_ms
             ) VALUES (?, ?, ?, ?, ?)''',
          <Object?>[
            lease.trialSlotId,
            recoveryHead.checkpointHash,
            committedSandbox.generationHash,
            evidenceHash,
            sealedAtMs,
          ],
        );
      }
      return AgentEvaluationSealedResult(
        trialSlotId: lease.trialSlotId,
        result: result,
        evidenceHash: evidenceHash,
        sealedAtMs: sealedAtMs,
      );
    });
  }

  AgentEvaluationSandboxGeneration? readLatestSandboxGeneration({
    required String executionId,
    required String isolationTrialId,
  }) {
    _requireIdentity(executionId, 'executionId');
    _requireIdentity(isolationTrialId, 'isolationTrialId');
    final rows = db.select(
      '''SELECT * FROM eval_sandbox_generations
         WHERE execution_id = ? AND isolation_trial_id = ?
         ORDER BY generation_no DESC LIMIT 1''',
      <Object?>[executionId, isolationTrialId],
    );
    return rows.isEmpty ? null : _sandboxGenerationFromRow(rows.single);
  }

  AgentEvaluationSandboxGeneration _commitSandboxGeneration({
    required AgentEvaluationLease lease,
    required AgentEvaluationSandboxCommit commit,
    required int createdAtMs,
  }) {
    _requireIdentity(commit.isolationTrialId, 'isolationTrialId');
    _requireIdentity(commit.databasePath, 'databasePath');
    _requireDigest(commit.databaseFileHash, 'databaseFileHash');
    if (!<String>{'independent', 'episode'}.contains(commit.isolationMode)) {
      throw const AgentEvaluationLedgerException(
        'invalid sandbox isolation mode',
      );
    }
    if (commit.baseGenerationHash != null) {
      _requireDigest(commit.baseGenerationHash!, 'baseGenerationHash');
    }
    final rows = db.select(
      '''SELECT * FROM eval_sandbox_generations
         WHERE execution_id = ? AND isolation_trial_id = ?
         ORDER BY generation_no DESC LIMIT 1''',
      <Object?>[lease.executionId, commit.isolationTrialId],
    );
    final previous = rows.isEmpty
        ? null
        : _sandboxGenerationFromRow(rows.single);
    if (previous?.generationHash != commit.baseGenerationHash) {
      throw const AgentEvaluationConflict(
        'sandbox generation parent is stale or missing',
      );
    }
    if (commit.isolationMode == 'independent' && previous != null) {
      throw const AgentEvaluationConflict(
        'independent sandbox cannot inherit a prior generation',
      );
    }
    final generationNo = (previous?.generationNo ?? 0) + 1;
    final generationHash =
        _domainHash('eval-sandbox-generation-v1', <String, Object?>{
          'executionId': lease.executionId,
          'isolationTrialId': commit.isolationTrialId,
          'generationNo': generationNo,
          'sourceTrialSlotId': lease.trialSlotId,
          'baseGenerationHash': commit.baseGenerationHash,
          'isolationMode': commit.isolationMode,
          'databasePath': commit.databasePath,
          'databaseFileHash': commit.databaseFileHash,
          'leaseEpoch': lease.epoch,
          'leaseOwner': lease.owner,
        });
    db.execute(
      '''INSERT INTO eval_sandbox_generations (
           generation_hash, execution_id, isolation_trial_id, generation_no,
           source_trial_slot_id, base_generation_hash, isolation_mode,
           database_path, database_file_hash, lease_epoch, lease_owner,
           created_at_ms
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        generationHash,
        lease.executionId,
        commit.isolationTrialId,
        generationNo,
        lease.trialSlotId,
        commit.baseGenerationHash,
        commit.isolationMode,
        commit.databasePath,
        commit.databaseFileHash,
        lease.epoch,
        lease.owner,
        createdAtMs,
      ],
    );
    return AgentEvaluationSandboxGeneration(
      generationHash: generationHash,
      executionId: lease.executionId,
      isolationTrialId: commit.isolationTrialId,
      generationNo: generationNo,
      sourceTrialSlotId: lease.trialSlotId,
      baseGenerationHash: commit.baseGenerationHash,
      isolationMode: commit.isolationMode,
      databasePath: commit.databasePath,
      databaseFileHash: commit.databaseFileHash,
      leaseEpoch: lease.epoch,
      leaseOwner: lease.owner,
      createdAtMs: createdAtMs,
    );
  }

  AgentEvaluationSealedResult? readSealedResult(String trialSlotId) {
    _requireIdentity(trialSlotId, 'trialSlotId');
    final rows = db.select(
      '''SELECT result, sealed_evidence_hash, sealed_at_ms
         FROM eval_trial_slots WHERE trial_slot_id = ? AND status = 'sealed' ''',
      <Object?>[trialSlotId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return AgentEvaluationSealedResult(
      trialSlotId: trialSlotId,
      result: row['result'] as String,
      evidenceHash: row['sealed_evidence_hash'] as String,
      sealedAtMs: row['sealed_at_ms'] as int,
    );
  }

  void _createOrValidateDispatchPlan({
    required String executionId,
    required String experimentId,
    required String manifestHash,
    required String manifestJson,
    required String expectedSlotSetHash,
    required int createdAtMs,
  }) {
    Object? seedPolicy = const <String, Object?>{};
    try {
      final decoded = jsonDecode(manifestJson);
      if (decoded is Map<String, Object?>) {
        seedPolicy = decoded['seedPolicy'] ?? const <String, Object?>{};
      }
    } on FormatException {
      throw const AgentEvaluationConflict(
        'experiment manifest JSON is not canonical JSON',
      );
    }
    final rows = db.select(
      '''SELECT s.trial_slot_id, s.cell_id, s.trial_no,
           c.generation_bundle_hash, c.sut_model_route_hash,
           c.scenario_release_hash, c.decoding_config_hash,
           scenario.isolation_mode, scenario.episode_id,
           scenario.episode_step
         FROM eval_trial_slots s
         JOIN eval_cells c ON c.cell_id = s.cell_id
         JOIN eval_scenarios scenario
           ON scenario.scenario_release_hash = c.scenario_release_hash
         WHERE s.execution_id = ?''',
      <Object?>[executionId],
    );
    final plan = AgentEvaluationDispatchPlanner.build(
      experimentId: experimentId,
      manifestHash: manifestHash,
      seedPolicy: seedPolicy,
      expectedSlotSetHash: expectedSlotSetHash,
      descriptors: rows.map(
        (row) => AgentEvaluationDispatchDescriptor(
          trialSlotId: row['trial_slot_id'] as String,
          cellId: row['cell_id'] as String,
          generationBundleHash: row['generation_bundle_hash'] as String,
          modelRouteHash: row['sut_model_route_hash'] as String,
          scenarioReleaseHash: row['scenario_release_hash'] as String,
          decodingConfigHash: row['decoding_config_hash'] as String,
          trialNo: row['trial_no'] as int,
          isolationMode: row['isolation_mode'] as String,
          episodeId: row['episode_id'] as String?,
          episodeStep: row['episode_step'] as int?,
        ),
      ),
    );
    final storedPlans = db.select(
      'SELECT * FROM eval_dispatch_plans WHERE execution_id = ?',
      <Object?>[executionId],
    );
    if (storedPlans.isEmpty) {
      db.execute(
        '''INSERT INTO eval_dispatch_plans (
             execution_id, policy, policy_release_hash, seed_policy_hash,
             seed_hash, expected_slot_set_hash, plan_hash, entry_count,
             created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          executionId,
          plan.policy,
          plan.policyReleaseHash,
          plan.seedPolicyHash,
          plan.seedHash,
          plan.expectedSlotSetHash,
          plan.planHash,
          plan.entries.length,
          createdAtMs,
        ],
      );
      for (var ordinal = 0; ordinal < plan.entries.length; ordinal += 1) {
        final entry = plan.entries[ordinal];
        db.execute(
          '''INSERT INTO eval_dispatch_entries (
               execution_id, dispatch_ordinal, trial_slot_id, pair_id,
               arm_ordinal
             ) VALUES (?, ?, ?, ?, ?)''',
          <Object?>[
            executionId,
            ordinal,
            entry.trialSlotId,
            entry.pairId,
            entry.armOrdinal,
          ],
        );
      }
      return;
    }
    final storedPlan = storedPlans.single;
    if (storedPlan['policy'] != plan.policy ||
        storedPlan['policy_release_hash'] != plan.policyReleaseHash ||
        storedPlan['seed_policy_hash'] != plan.seedPolicyHash ||
        storedPlan['seed_hash'] != plan.seedHash ||
        storedPlan['expected_slot_set_hash'] != plan.expectedSlotSetHash ||
        storedPlan['plan_hash'] != plan.planHash ||
        storedPlan['entry_count'] != plan.entries.length) {
      throw const AgentEvaluationConflict(
        'stored dispatch plan does not match frozen experiment inputs',
      );
    }
    final storedEntries = db.select(
      '''SELECT * FROM eval_dispatch_entries WHERE execution_id = ?
         ORDER BY dispatch_ordinal''',
      <Object?>[executionId],
    );
    if (storedEntries.length != plan.entries.length) {
      throw const AgentEvaluationConflict('stored dispatch plan is incomplete');
    }
    for (var ordinal = 0; ordinal < plan.entries.length; ordinal += 1) {
      final stored = storedEntries[ordinal];
      final expected = plan.entries[ordinal];
      if (stored['dispatch_ordinal'] != ordinal ||
          stored['trial_slot_id'] != expected.trialSlotId ||
          stored['pair_id'] != expected.pairId ||
          stored['arm_ordinal'] != expected.armOrdinal) {
        throw const AgentEvaluationConflict(
          'stored dispatch entries are not canonical',
        );
      }
    }
  }

  void _appendAttemptStartedEventIfMissing({
    required AgentEvaluationLease lease,
    required int attemptNo,
    required String runId,
    required int occurredAtMs,
  }) {
    final existing = db.select(
      '''SELECT 1 FROM eval_dispatch_events
         WHERE execution_id = ? AND trial_slot_id = ?
           AND event_type = 'attemptStarted' AND lease_epoch = ?
           AND lease_owner = ? AND attempt_no = ? AND run_id = ?''',
      <Object?>[
        lease.executionId,
        lease.trialSlotId,
        lease.epoch,
        lease.owner,
        attemptNo,
        runId,
      ],
    );
    if (existing.isNotEmpty) return;
    final active = db.select(
      '''SELECT lease_expires_at_ms FROM eval_trial_slots
         WHERE execution_id = ? AND trial_slot_id = ? AND lease_epoch = ?
           AND lease_owner = ? AND status IN ('leased', 'running')''',
      <Object?>[lease.executionId, lease.trialSlotId, lease.epoch, lease.owner],
    );
    if (active.length != 1) {
      throw const AgentEvaluationLeaseLost(
        'attempt start event lost its active lease',
      );
    }
    _appendDispatchEvent(
      executionId: lease.executionId,
      trialSlotId: lease.trialSlotId,
      eventType: 'attemptStarted',
      leaseEpoch: lease.epoch,
      leaseOwner: lease.owner,
      leaseExpiresAtMs: active.single['lease_expires_at_ms'] as int,
      attemptNo: attemptNo,
      runId: runId,
      occurredAtMs: occurredAtMs,
    );
  }

  void _appendDispatchEvent({
    required String executionId,
    required String trialSlotId,
    required String eventType,
    required int leaseEpoch,
    required String leaseOwner,
    required int occurredAtMs,
    int? leaseExpiresAtMs,
    String? sealedEvidenceHash,
    int? attemptNo,
    String? runId,
  }) {
    final entries = db.select(
      '''SELECT dispatch_ordinal FROM eval_dispatch_entries
         WHERE execution_id = ? AND trial_slot_id = ?''',
      <Object?>[executionId, trialSlotId],
    );
    if (entries.length != 1) {
      throw const AgentEvaluationConflict(
        'dispatch event slot is absent from the immutable plan',
      );
    }
    final previousRows = db.select(
      '''SELECT event_ordinal, event_hash FROM eval_dispatch_events
         WHERE execution_id = ? ORDER BY event_ordinal DESC LIMIT 1''',
      <Object?>[executionId],
    );
    final eventOrdinal = previousRows.isEmpty
        ? 0
        : (previousRows.single['event_ordinal'] as int) + 1;
    final previousEventHash = previousRows.isEmpty
        ? null
        : previousRows.single['event_hash'] as String;
    final dispatchOrdinal = entries.single['dispatch_ordinal'] as int;
    final eventHash = AgentEvaluationDispatchPlanner.canonicalEventHash(
      executionId: executionId,
      eventOrdinal: eventOrdinal,
      dispatchOrdinal: dispatchOrdinal,
      trialSlotId: trialSlotId,
      eventType: eventType,
      leaseEpoch: leaseEpoch,
      leaseOwner: leaseOwner,
      leaseExpiresAtMs: leaseExpiresAtMs,
      sealedEvidenceHash: sealedEvidenceHash,
      attemptNo: attemptNo,
      runId: runId,
      occurredAtMs: occurredAtMs,
      previousEventHash: previousEventHash,
    );
    db.execute(
      '''INSERT INTO eval_dispatch_events (
           event_hash, execution_id, event_ordinal, dispatch_ordinal,
           trial_slot_id, event_type, lease_epoch, lease_owner,
           lease_expires_at_ms, sealed_evidence_hash, attempt_no, run_id,
           occurred_at_ms, previous_event_hash
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        eventHash,
        executionId,
        eventOrdinal,
        dispatchOrdinal,
        trialSlotId,
        eventType,
        leaseEpoch,
        leaseOwner,
        leaseExpiresAtMs,
        sealedEvidenceHash,
        attemptNo,
        runId,
        occurredAtMs,
        previousEventHash,
      ],
    );
  }

  void _createOrValidateCellMembership({
    required String table,
    required String ownerColumn,
    required String ownerId,
    required List<String> cellIds,
  }) {
    final stored = db.select(
      'SELECT cell_id, ordinal FROM $table WHERE $ownerColumn = ? ORDER BY ordinal',
      <Object?>[ownerId],
    );
    if (stored.isEmpty) {
      for (var ordinal = 0; ordinal < cellIds.length; ordinal += 1) {
        db.execute(
          'INSERT INTO $table ($ownerColumn, cell_id, ordinal) VALUES (?, ?, ?)',
          <Object?>[ownerId, cellIds[ordinal], ordinal],
        );
      }
      return;
    }
    if (stored.length != cellIds.length) {
      throw const AgentEvaluationConflict('cell membership is incomplete');
    }
    for (var ordinal = 0; ordinal < cellIds.length; ordinal += 1) {
      if (stored[ordinal]['ordinal'] != ordinal ||
          stored[ordinal]['cell_id'] != cellIds[ordinal]) {
        throw const AgentEvaluationConflict('cell membership is not canonical');
      }
    }
  }

  Row _requireActiveLease(AgentEvaluationLease lease, int nowMs) {
    final rows = db.select(
      '''SELECT * FROM eval_trial_slots
         WHERE trial_slot_id = ? AND lease_epoch = ? AND lease_owner = ?
           AND status IN ('leased', 'running') AND lease_expires_at_ms > ?''',
      <Object?>[lease.trialSlotId, lease.epoch, lease.owner, nowMs],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationLeaseLost(
        'slot lease is stale, expired, or already sealed',
      );
    }
    return rows.single;
  }

  List<AgentEvaluationSandboxRecoveryCheckpoint>
  _readAndVerifySandboxRecoveryChain({
    required String trialSlotId,
    required int attemptNo,
  }) {
    final rows = db.select(
      '''SELECT * FROM eval_sandbox_recovery_checkpoints
         WHERE trial_slot_id = ? AND attempt_no = ?
         ORDER BY checkpoint_no''',
      <Object?>[trialSlotId, attemptNo],
    );
    final chain = <AgentEvaluationSandboxRecoveryCheckpoint>[];
    for (var index = 0; index < rows.length; index += 1) {
      final checkpoint = _sandboxRecoveryCheckpointFromRow(rows[index]);
      final expectedNo = index + 1;
      final expectedStage = sandboxRecoveryStageOrdinals.entries
          .singleWhere((entry) => entry.value == expectedNo)
          .key;
      final expectedBase = chain.isEmpty ? null : chain.last.checkpointHash;
      final expectedHash = _domainHash(
        'eval-sandbox-recovery-checkpoint-v1',
        _sandboxRecoveryCheckpointValue(
          executionId: checkpoint.executionId,
          trialSlotId: checkpoint.trialSlotId,
          attemptNo: checkpoint.attemptNo,
          attemptRunId: checkpoint.attemptRunId,
          originalLeaseEpoch: checkpoint.originalLeaseEpoch,
          originalLeaseOwner: checkpoint.originalLeaseOwner,
          writerLeaseEpoch: checkpoint.writerLeaseEpoch,
          writerLeaseOwner: checkpoint.writerLeaseOwner,
          cellId: checkpoint.cellId,
          manifestHash: checkpoint.manifestHash,
          isolationTrialId: checkpoint.isolationTrialId,
          isolationMode: checkpoint.isolationMode,
          checkpointNo: checkpoint.checkpointNo,
          stage: checkpoint.stage,
          candidateHash: checkpoint.candidateHash,
          databasePath: checkpoint.databasePath,
          databaseFileHash: checkpoint.databaseFileHash,
          databaseFileSize: checkpoint.databaseFileSize,
          stateProjectionHash: checkpoint.stateProjectionHash,
          baseCheckpointHash: checkpoint.baseCheckpointHash,
          createdAtMs: checkpoint.createdAtMs,
        ),
      );
      if (checkpoint.checkpointNo != expectedNo ||
          checkpoint.stage != expectedStage ||
          checkpoint.baseCheckpointHash != expectedBase ||
          checkpoint.checkpointHash != expectedHash ||
          (chain.isEmpty &&
              (checkpoint.originalLeaseEpoch != checkpoint.writerLeaseEpoch ||
                  checkpoint.originalLeaseOwner !=
                      checkpoint.writerLeaseOwner)) ||
          (chain.isNotEmpty &&
              (checkpoint.executionId != chain.first.executionId ||
                  checkpoint.trialSlotId != chain.first.trialSlotId ||
                  checkpoint.attemptNo != chain.first.attemptNo ||
                  checkpoint.attemptRunId != chain.first.attemptRunId ||
                  checkpoint.originalLeaseEpoch !=
                      chain.first.originalLeaseEpoch ||
                  checkpoint.originalLeaseOwner !=
                      chain.first.originalLeaseOwner ||
                  checkpoint.cellId != chain.first.cellId ||
                  checkpoint.manifestHash != chain.first.manifestHash ||
                  checkpoint.isolationTrialId != chain.first.isolationTrialId ||
                  checkpoint.isolationMode != chain.first.isolationMode ||
                  checkpoint.candidateHash != chain.first.candidateHash))) {
        throw const AgentEvaluationConflict(
          'sandbox recovery checkpoint chain is malformed or tampered',
        );
      }
      chain.add(checkpoint);
    }
    return List<AgentEvaluationSandboxRecoveryCheckpoint>.unmodifiable(chain);
  }

  static AgentEvaluationLease _leaseFromRow(Row row) => AgentEvaluationLease(
    trialSlotId: row['trial_slot_id'] as String,
    executionId: row['execution_id'] as String,
    cellId: row['cell_id'] as String,
    trialNo: row['trial_no'] as int,
    epoch: row['lease_epoch'] as int,
    owner: row['lease_owner'] as String,
    expiresAtMs: row['lease_expires_at_ms'] as int,
    status: row['status'] as String,
  );

  static AgentEvaluationAttempt _attemptFromRow(Row row) =>
      AgentEvaluationAttempt(
        trialSlotId: row['trial_slot_id'] as String,
        attemptNo: row['attempt_no'] as int,
        runId: row['run_id'] as String,
        kind: row['kind'] as String,
        status: row['status'] as String,
        leaseEpoch: row['lease_epoch'] as int,
        leaseOwner: row['lease_owner'] as String,
        startedAtMs: row['started_at_ms'] as int,
        finishedAtMs: row['finished_at_ms'] as int?,
      );

  static AgentEvaluationObservation _observationFromRow(Row row) =>
      AgentEvaluationObservation(
        observationId: row['observation_id'] as String,
        trialSlotId: row['trial_slot_id'] as String,
        leaseEpoch: row['lease_epoch'] as int,
        leaseOwner: row['lease_owner'] as String,
        input: AgentEvaluationObservationInput(
          observationId: row['observation_id'] as String,
          attemptNo: row['attempt_no'] as int,
          sequenceNo: row['sequence_no'] as int,
          stageId: row['stage_id'] as String,
          kind: row['kind'] as String,
          itemKey: row['item_key'] as String,
          valueJson: row['value_json'] as String,
          evidenceHash: row['evidence_hash'] as String,
          evaluationBundleHash: row['evaluation_bundle_hash'] as String,
          proseHash: row['prose_hash'] as String?,
          createdAtMs: row['created_at_ms'] as int,
        ),
      );

  static AgentEvaluationSandboxGeneration _sandboxGenerationFromRow(Row row) =>
      AgentEvaluationSandboxGeneration(
        generationHash: row['generation_hash'] as String,
        executionId: row['execution_id'] as String,
        isolationTrialId: row['isolation_trial_id'] as String,
        generationNo: row['generation_no'] as int,
        sourceTrialSlotId: row['source_trial_slot_id'] as String,
        baseGenerationHash: row['base_generation_hash'] as String?,
        isolationMode: row['isolation_mode'] as String,
        databasePath: row['database_path'] as String,
        databaseFileHash: row['database_file_hash'] as String,
        leaseEpoch: row['lease_epoch'] as int,
        leaseOwner: row['lease_owner'] as String,
        createdAtMs: row['created_at_ms'] as int,
      );

  static AgentEvaluationSandboxRecoveryCheckpoint
  _sandboxRecoveryCheckpointFromRow(Row row) =>
      AgentEvaluationSandboxRecoveryCheckpoint(
        checkpointHash: row['checkpoint_hash'] as String,
        executionId: row['execution_id'] as String,
        trialSlotId: row['trial_slot_id'] as String,
        attemptNo: row['attempt_no'] as int,
        attemptRunId: row['attempt_run_id'] as String,
        originalLeaseEpoch: row['original_lease_epoch'] as int,
        originalLeaseOwner: row['original_lease_owner'] as String,
        writerLeaseEpoch: row['writer_lease_epoch'] as int,
        writerLeaseOwner: row['writer_lease_owner'] as String,
        cellId: row['cell_id'] as String,
        manifestHash: row['manifest_hash'] as String,
        isolationTrialId: row['isolation_trial_id'] as String,
        isolationMode: row['isolation_mode'] as String,
        checkpointNo: row['checkpoint_no'] as int,
        stage: row['stage'] as String,
        candidateHash: row['candidate_hash'] as String,
        databasePath: row['database_path'] as String,
        databaseFileHash: row['database_file_hash'] as String,
        databaseFileSize: row['database_file_size'] as int,
        stateProjectionHash: row['state_projection_hash'] as String,
        baseCheckpointHash: row['base_checkpoint_hash'] as String?,
        createdAtMs: row['created_at_ms'] as int,
      );

  static Map<String, Object?> _sandboxRecoveryCheckpointValue({
    required String executionId,
    required String trialSlotId,
    required int attemptNo,
    required String attemptRunId,
    required int originalLeaseEpoch,
    required String originalLeaseOwner,
    required int writerLeaseEpoch,
    required String writerLeaseOwner,
    required String cellId,
    required String manifestHash,
    required String isolationTrialId,
    required String isolationMode,
    required int checkpointNo,
    required String stage,
    required String candidateHash,
    required String databasePath,
    required String databaseFileHash,
    required int databaseFileSize,
    required String stateProjectionHash,
    required String? baseCheckpointHash,
    required int createdAtMs,
  }) => <String, Object?>{
    'executionId': executionId,
    'trialSlotId': trialSlotId,
    'attemptNo': attemptNo,
    'attemptRunId': attemptRunId,
    'originalLeaseEpoch': originalLeaseEpoch,
    'originalLeaseOwner': originalLeaseOwner,
    'writerLeaseEpoch': writerLeaseEpoch,
    'writerLeaseOwner': writerLeaseOwner,
    'cellId': cellId,
    'manifestHash': manifestHash,
    'isolationTrialId': isolationTrialId,
    'isolationMode': isolationMode,
    'checkpointNo': checkpointNo,
    'stage': stage,
    'candidateHash': candidateHash,
    'databasePath': databasePath,
    'databaseFileHash': databaseFileHash,
    'databaseFileSize': databaseFileSize,
    'stateProjectionHash': stateProjectionHash,
    'baseCheckpointHash': baseCheckpointHash,
    'createdAtMs': createdAtMs,
  };

  static void _validateObservation(AgentEvaluationObservationInput value) {
    _requireIdentity(value.observationId, 'observationId');
    _requireIdentity(value.stageId, 'stageId');
    _requireIdentity(value.kind, 'kind');
    _requireIdentity(value.itemKey, 'itemKey');
    _requireDigest(value.evidenceHash, 'evidenceHash');
    _requireDigest(value.evaluationBundleHash, 'evaluationBundleHash');
    if (value.proseHash != null) {
      _requireDigest(value.proseHash!, 'proseHash');
    }
    if (value.attemptNo <= 0 || value.sequenceNo < 0 || value.createdAtMs < 0) {
      throw const AgentEvaluationLedgerException(
        'observation attempt, sequence, and time are invalid',
      );
    }
  }

  T _inImmediateTransaction<T>(T Function() body) {
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

  static String _domainHash(String domainTag, Object? value) {
    final prefixed = AppLlmCanonicalHash.domainHash(domainTag, value);
    return prefixed.substring('sha256:'.length);
  }

  static void _requireIdentity(String value, String field) {
    if (value.trim().isEmpty) {
      throw AgentEvaluationLedgerException('$field is required');
    }
  }

  static void _requireDigest(String value, String field) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw AgentEvaluationLedgerException(
        '$field must be canonical lowercase SHA-256 hex',
      );
    }
  }

  static void _requireUnique(List<String> values, String field) {
    if (values.toSet().length != values.length) {
      throw AgentEvaluationConflict('$field contains duplicates');
    }
  }

  static bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
