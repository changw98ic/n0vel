/// Executable outline data models for story generation planning.
///
/// These models define the hierarchical plan structure:
/// NovelPlan -> ChapterPlan -> ScenePlan -> BeatPlan
/// with transition targets that track required state changes between scenes.
library;

// -- Validation helpers -------------------------------------------------------

/// Validates that [id] is non-empty and contains only alphanumeric characters,
/// dashes, and underscores.
bool validatePlanId(String id) {
  if (id.isEmpty) return false;
  return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);
}

/// Checks that every [BeatPlan] with a [StateTransitionTarget] references
/// scene IDs that exist within the parent [ScenePlan] and its siblings.
///
/// Returns a list of human-readable issue descriptions. An empty list means
/// the plan is valid.
List<String> validateTransitionReferences(ScenePlan plan) {
  final issues = <String>[];
  final knownSceneIds = <String>{plan.id};
  // Collect sibling scene IDs from metadata if available.
  final siblings = plan.metadata['siblingSceneIds'];
  if (siblings is List) {
    for (final s in siblings) {
      if (s is String && s.isNotEmpty) knownSceneIds.add(s);
    }
  }

  for (final beat in plan.beats) {
    final t = beat.transitionTarget;
    if (t == null) continue;
    if (t.fromSceneId.isNotEmpty && !knownSceneIds.contains(t.fromSceneId)) {
      issues.add(
        'Beat "${beat.id}" transition.fromSceneId "${t.fromSceneId}" '
        'not found in known scene IDs',
      );
    }
    if (t.toSceneId.isNotEmpty && !knownSceneIds.contains(t.toSceneId)) {
      issues.add(
        'Beat "${beat.id}" transition.toSceneId "${t.toSceneId}" '
        'not found in known scene IDs',
      );
    }
  }
  return issues;
}

/// Returns `true` when [beats] are in strict ascending order by `sequence`
/// with no duplicates and no gaps starting from 1.
bool isValidBeatSequence(List<BeatPlan> beats) {
  if (beats.isEmpty) return true;
  for (var i = 0; i < beats.length; i++) {
    if (beats[i].sequence != i + 1) return false;
  }
  return true;
}

// -- Model classes ------------------------------------------------------------

/// A transition that must be resolved before or after a scene.
class StateTransitionTarget {
  const StateTransitionTarget({
    required this.id,
    required this.fromSceneId,
    required this.toSceneId,
    required this.kind,
    this.constraints = const {},
  });

  final String id;
  final String fromSceneId;
  final String toSceneId;
  final String kind; // 'entry', 'exit', 'flashback', 'time_skip'
  final Map<String, Object?> constraints;

  StateTransitionTarget copyWith({
    String? id,
    String? fromSceneId,
    String? toSceneId,
    String? kind,
    Map<String, Object?>? constraints,
  }) {
    return StateTransitionTarget(
      id: id ?? this.id,
      fromSceneId: fromSceneId ?? this.fromSceneId,
      toSceneId: toSceneId ?? this.toSceneId,
      kind: kind ?? this.kind,
      constraints: constraints ?? this.constraints,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'fromSceneId': fromSceneId,
      'toSceneId': toSceneId,
      'kind': kind,
      'constraints': Map<String, Object?>.from(constraints),
    };
  }

  static StateTransitionTarget fromJson(Map<Object?, Object?> json) {
    return StateTransitionTarget(
      id: json['id']?.toString() ?? '',
      fromSceneId: json['fromSceneId']?.toString() ?? '',
      toSceneId: json['toSceneId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      constraints: json['constraints'] is Map
          ? Map<String, Object?>.from(json['constraints'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StateTransitionTarget) return false;
    if (other.id != id) return false;
    if (other.fromSceneId != fromSceneId) return false;
    if (other.toSceneId != toSceneId) return false;
    if (other.kind != kind) return false;
    if (other.constraints.length != constraints.length) return false;
    for (final key in constraints.keys) {
      if (!other.constraints.containsKey(key) ||
          other.constraints[key] != constraints[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        fromSceneId,
        toSceneId,
        kind,
        Object.hashAllUnordered(constraints.entries),
      );
}

/// A single beat within a scene — the smallest unit of narrative action.
class BeatPlan {
  BeatPlan({
    required this.id,
    required this.scenePlanId,
    required this.sequence,
    required this.beatType,
    required this.content,
    this.povCharacterId,
    List<String> requiredCognitionIds = const [],
    this.transitionTarget,
  }) : requiredCognitionIds =
            List<String>.unmodifiable(requiredCognitionIds);

  final String id;
  final String scenePlanId;
  final int sequence;
  final String beatType; // 'action', 'dialogue', 'reflection', 'transition'
  final String content;
  final String? povCharacterId;
  final List<String> requiredCognitionIds;
  final StateTransitionTarget? transitionTarget;

  BeatPlan copyWith({
    String? id,
    String? scenePlanId,
    int? sequence,
    String? beatType,
    String? content,
    String? povCharacterId,
    List<String>? requiredCognitionIds,
    StateTransitionTarget? transitionTarget,
  }) {
    return BeatPlan(
      id: id ?? this.id,
      scenePlanId: scenePlanId ?? this.scenePlanId,
      sequence: sequence ?? this.sequence,
      beatType: beatType ?? this.beatType,
      content: content ?? this.content,
      povCharacterId: povCharacterId ?? this.povCharacterId,
      requiredCognitionIds: requiredCognitionIds ?? this.requiredCognitionIds,
      transitionTarget: transitionTarget ?? this.transitionTarget,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'scenePlanId': scenePlanId,
      'sequence': sequence,
      'beatType': beatType,
      'content': content,
      'povCharacterId': povCharacterId,
      'requiredCognitionIds': [...requiredCognitionIds],
      if (transitionTarget != null)
        'transitionTarget': transitionTarget!.toJson(),
    };
  }

  static BeatPlan fromJson(Map<Object?, Object?> json) {
    return BeatPlan(
      id: json['id']?.toString() ?? '',
      scenePlanId: json['scenePlanId']?.toString() ?? '',
      sequence: _parseIntOrFallback(json['sequence'], fallback: 0),
      beatType: json['beatType']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      povCharacterId: json['povCharacterId']?.toString(),
      requiredCognitionIds: _decodeStringList(json['requiredCognitionIds']),
      transitionTarget: json['transitionTarget'] is Map
          ? StateTransitionTarget.fromJson(
              Map<Object?, Object?>.from(json['transitionTarget'] as Map),
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeatPlan &&
        other.id == id &&
        other.scenePlanId == scenePlanId &&
        other.sequence == sequence &&
        other.beatType == beatType &&
        other.content == content &&
        other.povCharacterId == povCharacterId &&
        _listEquals(other.requiredCognitionIds, requiredCognitionIds) &&
        other.transitionTarget == transitionTarget;
  }

  @override
  int get hashCode => Object.hash(
        id,
        scenePlanId,
        sequence,
        beatType,
        content,
        povCharacterId,
        Object.hashAll(requiredCognitionIds),
        transitionTarget,
      );
}

/// A scene within a chapter, containing ordered beats.
class ScenePlan {
  ScenePlan({
    required this.id,
    required this.chapterPlanId,
    required this.title,
    required this.summary,
    this.targetLength = 0,
    required this.povCharacterId,
    List<String> castIds = const [],
    List<String> worldNodeIds = const [],
    List<BeatPlan> beats = const [],
    this.narrativeArc = '',
    Map<String, Object?> metadata = const {},
  })  : castIds = List<String>.unmodifiable(castIds),
        worldNodeIds = List<String>.unmodifiable(worldNodeIds),
        beats = List<BeatPlan>.unmodifiable(beats),
        metadata = Map<String, Object?>.unmodifiable(
          Map<String, Object?>.from(metadata),
        );

  final String id;
  final String chapterPlanId;
  final String title;
  final String summary;
  final int targetLength;
  final String povCharacterId;
  final List<String> castIds;
  final List<String> worldNodeIds;
  final List<BeatPlan> beats;
  final String narrativeArc;
  final Map<String, Object?> metadata;

  ScenePlan copyWith({
    String? id,
    String? chapterPlanId,
    String? title,
    String? summary,
    int? targetLength,
    String? povCharacterId,
    List<String>? castIds,
    List<String>? worldNodeIds,
    List<BeatPlan>? beats,
    String? narrativeArc,
    Map<String, Object?>? metadata,
  }) {
    return ScenePlan(
      id: id ?? this.id,
      chapterPlanId: chapterPlanId ?? this.chapterPlanId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      targetLength: targetLength ?? this.targetLength,
      povCharacterId: povCharacterId ?? this.povCharacterId,
      castIds: castIds ?? this.castIds,
      worldNodeIds: worldNodeIds ?? this.worldNodeIds,
      beats: beats ?? this.beats,
      narrativeArc: narrativeArc ?? this.narrativeArc,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'chapterPlanId': chapterPlanId,
      'title': title,
      'summary': summary,
      'targetLength': targetLength,
      'povCharacterId': povCharacterId,
      'castIds': [...castIds],
      'worldNodeIds': [...worldNodeIds],
      'beats': [for (final b in beats) b.toJson()],
      'narrativeArc': narrativeArc,
      'metadata': Map<String, Object?>.from(metadata),
    };
  }

  static ScenePlan fromJson(Map<Object?, Object?> json) {
    return ScenePlan(
      id: json['id']?.toString() ?? '',
      chapterPlanId: json['chapterPlanId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      targetLength: _parseIntOrFallback(json['targetLength'], fallback: 0),
      povCharacterId: json['povCharacterId']?.toString() ?? '',
      castIds: _decodeStringList(json['castIds']),
      worldNodeIds: _decodeStringList(json['worldNodeIds']),
      beats: _decodeList(json['beats'], BeatPlan.fromJson),
      narrativeArc: json['narrativeArc']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScenePlan &&
        other.id == id &&
        other.chapterPlanId == chapterPlanId &&
        other.title == title &&
        other.summary == summary &&
        other.targetLength == targetLength &&
        other.povCharacterId == povCharacterId &&
        _listEquals(other.castIds, castIds) &&
        _listEquals(other.worldNodeIds, worldNodeIds) &&
        _listEquals(other.beats, beats) &&
        other.narrativeArc == narrativeArc &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        chapterPlanId,
        title,
        summary,
        targetLength,
        povCharacterId,
        Object.hashAll(castIds),
        Object.hashAll(worldNodeIds),
        Object.hashAll(beats),
        narrativeArc,
        _mapHash(metadata),
      );
}

/// A chapter within the novel plan, containing ordered scenes.
class ChapterPlan {
  ChapterPlan({
    required this.id,
    required this.novelPlanId,
    required this.title,
    required this.summary,
    this.targetSceneCount = 0,
    List<ScenePlan> scenes = const [],
  }) : scenes = List<ScenePlan>.unmodifiable(scenes);

  final String id;
  final String novelPlanId;
  final String title;
  final String summary;
  final int targetSceneCount;
  final List<ScenePlan> scenes;

  ChapterPlan copyWith({
    String? id,
    String? novelPlanId,
    String? title,
    String? summary,
    int? targetSceneCount,
    List<ScenePlan>? scenes,
  }) {
    return ChapterPlan(
      id: id ?? this.id,
      novelPlanId: novelPlanId ?? this.novelPlanId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      targetSceneCount: targetSceneCount ?? this.targetSceneCount,
      scenes: scenes ?? this.scenes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'novelPlanId': novelPlanId,
      'title': title,
      'summary': summary,
      'targetSceneCount': targetSceneCount,
      'scenes': [for (final s in scenes) s.toJson()],
    };
  }

  static ChapterPlan fromJson(Map<Object?, Object?> json) {
    return ChapterPlan(
      id: json['id']?.toString() ?? '',
      novelPlanId: json['novelPlanId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      targetSceneCount:
          _parseIntOrFallback(json['targetSceneCount'], fallback: 0),
      scenes: _decodeList(json['scenes'], ScenePlan.fromJson),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChapterPlan &&
        other.id == id &&
        other.novelPlanId == novelPlanId &&
        other.title == title &&
        other.summary == summary &&
        other.targetSceneCount == targetSceneCount &&
        _listEquals(other.scenes, scenes);
  }

  @override
  int get hashCode => Object.hash(
        id,
        novelPlanId,
        title,
        summary,
        targetSceneCount,
        Object.hashAll(scenes),
      );
}

/// Top-level plan for a novel, containing ordered chapters.
class NovelPlan {
  NovelPlan({
    required this.id,
    required this.projectId,
    required this.title,
    required this.premise,
    this.targetChapterCount = 0,
    List<ChapterPlan> chapters = const [],
    Map<String, Object?> metadata = const {},
  })  : chapters = List<ChapterPlan>.unmodifiable(chapters),
        metadata = Map<String, Object?>.unmodifiable(
          Map<String, Object?>.from(metadata),
        );

  final String id;
  final String projectId;
  final String title;
  final String premise;
  final int targetChapterCount;
  final List<ChapterPlan> chapters;
  final Map<String, Object?> metadata;

  NovelPlan copyWith({
    String? id,
    String? projectId,
    String? title,
    String? premise,
    int? targetChapterCount,
    List<ChapterPlan>? chapters,
    Map<String, Object?>? metadata,
  }) {
    return NovelPlan(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      premise: premise ?? this.premise,
      targetChapterCount: targetChapterCount ?? this.targetChapterCount,
      chapters: chapters ?? this.chapters,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'premise': premise,
      'targetChapterCount': targetChapterCount,
      'chapters': [for (final c in chapters) c.toJson()],
      'metadata': Map<String, Object?>.from(metadata),
    };
  }

  static NovelPlan fromJson(Map<Object?, Object?> json) {
    return NovelPlan(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      premise: json['premise']?.toString() ?? '',
      targetChapterCount:
          _parseIntOrFallback(json['targetChapterCount'], fallback: 0),
      chapters: _decodeList(json['chapters'], ChapterPlan.fromJson),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NovelPlan &&
        other.id == id &&
        other.projectId == projectId &&
        other.title == title &&
        other.premise == premise &&
        other.targetChapterCount == targetChapterCount &&
        _listEquals(other.chapters, chapters) &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        projectId,
        title,
        premise,
        targetChapterCount,
        Object.hashAll(chapters),
        _mapHash(metadata),
      );
}

// -- Private helpers ----------------------------------------------------------

int _parseIntOrFallback(Object? raw, {required int fallback}) {
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

List<T> _decodeList<T>(
  Object? raw,
  T Function(Map<Object?, Object?>) decoder,
) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) decoder(Map<Object?, Object?>.from(item)),
  ];
}

List<String> _decodeStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null) item.toString(),
  ];
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

int _mapHash(Map<String, Object?> map) {
  var hash = 0;
  for (final entry in map.entries) {
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
