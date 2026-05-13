/// Export configuration for controlling what gets exported and how.
///
/// Pass an [ExportConfig] to [ProjectTransferService.exportPackage] to
/// control entity types, field whitelists, time windows, and incremental
/// export behaviour.
///
/// Defaults (via [ExportConfig.full] or the default constructor) export
/// everything, matching the pre-refactor behaviour.
class ExportConfig {
  const ExportConfig({
    this.entityTypes,
    this.fieldWhitelist,
    this.timeWindow,
    this.incrementalSince,
  });

  /// Entity types to include.  `null` means "include all".
  final Set<ExportEntityType>? entityTypes;

  /// Per-entity-type field whitelist.  `null` value for a key means "all
  /// fields".  A top-level `null` means "all fields for everything".
  final Map<ExportEntityType, Set<String>>? fieldWhitelist;

  /// Only include entities created/modified within this time window.
  final ExportTimeWindow? timeWindow;

  /// When non-null, only export entities modified after this timestamp.
  final DateTime? incrementalSince;

  /// Full export – every entity type, every field, no time filter.
  static const ExportConfig full = ExportConfig();

  /// Export only prose content (drafts, scenes, versions).
  static const ExportConfig proseOnly = ExportConfig(
    entityTypes: {
      ExportEntityType.drafts,
      ExportEntityType.scenes,
      ExportEntityType.versions,
    },
  );

  /// Export only structural content (outlines, characters, scenes).
  static const ExportConfig structureOnly = ExportConfig(
    entityTypes: {
      ExportEntityType.outlines,
      ExportEntityType.characters,
      ExportEntityType.scenes,
    },
  );

  /// Whether [type] should be exported under this config.
  bool shouldExport(ExportEntityType type) {
    final types = entityTypes;
    return types == null || types.contains(type);
  }

  /// Whether [field] should be included for [type].
  bool shouldIncludeField(ExportEntityType type, String field) {
    final whitelist = fieldWhitelist;
    if (whitelist == null) return true;
    final allowed = whitelist[type];
    if (allowed == null) return true;
    return allowed.contains(field);
  }

  /// Filter a JSON map down to the fields allowed for [type].
  Map<String, Object?> filterFields(
    ExportEntityType type,
    Map<String, Object?> json,
  ) {
    final whitelist = fieldWhitelist;
    if (whitelist == null) return json;
    final allowed = whitelist[type];
    if (allowed == null) return json;
    return {
      for (final entry in json.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// Check whether a timestamp (milliseconds since epoch) falls within the
  /// configured time window.
  bool isInTimeWindow(int? timestampMs) {
    if (timestampMs == null) return true;
    final window = timeWindow;
    if (window == null) return true;
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    if (window.start != null && dt.isBefore(window.start!)) return false;
    if (window.end != null && dt.isAfter(window.end!)) return false;
    return true;
  }

  /// Check whether a timestamp (ms since epoch) is newer than
  /// [incrementalSince].
  bool isAfterIncremental(int? timestampMs) {
    final since = incrementalSince;
    if (since == null) return true;
    if (timestampMs == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(timestampMs).isAfter(since);
  }
}

/// Entity types that can be exported.
enum ExportEntityType {
  /// workspace.json – projects, characters, scenes, world nodes, styles,
  /// audit issues.
  workspace,

  /// draft.json
  drafts,

  /// versions.json
  versions,

  /// ai_history.json
  aiHistory,

  /// scene_context.json
  sceneContext,

  /// simulation.json
  simulations,

  /// outline.json
  outlines,

  /// generation_state.json
  generationState,

  /// story_memory.json (async)
  storyMemory,

  /// roleplay_state.json (async)
  roleplayState,

  /// Characters extracted from workspace.
  characters,

  /// Scenes extracted from workspace.
  scenes,
}

/// Time window for filtering exported entities.
class ExportTimeWindow {
  const ExportTimeWindow({this.start, this.end});

  /// Inclusive lower bound.  `null` means no lower bound.
  final DateTime? start;

  /// Inclusive upper bound.  `null` means no upper bound.
  final DateTime? end;
}
