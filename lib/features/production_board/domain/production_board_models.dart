import '../../../app/state/story_generation_run_store.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../../domain/workspace_models.dart';

enum ProductionBoardLane {
  notStarted,
  drafting,
  reviewing,
  needsWork,
  approved,
}

class ProductionBoardSnapshot {
  const ProductionBoardSnapshot({
    required this.projectTitle,
    required this.projectSummary,
    required this.totalChapters,
    required this.totalScenes,
    required this.completedScenes,
    required this.inFlightScenes,
    required this.needsWorkScenes,
    required this.lanes,
    required this.chapters,
    required this.recentRun,
  });

  final String projectTitle;
  final String projectSummary;
  final int totalChapters;
  final int totalScenes;
  final int completedScenes;
  final int inFlightScenes;
  final int needsWorkScenes;
  final Map<ProductionBoardLane, List<ProductionBoardSceneCard>> lanes;
  final List<ProductionBoardChapterCard> chapters;
  final ProductionBoardRunCard recentRun;

  double get completionRatio =>
      totalScenes == 0 ? 0 : completedScenes / totalScenes;

  int get notStartedScenes =>
      lanes[ProductionBoardLane.notStarted]?.length ?? 0;

  int get reviewQueueScenes =>
      (lanes[ProductionBoardLane.reviewing]?.length ?? 0) + needsWorkScenes;
}

class ProductionBoardChapterCard {
  const ProductionBoardChapterCard({
    required this.id,
    required this.title,
    required this.statusLabel,
    required this.completedScenes,
    required this.totalScenes,
  });

  final String id;
  final String title;
  final String statusLabel;
  final int completedScenes;
  final int totalScenes;
}

class ProductionBoardSceneCard {
  const ProductionBoardSceneCard({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.summary,
    required this.statusLabel,
    required this.lane,
  });

  final String id;
  final String chapterId;
  final String title;
  final String summary;
  final String statusLabel;
  final ProductionBoardLane lane;
}

class ProductionBoardRunCard {
  const ProductionBoardRunCard({
    required this.statusLabel,
    required this.headline,
    required this.summary,
    required this.stageSummary,
    required this.sceneLabel,
  });

  final String statusLabel;
  final String headline;
  final String summary;
  final String stageSummary;
  final String sceneLabel;
}

class ProductionBoardSnapshotBuilder {
  const ProductionBoardSnapshotBuilder();

  ProductionBoardSnapshot build({
    required ProjectRecord project,
    required List<SceneRecord> workspaceScenes,
    required StoryOutlineSnapshot outline,
    required StoryGenerationSnapshot generation,
    required StoryGenerationRunSnapshot run,
  }) {
    final sceneSources = _sceneSources(outline, workspaceScenes);
    final generatedScenes = <String, StorySceneGenerationState>{
      for (final chapter in generation.chapters)
        for (final scene in chapter.scenes) scene.sceneId: scene,
    };
    final generatedChapters = <String, StoryChapterGenerationState>{
      for (final chapter in generation.chapters) chapter.chapterId: chapter,
    };

    final lanes = {
      for (final lane in ProductionBoardLane.values)
        lane: <ProductionBoardSceneCard>[],
    };
    for (final source in sceneSources) {
      final state = generatedScenes[source.sceneId];
      final lane = _laneForScene(state);
      lanes[lane]!.add(
        ProductionBoardSceneCard(
          id: source.sceneId,
          chapterId: source.chapterId,
          title: source.sceneTitle,
          summary: source.sceneSummary,
          statusLabel: _sceneStatusLabel(state?.status),
          lane: lane,
        ),
      );
    }

    final chapterSources = _chapterSources(outline, workspaceScenes);
    final chapters = [
      for (final source in chapterSources)
        ProductionBoardChapterCard(
          id: source.chapterId,
          title: source.chapterTitle,
          statusLabel: _chapterStatusLabel(
            generatedChapters[source.chapterId]?.status,
          ),
          completedScenes: sceneSources
              .where((scene) => scene.chapterId == source.chapterId)
              .where(
                (scene) =>
                    generatedScenes[scene.sceneId]?.status ==
                    StorySceneGenerationStatus.passed,
              )
              .length,
          totalScenes: sceneSources
              .where((scene) => scene.chapterId == source.chapterId)
              .length,
        ),
    ];

    final completedScenes = lanes[ProductionBoardLane.approved]!.length;
    final inFlightScenes =
        lanes[ProductionBoardLane.drafting]!.length +
        lanes[ProductionBoardLane.reviewing]!.length;
    final needsWorkScenes = lanes[ProductionBoardLane.needsWork]!.length;

    return ProductionBoardSnapshot(
      projectTitle: project.title,
      projectSummary: project.summary,
      totalChapters: chapters.length,
      totalScenes: sceneSources.length,
      completedScenes: completedScenes,
      inFlightScenes: inFlightScenes,
      needsWorkScenes: needsWorkScenes,
      lanes: lanes,
      chapters: chapters,
      recentRun: ProductionBoardRunCard(
        statusLabel: _runStatusLabel(run.status),
        headline: run.headline,
        summary: run.summary,
        stageSummary: run.stageSummary,
        sceneLabel: run.sceneLabel,
      ),
    );
  }

  List<_SceneSource> _sceneSources(
    StoryOutlineSnapshot outline,
    List<SceneRecord> workspaceScenes,
  ) {
    if (outline.chapters.any((chapter) => chapter.scenes.isNotEmpty)) {
      return [
        for (final chapter in outline.chapters)
          for (final scene in chapter.scenes)
            _SceneSource(
              chapterId: chapter.id,
              sceneId: scene.id,
              sceneTitle: scene.title,
              sceneSummary: scene.summary,
            ),
      ];
    }
    return [
      for (final scene in workspaceScenes)
        _SceneSource(
          chapterId: scene.chapterLabel,
          sceneId: scene.id,
          sceneTitle: scene.title,
          sceneSummary: scene.summary,
        ),
    ];
  }

  List<_ChapterSource> _chapterSources(
    StoryOutlineSnapshot outline,
    List<SceneRecord> workspaceScenes,
  ) {
    if (outline.chapters.isNotEmpty) {
      return [
        for (final chapter in outline.chapters)
          _ChapterSource(chapterId: chapter.id, chapterTitle: chapter.title),
      ];
    }
    final seen = <String>{};
    return [
      for (final scene in workspaceScenes)
        if (seen.add(scene.chapterLabel))
          _ChapterSource(
            chapterId: scene.chapterLabel,
            chapterTitle: scene.chapterLabel,
          ),
    ];
  }

  ProductionBoardLane _laneForScene(StorySceneGenerationState? state) {
    return switch (state?.status) {
      null ||
      StorySceneGenerationStatus.pending => ProductionBoardLane.notStarted,
      StorySceneGenerationStatus.directing ||
      StorySceneGenerationStatus.roleRunning ||
      StorySceneGenerationStatus.drafting => ProductionBoardLane.drafting,
      StorySceneGenerationStatus.reviewing => ProductionBoardLane.reviewing,
      StorySceneGenerationStatus.invalidated ||
      StorySceneGenerationStatus.blocked => ProductionBoardLane.needsWork,
      StorySceneGenerationStatus.passed => ProductionBoardLane.approved,
    };
  }

  String _sceneStatusLabel(StorySceneGenerationStatus? status) {
    return switch (status) {
      null || StorySceneGenerationStatus.pending => '未开始',
      StorySceneGenerationStatus.directing => '导演编排',
      StorySceneGenerationStatus.roleRunning => '角色回合',
      StorySceneGenerationStatus.drafting => '正文草拟',
      StorySceneGenerationStatus.reviewing => '审查中',
      StorySceneGenerationStatus.passed => '已通过',
      StorySceneGenerationStatus.invalidated => '需重跑',
      StorySceneGenerationStatus.blocked => '受阻',
    };
  }

  String _chapterStatusLabel(StoryChapterGenerationStatus? status) {
    return switch (status) {
      null || StoryChapterGenerationStatus.pending => '未开始',
      StoryChapterGenerationStatus.inProgress => '生成中',
      StoryChapterGenerationStatus.reviewing => '审查中',
      StoryChapterGenerationStatus.passed => '已通过',
      StoryChapterGenerationStatus.invalidated => '需重跑',
      StoryChapterGenerationStatus.blocked => '受阻',
    };
  }

  String _runStatusLabel(StoryGenerationRunStatus status) {
    return switch (status) {
      StoryGenerationRunStatus.idle => '暂无运行',
      StoryGenerationRunStatus.running => '运行中',
      StoryGenerationRunStatus.completed => '已完成',
      StoryGenerationRunStatus.failed => '失败',
      StoryGenerationRunStatus.cancelled => '已取消',
    };
  }
}

class _SceneSource {
  const _SceneSource({
    required this.chapterId,
    required this.sceneId,
    required this.sceneTitle,
    required this.sceneSummary,
  });

  final String chapterId;
  final String sceneId;
  final String sceneTitle;
  final String sceneSummary;
}

class _ChapterSource {
  const _ChapterSource({required this.chapterId, required this.chapterTitle});

  final String chapterId;
  final String chapterTitle;
}
