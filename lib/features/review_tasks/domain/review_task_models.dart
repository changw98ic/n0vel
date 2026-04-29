import 'package:novel_writer/app/state/app_storage_clone.dart';

enum ReviewTaskSeverity { info, warning, critical }

enum ReviewTaskStatus { open, inProgress, resolved, ignored }

class ReviewTaskReference {
  ReviewTaskReference({
    this.projectId,
    this.chapterId,
    this.chapterTitle = '',
    this.sceneId,
    this.sceneTitle = '',
  });

  final String? projectId;
  final String? chapterId;
  final String chapterTitle;
  final String? sceneId;
  final String sceneTitle;

  Map<String, Object?> toJson() {
    return {
      'projectId': projectId,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'sceneId': sceneId,
      'sceneTitle': sceneTitle,
    };
  }

  static ReviewTaskReference fromJson(Map<Object?, Object?> json) {
    return ReviewTaskReference(
      projectId: _optionalString(json['projectId']),
      chapterId: _optionalString(json['chapterId']),
      chapterTitle: json['chapterTitle']?.toString() ?? '',
      sceneId: _optionalString(json['sceneId']),
      sceneTitle: json['sceneTitle']?.toString() ?? '',
    );
  }
}

class ReviewTaskSource {
  ReviewTaskSource({
    required this.kind,
    this.reviewId = '',
    this.runId = '',
    this.passName = '',
    Map<String, Object?> metadata = const {},
  }) : metadata = immutableMap(metadata);

  final String kind;
  final String reviewId;
  final String runId;
  final String passName;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'reviewId': reviewId,
      'runId': runId,
      'passName': passName,
      'metadata': Map<String, Object?>.from(metadata),
    };
  }

  static ReviewTaskSource fromJson(Map<Object?, Object?> json) {
    return ReviewTaskSource(
      kind: json['kind']?.toString() ?? '',
      reviewId: json['reviewId']?.toString() ?? '',
      runId: json['runId']?.toString() ?? '',
      passName: json['passName']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }
}

class ReviewTask {
  ReviewTask({
    required this.id,
    required this.severity,
    required this.status,
    required this.title,
    required this.body,
    required this.reference,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final ReviewTaskSeverity severity;
  final ReviewTaskStatus status;
  final String title;
  final String body;
  final ReviewTaskReference reference;
  final ReviewTaskSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewTask copyWith({
    ReviewTaskSeverity? severity,
    ReviewTaskStatus? status,
    String? title,
    String? body,
    ReviewTaskReference? reference,
    ReviewTaskSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewTask(
      id: id,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      title: title ?? this.title,
      body: body ?? this.body,
      reference: reference ?? this.reference,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'severity': severity.name,
      'status': status.name,
      'title': title,
      'body': body,
      'reference': reference.toJson(),
      'source': source.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ReviewTask fromJson(Map<Object?, Object?> json) {
    return ReviewTask(
      id: json['id']?.toString() ?? '',
      severity: _enumByName(
        ReviewTaskSeverity.values,
        json['severity']?.toString(),
        ReviewTaskSeverity.warning,
      ),
      status: _enumByName(
        ReviewTaskStatus.values,
        json['status']?.toString(),
        ReviewTaskStatus.open,
      ),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      reference: json['reference'] is Map
          ? ReviewTaskReference.fromJson(
              Map<Object?, Object?>.from(json['reference'] as Map),
            )
          : ReviewTaskReference(),
      source: json['source'] is Map
          ? ReviewTaskSource.fromJson(
              Map<Object?, Object?>.from(json['source'] as Map),
            )
          : ReviewTaskSource(kind: ''),
      createdAt: _dateTime(json['createdAt']),
      updatedAt: _dateTime(json['updatedAt']),
    );
  }
}

String? _optionalString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

DateTime _dateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}
