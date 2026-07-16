part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSnapshotPersistence on StoryGenerationRunStore {
  Future<void> _restoreCurrentScene() async {
    final restoreVersion = _mutationVersion;
    final sceneScopeId = _activeSceneScopeId;
    final restored = await _storage.load(sceneScopeId: sceneScopeId);
    if (restoreVersion != _mutationVersion || restored == null) {
      return;
    }
    var snapshot = StoryGenerationRunSnapshot.fromJson({
      for (final entry in restored.entries)
        entry.key: cloneStorageValue(entry.value),
    });
    // A compatibility snapshot may cache candidate prose for display, but a
    // V9 pointer is actionable only while its durable proof and payload still
    // exist.  Do this validation before the snapshot reaches the UI.
    if (snapshot.candidateRevision != null &&
        _generationLedger != null &&
        (!_generationLedger.hasCandidateProofAndPayload(
              runId: snapshot.runId,
              candidateRevision: snapshot.candidateRevision!,
              candidateHash: snapshot.candidateHash,
            ) ||
            !_generationLedger.isRunBoundToGenerationBundle(
              runId: snapshot.runId,
              generationBundleHash: snapshot.candidateGenerationBundleHash,
            ))) {
      snapshot = snapshot.copyWith(
        status: StoryGenerationRunStatus.failed,
        phase: StoryGenerationRunPhase.fail,
        headline: '候选证据不可用',
        summary: '候选稿的数据库证据或正文载荷已不存在，不能展示或采纳。',
        stageSummary: '候选证据缺失',
        errorDetail: 'durable-candidate-proof-missing',
        candidateProse: '',
        clearCandidateRevision: true,
        candidateHash: '',
        candidateFinalProseHash: '',
        candidateDeterministicGateEvidenceHash: '',
        candidateFinalCouncilEvidenceHash: '',
        candidateQualityEvidenceHash: '',
        candidatePendingWriteSetHash: '',
        candidateMaterialDigest: '',
        candidateInputDigest: '',
        candidateBaseDraftHash: '',
        candidateGenerationBundleHash: '',
      );
    }
    _snapshot = snapshot;
    _snapshotsBySceneScope[sceneScopeId] = snapshot;
    _syncFeedbackCache(sceneScopeId, snapshot);
    _notifySnapshotListeners();
  }

  Future<void> _persistSnapshot(
    StoryGenerationRunSnapshot snapshot,
    String sceneScopeId,
  ) {
    return _storage.save({
      ...snapshot.toJson(),
      'sceneScopeId': sceneScopeId,
    }, sceneScopeId: sceneScopeId);
  }

  void _syncFeedbackCache(
    String sceneScopeId,
    StoryGenerationRunSnapshot snapshot,
  ) {
    _directorFeedbackBySceneScope[sceneScopeId] = [
      for (final message in snapshot.messages)
        if (message.kind == StoryGenerationRunMessageKind.authorFeedback &&
            message.body.trim().isNotEmpty)
          message.body.trim(),
    ];
  }

  Future<void> _setSnapshot(StoryGenerationRunSnapshot next) async {
    _mutationVersion += 1;
    final mutationVersion = _mutationVersion;
    final sceneScopeId = _activeSceneScopeId;
    await _persistSnapshot(next, sceneScopeId);
    _snapshotsBySceneScope[sceneScopeId] = next;
    _syncFeedbackCache(sceneScopeId, next);
    if (mutationVersion == _mutationVersion &&
        sceneScopeId == _activeSceneScopeId) {
      _snapshot = next;
      _notifySnapshotListeners();
    }
  }
}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): cloneStorageValue(entry.value),
  };
}

/// Snapshot-backed checkpoint persistence for the compatibility run surface.
///
/// It retains only typed, hash-bound execution records. It does not create or
/// expose candidate proofs, so a corrupted local snapshot cannot be promoted
/// into author-committable story state.
class _SnapshotPipelineCheckpointStore implements PipelineCheckpointStore {
  _SnapshotPipelineCheckpointStore({
    required this.owner,
    required this.runId,
    required this.sceneScopeId,
  });

  final StoryGenerationRunStore owner;
  final String runId;
  final String sceneScopeId;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async {
    if (runId != this.runId ||
        owner._activeSceneScopeId != sceneScopeId ||
        owner._snapshot.runId != runId) {
      return const [];
    }
    final result = <PipelineStageCheckpoint>[];
    for (final checkpoint in owner._snapshot.checkpoints) {
      if (!_isStructurallyValid(checkpoint)) continue;
      result.add(
        PipelineStageCheckpoint(
          runId: runId,
          ordinal: checkpoint.ordinal,
          stageId: checkpoint.stageId,
          stageAttempt: checkpoint.stageAttempt,
          schemaVersion: checkpoint.schemaVersion,
          inputDigest: checkpoint.inputDigest,
          artifactDigest: checkpoint.artifactDigest,
          status: checkpoint.status,
          createdAtMs: checkpoint.createdAtMs,
          completedAtMs: checkpoint.completedAtMs,
          artifactType: checkpoint.artifactType,
          artifactJson: checkpoint.artifactJson,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    if (checkpoint.runId != runId ||
        owner._activeSceneScopeId != sceneScopeId ||
        owner._snapshot.runId != runId ||
        owner._snapshot.status != StoryGenerationRunStatus.running) {
      return;
    }
    if (!_isValidPipelineCheckpoint(checkpoint)) {
      // Fail closed: never persist malformed data that a later resume could
      // mistake for a completed stage.
      return;
    }
    final next =
        <StoryGenerationRunCheckpoint>[
          for (final existing in owner._snapshot.checkpoints)
            if (!_sameIdentity(existing, checkpoint)) existing,
          StoryGenerationRunCheckpoint(
            ordinal: checkpoint.ordinal,
            stageId: checkpoint.stageId,
            stageAttempt: checkpoint.stageAttempt,
            schemaVersion: checkpoint.schemaVersion,
            inputDigest: checkpoint.inputDigest,
            artifactDigest: checkpoint.artifactDigest,
            status: checkpoint.status,
            createdAtMs: checkpoint.createdAtMs,
            completedAtMs: checkpoint.completedAtMs,
            artifactType: checkpoint.artifactType,
            artifactJson: checkpoint.artifactJson,
          ),
        ]..sort((left, right) {
          final ordinal = left.ordinal.compareTo(right.ordinal);
          if (ordinal != 0) return ordinal;
          return left.stageAttempt.compareTo(right.stageAttempt);
        });
    await owner._setSnapshot(owner._snapshot.copyWith(checkpoints: next));
  }

  bool _sameIdentity(
    StoryGenerationRunCheckpoint existing,
    PipelineStageCheckpoint next,
  ) {
    return existing.ordinal == next.ordinal &&
        existing.stageId == next.stageId &&
        existing.stageAttempt == next.stageAttempt;
  }

  bool _isStructurallyValid(StoryGenerationRunCheckpoint checkpoint) {
    return checkpoint.ordinal >= 0 &&
        checkpoint.stageId.trim().isNotEmpty &&
        checkpoint.stageAttempt > 0 &&
        checkpoint.schemaVersion ==
            PipelineStageCheckpoint.currentSchemaVersion &&
        checkpoint.inputDigest.length == 64 &&
        (checkpoint.status == 'started' ||
            (checkpoint.isCompleted && checkpoint.artifactDigest.length == 64));
  }

  bool _isValidPipelineCheckpoint(PipelineStageCheckpoint checkpoint) {
    return checkpoint.ordinal >= 0 &&
        checkpoint.stageId.trim().isNotEmpty &&
        checkpoint.stageAttempt > 0 &&
        checkpoint.schemaVersion ==
            PipelineStageCheckpoint.currentSchemaVersion &&
        checkpoint.inputDigest.length == 64 &&
        (checkpoint.status == 'started' ||
            (checkpoint.isCompleted && checkpoint.artifactDigest.length == 64));
  }
}
