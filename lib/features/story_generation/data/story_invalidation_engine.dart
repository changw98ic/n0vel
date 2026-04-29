import '../../../app/state/story_generation_store.dart';
import 'scene_review_models.dart';

/// Describes the scope of an invalidation: which scenes, chapters, and
/// review categories are affected.
class InvalidationScope {
  const InvalidationScope({
    this.sceneIds = const {},
    this.chapterIds = const {},
    this.categories = const {},
  });

  /// Scene IDs that need invalidation.
  final Set<String> sceneIds;

  /// Chapter IDs that need invalidation.
  final Set<String> chapterIds;

  /// Review categories affected by the change.
  final Set<SceneReviewCategory> categories;

  /// A global scope means no specific scenes or chapters could be identified,
  /// so everything should be invalidated.
  bool get isGlobal => sceneIds.isEmpty && chapterIds.isEmpty;

  /// An empty scope means nothing needs invalidation.
  bool get isEmpty => sceneIds.isEmpty && chapterIds.isEmpty && categories.isEmpty;

  InvalidationScope merge(InvalidationScope other) {
    return InvalidationScope(
      sceneIds: {...sceneIds, ...other.sceneIds},
      chapterIds: {...chapterIds, ...other.chapterIds},
      categories: {...categories, ...other.categories},
    );
  }
}

class StoryInvalidationEngine {
  List<StoryChapterGenerationState> invalidateForChangedRole({
    required String roleId,
    required List<StoryChapterGenerationState> chapters,
  }) {
    return _invalidateMatchingScenes(
      chapters: chapters,
      matches: (scene) => _matchesExplicitOrFallback(
        scene: scene,
        explicitPrefixes: const ['role', 'character'],
        id: roleId,
        fallback: () => scene.castRoleIds.contains(roleId),
      ),
    );
  }

  List<StoryChapterGenerationState> invalidateForChangedCognition({
    required String characterId,
    required List<StoryChapterGenerationState> chapters,
  }) {
    return _invalidateMatchingScenes(
      chapters: chapters,
      matches: (scene) => _matchesExplicitOrFallback(
        scene: scene,
        explicitPrefixes: const ['cognition'],
        id: characterId,
        fallback: () => scene.castRoleIds.contains(characterId),
      ),
    );
  }

  List<StoryChapterGenerationState> invalidateForChangedWorldSetting({
    required String worldNodeId,
    required List<StoryChapterGenerationState> chapters,
  }) {
    return _invalidateMatchingScenes(
      chapters: chapters,
      matches: (scene) => _matchesExplicitOrFallback(
        scene: scene,
        explicitPrefixes: const ['world'],
        id: worldNodeId,
        fallback: () => scene.worldNodeIds.contains(worldNodeId),
      ),
    );
  }

  List<StoryChapterGenerationState> invalidateForChangedTransition({
    required String transitionId,
    required List<StoryChapterGenerationState> chapters,
  }) {
    return invalidateForChangedTransitions(
      transitionIds: [transitionId],
      chapters: chapters,
    );
  }

  List<StoryChapterGenerationState> invalidateForChangedTransitions({
    required Iterable<String> transitionIds,
    required List<StoryChapterGenerationState> chapters,
  }) {
    final ids = {
      for (final transitionId in transitionIds)
        if (transitionId.trim().isNotEmpty) transitionId.trim(),
    };
    return _invalidateMatchingScenes(
      chapters: chapters,
      matches: (scene) => ids.any(
        (transitionId) => _matchesExplicitEdge(
          scene: scene,
          prefixes: const ['transition'],
          id: transitionId,
        ),
      ),
    );
  }

  List<StoryChapterGenerationState> _invalidateMatchingScenes({
    required List<StoryChapterGenerationState> chapters,
    required bool Function(StorySceneGenerationState scene) matches,
  }) {
    return [
      for (final chapter in chapters)
        _invalidateChapter(chapter: chapter, matches: matches),
    ];
  }

  StoryChapterGenerationState _invalidateChapter({
    required StoryChapterGenerationState chapter,
    required bool Function(StorySceneGenerationState scene) matches,
  }) {
    var invalidatedPassedScene = false;
    final nextScenes = [
      for (final scene in chapter.scenes)
        if (matches(scene) && scene.status == StorySceneGenerationStatus.passed)
          (() {
            invalidatedPassedScene = true;
            return scene.copyWith(
              status: StorySceneGenerationStatus.invalidated,
              judgeStatus: StoryReviewStatus.pending,
              consistencyStatus: StoryReviewStatus.pending,
            );
          })()
        else
          scene.copyWith(),
    ];

    final shouldInvalidateChapter =
        chapter.status == StoryChapterGenerationStatus.passed &&
        invalidatedPassedScene;

    return chapter.copyWith(
      status: shouldInvalidateChapter
          ? StoryChapterGenerationStatus.invalidated
          : chapter.status,
      scenes: nextScenes,
    );
  }

  bool _matchesExplicitOrFallback({
    required StorySceneGenerationState scene,
    required List<String> explicitPrefixes,
    required String id,
    required bool Function() fallback,
  }) {
    if (scene.invalidationEdges.isEmpty) {
      return fallback();
    }
    return _matchesExplicitEdge(
      scene: scene,
      prefixes: explicitPrefixes,
      id: id,
    );
  }

  bool _matchesExplicitEdge({
    required StorySceneGenerationState scene,
    required List<String> prefixes,
    required String id,
  }) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return false;
    final validEdges = {
      normalizedId,
      for (final prefix in prefixes) '$prefix:$normalizedId',
    };
    return scene.invalidationEdges.any(validEdges.contains);
  }

  /// Determine what outputs need invalidation based on what changed.
  ///
  /// Returns a scoped invalidation (not global) when specific scene mappings
  /// are available. Falls back to global invalidation when no mappings exist
  /// for the changed items.
  InvalidationScope computeInvalidation({
    required Set<String> changedTransitionIds,
    required Set<String> changedWorldNodeIds,
    required Set<String> changedCognitionInputs,
    required Map<String, List<String>> sceneToTransitions,
    required Map<String, List<String>> sceneToWorldNodes,
    required Map<String, List<String>> sceneToCognitionInputs,
  }) {
    if (changedTransitionIds.isEmpty &&
        changedWorldNodeIds.isEmpty &&
        changedCognitionInputs.isEmpty) {
      return const InvalidationScope();
    }

    final affectedSceneIds = <String>{};
    final categories = <SceneReviewCategory>{};

    // Transition changes -> continuity + scenePlan
    if (changedTransitionIds.isNotEmpty) {
      categories.addAll([
        SceneReviewCategory.continuity,
        SceneReviewCategory.scenePlan,
      ]);
      if (sceneToTransitions.isEmpty) {
        // No mapping available -> global
        return InvalidationScope(categories: categories);
      }
      for (final entry in sceneToTransitions.entries) {
        if (entry.value.any(changedTransitionIds.contains)) {
          affectedSceneIds.add(entry.key);
        }
      }
    }

    // World node changes -> worldState + continuity
    if (changedWorldNodeIds.isNotEmpty) {
      categories.addAll([
        SceneReviewCategory.worldState,
        SceneReviewCategory.continuity,
      ]);
      if (sceneToWorldNodes.isEmpty) {
        return InvalidationScope(categories: categories);
      }
      for (final entry in sceneToWorldNodes.entries) {
        if (entry.value.any(changedWorldNodeIds.contains)) {
          affectedSceneIds.add(entry.key);
        }
      }
    }

    // Cognition changes -> characterState + prose
    if (changedCognitionInputs.isNotEmpty) {
      categories.addAll([
        SceneReviewCategory.characterState,
        SceneReviewCategory.prose,
      ]);
      if (sceneToCognitionInputs.isEmpty) {
        return InvalidationScope(categories: categories);
      }
      for (final entry in sceneToCognitionInputs.entries) {
        if (entry.value.any(changedCognitionInputs.contains)) {
          affectedSceneIds.add(entry.key);
        }
      }
    }

    return InvalidationScope(
      sceneIds: affectedSceneIds,
      categories: categories,
    );
  }
}
