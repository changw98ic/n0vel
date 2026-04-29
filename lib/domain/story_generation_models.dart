const String fallbackStoryGenerationProjectId = 'project-yuechao';

enum StorySceneGenerationStatus {
  pending,
  directing,
  roleRunning,
  drafting,
  reviewing,
  passed,
  invalidated,
  blocked,
}

enum StoryChapterGenerationStatus {
  pending,
  inProgress,
  reviewing,
  passed,
  invalidated,
  blocked,
}

enum StoryReviewStatus { pending, passed, failed, softFailed, hardFailed }

class StorySceneGenerationState {
  StorySceneGenerationState({
    required this.sceneId,
    required this.status,
    required this.judgeStatus,
    required this.consistencyStatus,
    required this.proseRetryCount,
    required this.directorRetryCount,
    List<String> castRoleIds = const [],
    List<String> worldNodeIds = const [],
    required this.upstreamFingerprint,
    this.memoryFingerprint = '',
    List<String> invalidationEdges = const [],
  }) : castRoleIds = List.unmodifiable([...castRoleIds]),
       worldNodeIds = List.unmodifiable([...worldNodeIds]),
       invalidationEdges = List.unmodifiable([...invalidationEdges]);

  final String sceneId;
  final StorySceneGenerationStatus status;
  final StoryReviewStatus judgeStatus;
  final StoryReviewStatus consistencyStatus;
  final int proseRetryCount;
  final int directorRetryCount;
  final List<String> castRoleIds;
  final List<String> worldNodeIds;
  final String upstreamFingerprint;

  final String memoryFingerprint;

  final List<String> invalidationEdges;

  StorySceneGenerationState copyWith({
    String? sceneId,
    StorySceneGenerationStatus? status,
    StoryReviewStatus? judgeStatus,
    StoryReviewStatus? consistencyStatus,
    int? proseRetryCount,
    int? directorRetryCount,
    List<String>? castRoleIds,
    List<String>? worldNodeIds,
    String? upstreamFingerprint,
    String? memoryFingerprint,
    List<String>? invalidationEdges,
  }) {
    return StorySceneGenerationState(
      sceneId: sceneId ?? this.sceneId,
      status: status ?? this.status,
      judgeStatus: judgeStatus ?? this.judgeStatus,
      consistencyStatus: consistencyStatus ?? this.consistencyStatus,
      proseRetryCount: proseRetryCount ?? this.proseRetryCount,
      directorRetryCount: directorRetryCount ?? this.directorRetryCount,
      castRoleIds: [...(castRoleIds ?? this.castRoleIds)],
      worldNodeIds: [...(worldNodeIds ?? this.worldNodeIds)],
      upstreamFingerprint: upstreamFingerprint ?? this.upstreamFingerprint,
      memoryFingerprint: memoryFingerprint ?? this.memoryFingerprint,
      invalidationEdges: [...(invalidationEdges ?? this.invalidationEdges)],
    );
  }

  StorySceneGenerationState deepCopy() => StorySceneGenerationState(
      sceneId: sceneId,
      status: status,
      judgeStatus: judgeStatus,
      consistencyStatus: consistencyStatus,
      proseRetryCount: proseRetryCount,
      directorRetryCount: directorRetryCount,
      castRoleIds: castRoleIds,
      worldNodeIds: worldNodeIds,
      upstreamFingerprint: upstreamFingerprint,
      memoryFingerprint: memoryFingerprint,
      invalidationEdges: invalidationEdges,
    );

  Map<String, Object?> toJson() {
    return {
      'sceneId': sceneId,
      'status': status.name,
      'judgeStatus': judgeStatus.name,
      'consistencyStatus': consistencyStatus.name,
      'proseRetryCount': proseRetryCount,
      'directorRetryCount': directorRetryCount,
      'castRoleIds': [for (final roleId in castRoleIds) roleId],
      'worldNodeIds': [for (final worldNodeId in worldNodeIds) worldNodeId],
      'upstreamFingerprint': upstreamFingerprint,
      'memoryFingerprint': memoryFingerprint,
      'invalidationEdges': [for (final edge in invalidationEdges) edge],
    };
  }

  static StorySceneGenerationState fromJson(Map<String, Object?> json) {
    return StorySceneGenerationState(
      sceneId: json['sceneId']?.toString() ?? json['id']?.toString() ?? '',
      status: storySceneGenerationStatusFromRaw(json['status']),
      judgeStatus: storyReviewStatusFromRaw(json['judgeStatus']),
      consistencyStatus: storyReviewStatusFromRaw(json['consistencyStatus']),
      proseRetryCount: intFromRaw(json['proseRetryCount']),
      directorRetryCount: intFromRaw(json['directorRetryCount']),
      castRoleIds: stringListFromRaw(json['castRoleIds']),
      worldNodeIds: stringListFromRaw(json['worldNodeIds']),
      upstreamFingerprint: json['upstreamFingerprint']?.toString() ?? '',
      memoryFingerprint: json['memoryFingerprint']?.toString() ?? '',
      invalidationEdges: stringListFromRaw(json['invalidationEdges']),
    );
  }
}

class StoryChapterGenerationState {
  StoryChapterGenerationState({
    required this.chapterId,
    required this.status,
    this.targetLength = 0,
    this.actualLength = 0,
    List<String> participatingRoleIds = const [],
    List<String> worldNodeIds = const [],
    List<StorySceneGenerationState> scenes = const [],
  }) : participatingRoleIds = List.unmodifiable([...participatingRoleIds]),
       worldNodeIds = List.unmodifiable([...worldNodeIds]),
       scenes = List.unmodifiable([...scenes]);

  final String chapterId;
  final StoryChapterGenerationStatus status;
  final int targetLength;
  final int actualLength;
  final List<String> participatingRoleIds;
  final List<String> worldNodeIds;
  final List<StorySceneGenerationState> scenes;

  StoryChapterGenerationState copyWith({
    String? chapterId,
    StoryChapterGenerationStatus? status,
    int? targetLength,
    int? actualLength,
    List<String>? participatingRoleIds,
    List<String>? worldNodeIds,
    List<StorySceneGenerationState>? scenes,
  }) {
    return StoryChapterGenerationState(
      chapterId: chapterId ?? this.chapterId,
      status: status ?? this.status,
      targetLength: targetLength ?? this.targetLength,
      actualLength: actualLength ?? this.actualLength,
      participatingRoleIds: [
        ...(participatingRoleIds ?? this.participatingRoleIds),
      ],
      worldNodeIds: [...(worldNodeIds ?? this.worldNodeIds)],
      scenes: [...(scenes ?? this.scenes)],
    );
  }

  StoryChapterGenerationState deepCopy() => StoryChapterGenerationState(
      chapterId: chapterId,
      status: status,
      targetLength: targetLength,
      actualLength: actualLength,
      participatingRoleIds: participatingRoleIds,
      worldNodeIds: worldNodeIds,
      scenes: [for (final scene in scenes) scene.deepCopy()],
    );

  Map<String, Object?> toJson() {
    return {
      'chapterId': chapterId,
      'status': status.name,
      'targetLength': targetLength,
      'actualLength': actualLength,
      'participatingRoleIds': [
        for (final roleId in participatingRoleIds) roleId,
      ],
      'worldNodeIds': [for (final worldNodeId in worldNodeIds) worldNodeId],
      'scenes': [for (final scene in scenes) scene.toJson()],
    };
  }

  static StoryChapterGenerationState fromJson(Map<String, Object?> json) {
    final rawScenes = json['scenes'] as List<Object?>? ?? const [];
    return StoryChapterGenerationState(
      chapterId: json['chapterId']?.toString() ?? json['id']?.toString() ?? '',
      status: storyChapterGenerationStatusFromRaw(json['status']),
      targetLength: intFromRaw(json['targetLength']),
      actualLength: intFromRaw(json['actualLength']),
      participatingRoleIds: stringListFromRaw(json['participatingRoleIds']),
      worldNodeIds: stringListFromRaw(json['worldNodeIds']),
      scenes: [
        for (final scene in rawScenes)
          if (scene is Map)
            StorySceneGenerationState.fromJson(asStringObjectMap(scene)),
      ],
    );
  }
}

class StoryGenerationSnapshot {
  StoryGenerationSnapshot({
    required this.projectId,
    List<StoryChapterGenerationState> chapters = const [],
  }) : chapters = List.unmodifiable([...chapters]);

  final String projectId;
  final List<StoryChapterGenerationState> chapters;

  StoryGenerationSnapshot copyWith({
    String? projectId,
    List<StoryChapterGenerationState>? chapters,
  }) {
    return StoryGenerationSnapshot(
      projectId: projectId ?? this.projectId,
      chapters: [...(chapters ?? this.chapters)],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'projectId': projectId,
      'chapters': [for (final chapter in chapters) chapter.toJson()],
    };
  }

  StoryGenerationSnapshot deepCopy() => StoryGenerationSnapshot(
      projectId: projectId,
      chapters: [for (final chapter in chapters) chapter.deepCopy()],
    );

  static StoryGenerationSnapshot empty(String projectId) {
    return StoryGenerationSnapshot(projectId: projectId);
  }

  static StoryGenerationSnapshot fromJson(Map<String, Object?> json) {
    final rawChapters = json['chapters'] as List<Object?>? ?? const [];
    return StoryGenerationSnapshot(
      projectId:
          json['projectId']?.toString() ?? fallbackStoryGenerationProjectId,
      chapters: [
        for (final chapter in rawChapters)
          if (chapter is Map)
            StoryChapterGenerationState.fromJson(asStringObjectMap(chapter)),
      ],
    );
  }
}

Map<String, Object?> asStringObjectMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value,
  };
}

List<String> stringListFromRaw(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
}

int intFromRaw(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

final _sceneStatusByName = {
  for (final v in StorySceneGenerationStatus.values) v.name: v,
};

StorySceneGenerationStatus storySceneGenerationStatusFromRaw(Object? value) =>
    _sceneStatusByName[value?.toString()] ??
    StorySceneGenerationStatus.pending;

final _chapterStatusByName = {
  for (final v in StoryChapterGenerationStatus.values) v.name: v,
  'in_progress': StoryChapterGenerationStatus.inProgress,
};

StoryChapterGenerationStatus storyChapterGenerationStatusFromRaw(
  Object? value,
) =>
    _chapterStatusByName[value?.toString()] ??
    StoryChapterGenerationStatus.pending;

final _reviewStatusByName = {
  for (final v in StoryReviewStatus.values) v.name: v,
};

StoryReviewStatus storyReviewStatusFromRaw(Object? value) =>
    _reviewStatusByName[value?.toString()] ?? StoryReviewStatus.pending;
