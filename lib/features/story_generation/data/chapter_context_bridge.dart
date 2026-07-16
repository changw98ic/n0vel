import 'dart:convert';

import 'package:sqlite3/sqlite3.dart' show Database;

import '../../../app/logging/app_log.dart';
import '../domain/memory_models.dart';
import '../domain/outline_plan_models.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';
import 'story_memory_storage.dart';
import 'chapter_summarizer.dart';

/// Scope ID used to identify chapter summary entries in storage.
const String _chapterSummaryScopeId = '__chapter_summaries';

/// Tag used to mark chapter summary sources for filtering.
const String _chapterSummaryTag = 'chapter-summary';
const String _chapterSummaryRevisionTag = 'chapter-summary-revision';
const String _chapterSummaryHeadTag = 'chapter-summary-head';

/// Immutable authoritative chapter-summary revision bound to the exact set of
/// committed scene receipts that produced it.
class ChapterSummaryRevision {
  const ChapterSummaryRevision({
    required this.chapterId,
    required this.sceneCommitSetHash,
    required this.summary,
    required this.createdAtMs,
  });

  final String chapterId;
  final String sceneCommitSetHash;
  final ChapterSummary summary;
  final int createdAtMs;

  Map<String, Object?> toJson() => {
    'chapterId': chapterId,
    'sceneCommitSetHash': sceneCommitSetHash,
    'summary': summary.toJson(),
    'createdAtMs': createdAtMs,
  };

  static ChapterSummaryRevision? fromJson(Map<Object?, Object?> json) {
    final rawSummary = json['summary'];
    final hash = json['sceneCommitSetHash']?.toString() ?? '';
    if (rawSummary is! Map || hash.isEmpty) return null;
    return ChapterSummaryRevision(
      chapterId: json['chapterId']?.toString() ?? '',
      sceneCommitSetHash: hash,
      summary: ChapterSummary.fromJson(Map<String, Object?>.from(rawSummary)),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

// -- Chapter continuity models -------------------------------------------------

/// A brief description of a state transition between scenes.
class TransitionSummary {
  const TransitionSummary({
    required this.transitionId,
    required this.kind,
    required this.fromSceneId,
    required this.toSceneId,
    required this.summary,
    this.isResolved = false,
  });

  final String transitionId;
  final String kind;
  final String fromSceneId;
  final String toSceneId;
  final String summary;
  final bool isResolved;

  TransitionSummary copyWith({
    String? transitionId,
    String? kind,
    String? fromSceneId,
    String? toSceneId,
    String? summary,
    bool? isResolved,
  }) {
    return TransitionSummary(
      transitionId: transitionId ?? this.transitionId,
      kind: kind ?? this.kind,
      fromSceneId: fromSceneId ?? this.fromSceneId,
      toSceneId: toSceneId ?? this.toSceneId,
      summary: summary ?? this.summary,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  Map<String, Object?> toJson() => {
    'transitionId': transitionId,
    'kind': kind,
    'fromSceneId': fromSceneId,
    'toSceneId': toSceneId,
    'summary': summary,
    'isResolved': isResolved,
  };

  static TransitionSummary fromJson(Map<Object?, Object?> json) =>
      TransitionSummary(
        transitionId: json['transitionId']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        fromSceneId: json['fromSceneId']?.toString() ?? '',
        toSceneId: json['toSceneId']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        isResolved: json['isResolved'] == true,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitionSummary &&
          runtimeType == other.runtimeType &&
          transitionId == other.transitionId &&
          kind == other.kind &&
          fromSceneId == other.fromSceneId &&
          toSceneId == other.toSceneId &&
          summary == other.summary &&
          isResolved == other.isResolved;

  @override
  int get hashCode => Object.hash(
    transitionId,
    kind,
    fromSceneId,
    toSceneId,
    summary,
    isResolved,
  );
}

/// A cognition change for a character across chapter boundaries.
class CognitionDelta {
  const CognitionDelta({
    required this.characterId,
    required this.characterName,
    required this.kind,
    required this.description,
    required this.sourceSceneId,
  });

  final String characterId;
  final String characterName;
  final String kind; // 'belief', 'relationship', 'goal', 'intent'
  final String description;
  final String sourceSceneId;

  CognitionDelta copyWith({
    String? characterId,
    String? characterName,
    String? kind,
    String? description,
    String? sourceSceneId,
  }) {
    return CognitionDelta(
      characterId: characterId ?? this.characterId,
      characterName: characterName ?? this.characterName,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      sourceSceneId: sourceSceneId ?? this.sourceSceneId,
    );
  }

  Map<String, Object?> toJson() => {
    'characterId': characterId,
    'characterName': characterName,
    'kind': kind,
    'description': description,
    'sourceSceneId': sourceSceneId,
  };

  static CognitionDelta fromJson(Map<Object?, Object?> json) => CognitionDelta(
    characterId: json['characterId']?.toString() ?? '',
    characterName: json['characterName']?.toString() ?? '',
    kind: json['kind']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    sourceSceneId: json['sourceSceneId']?.toString() ?? '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CognitionDelta &&
          runtimeType == other.runtimeType &&
          characterId == other.characterId &&
          characterName == other.characterName &&
          kind == other.kind &&
          description == other.description &&
          sourceSceneId == other.sourceSceneId;

  @override
  int get hashCode =>
      Object.hash(characterId, characterName, kind, description, sourceSceneId);
}

/// Structured exit state of a completed chapter for continuity bridging.
class ChapterExitState {
  const ChapterExitState({
    required this.chapterId,
    required this.chapterTitle,
    this.outgoingTransitions = const [],
    this.unresolvedThreads = const [],
    this.unresolvedCognitionDeltas = const [],
    this.metadata = const {},
  });

  final String chapterId;
  final String chapterTitle;
  final List<TransitionSummary> outgoingTransitions;
  final List<String> unresolvedThreads;
  final List<CognitionDelta> unresolvedCognitionDeltas;
  final Map<String, Object?> metadata;

  ChapterExitState copyWith({
    String? chapterId,
    String? chapterTitle,
    List<TransitionSummary>? outgoingTransitions,
    List<String>? unresolvedThreads,
    List<CognitionDelta>? unresolvedCognitionDeltas,
    Map<String, Object?>? metadata,
  }) {
    return ChapterExitState(
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      outgoingTransitions: outgoingTransitions ?? this.outgoingTransitions,
      unresolvedThreads: unresolvedThreads ?? this.unresolvedThreads,
      unresolvedCognitionDeltas:
          unresolvedCognitionDeltas ?? this.unresolvedCognitionDeltas,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() => {
    'chapterId': chapterId,
    'chapterTitle': chapterTitle,
    'outgoingTransitions': [for (final t in outgoingTransitions) t.toJson()],
    'unresolvedThreads': unresolvedThreads,
    'unresolvedCognitionDeltas': [
      for (final d in unresolvedCognitionDeltas) d.toJson(),
    ],
    'metadata': Map<String, Object?>.from(metadata),
  };

  static ChapterExitState fromJson(Map<Object?, Object?> json) =>
      ChapterExitState(
        chapterId: json['chapterId']?.toString() ?? '',
        chapterTitle: json['chapterTitle']?.toString() ?? '',
        outgoingTransitions: _parseTransitionList(json['outgoingTransitions']),
        unresolvedThreads: _parseStringList(json['unresolvedThreads']),
        unresolvedCognitionDeltas: _parseCognitionDeltaList(
          json['unresolvedCognitionDeltas'],
        ),
        metadata: json['metadata'] is Map
            ? Map<String, Object?>.from(json['metadata'] as Map)
            : const {},
      );
}

/// Validation result when checking entry state against a previous exit.
class ChapterEntryValidation {
  const ChapterEntryValidation({
    required this.chapterId,
    required this.isConsistent,
    this.issues = const [],
  });

  final String chapterId;
  final bool isConsistent;
  final List<String> issues;

  Map<String, Object?> toJson() => {
    'chapterId': chapterId,
    'isConsistent': isConsistent,
    'issues': issues,
  };

  static ChapterEntryValidation fromJson(Map<Object?, Object?> json) =>
      ChapterEntryValidation(
        chapterId: json['chapterId']?.toString() ?? '',
        isConsistent: json['isConsistent'] == true,
        issues: _parseStringList(json['issues']),
      );
}

/// Complete handoff payload from one chapter to the next.
class ChapterHandoffPayload {
  const ChapterHandoffPayload({
    required this.exitState,
    required this.entryValidation,
  });

  final ChapterExitState exitState;
  final ChapterEntryValidation entryValidation;

  Map<String, Object?> toJson() => {
    'exitState': exitState.toJson(),
    'entryValidation': entryValidation.toJson(),
  };

  static ChapterHandoffPayload fromJson(Map<Object?, Object?> json) =>
      ChapterHandoffPayload(
        exitState: json['exitState'] is Map
            ? ChapterExitState.fromJson(
                Map<Object?, Object?>.from(json['exitState'] as Map),
              )
            : const ChapterExitState(chapterId: '', chapterTitle: ''),
        entryValidation: json['entryValidation'] is Map
            ? ChapterEntryValidation.fromJson(
                Map<Object?, Object?>.from(json['entryValidation'] as Map),
              )
            : const ChapterEntryValidation(
                chapterId: '',
                isConsistent: false,
                issues: ['missing entryValidation'],
              ),
      );
}

// -- JSON parse helpers for continuity models ----------------------------------

List<TransitionSummary> _parseTransitionList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        TransitionSummary.fromJson(Map<Object?, Object?>.from(item)),
  ];
}

List<CognitionDelta> _parseCognitionDeltaList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        CognitionDelta.fromJson(Map<Object?, Object?>.from(item)),
  ];
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
}

/// Concrete bridge for cross-chapter context passing.
///
/// Persists chapter summaries as [StoryMemorySource] entries at the project
/// level and loads context from previous chapters to maintain narrative
/// continuity across chapter boundaries.
class ChapterContextBridge implements ChapterContextBridgeService {
  ChapterContextBridge({
    required this.storage,
    this.summarizer,
    this.authorityDb,
  });

  final StoryMemoryStorage storage;
  final Database? authorityDb;

  /// Optional LLM-based summarizer. When set, [summarizeFromOutputs] will
  /// attempt LLM summarization first and fall back to structural logic.
  final ChapterSummarizer? summarizer;

  @override
  Future<void> saveChapterSummary(
    String projectId,
    ChapterSummary summary,
  ) async {
    final existing = await loadChapterSummaries(projectId);
    final updated =
        existing.where((s) => s.chapterId != summary.chapterId).toList()
          ..add(summary);

    final sources = updated
        .map(
          (s) => StoryMemorySource(
            id: 'cs_${s.chapterId}',
            projectId: projectId,
            scopeId: _chapterSummaryScopeId,
            kind: MemorySourceKind.sceneSummary,
            content: jsonEncode(s.toJson()),
            tags: [_chapterSummaryTag, 'ch-${s.chapterId}'],
            createdAtMs: s.createdAtMs,
          ),
        )
        .toList();

    await storage.saveSources(projectId, sources);
  }

  @override
  Future<List<ChapterSummary>> loadChapterSummaries(String projectId) async {
    final sources = await storage.loadSources(projectId);
    final summaries = <ChapterSummary>[];

    for (final source in sources) {
      if (!source.tags.contains(_chapterSummaryTag)) continue;
      try {
        final json = jsonDecode(source.content) as Map<String, Object?>;
        summaries.add(ChapterSummary.fromJson(json));
      } catch (error) {
        AppLog.w(
          'Skipped malformed chapter summary source ${source.id}: $error',
          tag: 'ChapterContextBridge',
        );
      }
    }

    summaries.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    return summaries;
  }

  /// Appends an immutable authoritative revision and advances the chapter head
  /// only when the committed receipt set changes. This is intentionally a
  /// storage primitive: the accept coordinator owns the surrounding CAS.
  Future<ChapterSummaryRevision> saveAuthoritativeSummaryRevision({
    required String projectId,
    required String sceneCommitSetHash,
    required ChapterSummary summary,
    int? nowMs,
  }) async {
    if (sceneCommitSetHash.trim().isEmpty) {
      throw ArgumentError.value(
        sceneCommitSetHash,
        'sceneCommitSetHash',
        'must not be empty',
      );
    }
    final existing = await loadAuthoritativeSummaryHead(
      projectId: projectId,
      chapterId: summary.chapterId,
    );
    if (existing != null && existing.sceneCommitSetHash == sceneCommitSetHash) {
      return existing;
    }
    final revision = ChapterSummaryRevision(
      chapterId: summary.chapterId,
      sceneCommitSetHash: sceneCommitSetHash,
      summary: summary,
      createdAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    final sources = await storage.loadSources(projectId);
    final revisionId = 'csr_${summary.chapterId}_$sceneCommitSetHash';
    final headId = 'csh_${summary.chapterId}';
    final kept = sources
        .where((source) => source.id != revisionId && source.id != headId)
        .toList();
    kept.addAll([
      StoryMemorySource(
        id: revisionId,
        projectId: projectId,
        scopeId: _chapterSummaryScopeId,
        kind: MemorySourceKind.sceneSummary,
        content: jsonEncode(revision.toJson()),
        tags: const [_chapterSummaryRevisionTag],
        createdAtMs: revision.createdAtMs,
      ),
      StoryMemorySource(
        id: headId,
        projectId: projectId,
        scopeId: _chapterSummaryScopeId,
        kind: MemorySourceKind.sceneSummary,
        content: jsonEncode(revision.toJson()),
        tags: const [_chapterSummaryHeadTag],
        createdAtMs: revision.createdAtMs,
      ),
    ]);
    await storage.saveSources(projectId, kept);
    return revision;
  }

  Future<ChapterSummaryRevision?> loadAuthoritativeSummaryHead({
    required String projectId,
    required String chapterId,
  }) async {
    final db = authorityDb;
    if (db != null) {
      final rows = db.select(
        '''
        SELECT r.payload_json FROM story_generation_summary_heads h
        JOIN story_generation_summary_revisions r ON r.revision_id = h.revision_id
        WHERE h.project_id = ? AND h.chapter_id = ?
      ''',
        [projectId, chapterId],
      );
      if (rows.length == 1) {
        try {
          final raw = jsonDecode(rows.single['payload_json'] as String) as Map;
          final summaryRaw = raw['summary'];
          if (summaryRaw is Map) {
            return ChapterSummaryRevision(
              chapterId: chapterId,
              sceneCommitSetHash: raw['sceneCommitSetHash']?.toString() ?? '',
              summary: ChapterSummary.fromJson(
                Map<String, Object?>.from(summaryRaw),
              ),
              createdAtMs: 0,
            );
          }
        } on Object {
          // Fall through to the legacy blob reader.
        }
      }
    }
    final sources = await storage.loadSources(projectId);
    for (final source in sources) {
      if (source.id != 'csh_$chapterId' ||
          !source.tags.contains(_chapterSummaryHeadTag)) {
        continue;
      }
      try {
        return ChapterSummaryRevision.fromJson(
          Map<Object?, Object?>.from(jsonDecode(source.content) as Map),
        );
      } on Object {
        return null;
      }
    }
    return null;
  }

  @override
  ChapterSummary summarizeFromOutputs({
    required String chapterId,
    required String chapterTitle,
    required List<SceneRuntimeOutput> outputs,
    int? nowMs,
  }) {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;

    final plotParts = <String>[];
    final charArcs = <String>{};
    final threads = <String>[];

    for (final output in outputs) {
      if (output.director.text.isNotEmpty) {
        plotParts.add(_truncate(output.director.text, 120));
      }

      for (final member in output.resolvedCast) {
        charArcs.add('${member.name}(${member.role})');
      }

      if (output.review.decision != SceneReviewDecision.pass) {
        threads.add(
          '${output.brief.sceneTitle}: review=${output.review.decision.name}',
        );
      }
    }

    return ChapterSummary(
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      sceneCount: outputs.length,
      plotProgress: plotParts.join(' → '),
      characterStateChanges: charArcs.toList(),
      unresolvedThreads: threads,
      createdAtMs: ts,
    );
  }

  /// Attempts LLM-based summarization. Returns null on failure,
  /// in which case the caller should fall back to [summarizeFromOutputs].
  Future<ChapterSummary?> summarizeFromOutputsAsync({
    required String chapterId,
    required String chapterTitle,
    required List<SceneRuntimeOutput> outputs,
    int? nowMs,
    String? projectId,
  }) async {
    if (summarizer == null) return null;

    final summaries = projectId == null
        ? const <ChapterSummary>[]
        : await loadChapterSummaries(projectId);
    final previousSummary = summaries.isNotEmpty ? summaries.last : null;

    return summarizer!.summarizeChapter(
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      outputs: outputs,
      previousSummary: previousSummary,
      nowMs: nowMs,
    );
  }

  @override
  Future<CrossChapterContext> buildCrossChapterContext({
    required String projectId,
    required String currentChapterId,
    int maxPreviousChapters = 3,
  }) async {
    final summaries = await loadChapterSummaries(projectId);

    final previousSummaries =
        summaries.where((s) => s.chapterId != currentChapterId).toList()
          ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    final selectedSummaries = previousSummaries
        .take(maxPreviousChapters)
        .toList();

    final thoughts = <ThoughtAtom>[];
    final projectThoughts = await storage.loadThoughts(projectId);
    for (final summary in selectedSummaries) {
      try {
        thoughts.addAll(
          projectThoughts
              .where((thought) => thought.scopeId.contains(summary.chapterId))
              .where((t) => t.confidence >= 0.7 && t.abstractionLevel >= 1.5)
              .take(5),
        );
      } catch (error) {
        AppLog.w(
          'Skipped carry-over thoughts for chapter ${summary.chapterId}: $error',
          tag: 'ChapterContextBridge',
        );
      }
    }

    thoughts.sort((a, b) => b.confidence.compareTo(a.confidence));

    return CrossChapterContext(
      previousSummaries: selectedSummaries,
      carryOverThoughts: thoughts.take(15).toList(),
    );
  }

  @override
  ProjectMaterialSnapshot enrichMaterialSnapshot(
    ProjectMaterialSnapshot base,
    CrossChapterContext context,
  ) {
    if (context.isEmpty) return base;

    final summaryEntries = <String>[];
    for (final s in context.previousSummaries) {
      summaryEntries.add('[前章概要] ${s.chapterTitle}: ${s.plotProgress}');
      if (s.isLlmGenerated) {
        if (s.emotionalArcs.isNotEmpty) {
          summaryEntries.add('[前章情感] $s.chapterTitle: ${s.emotionalArcs}');
        }
        if (s.worldStateChanges.isNotEmpty) {
          summaryEntries.add('[前章世界观] $s.chapterTitle: ${s.worldStateChanges}');
        }
        if (s.foreshadowingStatus.isNotEmpty) {
          summaryEntries.add(
            '[前章伏笔] $s.chapterTitle: ${s.foreshadowingStatus}',
          );
        }
        if (s.keyRevelations.isNotEmpty) {
          summaryEntries.add('[前章揭示] $s.chapterTitle: ${s.keyRevelations}');
        }
      }
    }

    final thoughtEntries = <String>[];
    for (final t in context.carryOverThoughts) {
      thoughtEntries.add('[跨章记忆][${t.thoughtType.name}] ${t.content}');
    }

    final stateEntries = <String>[
      ...base.acceptedStates,
      for (final s in context.previousSummaries)
        ...s.characterStateChanges.map((c) => '[前章角色] $c'),
      for (final s in context.previousSummaries)
        ...s.unresolvedThreads.map((t) => '[前章悬念] $t'),
    ];

    return ProjectMaterialSnapshot(
      worldFacts: base.worldFacts,
      characterProfiles: base.characterProfiles,
      relationshipHints: base.relationshipHints,
      outlineBeats: base.outlineBeats,
      sceneSummaries: [
        ...base.sceneSummaries,
        ...summaryEntries,
        ...thoughtEntries,
      ],
      acceptedStates: stateEntries,
      reviewFindings: base.reviewFindings,
    );
  }

  /// Summarize outgoing state from a completed chapter.
  ChapterExitState summarizeExit({
    required String chapterId,
    required String chapterTitle,
    required List<StateTransitionTarget> transitions,
    required List<String> unresolvedThreads,
    required List<CognitionDelta> cognitionDeltas,
  }) {
    final transitionSummaries = <TransitionSummary>[];
    for (final t in transitions) {
      final desc = t.kind == 'time_skip'
          ? '时间跳转'
          : t.kind == 'flashback'
          ? '闪回'
          : t.kind == 'exit'
          ? '退出场景'
          : '进入场景';
      transitionSummaries.add(
        TransitionSummary(
          transitionId: t.id,
          kind: t.kind,
          fromSceneId: t.fromSceneId,
          toSceneId: t.toSceneId,
          summary: '${t.fromSceneId} -> ${t.toSceneId} ($desc)',
          isResolved: false,
        ),
      );
    }

    return ChapterExitState(
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      outgoingTransitions: transitionSummaries,
      unresolvedThreads: List.unmodifiable(unresolvedThreads),
      unresolvedCognitionDeltas: List.unmodifiable(cognitionDeltas),
    );
  }

  /// Validate that entry state is consistent with previous exit.
  ChapterEntryValidation validateEntry({
    required ChapterExitState previousExit,
    required String nextChapterId,
  }) {
    final issues = <String>[];

    if (nextChapterId.isEmpty) {
      issues.add('nextChapterId is empty');
    }

    if (previousExit.chapterId == nextChapterId) {
      issues.add(
        'chapter ID mismatch: exit chapter "${previousExit.chapterId}" '
        'is the same as next chapter "$nextChapterId"',
      );
    }

    if (previousExit.chapterId.isEmpty) {
      issues.add('previousExit has empty chapterId');
    }

    return ChapterEntryValidation(
      chapterId: nextChapterId,
      isConsistent: issues.isEmpty,
      issues: issues,
    );
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 3)}...';
  }
}
