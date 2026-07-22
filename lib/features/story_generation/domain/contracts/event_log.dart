import 'typed_artifact.dart';

/// Machine-readable failure codes for pipeline events.
enum FailureCode {
  /// Transient issue — retry may succeed.
  recoverable,

  /// Quality score below threshold.
  qualityFail,

  /// Contradicts established world facts.
  canonViolation,

  /// Violates character's soul contract.
  soulViolation,

  /// Memory store returned corrupted or inconsistent data.
  memoryCorrupted,

  /// Token budget or cost limit exceeded.
  budgetExceeded,

  /// Stage is blocked by an upstream failure.
  blocked,

  /// Unrecoverable error — pipeline must abort.
  fatal,
}

/// A structured event emitted by pipeline stages.
class PipelineEvent {
  const PipelineEvent({
    required this.timestampMs,
    required this.stageId,
    required this.eventType,
    this.artifactType,
    this.failureCode,
    this.metadata = const {},
    this.durationMs,
  });

  final int timestampMs;
  final String stageId;
  final String eventType;
  final ArtifactType? artifactType;
  final FailureCode? failureCode;
  final Map<String, Object?> metadata;
  final int? durationMs;

  Map<String, Object?> toJson() => {
    'timestampMs': timestampMs,
    'stageId': stageId,
    'eventType': eventType,
    'artifactType': artifactType?.name,
    'failureCode': failureCode?.name,
    'metadata': metadata,
    'durationMs': durationMs,
  };

  factory PipelineEvent.fromJson(Map<String, Object?> json) {
    return PipelineEvent(
      timestampMs: _parseInt(json['timestampMs']),
      stageId: json['stageId']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      artifactType: _parseArtifactType(json['artifactType']),
      failureCode: _parseFailureCode(json['failureCode']),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
      durationMs: json['durationMs'] as int?,
    );
  }
}

// -- Parse helpers ------------------------------------------------------------

int _parseInt(Object? raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

final _artifactTypeByName = {for (final v in ArtifactType.values) v.name: v};

ArtifactType? _parseArtifactType(Object? raw) {
  if (raw == null) return null;
  return _artifactTypeByName[raw.toString()];
}

final _failureCodeByName = {for (final v in FailureCode.values) v.name: v};

FailureCode? _parseFailureCode(Object? raw) {
  if (raw == null) return null;
  return _failureCodeByName[raw.toString()];
}
