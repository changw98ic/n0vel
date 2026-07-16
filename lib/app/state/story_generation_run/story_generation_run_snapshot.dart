part of '../story_generation_run_store.dart';

enum StoryGenerationRunStatus {
  idle,
  running,
  completed,
  preliminaryReviewBlocked,
  finalReviewBlocked,
  qualityBlocked,
  budgetBlocked,
  conflict,
  failed,
  cancelled,
}

enum StoryGenerationRunPhase {
  draft,
  candidate,
  feedback,
  check,
  commit,
  fail,
  cancel,
  resume,
  preliminaryReviewBlocked,
  finalReviewBlocked,
  qualityBlocked,
  budgetBlocked,
  conflict,
}

/// A fail-closed presentation projection for the author-candidate surface.
///
/// This is intentionally derived from the persisted run pointer instead of
/// treating [StoryGenerationRunSnapshot.candidateProse] as authority.  The
/// prose cache is displayable only alongside every proof identity required by
/// the author-accept transaction.
enum StoryGenerationCandidatePresentationState {
  none,
  generating,
  ready,
  committed,
  rejected,
  cancelled,
  evidenceUnavailable,
  qualityBlocked,
  reviewBlocked,
  budgetBlocked,
  conflict,
  failed,
}

class StoryGenerationCandidatePresentation {
  const StoryGenerationCandidatePresentation({
    required this.state,
    required this.headline,
    required this.message,
    this.prose = '',
  });

  final StoryGenerationCandidatePresentationState state;
  final String headline;
  final String message;

  /// Non-empty only for a proof-bound candidate that may be author accepted.
  final String prose;

  bool get canAccept =>
      state == StoryGenerationCandidatePresentationState.ready;
  bool get canReject =>
      state == StoryGenerationCandidatePresentationState.ready;
  bool get showsCandidateProse => canAccept && prose.trim().isNotEmpty;
}

class StoryGenerationRunPhaseTransitionResult {
  const StoryGenerationRunPhaseTransitionResult._({
    required this.from,
    required this.to,
    required this.accepted,
    required this.message,
  });

  factory StoryGenerationRunPhaseTransitionResult.accepted({
    required StoryGenerationRunPhase from,
    required StoryGenerationRunPhase to,
  }) {
    return StoryGenerationRunPhaseTransitionResult._(
      from: from,
      to: to,
      accepted: true,
      message: '',
    );
  }

  factory StoryGenerationRunPhaseTransitionResult.rejected({
    required StoryGenerationRunPhase from,
    required StoryGenerationRunPhase to,
  }) {
    return StoryGenerationRunPhaseTransitionResult._(
      from: from,
      to: to,
      accepted: false,
      message:
          'Invalid story generation phase transition: '
          '${from.name} -> ${to.name}.',
    );
  }

  final StoryGenerationRunPhase from;
  final StoryGenerationRunPhase to;
  final bool accepted;
  final String message;
}

class StoryGenerationRunPhaseTransitions {
  const StoryGenerationRunPhaseTransitions._();

  static StoryGenerationRunPhaseTransitionResult validate(
    StoryGenerationRunPhase from,
    StoryGenerationRunPhase to,
  ) {
    if (from == to || _allowed[from]?.contains(to) == true) {
      return StoryGenerationRunPhaseTransitionResult.accepted(
        from: from,
        to: to,
      );
    }
    return StoryGenerationRunPhaseTransitionResult.rejected(from: from, to: to);
  }

  static const Map<StoryGenerationRunPhase, Set<StoryGenerationRunPhase>>
  _allowed = {
    StoryGenerationRunPhase.draft: {
      StoryGenerationRunPhase.candidate,
      StoryGenerationRunPhase.fail,
      StoryGenerationRunPhase.cancel,
      StoryGenerationRunPhase.preliminaryReviewBlocked,
      StoryGenerationRunPhase.finalReviewBlocked,
      StoryGenerationRunPhase.qualityBlocked,
      StoryGenerationRunPhase.budgetBlocked,
      StoryGenerationRunPhase.conflict,
    },
    StoryGenerationRunPhase.candidate: {
      StoryGenerationRunPhase.feedback,
      StoryGenerationRunPhase.fail,
      StoryGenerationRunPhase.cancel,
      StoryGenerationRunPhase.preliminaryReviewBlocked,
      StoryGenerationRunPhase.finalReviewBlocked,
      StoryGenerationRunPhase.qualityBlocked,
      StoryGenerationRunPhase.budgetBlocked,
      StoryGenerationRunPhase.conflict,
    },
    StoryGenerationRunPhase.feedback: {
      StoryGenerationRunPhase.check,
      StoryGenerationRunPhase.commit,
      StoryGenerationRunPhase.candidate,
      StoryGenerationRunPhase.cancel,
      StoryGenerationRunPhase.preliminaryReviewBlocked,
      StoryGenerationRunPhase.finalReviewBlocked,
      StoryGenerationRunPhase.qualityBlocked,
      StoryGenerationRunPhase.budgetBlocked,
      StoryGenerationRunPhase.conflict,
    },
    StoryGenerationRunPhase.check: {
      StoryGenerationRunPhase.feedback,
      StoryGenerationRunPhase.commit,
      StoryGenerationRunPhase.fail,
      StoryGenerationRunPhase.cancel,
      StoryGenerationRunPhase.preliminaryReviewBlocked,
      StoryGenerationRunPhase.finalReviewBlocked,
      StoryGenerationRunPhase.qualityBlocked,
      StoryGenerationRunPhase.budgetBlocked,
      StoryGenerationRunPhase.conflict,
    },
    StoryGenerationRunPhase.fail: {StoryGenerationRunPhase.resume},
    StoryGenerationRunPhase.resume: {StoryGenerationRunPhase.candidate},
    StoryGenerationRunPhase.preliminaryReviewBlocked: {
      StoryGenerationRunPhase.cancel,
    },
    StoryGenerationRunPhase.finalReviewBlocked: {
      StoryGenerationRunPhase.cancel,
    },
    StoryGenerationRunPhase.qualityBlocked: {StoryGenerationRunPhase.cancel},
    StoryGenerationRunPhase.budgetBlocked: {StoryGenerationRunPhase.cancel},
    StoryGenerationRunPhase.conflict: {StoryGenerationRunPhase.cancel},
  };
}

enum StoryGenerationRunMessageKind {
  status,
  director,
  roleTurn,
  beat,
  editorial,
  review,
  authorFeedback,
  error,
}

class StoryGenerationRunParticipant {
  const StoryGenerationRunParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.summary,
    required this.statusSummary,
  });

  final String id;
  final String name;
  final String role;
  final String summary;
  final String statusSummary;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'summary': summary,
      'statusSummary': statusSummary,
    };
  }

  static StoryGenerationRunParticipant fromJson(Map<String, Object?> json) {
    return StoryGenerationRunParticipant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      statusSummary: json['statusSummary']?.toString() ?? '',
    );
  }
}

class StoryGenerationRunMessage {
  const StoryGenerationRunMessage({
    required this.title,
    required this.body,
    required this.kind,
    this.participantId,
  });

  final String title;
  final String body;
  final StoryGenerationRunMessageKind kind;
  final String? participantId;

  Map<String, Object?> toJson() {
    return {
      'title': title,
      'body': body,
      'kind': kind.name,
      'participantId': participantId,
    };
  }

  static StoryGenerationRunMessage fromJson(Map<String, Object?> json) {
    final kindName = json['kind']?.toString() ?? '';
    final kind = StoryGenerationRunMessageKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse: () => StoryGenerationRunMessageKind.status,
    );
    return StoryGenerationRunMessage(
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      kind: kind,
      participantId: json['participantId']?.toString(),
    );
  }
}

class StoryGenerationRunSnapshot {
  const StoryGenerationRunSnapshot({
    required this.status,
    this.phase = StoryGenerationRunPhase.draft,
    required this.sceneId,
    required this.sceneLabel,
    required this.headline,
    required this.summary,
    required this.stageSummary,
    this.turnLabel = '',
    this.errorDetail = '',
    this.candidateProse = '',
    this.candidateRevision,
    this.candidateHash = '',
    this.candidateFinalProseHash = '',
    this.candidateDeterministicGateEvidenceHash = '',
    this.candidateFinalCouncilEvidenceHash = '',
    this.candidateQualityEvidenceHash = '',
    this.candidatePendingWriteSetHash = '',
    this.candidateMaterialDigest = '',
    this.candidateInputDigest = '',
    this.candidateBaseDraftHash = '',
    this.candidateGenerationBundleHash = '',
    this.runId = '',
    this.checkpointSchemaVersion = 1,
    this.checkpoints = const [],
    this.participants = const [],
    this.messages = const [],
  });

  final StoryGenerationRunStatus status;
  final StoryGenerationRunPhase phase;
  final String sceneId;
  final String sceneLabel;
  final String headline;
  final String summary;
  final String stageSummary;
  final String turnLabel;
  final String errorDetail;

  /// The exact output text displayed as this run's recoverable candidate.
  ///
  /// This is a compatibility snapshot, not a CandidateProof or an author
  /// commit receipt. The ledger lane will replace it with durable candidate
  /// payload storage before author acceptance is enabled.
  final String candidateProse;

  /// Presentation pointer to the ledger proof.  The prose above is a cached
  /// preview only; acceptance reads the database proof/payload by this exact
  /// identity and never trusts the snapshot text.
  final int? candidateRevision;
  final String candidateHash;
  final String candidateFinalProseHash;
  final String candidateDeterministicGateEvidenceHash;
  final String candidateFinalCouncilEvidenceHash;
  final String candidateQualityEvidenceHash;
  final String candidatePendingWriteSetHash;
  final String candidateMaterialDigest;
  final String candidateInputDigest;
  final String candidateBaseDraftHash;
  final String candidateGenerationBundleHash;

  bool get hasDurableCandidateProof =>
      runId.trim().isNotEmpty &&
      candidateRevision != null &&
      candidateHash.trim().isNotEmpty &&
      candidateFinalProseHash.trim().isNotEmpty &&
      candidateDeterministicGateEvidenceHash.trim().isNotEmpty &&
      candidateFinalCouncilEvidenceHash.trim().isNotEmpty &&
      candidateQualityEvidenceHash.trim().isNotEmpty &&
      candidatePendingWriteSetHash.trim().isNotEmpty &&
      candidateMaterialDigest.trim().isNotEmpty &&
      candidateInputDigest.trim().isNotEmpty &&
      candidateBaseDraftHash.trim().isNotEmpty &&
      candidateGenerationBundleHash.trim().isNotEmpty;

  /// Whether this snapshot is allowed to expose its cached candidate payload
  /// to the authoring UI.  This cannot establish database truth by itself;
  /// restoration validates the proof/payload pair against the ledger before a
  /// snapshot reaches the UI.
  bool get hasDisplayableDurableCandidate =>
      status == StoryGenerationRunStatus.completed &&
      phase != StoryGenerationRunPhase.commit &&
      phase != StoryGenerationRunPhase.cancel &&
      hasDurableCandidateProof &&
      candidateProse.trim().isNotEmpty;

  StoryGenerationCandidatePresentation get candidatePresentation {
    if (phase == StoryGenerationRunPhase.commit) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.committed,
        headline: '候选稿已采纳',
        message: '作者采纳已经提交；正文和批准的生成写入以同一事务落库。',
      );
    }
    if (status == StoryGenerationRunStatus.cancelled ||
        phase == StoryGenerationRunPhase.cancel) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.cancelled,
        headline: '本场生成已取消',
        message: '运行已停止，未采纳的内容不会写入正文或长期记忆。',
      );
    }
    if (_isExplicitlyRejectedCandidate) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.rejected,
        headline: '候选稿已拒绝',
        message: '作者没有采纳此候选；正文、版本和长期记忆均未提交。',
      );
    }
    switch (status) {
      case StoryGenerationRunStatus.preliminaryReviewBlocked:
        return const StoryGenerationCandidatePresentation(
          state: StoryGenerationCandidatePresentationState.reviewBlocked,
          headline: '初审阻断了候选生成',
          message: '当前正文的初审重试已耗尽。该 revision 只能查看、取消或由作者编辑后重新生成；系统不会自动恢复。',
        );
      case StoryGenerationRunStatus.finalReviewBlocked:
        return const StoryGenerationCandidatePresentation(
          state: StoryGenerationCandidatePresentationState.reviewBlocked,
          headline: '终审阻断了候选生成',
          message: '当前正文的终审重试已耗尽。该 revision 只能查看、取消或由作者编辑后重新生成；系统不会自动恢复。',
        );
      case StoryGenerationRunStatus.qualityBlocked:
        return const StoryGenerationCandidatePresentation(
          state: StoryGenerationCandidatePresentationState.qualityBlocked,
          headline: '质量门禁未通过',
          message: '当前正文不能生成候选。只有在仍有预算且作者形成新正文后才能重新尝试；系统不会自动恢复。',
        );
      case StoryGenerationRunStatus.budgetBlocked:
        return const StoryGenerationCandidatePresentation(
          state: StoryGenerationCandidatePresentationState.budgetBlocked,
          headline: '预算门禁阻断了本场生成',
          message: '该运行的预算已耗尽，只能取消或创建新的运行；系统不会自动恢复或追加预算。',
        );
      case StoryGenerationRunStatus.conflict:
        return const StoryGenerationCandidatePresentation(
          state: StoryGenerationCandidatePresentationState.conflict,
          headline: '资料或正文发生冲突',
          message: '候选或运行没有提交。请确认正文和资料后创建新的运行；系统不会自动覆盖或恢复。',
        );
      case StoryGenerationRunStatus.idle:
      case StoryGenerationRunStatus.running:
      case StoryGenerationRunStatus.completed:
      case StoryGenerationRunStatus.failed:
      case StoryGenerationRunStatus.cancelled:
        break;
    }
    if (status == StoryGenerationRunStatus.failed) {
      return _blockedPresentation(errorDetail);
    }
    if (hasDisplayableDurableCandidate) {
      return StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.ready,
        headline: '候选稿等待作者采纳',
        message: '正文已与候选证明绑定。采纳会提交正文和已批准写入；拒绝不会提交任何权威状态。',
        prose: candidateProse,
      );
    }
    if (_containsCandidateMaterialWithoutProof) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.evidenceUnavailable,
        headline: '候选证据不可用',
        message: '候选正文缺少可验证的 proof 或持久化正文载荷，不能展示或采纳；系统不会自动恢复它。',
      );
    }
    if (status == StoryGenerationRunStatus.running) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.generating,
        headline: '正在生成候选稿',
        message: '本场仍在运行；完成前不会显示可采纳正文。',
      );
    }
    return const StoryGenerationCandidatePresentation(
      state: StoryGenerationCandidatePresentationState.none,
      headline: '',
      message: '',
    );
  }

  bool get _isExplicitlyRejectedCandidate =>
      phase == StoryGenerationRunPhase.feedback &&
      stageSummary.trim() == '已拒绝' &&
      !hasDurableCandidateProof &&
      candidateProse.trim().isEmpty;

  bool get _containsCandidateMaterialWithoutProof =>
      candidateProse.trim().isNotEmpty ||
      candidateRevision != null ||
      candidateHash.trim().isNotEmpty ||
      candidateFinalProseHash.trim().isNotEmpty ||
      candidateDeterministicGateEvidenceHash.trim().isNotEmpty ||
      candidateFinalCouncilEvidenceHash.trim().isNotEmpty ||
      candidateQualityEvidenceHash.trim().isNotEmpty ||
      candidatePendingWriteSetHash.trim().isNotEmpty ||
      candidateMaterialDigest.trim().isNotEmpty ||
      candidateInputDigest.trim().isNotEmpty ||
      candidateBaseDraftHash.trim().isNotEmpty ||
      candidateGenerationBundleHash.trim().isNotEmpty;

  StoryGenerationCandidatePresentation _blockedPresentation(String detail) {
    final normalized = detail.toLowerCase();
    if (normalized.contains('budget')) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.budgetBlocked,
        headline: '预算门禁阻断了本场生成',
        message: '该运行不能在原预算上继续请求。可以取消，或创建新的运行；系统没有自动恢复。',
      );
    }
    if (normalized.contains('quality')) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.qualityBlocked,
        headline: '质量门禁未通过',
        message: '缺分、解析异常或质量分不足时不能生成候选。请修改后重新生成；系统没有自动恢复。',
      );
    }
    if (normalized.contains('review')) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.reviewBlocked,
        headline: '评审阻断了候选生成',
        message: '本次正文未通过所需评审，不能采纳。请根据评审反馈重新生成；系统没有自动恢复。',
      );
    }
    if (normalized.contains('material') ||
        normalized.contains('draft') ||
        normalized.contains('conflict')) {
      return const StoryGenerationCandidatePresentation(
        state: StoryGenerationCandidatePresentationState.conflict,
        headline: '资料或正文发生冲突',
        message: '当前候选未被提交。请确认正文和资料后重新生成；系统没有自动覆盖或恢复。',
      );
    }
    return const StoryGenerationCandidatePresentation(
      state: StoryGenerationCandidatePresentationState.failed,
      headline: '本场生成未完成',
      message: '运行没有产生可采纳候选。请查看运行详情后决定是否重新生成；系统没有自动恢复。',
    );
  }

  /// Local lifecycle identity.  This deliberately is not a candidate proof:
  /// only the ledger/finalization path can create a proof for author accept.
  final String runId;

  /// Versioned checkpoint envelopes retained only to resume work safely.
  final int checkpointSchemaVersion;
  final List<StoryGenerationRunCheckpoint> checkpoints;
  final List<StoryGenerationRunParticipant> participants;
  final List<StoryGenerationRunMessage> messages;

  bool get hasRun => status != StoryGenerationRunStatus.idle;

  Map<String, Object?> toJson() {
    return {
      'status': status.name,
      'phase': phase.name,
      'sceneId': sceneId,
      'sceneLabel': sceneLabel,
      'headline': headline,
      'summary': summary,
      'stageSummary': stageSummary,
      'turnLabel': turnLabel,
      'errorDetail': errorDetail,
      'candidateProse': candidateProse,
      'candidateRevision': candidateRevision,
      'candidateHash': candidateHash,
      'candidateFinalProseHash': candidateFinalProseHash,
      'candidateDeterministicGateEvidenceHash':
          candidateDeterministicGateEvidenceHash,
      'candidateFinalCouncilEvidenceHash': candidateFinalCouncilEvidenceHash,
      'candidateQualityEvidenceHash': candidateQualityEvidenceHash,
      'candidatePendingWriteSetHash': candidatePendingWriteSetHash,
      'candidateMaterialDigest': candidateMaterialDigest,
      'candidateInputDigest': candidateInputDigest,
      'candidateBaseDraftHash': candidateBaseDraftHash,
      'candidateGenerationBundleHash': candidateGenerationBundleHash,
      'runId': runId,
      'checkpointSchemaVersion': checkpointSchemaVersion,
      'checkpoints': [
        for (final checkpoint in checkpoints) checkpoint.toJson(),
      ],
      'participants': [
        for (final participant in participants) participant.toJson(),
      ],
      'messages': [for (final message in messages) message.toJson()],
    };
  }

  static StoryGenerationRunSnapshot fromJson(Map<String, Object?> json) {
    final statusName = json['status']?.toString() ?? '';
    final status = StoryGenerationRunStatus.values.firstWhere(
      (candidate) => candidate.name == statusName,
      orElse: () => StoryGenerationRunStatus.idle,
    );
    final phaseName = json['phase']?.toString() ?? '';
    final phase = StoryGenerationRunPhase.values.firstWhere(
      (candidate) => candidate.name == phaseName,
      orElse: () => _phaseForLegacyStatus(status),
    );
    return StoryGenerationRunSnapshot(
      status: status,
      phase: phase,
      sceneId: json['sceneId']?.toString() ?? '',
      sceneLabel: json['sceneLabel']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      stageSummary: json['stageSummary']?.toString() ?? '',
      turnLabel: json['turnLabel']?.toString() ?? '',
      errorDetail: json['errorDetail']?.toString() ?? '',
      candidateProse: json['candidateProse']?.toString() ?? '',
      candidateRevision: int.tryParse(
        json['candidateRevision']?.toString() ?? '',
      ),
      candidateHash: json['candidateHash']?.toString() ?? '',
      candidateFinalProseHash:
          json['candidateFinalProseHash']?.toString() ?? '',
      candidateDeterministicGateEvidenceHash:
          json['candidateDeterministicGateEvidenceHash']?.toString() ?? '',
      candidateFinalCouncilEvidenceHash:
          json['candidateFinalCouncilEvidenceHash']?.toString() ?? '',
      candidateQualityEvidenceHash:
          json['candidateQualityEvidenceHash']?.toString() ?? '',
      candidatePendingWriteSetHash:
          json['candidatePendingWriteSetHash']?.toString() ?? '',
      candidateMaterialDigest:
          json['candidateMaterialDigest']?.toString() ?? '',
      candidateInputDigest: json['candidateInputDigest']?.toString() ?? '',
      candidateBaseDraftHash: json['candidateBaseDraftHash']?.toString() ?? '',
      candidateGenerationBundleHash:
          json['candidateGenerationBundleHash']?.toString() ?? '',
      runId: json['runId']?.toString() ?? '',
      checkpointSchemaVersion:
          int.tryParse(json['checkpointSchemaVersion']?.toString() ?? '') ?? 1,
      checkpoints: _checkpointsFromJson(json['checkpoints']),
      participants: [
        for (final raw in (json['participants'] as List<Object?>? ?? const []))
          if (raw is Map)
            StoryGenerationRunParticipant.fromJson(_asStringObjectMap(raw)),
      ],
      messages: [
        for (final raw in (json['messages'] as List<Object?>? ?? const []))
          if (raw is Map)
            StoryGenerationRunMessage.fromJson(_asStringObjectMap(raw)),
      ],
    );
  }

  StoryGenerationRunSnapshot copyWith({
    StoryGenerationRunStatus? status,
    StoryGenerationRunPhase? phase,
    String? sceneId,
    String? sceneLabel,
    String? headline,
    String? summary,
    String? stageSummary,
    String? turnLabel,
    String? errorDetail,
    String? candidateProse,
    int? candidateRevision,
    bool clearCandidateRevision = false,
    String? candidateHash,
    String? candidateFinalProseHash,
    String? candidateDeterministicGateEvidenceHash,
    String? candidateFinalCouncilEvidenceHash,
    String? candidateQualityEvidenceHash,
    String? candidatePendingWriteSetHash,
    String? candidateMaterialDigest,
    String? candidateInputDigest,
    String? candidateBaseDraftHash,
    String? candidateGenerationBundleHash,
    String? runId,
    int? checkpointSchemaVersion,
    List<StoryGenerationRunCheckpoint>? checkpoints,
    List<StoryGenerationRunParticipant>? participants,
    List<StoryGenerationRunMessage>? messages,
  }) {
    return StoryGenerationRunSnapshot(
      status: status ?? this.status,
      phase: phase ?? this.phase,
      sceneId: sceneId ?? this.sceneId,
      sceneLabel: sceneLabel ?? this.sceneLabel,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      stageSummary: stageSummary ?? this.stageSummary,
      turnLabel: turnLabel ?? this.turnLabel,
      errorDetail: errorDetail ?? this.errorDetail,
      candidateProse: candidateProse ?? this.candidateProse,
      candidateRevision: clearCandidateRevision
          ? null
          : candidateRevision ?? this.candidateRevision,
      candidateHash: candidateHash ?? this.candidateHash,
      candidateFinalProseHash:
          candidateFinalProseHash ?? this.candidateFinalProseHash,
      candidateDeterministicGateEvidenceHash:
          candidateDeterministicGateEvidenceHash ??
          this.candidateDeterministicGateEvidenceHash,
      candidateFinalCouncilEvidenceHash:
          candidateFinalCouncilEvidenceHash ??
          this.candidateFinalCouncilEvidenceHash,
      candidateQualityEvidenceHash:
          candidateQualityEvidenceHash ?? this.candidateQualityEvidenceHash,
      candidatePendingWriteSetHash:
          candidatePendingWriteSetHash ?? this.candidatePendingWriteSetHash,
      candidateMaterialDigest:
          candidateMaterialDigest ?? this.candidateMaterialDigest,
      candidateInputDigest: candidateInputDigest ?? this.candidateInputDigest,
      candidateBaseDraftHash:
          candidateBaseDraftHash ?? this.candidateBaseDraftHash,
      candidateGenerationBundleHash:
          candidateGenerationBundleHash ?? this.candidateGenerationBundleHash,
      runId: runId ?? this.runId,
      checkpointSchemaVersion:
          checkpointSchemaVersion ?? this.checkpointSchemaVersion,
      checkpoints: checkpoints ?? this.checkpoints,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
    );
  }
}

/// A local, typed stage checkpoint envelope. It is intentionally separate
/// from a durable CandidateProof: a checkpoint may be discarded whenever its
/// version, continuity or digest verification fails.
class StoryGenerationRunCheckpoint {
  const StoryGenerationRunCheckpoint({
    required this.ordinal,
    required this.stageId,
    required this.stageAttempt,
    required this.schemaVersion,
    required this.inputDigest,
    required this.artifactDigest,
    required this.status,
    required this.createdAtMs,
    this.completedAtMs,
    this.artifactType = '',
    this.artifactJson = const {},
  });

  final int ordinal;
  final String stageId;
  final int stageAttempt;
  final int schemaVersion;
  final String inputDigest;
  final String artifactDigest;
  final String status;
  final int createdAtMs;
  final int? completedAtMs;
  final String artifactType;
  final Map<String, Object?> artifactJson;

  bool get isCompleted => status == 'completed' && completedAtMs != null;

  Map<String, Object?> toJson() => {
    'ordinal': ordinal,
    'stageId': stageId,
    'stageAttempt': stageAttempt,
    'schemaVersion': schemaVersion,
    'inputDigest': inputDigest,
    'artifactDigest': artifactDigest,
    'status': status,
    'createdAtMs': createdAtMs,
    'completedAtMs': completedAtMs,
    'artifactType': artifactType,
    'artifactJson': artifactJson,
  };

  static StoryGenerationRunCheckpoint fromJson(Map<String, Object?> json) {
    return StoryGenerationRunCheckpoint(
      ordinal: int.tryParse(json['ordinal']?.toString() ?? '') ?? -1,
      stageId: json['stageId']?.toString() ?? '',
      stageAttempt: int.tryParse(json['stageAttempt']?.toString() ?? '') ?? 0,
      schemaVersion: int.tryParse(json['schemaVersion']?.toString() ?? '') ?? 0,
      inputDigest: json['inputDigest']?.toString() ?? '',
      artifactDigest: json['artifactDigest']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAtMs: int.tryParse(json['createdAtMs']?.toString() ?? '') ?? 0,
      completedAtMs: int.tryParse(json['completedAtMs']?.toString() ?? ''),
      artifactType: json['artifactType']?.toString() ?? '',
      artifactJson: _asStringObjectMap(json['artifactJson']),
    );
  }
}

List<StoryGenerationRunCheckpoint> _checkpointsFromJson(Object? raw) {
  if (raw is! List) return const [];
  final checkpoints = <StoryGenerationRunCheckpoint>[];
  for (final entry in raw) {
    if (entry is Map) {
      checkpoints.add(
        StoryGenerationRunCheckpoint.fromJson(_asStringObjectMap(entry)),
      );
    }
  }
  return List.unmodifiable(checkpoints);
}

StoryGenerationRunPhase _phaseForLegacyStatus(StoryGenerationRunStatus status) {
  return switch (status) {
    StoryGenerationRunStatus.failed => StoryGenerationRunPhase.fail,
    StoryGenerationRunStatus.cancelled => StoryGenerationRunPhase.cancel,
    StoryGenerationRunStatus.completed => StoryGenerationRunPhase.feedback,
    StoryGenerationRunStatus.preliminaryReviewBlocked =>
      StoryGenerationRunPhase.preliminaryReviewBlocked,
    StoryGenerationRunStatus.finalReviewBlocked =>
      StoryGenerationRunPhase.finalReviewBlocked,
    StoryGenerationRunStatus.qualityBlocked =>
      StoryGenerationRunPhase.qualityBlocked,
    StoryGenerationRunStatus.budgetBlocked =>
      StoryGenerationRunPhase.budgetBlocked,
    StoryGenerationRunStatus.conflict => StoryGenerationRunPhase.conflict,
    StoryGenerationRunStatus.idle ||
    StoryGenerationRunStatus.running => StoryGenerationRunPhase.draft,
  };
}
