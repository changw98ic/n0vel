import 'dart:convert';

import '../../domain/workspace_models.dart' as domain;
import '../../features/import_export/data/markdown_exporter.dart';
import '../../features/import_export/data/markdown_importer.dart';

/// Direction for a Markdown mirror sync plan.
enum PendingOverlaySyncDirection { sqliteToMarkdown, markdownToSqlite }

/// Target entity kind for overlay entries.
enum OverlayTargetKind { project, scene, character, worldNode, draft }

/// Overlay status representing the difference state.
enum OverlayStatus {
  /// No difference detected.
  unchanged,

  /// Pending record differs from source.
  pending,

  /// Both source and pending have unmergeable changes.
  conflict,

  /// Entry has been resolved with a decision.
  resolved,
}

/// Resolution decision for a pending entry.
enum OverlayDecision {
  /// No decision made yet.
  undecided,

  /// Keep the source (SQLite/app state) version.
  keepSource,

  /// Keep the pending (Markdown mirror-side) version.
  keepPending,
}

/// Reference to a target entity within the workspace.
class OverlayTargetRef {
  const OverlayTargetRef({required this.kind, required this.id});

  final OverlayTargetKind kind;
  final String id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OverlayTargetRef && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Fingerprint for comparing entity states.
class OverlayFingerprint {
  const OverlayFingerprint(this.value);

  factory OverlayFingerprint.fromCanonicalJson(Map<String, Object?> json) {
    const encoder = JsonEncoder.withIndent('');
    final canonicalized = _canonicalize(json);
    final canonical = encoder.convert(canonicalized);
    final bytes = utf8.encode(canonical);
    final hash = _hashBytes(bytes);
    return OverlayFingerprint(hash);
  }

  final String value;

  bool matches(OverlayFingerprint other) => value == other.value;

  @override
  String toString() => value;

  /// Simple hash function for deterministic fingerprints.
  static String _hashBytes(List<int> bytes) {
    var hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Recursively canonicalizes a value by sorting all map keys.
  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final canonicalized = <String, Object?>{};
      final sortedKeys = value.keys.toList()..sort();
      for (final key in sortedKeys) {
        canonicalized[key as String] = _canonicalize(value[key]);
      }
      return canonicalized;
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }
}

/// Summary for display in overlay UI.
class OverlaySummary {
  const OverlaySummary({required this.kind, required this.title, this.detail});

  final OverlayTargetKind kind;
  final String title;
  final String? detail;

  factory OverlaySummary.forProject(domain.ProjectRecord project) {
    return OverlaySummary(
      kind: OverlayTargetKind.project,
      title: project.title,
      detail: _truncate(project.summary),
    );
  }

  factory OverlaySummary.forScene(domain.SceneRecord scene) {
    return OverlaySummary(
      kind: OverlayTargetKind.scene,
      title: scene.title,
      detail: _truncate(scene.summary),
    );
  }

  factory OverlaySummary.forCharacter(domain.CharacterRecord character) {
    return OverlaySummary(
      kind: OverlayTargetKind.character,
      title: character.name,
      detail: character.role.isNotEmpty ? character.role : null,
    );
  }

  factory OverlaySummary.forWorldNode(domain.WorldNodeRecord node) {
    return OverlaySummary(
      kind: OverlayTargetKind.worldNode,
      title: node.title,
      detail: node.type.isNotEmpty ? node.type : null,
    );
  }

  factory OverlaySummary.forDraft(String draftText) {
    return OverlaySummary(
      kind: OverlayTargetKind.draft,
      title: '草稿文本',
      detail: _truncate(draftText),
    );
  }

  static String _truncate(String text, {int max = 50}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }
}

/// A single overlay entry representing a difference between source and pending.
class OverlayEntry {
  const OverlayEntry({
    required this.id,
    required this.targetRef,
    required this.status,
    this.decision = OverlayDecision.undecided,
    required this.sourceFingerprint,
    required this.pendingFingerprint,
    this.sourceSummary,
    this.pendingSummary,
    this.changedFields,
  });

  /// Stable entry ID (deterministic based on target kind and id).
  final String id;

  /// Reference to the target entity.
  final OverlayTargetRef targetRef;

  /// Current status of this entry.
  final OverlayStatus status;

  /// Resolution decision.
  final OverlayDecision decision;

  /// Fingerprint of source state.
  final OverlayFingerprint sourceFingerprint;

  /// Fingerprint of pending state.
  final OverlayFingerprint pendingFingerprint;

  /// Human-readable summary of source state.
  final OverlaySummary? sourceSummary;

  /// Human-readable summary of pending state.
  final OverlaySummary? pendingSummary;

  /// List of changed field names (for debugging/display).
  final List<String>? changedFields;

  /// Whether this entry has a pending difference.
  bool get isPending => status == OverlayStatus.pending;

  /// Whether this entry is a conflict.
  bool get isConflict => status == OverlayStatus.conflict;

  /// Whether this entry has been resolved.
  bool get isResolved => status == OverlayStatus.resolved;

  /// Create a copy with modified fields.
  OverlayEntry copyWith({
    String? id,
    OverlayTargetRef? targetRef,
    OverlayStatus? status,
    OverlayDecision? decision,
    OverlayFingerprint? sourceFingerprint,
    OverlayFingerprint? pendingFingerprint,
    OverlaySummary? sourceSummary,
    OverlaySummary? pendingSummary,
    List<String>? changedFields,
  }) {
    return OverlayEntry(
      id: id ?? this.id,
      targetRef: targetRef ?? this.targetRef,
      status: status ?? this.status,
      decision: decision ?? this.decision,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      pendingFingerprint: pendingFingerprint ?? this.pendingFingerprint,
      sourceSummary: sourceSummary ?? this.sourceSummary,
      pendingSummary: pendingSummary ?? this.pendingSummary,
      changedFields: changedFields ?? this.changedFields,
    );
  }

  /// Create an entry with the given decision.
  OverlayEntry withDecision(OverlayDecision newDecision) {
    return copyWith(decision: newDecision, status: OverlayStatus.resolved);
  }
}

/// Snapshot of pending overlay state with entries and counts.
class OverlayPlan {
  const OverlayPlan({
    required this.entries,
    required this.totalCount,
    required this.pendingCount,
    required this.conflictCount,
    required this.resolvedCount,
    required this.unchangedCount,
  });

  final List<OverlayEntry> entries;
  final int totalCount;
  final int pendingCount;
  final int conflictCount;
  final int resolvedCount;
  final int unchangedCount;

  /// Get entries by status.
  List<OverlayEntry> entriesByStatus(OverlayStatus status) {
    return entries.where((e) => e.status == status).toList();
  }

  /// Get entries by target kind.
  List<OverlayEntry> entriesByKind(OverlayTargetKind kind) {
    return entries.where((e) => e.targetRef.kind == kind).toList();
  }

  /// Check if plan has any unresolved entries.
  bool get hasUnresolved => pendingCount + conflictCount > 0;

  /// Check if plan is fully resolved.
  bool get isFullyResolved => hasUnresolved == false;
}

/// Result of resolving overlay entries.
class OverlayResolutionResult {
  const OverlayResolutionResult({
    required this.project,
    required this.scenes,
    required this.characters,
    required this.worldNodes,
    required this.draftText,
    required this.appliedDecisions,
  });

  final domain.ProjectRecord project;
  final List<domain.SceneRecord> scenes;
  final List<domain.CharacterRecord> characters;
  final List<domain.WorldNodeRecord> worldNodes;
  final String draftText;
  final List<OverlayEntry> appliedDecisions;

  /// Convert the resolved state back into exporter input.
  MarkdownExportInput toMarkdownExportInput() {
    return MarkdownExportInput(
      project: project,
      scenes: scenes,
      characters: characters,
      worldNodes: worldNodes,
      draftText: draftText,
    );
  }
}

/// Input for building pending overlay plan.
class PendingOverlayInput {
  const PendingOverlayInput({
    required this.sourceProject,
    required this.sourceScenes,
    required this.sourceCharacters,
    required this.sourceWorldNodes,
    this.sourceDraftText = '',
    required this.pendingProject,
    required this.pendingScenes,
    required this.pendingCharacters,
    required this.pendingWorldNodes,
    this.pendingDraftText = '',
  });

  /// Create overlay input from two exporter snapshots.
  factory PendingOverlayInput.fromExportInputs({
    required MarkdownExportInput source,
    required MarkdownExportInput pending,
  }) {
    return PendingOverlayInput(
      sourceProject: source.project,
      sourceScenes: source.scenes,
      sourceCharacters: source.characters,
      sourceWorldNodes: source.worldNodes,
      sourceDraftText: source.draftText,
      pendingProject: pending.project,
      pendingScenes: pending.scenes,
      pendingCharacters: pending.characters,
      pendingWorldNodes: pending.worldNodes,
      pendingDraftText: pending.draftText,
    );
  }

  final domain.ProjectRecord sourceProject;
  final List<domain.SceneRecord> sourceScenes;
  final List<domain.CharacterRecord> sourceCharacters;
  final List<domain.WorldNodeRecord> sourceWorldNodes;
  final String sourceDraftText;

  final domain.ProjectRecord pendingProject;
  final List<domain.SceneRecord> pendingScenes;
  final List<domain.CharacterRecord> pendingCharacters;
  final List<domain.WorldNodeRecord> pendingWorldNodes;
  final String pendingDraftText;

  /// Snapshot the source side as markdown exporter input.
  MarkdownExportInput toSourceExportInput() {
    return MarkdownExportInput(
      project: sourceProject,
      scenes: sourceScenes,
      characters: sourceCharacters,
      worldNodes: sourceWorldNodes,
      draftText: sourceDraftText,
    );
  }

  /// Snapshot the pending side as markdown exporter input.
  MarkdownExportInput toPendingExportInput() {
    return MarkdownExportInput(
      project: pendingProject,
      scenes: pendingScenes,
      characters: pendingCharacters,
      worldNodes: pendingWorldNodes,
      draftText: pendingDraftText,
    );
  }
}

/// Sync plan that bridges Markdown importer output to overlay review.
class PendingOverlaySyncPlan {
  const PendingOverlaySyncPlan({
    required this.direction,
    required this.input,
    required this.overlayPlan,
    this.importPlan,
    this.importIssues = const [],
  });

  final PendingOverlaySyncDirection direction;
  final PendingOverlayInput input;
  final OverlayPlan overlayPlan;
  final MarkdownImportPlan? importPlan;
  final List<MarkdownImportIssue> importIssues;

  List<MarkdownImportIssue> get blockingIssues =>
      importIssues.where((issue) => issue.blocking).toList(growable: false);

  bool get hasBlockingIssues => blockingIssues.isNotEmpty;

  bool get needsUserReview =>
      hasBlockingIssues ||
      overlayPlan.pendingCount > 0 ||
      overlayPlan.conflictCount > 0;
}

/// Store for pending overlay between SQLite and Markdown mirror.
class PendingOverlayStore {
  /// Build a SQLite -> Markdown mirror plan from two exporter snapshots.
  PendingOverlaySyncPlan buildMarkdownExportPlan({
    required MarkdownExportInput source,
    required MarkdownExportInput pending,
  }) {
    final input = PendingOverlayInput.fromExportInputs(
      source: source,
      pending: pending,
    );
    return PendingOverlaySyncPlan(
      direction: PendingOverlaySyncDirection.sqliteToMarkdown,
      input: input,
      overlayPlan: buildPlan(input),
    );
  }

  /// Build a Markdown -> SQLite review plan from an importer result.
  ///
  /// Blocking imports keep the pending side equal to source so a corrupt or
  /// incomplete mirror scan cannot accidentally plan deletions.
  PendingOverlaySyncPlan buildMarkdownImportPlan({
    required MarkdownExportInput source,
    required MarkdownImportResult importResult,
  }) {
    final hasBlockingIssues =
        importResult.project == null || importResult.plan.hasBlockingIssues;
    final pending = hasBlockingIssues
        ? source
        : MarkdownExportInput(
            project: importResult.project!,
            scenes: importResult.scenes,
            characters: importResult.characters,
            worldNodes: importResult.worldNodes,
            draftText: importResult.draftText,
          );

    final input = PendingOverlayInput.fromExportInputs(
      source: source,
      pending: pending,
    );
    final basePlan = buildPlan(input);
    final overlayPlan = hasBlockingIssues
        ? basePlan
        : _applyImportStatesToPlan(basePlan, importResult.plan);

    return PendingOverlaySyncPlan(
      direction: PendingOverlaySyncDirection.markdownToSqlite,
      input: input,
      overlayPlan: overlayPlan,
      importPlan: importResult.plan,
      importIssues: importResult.plan.issues,
    );
  }

  /// Build an overlay plan comparing source and pending states.
  OverlayPlan buildPlan(PendingOverlayInput input) {
    final entries = <OverlayEntry>[];

    // Compare project metadata
    final projectEntry = _compareProject(
      input.sourceProject,
      input.pendingProject,
    );
    entries.add(projectEntry);

    // Compare scenes
    entries.addAll(_compareScenes(input.sourceScenes, input.pendingScenes));

    // Compare characters
    entries.addAll(
      _compareCharacters(input.sourceCharacters, input.pendingCharacters),
    );

    // Compare world nodes
    entries.addAll(
      _compareWorldNodes(input.sourceWorldNodes, input.pendingWorldNodes),
    );

    // Compare draft text
    if (input.sourceDraftText.isNotEmpty || input.pendingDraftText.isNotEmpty) {
      final draftEntry = _compareDraft(
        input.sourceDraftText,
        input.pendingDraftText,
      );
      entries.add(draftEntry);
    }

    // Sort entries deterministically: by kind, then by id
    entries.sort((a, b) {
      final kindCompare = a.targetRef.kind.index.compareTo(
        b.targetRef.kind.index,
      );
      if (kindCompare != 0) return kindCompare;
      return a.targetRef.id.compareTo(b.targetRef.id);
    });

    return _countEntries(entries);
  }

  /// Apply decisions to produce resolved output.
  OverlayResolutionResult resolve(
    PendingOverlayInput input,
    List<OverlayEntry> entries,
  ) {
    final sceneDecisions = <String, OverlayDecision>{};
    final characterDecisions = <String, OverlayDecision>{};
    final worldNodeDecisions = <String, OverlayDecision>{};
    OverlayDecision? projectDecision;
    OverlayDecision? draftDecision;

    // Collect all decisions
    for (final entry in entries) {
      if (entry.decision == OverlayDecision.undecided) continue;

      switch (entry.targetRef.kind) {
        case OverlayTargetKind.project:
          projectDecision = entry.decision;
          break;
        case OverlayTargetKind.scene:
          sceneDecisions[entry.targetRef.id] = entry.decision;
          break;
        case OverlayTargetKind.character:
          characterDecisions[entry.targetRef.id] = entry.decision;
          break;
        case OverlayTargetKind.worldNode:
          worldNodeDecisions[entry.targetRef.id] = entry.decision;
          break;
        case OverlayTargetKind.draft:
          draftDecision = entry.decision;
          break;
      }
    }

    // Build resolved output
    final resolvedProject = projectDecision == OverlayDecision.keepPending
        ? input.pendingProject
        : input.sourceProject;

    final resolvedScenes = _resolveScenes(
      input.sourceScenes,
      input.pendingScenes,
      sceneDecisions,
    );

    final resolvedCharacters = _resolveCharacters(
      input.sourceCharacters,
      input.pendingCharacters,
      characterDecisions,
    );

    final resolvedWorldNodes = _resolveWorldNodes(
      input.sourceWorldNodes,
      input.pendingWorldNodes,
      worldNodeDecisions,
    );

    final resolvedDraftText = draftDecision == OverlayDecision.keepPending
        ? input.pendingDraftText
        : input.sourceDraftText;

    // Collect applied decisions (entries with non-undecided decisions)
    final appliedDecisions = entries
        .where((e) => e.decision != OverlayDecision.undecided)
        .toList();

    return OverlayResolutionResult(
      project: resolvedProject,
      scenes: resolvedScenes,
      characters: resolvedCharacters,
      worldNodes: resolvedWorldNodes,
      draftText: resolvedDraftText,
      appliedDecisions: appliedDecisions,
    );
  }

  /// Update an entry's decision in a plan.
  OverlayPlan updateDecision(
    OverlayPlan plan,
    String entryId,
    OverlayDecision decision,
  ) {
    final updatedEntries = plan.entries.map((e) {
      if (e.id == entryId) {
        return e.withDecision(decision);
      }
      return e;
    }).toList();

    return _countEntries(updatedEntries);
  }

  OverlayEntry _compareProject(
    domain.ProjectRecord source,
    domain.ProjectRecord pending,
  ) {
    final sourceJson = source.toJson();
    final pendingJson = pending.toJson();

    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    final changedFields = _findChangedFields(sourceJson, pendingJson);

    final status = _determineStatus(
      sourceFingerprint,
      pendingFingerprint,
      wasAdded: false,
      wasDeleted: false,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.project, source.id),
      targetRef: OverlayTargetRef(
        kind: OverlayTargetKind.project,
        id: source.id,
      ),
      status: status,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: pendingFingerprint,
      sourceSummary: OverlaySummary.forProject(source),
      pendingSummary: OverlaySummary.forProject(pending),
      changedFields: changedFields,
    );
  }

  List<OverlayEntry> _compareScenes(
    List<domain.SceneRecord> source,
    List<domain.SceneRecord> pending,
  ) {
    final sourceMap = {for (final s in source) s.id: s};
    final pendingMap = {for (final s in pending) s.id: s};

    final allIds = {...sourceMap.keys, ...pendingMap.keys}.toList()..sort();

    final entries = <OverlayEntry>[];

    for (final id in allIds) {
      final sourceScene = sourceMap[id];
      final pendingScene = pendingMap[id];

      if (sourceScene == null) {
        // Added in pending
        entries.add(_addedSceneEntry(id, pendingScene!));
      } else if (pendingScene == null) {
        // Deleted in pending (or added in source)
        entries.add(_deletedSceneEntry(id, sourceScene));
      } else {
        // Exists in both - compare
        entries.add(_compareScene(sourceScene, pendingScene));
      }
    }

    return entries;
  }

  OverlayEntry _compareScene(
    domain.SceneRecord source,
    domain.SceneRecord pending,
  ) {
    final sourceJson = source.toJson();
    final pendingJson = pending.toJson();

    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    final changedFields = _findChangedFields(sourceJson, pendingJson);

    final status = _determineStatus(
      sourceFingerprint,
      pendingFingerprint,
      wasAdded: false,
      wasDeleted: false,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.scene, source.id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.scene, id: source.id),
      status: status,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: pendingFingerprint,
      sourceSummary: OverlaySummary.forScene(source),
      pendingSummary: OverlaySummary.forScene(pending),
      changedFields: changedFields,
    );
  }

  OverlayEntry _addedSceneEntry(String id, domain.SceneRecord pendingScene) {
    final pendingJson = pendingScene.toJson();
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.scene, id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.scene, id: id),
      status: OverlayStatus.pending,
      sourceFingerprint: const OverlayFingerprint(''),
      pendingFingerprint: pendingFingerprint,
      sourceSummary: null,
      pendingSummary: OverlaySummary.forScene(pendingScene),
      changedFields: ['added'],
    );
  }

  OverlayEntry _deletedSceneEntry(String id, domain.SceneRecord sourceScene) {
    final sourceJson = sourceScene.toJson();
    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.scene, id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.scene, id: id),
      status: OverlayStatus.pending,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: const OverlayFingerprint(''),
      sourceSummary: OverlaySummary.forScene(sourceScene),
      pendingSummary: null,
      changedFields: ['deleted'],
    );
  }

  List<OverlayEntry> _compareCharacters(
    List<domain.CharacterRecord> source,
    List<domain.CharacterRecord> pending,
  ) {
    final sourceMap = {for (final c in source) c.id: c};
    final pendingMap = {for (final c in pending) c.id: c};

    final allIds = {...sourceMap.keys, ...pendingMap.keys}.toList()..sort();

    final entries = <OverlayEntry>[];

    for (final id in allIds) {
      final sourceChar = sourceMap[id];
      final pendingChar = pendingMap[id];

      if (sourceChar == null) {
        entries.add(_addedCharacterEntry(id, pendingChar!));
      } else if (pendingChar == null) {
        entries.add(_deletedCharacterEntry(id, sourceChar));
      } else {
        entries.add(_compareCharacter(sourceChar, pendingChar));
      }
    }

    return entries;
  }

  OverlayEntry _compareCharacter(
    domain.CharacterRecord source,
    domain.CharacterRecord pending,
  ) {
    final sourceJson = source.toJson();
    final pendingJson = pending.toJson();

    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    final changedFields = _findChangedFields(sourceJson, pendingJson);

    final status = _determineStatus(
      sourceFingerprint,
      pendingFingerprint,
      wasAdded: false,
      wasDeleted: false,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.character, source.id),
      targetRef: OverlayTargetRef(
        kind: OverlayTargetKind.character,
        id: source.id,
      ),
      status: status,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: pendingFingerprint,
      sourceSummary: OverlaySummary.forCharacter(source),
      pendingSummary: OverlaySummary.forCharacter(pending),
      changedFields: changedFields,
    );
  }

  OverlayEntry _addedCharacterEntry(
    String id,
    domain.CharacterRecord pendingChar,
  ) {
    final pendingJson = pendingChar.toJson();
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.character, id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.character, id: id),
      status: OverlayStatus.pending,
      sourceFingerprint: const OverlayFingerprint(''),
      pendingFingerprint: pendingFingerprint,
      sourceSummary: null,
      pendingSummary: OverlaySummary.forCharacter(pendingChar),
      changedFields: ['added'],
    );
  }

  OverlayEntry _deletedCharacterEntry(
    String id,
    domain.CharacterRecord sourceChar,
  ) {
    final sourceJson = sourceChar.toJson();
    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.character, id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.character, id: id),
      status: OverlayStatus.pending,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: const OverlayFingerprint(''),
      sourceSummary: OverlaySummary.forCharacter(sourceChar),
      pendingSummary: null,
      changedFields: ['deleted'],
    );
  }

  List<OverlayEntry> _compareWorldNodes(
    List<domain.WorldNodeRecord> source,
    List<domain.WorldNodeRecord> pending,
  ) {
    final sourceMap = {for (final w in source) w.id: w};
    final pendingMap = {for (final w in pending) w.id: w};

    final allIds = {...sourceMap.keys, ...pendingMap.keys}.toList()..sort();

    final entries = <OverlayEntry>[];

    for (final id in allIds) {
      final sourceNode = sourceMap[id];
      final pendingNode = pendingMap[id];

      if (sourceNode == null) {
        entries.add(_addedWorldNodeEntry(id, pendingNode!));
      } else if (pendingNode == null) {
        entries.add(_deletedWorldNodeEntry(id, sourceNode));
      } else {
        entries.add(_compareWorldNode(sourceNode, pendingNode));
      }
    }

    return entries;
  }

  OverlayEntry _compareWorldNode(
    domain.WorldNodeRecord source,
    domain.WorldNodeRecord pending,
  ) {
    final sourceJson = source.toJson();
    final pendingJson = pending.toJson();

    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    final changedFields = _findChangedFields(sourceJson, pendingJson);

    final status = _determineStatus(
      sourceFingerprint,
      pendingFingerprint,
      wasAdded: false,
      wasDeleted: false,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.worldNode, source.id),
      targetRef: OverlayTargetRef(
        kind: OverlayTargetKind.worldNode,
        id: source.id,
      ),
      status: status,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: pendingFingerprint,
      sourceSummary: OverlaySummary.forWorldNode(source),
      pendingSummary: OverlaySummary.forWorldNode(pending),
      changedFields: changedFields,
    );
  }

  OverlayEntry _addedWorldNodeEntry(
    String id,
    domain.WorldNodeRecord pendingNode,
  ) {
    final pendingJson = pendingNode.toJson();
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson(
      pendingJson,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.worldNode, id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.worldNode, id: id),
      status: OverlayStatus.pending,
      sourceFingerprint: const OverlayFingerprint(''),
      pendingFingerprint: pendingFingerprint,
      sourceSummary: null,
      pendingSummary: OverlaySummary.forWorldNode(pendingNode),
      changedFields: ['added'],
    );
  }

  OverlayEntry _deletedWorldNodeEntry(
    String id,
    domain.WorldNodeRecord sourceNode,
  ) {
    final sourceJson = sourceNode.toJson();
    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson(sourceJson);

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.worldNode, id),
      targetRef: OverlayTargetRef(kind: OverlayTargetKind.worldNode, id: id),
      status: OverlayStatus.pending,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: const OverlayFingerprint(''),
      sourceSummary: OverlaySummary.forWorldNode(sourceNode),
      pendingSummary: null,
      changedFields: ['deleted'],
    );
  }

  OverlayEntry _compareDraft(String source, String pending) {
    final sourceFingerprint = OverlayFingerprint.fromCanonicalJson({
      'text': source,
    });
    final pendingFingerprint = OverlayFingerprint.fromCanonicalJson({
      'text': pending,
    });

    final status = _determineStatus(
      sourceFingerprint,
      pendingFingerprint,
      wasAdded: false,
      wasDeleted: false,
    );

    return OverlayEntry(
      id: _entryId(OverlayTargetKind.draft, 'draft'),
      targetRef: const OverlayTargetRef(
        kind: OverlayTargetKind.draft,
        id: 'draft',
      ),
      status: status,
      sourceFingerprint: sourceFingerprint,
      pendingFingerprint: pendingFingerprint,
      sourceSummary: source.isNotEmpty ? OverlaySummary.forDraft(source) : null,
      pendingSummary: pending.isNotEmpty
          ? OverlaySummary.forDraft(pending)
          : null,
      changedFields: status == OverlayStatus.pending ? ['text'] : null,
    );
  }

  OverlayStatus _determineStatus(
    OverlayFingerprint source,
    OverlayFingerprint pending, {
    required bool wasAdded,
    required bool wasDeleted,
  }) {
    if (wasAdded || wasDeleted) {
      return OverlayStatus.pending;
    }
    if (source.matches(pending)) {
      return OverlayStatus.unchanged;
    }
    return OverlayStatus.pending;
  }

  List<String> _findChangedFields(
    Map<String, Object?> source,
    Map<String, Object?> pending,
  ) {
    final changed = <String>[];
    for (final key in {...source.keys, ...pending.keys}) {
      if (!_deepEquals(source[key], pending[key])) {
        changed.add(key);
      }
    }
    return changed;
  }

  bool _deepEquals(Object? a, Object? b) {
    if (a == b) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      final aKeys = a.keys.toSet();
      final bKeys = b.keys.toSet();
      if (aKeys.length != bKeys.length) return false;
      for (final key in aKeys) {
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return false;
  }

  List<domain.SceneRecord> _resolveScenes(
    List<domain.SceneRecord> source,
    List<domain.SceneRecord> pending,
    Map<String, OverlayDecision> decisions,
  ) {
    final sourceMap = {for (final s in source) s.id: s};
    final pendingMap = {for (final s in pending) s.id: s};

    final allIds = {...sourceMap.keys, ...pendingMap.keys}.toList()..sort();

    final resolved = <domain.SceneRecord>[];

    for (final id in allIds) {
      final decision = decisions[id];
      final sourceScene = sourceMap[id];
      final pendingScene = pendingMap[id];

      if (decision == OverlayDecision.keepSource) {
        if (sourceScene != null) {
          resolved.add(sourceScene);
        }
      } else if (decision == OverlayDecision.keepPending) {
        if (pendingScene != null) {
          resolved.add(pendingScene);
        }
        // keepPending on deleted-in-pending: omit (do not preserve source)
      } else if (sourceScene != null && pendingScene != null) {
        // Both exist: default to source when undecided
        resolved.add(sourceScene);
      } else if (pendingScene != null) {
        // Only in pending (added): keep it
        resolved.add(pendingScene);
      }
      // If only in source (deleted in pending) and undecided: omit
    }

    return resolved;
  }

  List<domain.CharacterRecord> _resolveCharacters(
    List<domain.CharacterRecord> source,
    List<domain.CharacterRecord> pending,
    Map<String, OverlayDecision> decisions,
  ) {
    final sourceMap = {for (final c in source) c.id: c};
    final pendingMap = {for (final c in pending) c.id: c};

    final allIds = {...sourceMap.keys, ...pendingMap.keys}.toList()..sort();

    final resolved = <domain.CharacterRecord>[];

    for (final id in allIds) {
      final decision = decisions[id];
      final sourceChar = sourceMap[id];
      final pendingChar = pendingMap[id];

      if (decision == OverlayDecision.keepSource) {
        if (sourceChar != null) {
          resolved.add(sourceChar);
        }
      } else if (decision == OverlayDecision.keepPending) {
        if (pendingChar != null) {
          resolved.add(pendingChar);
        }
        // keepPending on deleted-in-pending: omit (do not preserve source)
      } else if (sourceChar != null && pendingChar != null) {
        resolved.add(sourceChar);
      } else if (pendingChar != null) {
        resolved.add(pendingChar);
      }
    }

    return resolved;
  }

  List<domain.WorldNodeRecord> _resolveWorldNodes(
    List<domain.WorldNodeRecord> source,
    List<domain.WorldNodeRecord> pending,
    Map<String, OverlayDecision> decisions,
  ) {
    final sourceMap = {for (final w in source) w.id: w};
    final pendingMap = {for (final w in pending) w.id: w};

    final allIds = {...sourceMap.keys, ...pendingMap.keys}.toList()..sort();

    final resolved = <domain.WorldNodeRecord>[];

    for (final id in allIds) {
      final decision = decisions[id];
      final sourceNode = sourceMap[id];
      final pendingNode = pendingMap[id];

      if (decision == OverlayDecision.keepSource) {
        if (sourceNode != null) {
          resolved.add(sourceNode);
        }
      } else if (decision == OverlayDecision.keepPending) {
        if (pendingNode != null) {
          resolved.add(pendingNode);
        }
        // keepPending on deleted-in-pending: omit (do not preserve source)
      } else if (sourceNode != null && pendingNode != null) {
        resolved.add(sourceNode);
      } else if (pendingNode != null) {
        resolved.add(pendingNode);
      }
    }

    return resolved;
  }

  String _entryId(OverlayTargetKind kind, String id) {
    return '${kind.name}-$id';
  }

  OverlayPlan _countEntries(List<OverlayEntry> entries) {
    var pendingCount = 0;
    var conflictCount = 0;
    var resolvedCount = 0;
    var unchangedCount = 0;

    for (final entry in entries) {
      switch (entry.status) {
        case OverlayStatus.pending:
          pendingCount++;
          break;
        case OverlayStatus.conflict:
          conflictCount++;
          break;
        case OverlayStatus.resolved:
          resolvedCount++;
          break;
        case OverlayStatus.unchanged:
          unchangedCount++;
          break;
      }
    }

    return OverlayPlan(
      entries: entries,
      totalCount: entries.length,
      pendingCount: pendingCount,
      conflictCount: conflictCount,
      resolvedCount: resolvedCount,
      unchangedCount: unchangedCount,
    );
  }

  OverlayPlan _applyImportStatesToPlan(
    OverlayPlan plan,
    MarkdownImportPlan importPlan,
  ) {
    final importEntries = <_ImportEntryKey, List<ImportEntry>>{};
    for (final entry in importPlan.entries) {
      final key = _ImportEntryKey.fromImportEntry(entry);
      importEntries.putIfAbsent(key, () => <ImportEntry>[]).add(entry);
    }

    final updated = plan.entries.map((entry) {
      final imports = importEntries[_ImportEntryKey.fromOverlayEntry(entry)];
      if (imports == null || imports.isEmpty) {
        return entry;
      }

      final importStatus = _statusForImportEntries(imports, entry.status);
      final changedFields = _mergeChangedFields(entry.changedFields, imports);
      if (importStatus == entry.status &&
          _listEquals(changedFields, entry.changedFields)) {
        return entry;
      }

      return entry.copyWith(status: importStatus, changedFields: changedFields);
    }).toList();

    return _countEntries(updated);
  }

  OverlayStatus _statusForImportEntries(
    List<ImportEntry> entries,
    OverlayStatus currentStatus,
  ) {
    if (entries.any(
      (entry) =>
          entry.state == ImportState.conflictKeepBoth ||
          entry.state == ImportState.unsupported ||
          entry.state == ImportState.rejected,
    )) {
      return OverlayStatus.conflict;
    }

    if (entries.any((entry) => entry.state == ImportState.needsReview)) {
      return currentStatus == OverlayStatus.unchanged
          ? OverlayStatus.pending
          : currentStatus;
    }

    return currentStatus;
  }

  List<String> _mergeChangedFields(
    List<String>? changedFields,
    List<ImportEntry> imports,
  ) {
    final fields = <String>{...?changedFields};
    for (final import in imports) {
      if (import.state == ImportState.safeApply) continue;
      fields.add(import.reason ?? import.state.name);
    }
    return fields.toList()..sort();
  }

  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _ImportEntryKey {
  const _ImportEntryKey(this.kind, this.id);

  factory _ImportEntryKey.fromImportEntry(ImportEntry entry) {
    return _ImportEntryKey(_kindFromImport(entry.kind), _idFromImport(entry));
  }

  factory _ImportEntryKey.fromOverlayEntry(OverlayEntry entry) {
    return _ImportEntryKey(entry.targetRef.kind, entry.targetRef.id);
  }

  final OverlayTargetKind kind;
  final String id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ImportEntryKey && other.kind == kind && other.id == id;
  }

  @override
  int get hashCode => Object.hash(kind, id);

  static OverlayTargetKind _kindFromImport(ImportTargetKind kind) {
    switch (kind) {
      case ImportTargetKind.project:
        return OverlayTargetKind.project;
      case ImportTargetKind.scene:
        return OverlayTargetKind.scene;
      case ImportTargetKind.character:
        return OverlayTargetKind.character;
      case ImportTargetKind.worldNode:
        return OverlayTargetKind.worldNode;
      case ImportTargetKind.draft:
        return OverlayTargetKind.draft;
    }
  }

  static String _idFromImport(ImportEntry entry) {
    if (entry.kind == ImportTargetKind.draft) {
      return 'draft';
    }
    return entry.id;
  }
}
