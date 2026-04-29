enum AuthorFeedbackPriority { low, normal, high }

enum AuthorFeedbackStatus {
  open,
  revisionRequested,
  inProgress,
  resolved,
  accepted,
  rejected,
}

class AuthorFeedbackDecision {
  const AuthorFeedbackDecision({
    required this.status,
    required this.note,
    required this.createdAt,
    this.sourceRunId,
    this.sourceReviewId,
  });

  final AuthorFeedbackStatus status;
  final String note;
  final DateTime createdAt;
  final String? sourceRunId;
  final String? sourceReviewId;

  Map<String, Object?> toJson() {
    return {
      'status': status.name,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'sourceRunId': sourceRunId,
      'sourceReviewId': sourceReviewId,
    };
  }

  static AuthorFeedbackDecision fromJson(Map<Object?, Object?> json) {
    return AuthorFeedbackDecision(
      status: _statusFromName(json['status']?.toString()),
      note: json['note']?.toString() ?? '',
      createdAt: _dateFromJson(json['createdAt']),
      sourceRunId: _optionalString(json['sourceRunId']),
      sourceReviewId: _optionalString(json['sourceReviewId']),
    );
  }
}

class AuthorFeedbackItem {
  const AuthorFeedbackItem({
    required this.id,
    required this.projectId,
    required this.chapterId,
    required this.sceneId,
    required this.sceneLabel,
    required this.note,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sourceRunId,
    this.sourceRunLabel,
    this.sourceReviewId,
    this.decisions = const [],
  });

  final String id;
  final String projectId;
  final String chapterId;
  final String sceneId;
  final String sceneLabel;
  final String note;
  final AuthorFeedbackPriority priority;
  final AuthorFeedbackStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourceRunId;
  final String? sourceRunLabel;
  final String? sourceReviewId;
  final List<AuthorFeedbackDecision> decisions;

  bool get isActive =>
      status == AuthorFeedbackStatus.open ||
      status == AuthorFeedbackStatus.revisionRequested ||
      status == AuthorFeedbackStatus.inProgress;

  AuthorFeedbackItem copyWith({
    String? note,
    AuthorFeedbackPriority? priority,
    AuthorFeedbackStatus? status,
    DateTime? updatedAt,
    List<AuthorFeedbackDecision>? decisions,
  }) {
    return AuthorFeedbackItem(
      id: id,
      projectId: projectId,
      chapterId: chapterId,
      sceneId: sceneId,
      sceneLabel: sceneLabel,
      note: note ?? this.note,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceRunId: sourceRunId,
      sourceRunLabel: sourceRunLabel,
      sourceReviewId: sourceReviewId,
      decisions: decisions ?? this.decisions,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'sceneLabel': sceneLabel,
      'note': note,
      'priority': priority.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sourceRunId': sourceRunId,
      'sourceRunLabel': sourceRunLabel,
      'sourceReviewId': sourceReviewId,
      'decisions': [for (final decision in decisions) decision.toJson()],
    };
  }

  static AuthorFeedbackItem fromJson(Map<Object?, Object?> json) {
    return AuthorFeedbackItem(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      sceneId: json['sceneId']?.toString() ?? '',
      sceneLabel: json['sceneLabel']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      priority: _priorityFromName(json['priority']?.toString()),
      status: _statusFromName(json['status']?.toString()),
      createdAt: _dateFromJson(json['createdAt']),
      updatedAt: _dateFromJson(json['updatedAt']),
      sourceRunId: _optionalString(json['sourceRunId']),
      sourceRunLabel: _optionalString(json['sourceRunLabel']),
      sourceReviewId: _optionalString(json['sourceReviewId']),
      decisions: [
        for (final raw in (json['decisions'] as List<Object?>? ?? const []))
          if (raw is Map<Object?, Object?>)
            AuthorFeedbackDecision.fromJson(raw),
      ],
    );
  }
}

AuthorFeedbackPriority _priorityFromName(String? name) {
  return AuthorFeedbackPriority.values.firstWhere(
    (candidate) => candidate.name == name,
    orElse: () => AuthorFeedbackPriority.normal,
  );
}

AuthorFeedbackStatus _statusFromName(String? name) {
  return AuthorFeedbackStatus.values.firstWhere(
    (candidate) => candidate.name == name,
    orElse: () => AuthorFeedbackStatus.open,
  );
}

DateTime _dateFromJson(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

String? _optionalString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}
