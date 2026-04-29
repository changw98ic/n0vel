import 'package:novel_writer/app/state/app_storage_clone.dart';

/// What context an agent wants to retrieve during a turn.
class RetrievalIntent {
  RetrievalIntent({
    required this.characterId,
    required this.toolName,
    Map<String, Object?> parameters = const {},
    this.reasoning = '',
  }) : parameters = _immutableMap(parameters);

  final String characterId;
  final String toolName;
  final Map<String, Object?> parameters;
  final String reasoning;

  static const Set<String> allowedTools = {
    'character_profile',
    'relationship_history',
    'scene_context',
    'world_rule',
  };

  bool get isToolAllowed => allowedTools.contains(toolName);

  RetrievalIntent copyWith({
    String? characterId,
    String? toolName,
    Map<String, Object?>? parameters,
    String? reasoning,
  }) {
    return RetrievalIntent(
      characterId: characterId ?? this.characterId,
      toolName: toolName ?? this.toolName,
      parameters: parameters ?? this.parameters,
      reasoning: reasoning ?? this.reasoning,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'toolName': toolName,
      'parameters': parameters,
      'reasoning': reasoning,
    };
  }

  static RetrievalIntent fromJson(Map<Object?, Object?> json) {
    return RetrievalIntent(
      characterId: json['characterId']?.toString() ?? '',
      toolName: json['toolName']?.toString() ?? '',
      parameters: json['parameters'] is Map
          ? Map<String, Object?>.from(json['parameters'] as Map)
          : const {},
      reasoning: json['reasoning']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RetrievalIntent &&
        other.characterId == characterId &&
        other.toolName == toolName &&
        _mapEquals(other.parameters, parameters) &&
        other.reasoning == reasoning;
  }

  @override
  int get hashCode =>
      Object.hash(characterId, toolName, Object.hashAllUnordered(parameters.entries), reasoning);
}

/// Compressed retrieval result, bounded in size. Injected into prompts
/// instead of raw retrieval output so history stays small.
class ContextCapsule {
  ContextCapsule({
    required this.id,
    required this.sourceTool,
    required String summary,
    required this.charBudget,
    this.createdAtMs = 0,
    Map<String, Object?> metadata = const {},
  })  : assert(charBudget > 0, 'charBudget must be positive'),
        summary = summary.length > charBudget
            ? '${summary.substring(0, charBudget - 3)}...'
            : summary,
        metadata = _immutableMap(metadata);

  final String id;
  final String sourceTool;
  final String summary;
  final int charBudget;
  final int createdAtMs;
  final Map<String, Object?> metadata;

  bool get isWithinBudget => summary.length <= charBudget;

  ContextCapsule copyWith({
    String? id,
    String? sourceTool,
    String? summary,
    int? charBudget,
    int? createdAtMs,
    Map<String, Object?>? metadata,
  }) {
    return ContextCapsule(
      id: id ?? this.id,
      sourceTool: sourceTool ?? this.sourceTool,
      summary: summary ?? this.summary,
      charBudget: charBudget ?? this.charBudget,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sourceTool': sourceTool,
      'summary': summary,
      'charBudget': charBudget,
      'createdAtMs': createdAtMs,
      'metadata': metadata,
    };
  }

  static ContextCapsule fromJson(Map<Object?, Object?> json) {
    return ContextCapsule(
      id: json['id']?.toString() ?? '',
      sourceTool: json['sourceTool']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      charBudget: _parseIntOrFallback(json['charBudget'], fallback: 200),
      createdAtMs: _parseIntOrFallback(json['createdAtMs'], fallback: 0),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContextCapsule &&
        other.id == id &&
        other.sourceTool == sourceTool &&
        other.summary == summary &&
        other.charBudget == charBudget &&
        other.createdAtMs == createdAtMs &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        sourceTool,
        summary,
        charBudget,
        createdAtMs,
        Object.hashAllUnordered(metadata.entries),
      );
}

/// Enforces prompt size limits by tracking character budget allocation.
class PromptBudget {
  PromptBudget({required this.maxChars, int reservedChars = 0})
      : assert(maxChars > 0, 'maxChars must be positive'),
        assert(reservedChars >= 0, 'reservedChars must be non-negative'),
        _allocated = reservedChars.clamp(0, maxChars - 1);

  final int maxChars;
  int _allocated;

  int get remaining => maxChars - _allocated;
  bool get isExhausted => remaining <= 0;
  double get utilization => _allocated / maxChars;

  bool tryAllocate(int charCount) {
    if (charCount <= 0 || charCount > remaining) return false;
    _allocated += charCount;
    return true;
  }

  void release(int charCount) {
    _allocated = (_allocated - charCount).clamp(0, _allocated);
  }

  void reset({int reservedChars = 0}) {
    _allocated = reservedChars.clamp(0, maxChars - 1);
  }
}

/// Pipeline stages that require telemetry tracking.
enum ScenePipelineStage {
  retrieval,
  capsuleCompression,
  resolution,
  editorial,
}

/// A single telemetry record for a pipeline stage execution.
class ScenePipelineTelemetryEntry {
  ScenePipelineTelemetryEntry({
    required this.sceneId,
    required this.stage,
    required this.startedAtMs,
    required this.completedAtMs,
    required this.succeeded,
    this.detail = '',
    Map<String, Object?> metadata = const {},
  }) : metadata = _immutableMap(metadata);

  final String sceneId;
  final ScenePipelineStage stage;
  final int startedAtMs;
  final int completedAtMs;
  final bool succeeded;
  final String detail;
  final Map<String, Object?> metadata;

  int get durationMs => completedAtMs - startedAtMs;

  Map<String, Object?> toJson() {
    return {
      'sceneId': sceneId,
      'stage': stage.name,
      'startedAtMs': startedAtMs,
      'completedAtMs': completedAtMs,
      'succeeded': succeeded,
      'detail': detail,
      'metadata': metadata,
    };
  }

  static ScenePipelineTelemetryEntry fromJson(Map<Object?, Object?> json) {
    return ScenePipelineTelemetryEntry(
      sceneId: json['sceneId']?.toString() ?? '',
      stage: _parseStage(json['stage']),
      startedAtMs: _parseIntOrFallback(json['startedAtMs'], fallback: 0),
      completedAtMs: _parseIntOrFallback(json['completedAtMs'], fallback: 0),
      succeeded: json['succeeded'] == true,
      detail: json['detail']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }
}

// -- Shared helpers ----------------------------------------------------------

Map<String, Object?> _immutableMap(Map<String, Object?> value) {
  return Map<String, Object?>.unmodifiable({
    for (final entry in cloneStorageMap(value).entries)
      entry.key: entry.value,
  });
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

int _parseIntOrFallback(Object? raw, {required int fallback}) {
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

ScenePipelineStage _parseStage(Object? raw) {
  final name = raw?.toString() ?? '';
  for (final stage in ScenePipelineStage.values) {
    if (stage.name == name) return stage;
  }
  return ScenePipelineStage.retrieval;
}
