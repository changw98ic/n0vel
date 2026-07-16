import 'dart:async';

// This key must be identity-unique. A const Object can be canonicalized and
// collide with unrelated Zone keys in the wider application test suite.
final Object _agentEvaluationTraceZoneKey = Object();

/// Immutable evaluation identity propagated through asynchronous story work.
///
/// A formal experiment is all-or-nothing: if its Zone marker exists, every
/// field must be present and valid. Ordinary production execution has no marker
/// and therefore returns `null` from [current].
final class AgentEvaluationTraceContext {
  AgentEvaluationTraceContext({
    required String experimentId,
    required String executionId,
    required String cellId,
    required String trialSlotId,
    required int attemptNo,
    required String runId,
    required int leaseEpoch,
    required String leaseOwner,
    required String isolationTrialId,
    required String generationBundleHash,
    required String evaluationBundleHash,
  }) : experimentId = _required(experimentId, 'experimentId'),
       executionId = _required(executionId, 'executionId'),
       cellId = _required(cellId, 'cellId'),
       trialSlotId = _required(trialSlotId, 'trialSlotId'),
       attemptNo = _attempt(attemptNo),
       runId = _required(runId, 'runId'),
       leaseEpoch = _epoch(leaseEpoch),
       leaseOwner = _required(leaseOwner, 'leaseOwner'),
       isolationTrialId = _required(isolationTrialId, 'isolationTrialId'),
       generationBundleHash = _digest(
         generationBundleHash,
         'generationBundleHash',
       ),
       evaluationBundleHash = _digest(
         evaluationBundleHash,
         'evaluationBundleHash',
       );

  final String experimentId;
  final String executionId;
  final String cellId;
  final String trialSlotId;
  final int attemptNo;
  final String runId;
  final int leaseEpoch;
  final String leaseOwner;
  final String isolationTrialId;
  final String generationBundleHash;
  final String evaluationBundleHash;

  Map<String, Object?> toTraceMetadata() => <String, Object?>{
    'experimentId': experimentId,
    'executionId': executionId,
    'cellId': cellId,
    'trialSlotId': trialSlotId,
    'attemptNo': attemptNo,
    'runId': runId,
    'leaseEpoch': leaseEpoch,
    'leaseOwner': leaseOwner,
    'isolationTrialId': isolationTrialId,
    'generationBundleHash': generationBundleHash,
    'evaluationBundleHash': evaluationBundleHash,
  };

  static R run<R>(AgentEvaluationTraceContext context, R Function() body) =>
      runZoned<R>(
        body,
        zoneValues: <Object, Object?>{
          _agentEvaluationTraceZoneKey: _FormalEvaluationPayload.fromContext(
            context,
          ),
        },
      );

  /// Harness entry point which preserves a formal marker even when incomplete.
  /// Reading [current] then fails closed instead of degrading to production.
  static R runFormalExperiment<R>({
    String? experimentId,
    String? executionId,
    String? cellId,
    String? trialSlotId,
    int? attemptNo,
    String? runId,
    int? leaseEpoch,
    String? leaseOwner,
    String? isolationTrialId,
    String? generationBundleHash,
    String? evaluationBundleHash,
    required R Function() body,
  }) => runZoned<R>(
    body,
    zoneValues: <Object, Object?>{
      _agentEvaluationTraceZoneKey: _FormalEvaluationPayload(
        experimentId: experimentId,
        executionId: executionId,
        cellId: cellId,
        trialSlotId: trialSlotId,
        attemptNo: attemptNo,
        runId: runId,
        leaseEpoch: leaseEpoch,
        leaseOwner: leaseOwner,
        isolationTrialId: isolationTrialId,
        generationBundleHash: generationBundleHash,
        evaluationBundleHash: evaluationBundleHash,
      ),
    },
  );

  static AgentEvaluationTraceContext? get current {
    final payload = Zone.current[_agentEvaluationTraceZoneKey];
    if (payload == null) return null;
    if (payload is! _FormalEvaluationPayload) {
      throw StateError('invalid formal evaluation Zone payload');
    }
    return AgentEvaluationTraceContext(
      experimentId: _present(payload.experimentId, 'experimentId'),
      executionId: _present(payload.executionId, 'executionId'),
      cellId: _present(payload.cellId, 'cellId'),
      trialSlotId: _present(payload.trialSlotId, 'trialSlotId'),
      attemptNo: _present(payload.attemptNo, 'attemptNo'),
      runId: _present(payload.runId, 'runId'),
      leaseEpoch: _present(payload.leaseEpoch, 'leaseEpoch'),
      leaseOwner: _present(payload.leaseOwner, 'leaseOwner'),
      isolationTrialId: _present(payload.isolationTrialId, 'isolationTrialId'),
      generationBundleHash: _present(
        payload.generationBundleHash,
        'generationBundleHash',
      ),
      evaluationBundleHash: _present(
        payload.evaluationBundleHash,
        'evaluationBundleHash',
      ),
    );
  }
}

final class _FormalEvaluationPayload {
  const _FormalEvaluationPayload({
    required this.experimentId,
    required this.executionId,
    required this.cellId,
    required this.trialSlotId,
    required this.attemptNo,
    required this.runId,
    required this.leaseEpoch,
    required this.leaseOwner,
    required this.isolationTrialId,
    required this.generationBundleHash,
    required this.evaluationBundleHash,
  });

  factory _FormalEvaluationPayload.fromContext(
    AgentEvaluationTraceContext context,
  ) => _FormalEvaluationPayload(
    experimentId: context.experimentId,
    executionId: context.executionId,
    cellId: context.cellId,
    trialSlotId: context.trialSlotId,
    attemptNo: context.attemptNo,
    runId: context.runId,
    leaseEpoch: context.leaseEpoch,
    leaseOwner: context.leaseOwner,
    isolationTrialId: context.isolationTrialId,
    generationBundleHash: context.generationBundleHash,
    evaluationBundleHash: context.evaluationBundleHash,
  );

  final String? experimentId;
  final String? executionId;
  final String? cellId;
  final String? trialSlotId;
  final int? attemptNo;
  final String? runId;
  final int? leaseEpoch;
  final String? leaseOwner;
  final String? isolationTrialId;
  final String? generationBundleHash;
  final String? evaluationBundleHash;
}

T _present<T>(T? value, String field) {
  if (value == null) {
    throw StateError('formal evaluation context missing $field');
  }
  return value;
}

String _required(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError.value(value, field, 'required');
  return normalized;
}

int _attempt(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'attemptNo', 'must be > 0');
  return value;
}

int _epoch(int value) {
  if (value <= 0) throw ArgumentError.value(value, 'leaseEpoch', 'must be > 0');
  return value;
}

String _digest(String value, String field) {
  final normalized = _required(value, field);
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      field,
      'must be a sha256:<lower-hex> digest',
    );
  }
  return normalized;
}
