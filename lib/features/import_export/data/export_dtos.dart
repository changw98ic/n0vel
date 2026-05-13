import 'export_config.dart';

/// Lightweight DTO that applies [ExportConfig] filtering to a raw JSON map.
///
/// Each static method takes a raw JSON map and an optional [ExportConfig],
/// returning a filtered map with only the requested fields/entities.
class ExportFilter {
  const ExportFilter._();

  // ---------------------------------------------------------------------------
  // Workspace-level filtering
  // ---------------------------------------------------------------------------

  /// Filter the top-level workspace JSON according to [config].
  ///
  /// The workspace JSON has this shape:
  /// ```json
  /// {
  ///   "projects": [...],
  ///   "charactersByProject": {...},
  ///   "scenesByProject": {...},
  ///   "worldNodesByProject": {...},
  ///   "auditIssuesByProject": {...},
  ///   "projectStyles": {...},
  ///   "projectAuditStates": {...},
  ///   "projectTransferState": "...",
  ///   "currentProjectId": "..."
  /// }
  /// ```
  static Map<String, Object?> filterWorkspaceJson(
    Map<String, Object?> workspaceJson,
    ExportConfig config,
  ) {
    final result = <String, Object?>{};

    // Always preserve projectTransferState and currentProjectId (metadata).
    final transferState = workspaceJson['projectTransferState'];
    final currentProjectId = workspaceJson['currentProjectId'];
    if (transferState != null) {
      result['projectTransferState'] = transferState;
    }
    if (currentProjectId != null) {
      result['currentProjectId'] = currentProjectId;
    }

    // Projects – always included (needed for package identity).
    final rawProjects = workspaceJson['projects'];
    if (rawProjects is List) {
      result['projects'] = _filterList(
        rawProjects,
        ExportEntityType.workspace,
        config,
        timestampKey: 'lastOpenedAtMs',
      );
    }

    // Characters
    if (config.shouldExport(ExportEntityType.characters)) {
      final raw = workspaceJson['charactersByProject'];
      if (raw is Map) {
        result['charactersByProject'] = _filterNestedList(
          raw,
          ExportEntityType.characters,
          config,
        );
      }
    }

    // Scenes
    if (config.shouldExport(ExportEntityType.scenes)) {
      final raw = workspaceJson['scenesByProject'];
      if (raw is Map) {
        result['scenesByProject'] = _filterNestedList(
          raw,
          ExportEntityType.scenes,
          config,
        );
      }
    }

    // World nodes (grouped under workspace entity type)
    if (config.shouldExport(ExportEntityType.workspace)) {
      final raw = workspaceJson['worldNodesByProject'];
      if (raw is Map) {
        result['worldNodesByProject'] = _filterNestedList(
          raw,
          ExportEntityType.workspace,
          config,
        );
      }

      final auditRaw = workspaceJson['auditIssuesByProject'];
      if (auditRaw is Map) {
        result['auditIssuesByProject'] = _filterNestedList(
          auditRaw,
          ExportEntityType.workspace,
          config,
        );
      }

      final stylesRaw = workspaceJson['projectStyles'];
      if (stylesRaw is Map) {
        result['projectStyles'] = _filterNestedMap(
          stylesRaw,
          ExportEntityType.workspace,
          config,
        );
      }

      final auditStateRaw = workspaceJson['projectAuditStates'];
      if (auditStateRaw is Map) {
        result['projectAuditStates'] = _filterNestedMap(
          auditStateRaw,
          ExportEntityType.workspace,
          config,
        );
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Store payload filtering
  // ---------------------------------------------------------------------------

  /// Filter a generic store payload JSON by [entityType].
  ///
  /// For list-of-records payloads (e.g. versions, ai_history), this filters
  /// each record's fields.  For flat-map payloads (e.g. scene_context, draft),
  /// it filters the top-level keys.
  static Map<String, Object?> filterStorePayload(
    Map<String, Object?> payload,
    ExportEntityType entityType,
    ExportConfig config,
  ) {
    if (!config.shouldExport(entityType)) {
      return const {};
    }

    // Check for list-of-records pattern: top-level key "entries" with a List.
    final entriesKey = _entriesKey(payload);
    if (entriesKey != null) {
      final rawEntries = payload[entriesKey];
      if (rawEntries is List) {
        return {
          entriesKey: _filterList(rawEntries, entityType, config),
        };
      }
    }

    // Flat-map payload – filter top-level keys.
    return config.filterFields(entityType, payload);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Detect the key name for a list-of-records payload.
  ///
  /// Most stores use "entries", but some may use other keys.
  static String? _entriesKey(Map<String, Object?> payload) {
    for (final key in const ['entries']) {
      if (payload[key] is List) return key;
    }
    return null;
  }

  /// Filter a list of JSON records: apply field whitelist and time window.
  static List<Object?> _filterList(
    List<Object?> items,
    ExportEntityType entityType,
    ExportConfig config, {
    String? timestampKey,
  }) {
    return [
      for (final item in items)
        if (item is Map<String, Object?>)
          _filterRecord(item, entityType, config, timestampKey: timestampKey),
    ];
  }

  /// Filter a single JSON record.
  static Map<String, Object?> _filterRecord(
    Map<String, Object?> record,
    ExportEntityType entityType,
    ExportConfig config, {
    String? timestampKey,
  }) {
    // Time window filtering.
    if (timestampKey != null) {
      final ts = record[timestampKey];
      if (ts is int && !config.isInTimeWindow(ts)) {
        return const {};
      }
      if (ts is int && !config.isAfterIncremental(ts)) {
        return const {};
      }
    }

    // Field whitelist.
    return config.filterFields(entityType, record);
  }

  /// Filter a map of project-id -> list-of-records.
  static Map<String, Object?> _filterNestedList(
    Map raw,
    ExportEntityType entityType,
    ExportConfig config,
  ) {
    return {
      for (final entry in raw.entries)
        entry.key.toString(): _filterList(
          entry.value is List ? entry.value as List : [],
          entityType,
          config,
        ),
    };
  }

  /// Filter a map of project-id -> record-map.
  static Map<String, Object?> _filterNestedMap(
    Map raw,
    ExportEntityType entityType,
    ExportConfig config,
  ) {
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): config.filterFields(
            entityType,
            Map<String, Object?>.from(entry.value as Map),
          ),
    };
  }
}
