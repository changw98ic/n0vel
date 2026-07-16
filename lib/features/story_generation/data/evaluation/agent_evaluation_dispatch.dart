import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_manifest.dart';

final class AgentEvaluationDispatchDescriptor {
  const AgentEvaluationDispatchDescriptor({
    required this.trialSlotId,
    required this.cellId,
    required this.generationBundleHash,
    required this.modelRouteHash,
    required this.scenarioReleaseHash,
    required this.decodingConfigHash,
    required this.trialNo,
    required this.isolationMode,
    this.episodeId,
    this.episodeStep,
  });

  final String trialSlotId;
  final String cellId;
  final String generationBundleHash;
  final String modelRouteHash;
  final String scenarioReleaseHash;
  final String decodingConfigHash;
  final int trialNo;
  final String isolationMode;
  final String? episodeId;
  final int? episodeStep;

  String get groupKey => AgentEvaluationHashes.domainHash(
    'eval-dispatch-pair-group-v1',
    <Object?>[modelRouteHash, scenarioReleaseHash, decodingConfigHash, trialNo],
  );
}

final class AgentEvaluationDispatchPlan {
  const AgentEvaluationDispatchPlan({
    required this.policy,
    required this.policyReleaseHash,
    required this.seedPolicyHash,
    required this.seedHash,
    required this.expectedSlotSetHash,
    required this.entries,
    required this.planHash,
  });

  final String policy;
  final String policyReleaseHash;
  final String seedPolicyHash;
  final String seedHash;
  final String expectedSlotSetHash;
  final List<AgentEvaluationDispatchEntry> entries;
  final String planHash;

  List<String> get slotIds =>
      entries.map((entry) => entry.trialSlotId).toList(growable: false);
}

final class AgentEvaluationDispatchEntry {
  const AgentEvaluationDispatchEntry({
    required this.trialSlotId,
    required this.pairId,
    required this.armOrdinal,
  });

  final String trialSlotId;
  final String pairId;
  final int armOrdinal;
}

abstract final class AgentEvaluationDispatchPlanner {
  static const policy = 'interleaved-randomized-v1';
  static String get policyReleaseHash => AgentEvaluationHashes.domainHash(
    'eval-dispatch-policy-release-v1',
    <String, Object?>{
      'policy': policy,
      'grouping': 'model-scenario-decoding-trial-v1',
      'groupOrder': 'seeded-topological-hash-v1',
      'armOrder': 'seeded-hash-v1',
      'recoveryPriority': 'expired-before-new-v1',
      'eventChain': 'claim-reclaim-renew-attempt-start-seal-v1',
    },
  );

  static AgentEvaluationDispatchPlan build({
    required String experimentId,
    required String manifestHash,
    required Object? seedPolicy,
    required String expectedSlotSetHash,
    required Iterable<AgentEvaluationDispatchDescriptor> descriptors,
  }) {
    final values = descriptors.toList(growable: false);
    if (values.isEmpty) {
      throw ArgumentError('dispatch plan requires at least one trial slot');
    }
    final slotIds = values.map((value) => value.trialSlotId).toSet();
    if (slotIds.length != values.length) {
      throw StateError('dispatch descriptors contain duplicate trial slots');
    }
    final seedPolicyHash = AgentEvaluationHashes.domainHash(
      'eval-dispatch-seed-policy-v1',
      seedPolicy,
    );
    final seedHash = AgentEvaluationHashes.domainHash(
      'eval-dispatch-seed-v1',
      <String, Object?>{
        'experimentId': experimentId,
        'manifestHash': manifestHash,
        'seedPolicyHash': seedPolicyHash,
      },
    );
    final groups = <String, List<AgentEvaluationDispatchDescriptor>>{};
    for (final descriptor in values) {
      (groups[descriptor.groupKey] ??= <AgentEvaluationDispatchDescriptor>[])
          .add(descriptor);
    }
    final pending = Map<String, List<AgentEvaluationDispatchDescriptor>>.of(
      groups,
    );
    final ordered = <AgentEvaluationDispatchEntry>[];
    while (pending.isNotEmpty) {
      final eligible = pending.entries.where((entry) {
        final sample = entry.value.first;
        if (sample.isolationMode != 'episode') return true;
        final episodeId = sample.episodeId;
        final episodeStep = sample.episodeStep;
        if (episodeId == null || episodeStep == null) {
          throw StateError('episode dispatch descriptor is incomplete');
        }
        return !pending.values.any((candidateGroup) {
          final candidate = candidateGroup.first;
          return candidate.isolationMode == 'episode' &&
              candidate.modelRouteHash == sample.modelRouteHash &&
              candidate.decodingConfigHash == sample.decodingConfigHash &&
              candidate.trialNo == sample.trialNo &&
              candidate.episodeId == episodeId &&
              candidate.episodeStep! < episodeStep;
        });
      }).toList();
      if (eligible.isEmpty) {
        throw StateError('episode dispatch dependencies contain a cycle');
      }
      eligible.sort((left, right) {
        final leftPriority = AgentEvaluationHashes.domainHash(
          'eval-dispatch-group-priority-v1',
          <String>[seedHash, left.key],
        );
        final rightPriority = AgentEvaluationHashes.domainHash(
          'eval-dispatch-group-priority-v1',
          <String>[seedHash, right.key],
        );
        final priorityOrder = leftPriority.compareTo(rightPriority);
        return priorityOrder != 0
            ? priorityOrder
            : left.key.compareTo(right.key);
      });
      final selected = eligible.first;
      final arms = selected.value.toList()
        ..sort((left, right) {
          final leftPriority = AgentEvaluationHashes.domainHash(
            'eval-dispatch-arm-priority-v1',
            <String>[seedHash, selected.key, left.generationBundleHash],
          );
          final rightPriority = AgentEvaluationHashes.domainHash(
            'eval-dispatch-arm-priority-v1',
            <String>[seedHash, selected.key, right.generationBundleHash],
          );
          final priorityOrder = leftPriority.compareTo(rightPriority);
          return priorityOrder != 0
              ? priorityOrder
              : left.generationBundleHash.compareTo(right.generationBundleHash);
        });
      for (var armOrdinal = 0; armOrdinal < arms.length; armOrdinal += 1) {
        ordered.add(
          AgentEvaluationDispatchEntry(
            trialSlotId: arms[armOrdinal].trialSlotId,
            pairId: selected.key,
            armOrdinal: armOrdinal,
          ),
        );
      }
      pending.remove(selected.key);
    }
    final frozen = List<AgentEvaluationDispatchEntry>.unmodifiable(ordered);
    final planHash = canonicalPlanHash(
      policyReleaseHash: policyReleaseHash,
      seedPolicyHash: seedPolicyHash,
      seedHash: seedHash,
      expectedSlotSetHash: expectedSlotSetHash,
      entries: frozen,
    );
    return AgentEvaluationDispatchPlan(
      policy: policy,
      policyReleaseHash: policyReleaseHash,
      seedPolicyHash: seedPolicyHash,
      seedHash: seedHash,
      expectedSlotSetHash: expectedSlotSetHash,
      entries: frozen,
      planHash: planHash,
    );
  }

  static String canonicalPlanHash({
    required String policyReleaseHash,
    required String seedPolicyHash,
    required String seedHash,
    required String expectedSlotSetHash,
    required Iterable<AgentEvaluationDispatchEntry> entries,
  }) => AgentEvaluationHashes.domainHash(
    'eval-dispatch-plan-v1',
    <String, Object?>{
      'policy': policy,
      'policyReleaseHash': policyReleaseHash,
      'seedPolicyHash': seedPolicyHash,
      'seedHash': seedHash,
      'expectedSlotSetHash': expectedSlotSetHash,
      'entries': [
        for (final entry in entries)
          <String, Object?>{
            'trialSlotId': entry.trialSlotId,
            'pairId': entry.pairId,
            'armOrdinal': entry.armOrdinal,
          },
      ],
    },
  );

  static String canonicalEventHash({
    required String executionId,
    required int eventOrdinal,
    required int dispatchOrdinal,
    required String trialSlotId,
    required String eventType,
    required int leaseEpoch,
    required String leaseOwner,
    required int? leaseExpiresAtMs,
    required String? sealedEvidenceHash,
    required int? attemptNo,
    required String? runId,
    required int occurredAtMs,
    required String? previousEventHash,
  }) => AgentEvaluationHashes.domainHash(
    'eval-dispatch-event-v1',
    <String, Object?>{
      'executionId': executionId,
      'eventOrdinal': eventOrdinal,
      'dispatchOrdinal': dispatchOrdinal,
      'trialSlotId': trialSlotId,
      'eventType': eventType,
      'leaseEpoch': leaseEpoch,
      'leaseOwner': leaseOwner,
      'leaseExpiresAtMs': leaseExpiresAtMs,
      'sealedEvidenceHash': sealedEvidenceHash,
      'attemptNo': attemptNo,
      'runId': runId,
      'occurredAtMs': occurredAtMs,
      'previousEventHash': previousEventHash,
    },
  );
}

final class AgentEvaluationDispatchReplayResult {
  const AgentEvaluationDispatchReplayResult({
    required this.planHash,
    required this.policyReleaseHash,
    required this.eventRootHash,
    required this.eventCount,
    required this.firstStartOrder,
  });

  final String planHash;
  final String policyReleaseHash;
  final String eventRootHash;
  final int eventCount;
  final List<String> firstStartOrder;
}

final class AgentEvaluationDispatchReplayException implements Exception {
  const AgentEvaluationDispatchReplayException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationDispatchReplayException: $message';
}

/// Rebuilds the immutable plan and lease state solely from frozen database
/// inputs. A release gate can therefore reject a plausible-looking final slot
/// projection whose actual dispatch or recovery history was tampered with.
abstract final class AgentEvaluationDispatchReplay {
  static AgentEvaluationDispatchReplayResult verify({
    required Database db,
    required String executionId,
    bool requireComplete = true,
    bool requireTwoArms = true,
  }) {
    final roots = db.select(
      '''SELECT x.experiment_id, x.expected_slot_set_hash,
           e.manifest_hash, e.manifest_json
         FROM eval_executions x
         JOIN eval_experiments e ON e.experiment_id = x.experiment_id
         WHERE x.execution_id = ?''',
      <Object?>[executionId],
    );
    if (roots.length != 1) {
      throw const AgentEvaluationDispatchReplayException(
        'dispatch execution root is missing or ambiguous',
      );
    }
    final root = roots.single;
    final descriptorRows = db.select(
      '''SELECT s.*, c.generation_bundle_hash, c.sut_model_route_hash,
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
    Object? seedPolicy = const <String, Object?>{};
    try {
      final manifest = jsonDecode(root['manifest_json'] as String);
      if (manifest is Map<String, Object?>) {
        seedPolicy = manifest['seedPolicy'] ?? const <String, Object?>{};
      }
    } on FormatException {
      throw const AgentEvaluationDispatchReplayException(
        'dispatch manifest JSON cannot be decoded',
      );
    }
    final rebuilt = AgentEvaluationDispatchPlanner.build(
      experimentId: root['experiment_id'] as String,
      manifestHash: root['manifest_hash'] as String,
      seedPolicy: seedPolicy,
      expectedSlotSetHash: root['expected_slot_set_hash'] as String,
      descriptors: descriptorRows.map(
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
    final plans = db.select(
      'SELECT * FROM eval_dispatch_plans WHERE execution_id = ?',
      <Object?>[executionId],
    );
    if (plans.length != 1) {
      throw const AgentEvaluationDispatchReplayException(
        'immutable dispatch plan is missing or ambiguous',
      );
    }
    final plan = plans.single;
    if (plan['policy'] != rebuilt.policy ||
        plan['policy_release_hash'] != rebuilt.policyReleaseHash ||
        plan['seed_policy_hash'] != rebuilt.seedPolicyHash ||
        plan['seed_hash'] != rebuilt.seedHash ||
        plan['expected_slot_set_hash'] != rebuilt.expectedSlotSetHash ||
        plan['plan_hash'] != rebuilt.planHash ||
        plan['entry_count'] != rebuilt.entries.length) {
      throw const AgentEvaluationDispatchReplayException(
        'stored dispatch plan does not replay from frozen inputs',
      );
    }
    final entries = db.select(
      '''SELECT d.*, c.generation_bundle_hash
         FROM eval_dispatch_entries d
         JOIN eval_trial_slots s ON s.execution_id = d.execution_id
           AND s.trial_slot_id = d.trial_slot_id
         JOIN eval_cells c ON c.cell_id = s.cell_id
         WHERE d.execution_id = ? ORDER BY d.dispatch_ordinal''',
      <Object?>[executionId],
    );
    if (entries.length != rebuilt.entries.length) {
      throw const AgentEvaluationDispatchReplayException(
        'dispatch entry cardinality differs from the rebuilt plan',
      );
    }
    final entriesBySlot = <String, Row>{};
    final pairBundles = <String, Set<String>>{};
    final pairArmOrdinals = <String, Set<int>>{};
    for (var ordinal = 0; ordinal < entries.length; ordinal += 1) {
      final actual = entries[ordinal];
      final expected = rebuilt.entries[ordinal];
      if (actual['dispatch_ordinal'] != ordinal ||
          actual['trial_slot_id'] != expected.trialSlotId ||
          actual['pair_id'] != expected.pairId ||
          actual['arm_ordinal'] != expected.armOrdinal) {
        throw const AgentEvaluationDispatchReplayException(
          'dispatch entry order or pair membership was changed',
        );
      }
      entriesBySlot[actual['trial_slot_id'] as String] = actual;
      (pairBundles[actual['pair_id'] as String] ??= <String>{}).add(
        actual['generation_bundle_hash'] as String,
      );
      (pairArmOrdinals[actual['pair_id'] as String] ??= <int>{}).add(
        actual['arm_ordinal'] as int,
      );
    }
    if (requireTwoArms &&
        pairBundles.keys.any(
          (pair) =>
              pairBundles[pair]!.length != 2 ||
              pairArmOrdinals[pair]!.length != 2 ||
              !pairArmOrdinals[pair]!.containsAll(<int>{0, 1}),
        )) {
      throw const AgentEvaluationDispatchReplayException(
        'release dispatch pairs must contain exactly two distinct arms',
      );
    }

    final events = db.select(
      '''SELECT * FROM eval_dispatch_events WHERE execution_id = ?
         ORDER BY event_ordinal''',
      <Object?>[executionId],
    );
    final states = <String, _DispatchReplayState>{};
    final firstStartOrder = <String>[];
    String? previousHash;
    for (
      var eventOrdinal = 0;
      eventOrdinal < events.length;
      eventOrdinal += 1
    ) {
      final event = events[eventOrdinal];
      final slotId = event['trial_slot_id'] as String;
      final entry = entriesBySlot[slotId];
      if (entry == null ||
          event['event_ordinal'] != eventOrdinal ||
          event['dispatch_ordinal'] != entry['dispatch_ordinal'] ||
          event['previous_event_hash'] != previousHash) {
        throw const AgentEvaluationDispatchReplayException(
          'dispatch event ordinal, slot, or previous hash is invalid',
        );
      }
      final calculatedHash = AgentEvaluationDispatchPlanner.canonicalEventHash(
        executionId: executionId,
        eventOrdinal: eventOrdinal,
        dispatchOrdinal: event['dispatch_ordinal'] as int,
        trialSlotId: slotId,
        eventType: event['event_type'] as String,
        leaseEpoch: event['lease_epoch'] as int,
        leaseOwner: event['lease_owner'] as String,
        leaseExpiresAtMs: event['lease_expires_at_ms'] as int?,
        sealedEvidenceHash: event['sealed_evidence_hash'] as String?,
        attemptNo: event['attempt_no'] as int?,
        runId: event['run_id'] as String?,
        occurredAtMs: event['occurred_at_ms'] as int,
        previousEventHash: previousHash,
      );
      if (event['event_hash'] != calculatedHash) {
        throw const AgentEvaluationDispatchReplayException(
          'dispatch event hash does not match its canonical payload',
        );
      }
      _applyEvent(
        db: db,
        event: event,
        entry: entry,
        states: states,
        firstStartOrder: firstStartOrder,
      );
      previousHash = calculatedHash;
    }
    if (requireComplete &&
        (states.length != entries.length ||
            states.values.any((state) => !state.sealed))) {
      throw const AgentEvaluationDispatchReplayException(
        'release dispatch event chain is not complete',
      );
    }
    final attempts = db.select(
      '''SELECT a.* FROM eval_trial_attempts a
         JOIN eval_trial_slots s ON s.trial_slot_id = a.trial_slot_id
         WHERE s.execution_id = ?''',
      <Object?>[executionId],
    );
    for (final attempt in attempts) {
      final currentStart = db.select(
        '''SELECT 1 FROM eval_dispatch_events
           WHERE execution_id = ? AND trial_slot_id = ?
             AND event_type = 'attemptStarted' AND attempt_no = ?
             AND run_id = ? AND lease_epoch = ? AND lease_owner = ?''',
        <Object?>[
          executionId,
          attempt['trial_slot_id'],
          attempt['attempt_no'],
          attempt['run_id'],
          attempt['lease_epoch'],
          attempt['lease_owner'],
        ],
      );
      if (currentStart.length != 1) {
        throw const AgentEvaluationDispatchReplayException(
          'current attempt fence is not represented by one start event',
        );
      }
    }
    for (final slot in descriptorRows) {
      final slotId = slot['trial_slot_id'] as String;
      final state = states[slotId];
      if (state == null) {
        if (requireComplete) {
          throw const AgentEvaluationDispatchReplayException(
            'trial slot has no dispatch history',
          );
        }
        continue;
      }
      if (slot['lease_epoch'] != state.epoch ||
          (state.sealed
              ? slot['status'] != 'sealed' ||
                    slot['lease_owner'] != null ||
                    slot['lease_expires_at_ms'] != null ||
                    slot['sealed_evidence_hash'] != state.sealedEvidenceHash
              : !<String>{'leased', 'running'}.contains(slot['status']) ||
                    slot['lease_owner'] != state.owner ||
                    slot['lease_expires_at_ms'] != state.expiresAtMs)) {
        throw const AgentEvaluationDispatchReplayException(
          'slot projection differs from replayed dispatch state',
        );
      }
    }
    return AgentEvaluationDispatchReplayResult(
      planHash: rebuilt.planHash,
      policyReleaseHash: rebuilt.policyReleaseHash,
      eventRootHash:
          previousHash ??
          AgentEvaluationHashes.domainHash(
            'eval-empty-dispatch-event-root-v1',
            executionId,
          ),
      eventCount: events.length,
      firstStartOrder: List<String>.unmodifiable(firstStartOrder),
    );
  }

  static void _applyEvent({
    required Database db,
    required Row event,
    required Row entry,
    required Map<String, _DispatchReplayState> states,
    required List<String> firstStartOrder,
  }) {
    final slotId = event['trial_slot_id'] as String;
    final type = event['event_type'] as String;
    final epoch = event['lease_epoch'] as int;
    final owner = event['lease_owner'] as String;
    final occurredAt = event['occurred_at_ms'] as int;
    final expiry = event['lease_expires_at_ms'] as int?;
    final current = states[slotId];
    if (type == 'claimed') {
      if (current != null ||
          epoch != 1 ||
          expiry == null ||
          expiry <= occurredAt) {
        throw const AgentEvaluationDispatchReplayException(
          'initial claim violates dispatch lease semantics',
        );
      }
      states[slotId] = _DispatchReplayState(
        epoch: epoch,
        owner: owner,
        expiresAtMs: expiry,
      );
      return;
    }
    if (current == null || current.sealed) {
      throw const AgentEvaluationDispatchReplayException(
        'dispatch event has no active predecessor lease',
      );
    }
    if (type == 'reclaimed') {
      if (occurredAt < current.expiresAtMs ||
          epoch != current.epoch + 1 ||
          expiry == null ||
          expiry <= occurredAt) {
        throw const AgentEvaluationDispatchReplayException(
          'lease reclaim occurred before expiry or broke epoch fencing',
        );
      }
      states[slotId] = _DispatchReplayState(
        epoch: epoch,
        owner: owner,
        expiresAtMs: expiry,
      );
      return;
    }
    if (epoch != current.epoch || owner != current.owner) {
      throw const AgentEvaluationDispatchReplayException(
        'dispatch event uses a stale lease fence',
      );
    }
    if (type == 'renewed') {
      if (occurredAt >= current.expiresAtMs ||
          expiry == null ||
          expiry < current.expiresAtMs) {
        throw const AgentEvaluationDispatchReplayException(
          'lease renewal is late or shortens the active lease',
        );
      }
      states[slotId] = _DispatchReplayState(
        epoch: epoch,
        owner: owner,
        expiresAtMs: expiry,
        started: current.started,
      );
      return;
    }
    if (type == 'attemptStarted') {
      if (occurredAt >= current.expiresAtMs || expiry != current.expiresAtMs) {
        throw const AgentEvaluationDispatchReplayException(
          'attempt started outside its active lease',
        );
      }
      final attempt = db.select(
        '''SELECT lease_epoch, lease_owner FROM eval_trial_attempts
           WHERE trial_slot_id = ? AND attempt_no = ? AND run_id = ?''',
        <Object?>[slotId, event['attempt_no'], event['run_id']],
      );
      if (attempt.length != 1 ||
          (attempt.single['lease_epoch'] as int) < epoch ||
          ((attempt.single['lease_epoch'] as int) == epoch &&
              attempt.single['lease_owner'] != owner)) {
        throw const AgentEvaluationDispatchReplayException(
          'attempt-start event is not bound to the attempt ledger',
        );
      }
      if (!firstStartOrder.contains(slotId)) {
        final ordinal = entry['dispatch_ordinal'] as int;
        if (ordinal != firstStartOrder.length) {
          throw const AgentEvaluationDispatchReplayException(
            'actual first attempt starts do not follow the frozen plan',
          );
        }
        firstStartOrder.add(slotId);
      }
      states[slotId] = _DispatchReplayState(
        epoch: epoch,
        owner: owner,
        expiresAtMs: current.expiresAtMs,
        started: true,
      );
      return;
    }
    if (type == 'sealed') {
      if (occurredAt >= current.expiresAtMs ||
          !current.started ||
          event['sealed_evidence_hash'] == null) {
        throw const AgentEvaluationDispatchReplayException(
          'slot was sealed outside a started active lease',
        );
      }
      states[slotId] = _DispatchReplayState(
        epoch: epoch,
        owner: owner,
        expiresAtMs: current.expiresAtMs,
        started: true,
        sealed: true,
        sealedEvidenceHash: event['sealed_evidence_hash'] as String,
      );
      return;
    }
    throw const AgentEvaluationDispatchReplayException(
      'unknown dispatch event type',
    );
  }
}

final class _DispatchReplayState {
  const _DispatchReplayState({
    required this.epoch,
    required this.owner,
    required this.expiresAtMs,
    this.started = false,
    this.sealed = false,
    this.sealedEvidenceHash,
  });

  final int epoch;
  final String owner;
  final int expiresAtMs;
  final bool started;
  final bool sealed;
  final String? sealedEvidenceHash;
}
