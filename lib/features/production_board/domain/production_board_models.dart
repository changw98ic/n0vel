import '../../../app/state/story_generation_run_store.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../../domain/workspace_models.dart';
import '../../writing_stats/domain/writing_stats_models.dart';

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
    required this.totalWordCount,
    required this.dailyWordTrend,
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
  final int totalWordCount;
  final List<ProductionDailyWordStat> dailyWordTrend;
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
    required this.firstSceneId,
    required this.firstSceneLocation,
  });

  final String id;
  final String title;
  final String statusLabel;
  final int completedScenes;
  final int totalScenes;
  final String firstSceneId;
  final String firstSceneLocation;

  bool get canOpen => firstSceneId.trim().isNotEmpty;
}

class ProductionDailyWordStat {
  const ProductionDailyWordStat({required this.date, required this.deltaChars});

  final String date;
  final int deltaChars;
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
    WritingStatsSnapshot writingStats = WritingStatsSnapshot.empty,
    String draftText = '',
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
        _chapterCardForSource(
          source,
          sceneSources,
          generatedScenes,
          generatedChapters[source.chapterId],
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
      totalWordCount: _totalWordCount(writingStats, draftText),
      dailyWordTrend: _dailyWordTrend(writingStats.dailyStats),
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
              sceneLocation: '${chapter.title} · ${scene.title}',
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
          sceneLocation: scene.displayLocation,
        ),
    ];
  }

  ProductionBoardChapterCard _chapterCardForSource(
    _ChapterSource source,
    List<_SceneSource> sceneSources,
    Map<String, StorySceneGenerationState> generatedScenes,
    StoryChapterGenerationState? generatedChapter,
  ) {
    final chapterScenes = [
      for (final scene in sceneSources)
        if (scene.chapterId == source.chapterId) scene,
    ];
    final firstScene = chapterScenes.isEmpty ? null : chapterScenes.first;
    return ProductionBoardChapterCard(
      id: source.chapterId,
      title: source.chapterTitle,
      statusLabel: _chapterStatusLabel(generatedChapter?.status),
      completedScenes: chapterScenes
          .where(
            (scene) =>
                generatedScenes[scene.sceneId]?.status ==
                StorySceneGenerationStatus.passed,
          )
          .length,
      totalScenes: chapterScenes.length,
      firstSceneId: firstScene?.sceneId ?? '',
      firstSceneLocation: firstScene?.sceneLocation ?? '',
    );
  }

  int _totalWordCount(WritingStatsSnapshot writingStats, String draftText) {
    final persistedTotal = writingStats.projectStat.totalCharCount;
    if (persistedTotal > 0) {
      return persistedTotal;
    }
    return countNonWhitespace(draftText);
  }

  List<ProductionDailyWordStat> _dailyWordTrend(
    List<WritingDailyStat> dailyStats,
  ) {
    final byDate = <String, int>{};
    for (final stat in dailyStats) {
      byDate[stat.date] = (byDate[stat.date] ?? 0) + stat.deltaChars;
    }
    final dates = byDate.keys.toList()..sort();
    final visibleDates = dates.length <= 7
        ? dates
        : dates.sublist(dates.length - 7);
    return [
      for (final date in visibleDates)
        ProductionDailyWordStat(date: date, deltaChars: byDate[date] ?? 0),
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
    required this.sceneLocation,
  });

  final String chapterId;
  final String sceneId;
  final String sceneTitle;
  final String sceneSummary;
  final String sceneLocation;
}

class _ChapterSource {
  const _ChapterSource({required this.chapterId, required this.chapterTitle});

  final String chapterId;
  final String chapterTitle;
}
