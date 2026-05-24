/// Explicit pipeline topology definition for runtime hardening.
///
/// Extracted from M2-01: makes the nine-stage scene pipeline structure
/// declarative while preserving existing behavior. Stages are identified by
/// stable IDs for UI/API usage, with flags for runtime filtering.
///
/// See:
/// - TASK-M2-01 PipelineDefinition/preset extraction (#32)
/// - M2-02: user-custom pipelines (future)
library;

/// Stable identifiers for built-in pipeline stages.
///
/// These IDs are versioned API contracts — renaming or reordering
/// requires migration consideration.
enum PipelineStageId {
  /// Step 1: Cross-chapter context enrichment, memory indexing, RAG.
  contextEnrichment,

  /// Step 2: Scene planning with director orchestration.
  scenePlanning,

  /// Step 3: Character roleplay session execution.
  roleplay,

  /// Step 4: Stage narration generation.
  stageNarration,

  /// Step 5: Beat resolution and state determination.
  beatResolution,

  /// Step 6: Editorial prose draft generation.
  editorial,

  /// Step 7: Quality review with gate logic.
  review,

  /// Step 8: Prose polishing.
  polish,

  /// Step 9: Finalization, memory writeback, arc tracking.
  finalization,
}

/// Declarative specification for a single pipeline stage.
class PipelineStageSpec {
  const PipelineStageSpec({
    required this.id,
    required this.label,
    required this.description,
    this.enabled = true,
  });

  /// Stable stage identifier from [PipelineStageId].
  final PipelineStageId id;

  /// Human-readable label for UI display.
  final String label;

  /// Short description of the stage's purpose.
  final String description;

  /// Whether this stage participates in pipeline execution.
  ///
  /// When false, the stage is skipped during iteration. The default preset
  /// has all stages enabled; this is reserved for future customization.
  final bool enabled;

  /// Create a copy with [enabled] toggled or modified.
  PipelineStageSpec copyWith({bool? enabled}) {
    return PipelineStageSpec(
      id: id,
      label: label,
      description: description,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Convert to JSON for persistence or API transfer.
  Map<String, Object?> toJson() {
    return {
      'id': id.name,
      'label': label,
      'description': description,
      'enabled': enabled,
    };
  }

  /// Rehydrate from JSON.
  static PipelineStageSpec fromJson(Map<String, Object?> json) {
    return PipelineStageSpec(
      id: PipelineStageId.values.byName(json['id'] as String),
      label: json['label'] as String,
      description: json['description'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// A named pipeline preset defining an ordered sequence of stages.
///
/// Presets are declarative configuration — the runtime runner consumes
/// them to order and filter stage execution.
class PipelinePreset {
  const PipelinePreset({
    required this.id,
    required this.name,
    required this.stages,
  });

  /// Unique preset identifier (e.g., 'default-nine-stage').
  final String id;

  /// Human-readable preset name.
  final String name;

  /// Ordered stage specifications defining the pipeline topology.
  final List<PipelineStageSpec> stages;

  /// Create a copy with modified stages or metadata.
  PipelinePreset copyWith({
    String? id,
    String? name,
    List<PipelineStageSpec>? stages,
  }) {
    return PipelinePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      stages: stages ?? this.stages,
    );
  }

  /// Project only enabled stages for execution.
  List<PipelineStageSpec> get enabledStages {
    return stages.where((s) => s.enabled).toList();
  }

  /// Convert to JSON.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'stages': stages.map((s) => s.toJson()).toList(),
    };
  }

  /// Rehydrate from JSON.
  static PipelinePreset fromJson(Map<String, Object?> json) {
    return PipelinePreset(
      id: json['id'] as String,
      name: json['name'] as String,
      stages: (json['stages'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(PipelineStageSpec.fromJson)
          .toList(),
    );
  }
}

/// Built-in pipeline presets.
///
/// Exposes stable presets for the current nine-stage pipeline.
/// Future M2-02 work will add user-custom preset management here.
class BuiltInPresets {
  // Private constructor — static access only.
  BuiltInPresets._();

  /// The default nine-stage scene generation pipeline.
  ///
  /// Preserves the exact stage order and semantics from the legacy
  /// [PipelineStageRunnerImpl] hard-coded sequence.
  static const PipelinePreset defaultNineStage = PipelinePreset(
    id: 'default-nine-stage',
    name: '标准九阶段场景生成管线',
    stages: [
      PipelineStageSpec(
        id: PipelineStageId.contextEnrichment,
        label: '上下文增强',
        description: '跨章节上下文增强、记忆索引、RAG检索',
      ),
      PipelineStageSpec(
        id: PipelineStageId.scenePlanning,
        label: '场景规划',
        description: '导演协调场景结构规划',
      ),
      PipelineStageSpec(
        id: PipelineStageId.roleplay,
        label: '角色扮演',
        description: '执行角色扮演会话',
      ),
      PipelineStageSpec(
        id: PipelineStageId.stageNarration,
        label: '舞台旁白',
        description: '生成舞台旁白文本',
      ),
      PipelineStageSpec(
        id: PipelineStageId.beatResolution,
        label: '节奏解析',
        description: '解析节奏并确定状态',
      ),
      PipelineStageSpec(
        id: PipelineStageId.editorial,
        label: '编辑草稿',
        description: '生成编辑草稿',
      ),
      PipelineStageSpec(
        id: PipelineStageId.review,
        label: '质量审查',
        description: '质量审查与门控逻辑',
      ),
      PipelineStageSpec(
        id: PipelineStageId.polish,
        label: '润色',
        description: '散文润色',
      ),
      PipelineStageSpec(
        id: PipelineStageId.finalization,
        label: '收尾',
        description: '收尾、记忆回写、弧线追踪',
      ),
    ],
  );
}
