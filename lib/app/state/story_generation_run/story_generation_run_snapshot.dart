part of '../story_generation_run_store.dart';

enum StoryGenerationRunStatus { idle, running, completed, failed, cancelled }

/// Runtime status of a pipeline stage in a story generation run.
enum StoryGenerationRunStageStatus {
  /// Stage has not yet started.
  pending,

  /// Stage is currently executing.
  running,

  /// Stage completed successfully.
  completed,

  /// Stage failed with an error or rejection.
  failed,
}

/// Snapshot of a single pipeline stage's execution state.
///
/// Provides structured stage-level observability for the Run Center
/// without modifying the core generation algorithm.
class StoryGenerationRunStageSnapshot {
  const StoryGenerationRunStageSnapshot({
    required this.stageId,
    required this.label,
    required this.status,
    this.attempt = 1,
    this.failureCode,
    this.summary,
  });

  /// Stable stage identifier from [PipelineStageId].
  final PipelineStageId stageId;

  /// Human-readable stage label for UI display.
  final String label;

  /// Current runtime status of this stage.
  final StoryGenerationRunStageStatus status;

  /// Execution attempt number (starts at 1).
  final int attempt;

  /// Optional failure classification for failed stages.
  final String? failureCode;

  /// Optional human-readable summary of stage outcome or failure.
  final String? summary;

  /// Create a copy with modified fields.
  StoryGenerationRunStageSnapshot copyWith({
    PipelineStageId? stageId,
    String? label,
    StoryGenerationRunStageStatus? status,
    int? attempt,
    String? failureCode,
    String? summary,
  }) {
    return StoryGenerationRunStageSnapshot(
      stageId: stageId ?? this.stageId,
      label: label ?? this.label,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      failureCode: failureCode ?? this.failureCode,
      summary: summary ?? this.summary,
    );
  }

  /// Convert to JSON for persistence.
  Map<String, Object?> toJson() {
    return {
      'stageId': stageId.name,
      'label': label,
      'status': status.name,
      'attempt': attempt,
      'failureCode': failureCode,
      'summary': summary,
    };
  }

  /// Rehydrate from JSON with backward compatibility for missing fields.
  static StoryGenerationRunStageSnapshot fromJson(Map<String, Object?> json) {
    final stageIdName = json['stageId']?.toString() ?? '';
    final stageId = PipelineStageId.values.firstWhere(
      (candidate) => candidate.name == stageIdName,
      orElse: () => PipelineStageId.contextEnrichment,
    );
    final statusName = json['status']?.toString() ?? '';
    final status = StoryGenerationRunStageStatus.values.firstWhere(
      (candidate) => candidate.name == statusName,
      orElse: () => StoryGenerationRunStageStatus.pending,
    );
    return StoryGenerationRunStageSnapshot(
      stageId: stageId,
      label: json['label']?.toString() ?? '',
      status: status,
      attempt: json['attempt'] is int ? json['attempt'] as int : 1,
      failureCode: json['failureCode']?.toString(),
      summary: json['summary']?.toString(),
    );
  }

  /// Create initial stage snapshots from a pipeline preset.
  ///
  /// All stages start in [pending] status.
  static List<StoryGenerationRunStageSnapshot> fromPreset(
    PipelinePreset preset,
  ) {
    return preset.enabledStages.map((spec) {
      return StoryGenerationRunStageSnapshot(
        stageId: spec.id,
        label: spec.label,
        status: StoryGenerationRunStageStatus.pending,
      );
    }).toList();
  }
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
    },
    StoryGenerationRunPhase.candidate: {
      StoryGenerationRunPhase.feedback,
      StoryGenerationRunPhase.fail,
      StoryGenerationRunPhase.cancel,
    },
    StoryGenerationRunPhase.feedback: {
      StoryGenerationRunPhase.check,
      StoryGenerationRunPhase.commit,
      StoryGenerationRunPhase.candidate,
      StoryGenerationRunPhase.cancel,
    },
    StoryGenerationRunPhase.check: {
      StoryGenerationRunPhase.feedback,
      StoryGenerationRunPhase.commit,
      StoryGenerationRunPhase.fail,
      StoryGenerationRunPhase.cancel,
    },
    StoryGenerationRunPhase.fail: {StoryGenerationRunPhase.resume},
    StoryGenerationRunPhase.resume: {StoryGenerationRunPhase.candidate},
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
    this.participants = const [],
    this.messages = const [],
    this.stageTimeline = const [],
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
  final List<StoryGenerationRunParticipant> participants;
  final List<StoryGenerationRunMessage> messages;
  final List<StoryGenerationRunStageSnapshot> stageTimeline;

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
      'participants': [
        for (final participant in participants) participant.toJson(),
      ],
      'messages': [for (final message in messages) message.toJson()],
      'stageTimeline': [for (final stage in stageTimeline) stage.toJson()],
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
    final timelineList = json['stageTimeline'] as List<Object?>? ?? const [];
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
      stageTimeline: [
        for (final raw in timelineList)
          if (raw is Map)
            StoryGenerationRunStageSnapshot.fromJson(_asStringObjectMap(raw)),
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
    List<StoryGenerationRunParticipant>? participants,
    List<StoryGenerationRunMessage>? messages,
    List<StoryGenerationRunStageSnapshot>? stageTimeline,
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
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      stageTimeline: stageTimeline ?? this.stageTimeline,
    );
  }
}

StoryGenerationRunPhase _phaseForLegacyStatus(StoryGenerationRunStatus status) {
  return switch (status) {
    StoryGenerationRunStatus.failed => StoryGenerationRunPhase.fail,
    StoryGenerationRunStatus.cancelled => StoryGenerationRunPhase.cancel,
    StoryGenerationRunStatus.completed => StoryGenerationRunPhase.feedback,
    StoryGenerationRunStatus.idle ||
    StoryGenerationRunStatus.running => StoryGenerationRunPhase.draft,
  };
}
