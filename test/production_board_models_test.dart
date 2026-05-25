import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/production_board/domain/production_board_models.dart';
import 'package:novel_writer/features/writing_stats/domain/writing_stats_models.dart';

void main() {
  test('production board groups scenes by generation status', () {
    const builder = ProductionBoardSnapshotBuilder();
    const project = ProjectRecord(
      id: 'project-a',
      sceneId: 'scene-a',
      title: '海港月潮',
      genre: '悬疑',
      summary: '旧港风暴前夜。',
      recentLocation: '第 1 章 / 场景 01',
      lastOpenedAtMs: 1,
    );

    final snapshot = builder.build(
      project: project,
      workspaceScenes: const [],
      outline: const StoryOutlineSnapshot(
        projectId: 'project-a',
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'chapter-01',
            title: '第 1 章',
            summary: '开局',
            scenes: [
              StoryOutlineSceneSnapshot(
                id: 'scene-a',
                title: '码头截停',
                summary: '主角遇到阻拦。',
              ),
              StoryOutlineSceneSnapshot(
                id: 'scene-b',
                title: '旧仓审问',
                summary: '证词互相矛盾。',
              ),
              StoryOutlineSceneSnapshot(
                id: 'scene-c',
                title: '雨夜追踪',
                summary: '线索指向码头。',
              ),
            ],
          ),
        ],
      ),
      generation: StoryGenerationSnapshot(
        projectId: 'project-a',
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'chapter-01',
            status: StoryChapterGenerationStatus.inProgress,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-a',
                status: StorySceneGenerationStatus.passed,
                judgeStatus: StoryReviewStatus.passed,
                consistencyStatus: StoryReviewStatus.passed,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: 'outline:v1',
              ),
              StorySceneGenerationState(
                sceneId: 'scene-b',
                status: StorySceneGenerationStatus.reviewing,
                judgeStatus: StoryReviewStatus.pending,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: 'outline:v1',
              ),
              StorySceneGenerationState(
                sceneId: 'scene-c',
                status: StorySceneGenerationStatus.blocked,
                judgeStatus: StoryReviewStatus.failed,
                consistencyStatus: StoryReviewStatus.failed,
                proseRetryCount: 1,
                directorRetryCount: 0,
                upstreamFingerprint: 'outline:v1',
              ),
            ],
          ),
        ],
      ),
      run: const StoryGenerationRunSnapshot(
        status: StoryGenerationRunStatus.completed,
        sceneId: 'scene-a',
        sceneLabel: '海港月潮 / 第 1 章 / 场景 01',
        headline: 'AI 试写完成',
        summary: '审查通过。',
        stageSummary: '审查通过',
      ),
      writingStats: const WritingStatsSnapshot(
        dailyStats: [
          WritingDailyStat(
            date: '2026-05-19',
            sceneScopeId: 'project-a::scene-a',
            projectId: 'project-a',
            charCount: 1200,
            deltaChars: 1200,
            chaptersCompleted: 0,
            goalReached: false,
            updatedAtMs: 1,
          ),
          WritingDailyStat(
            date: '2026-05-20',
            sceneScopeId: 'project-a::scene-b',
            projectId: 'project-a',
            charCount: 800,
            deltaChars: 800,
            chaptersCompleted: 0,
            goalReached: false,
            updatedAtMs: 2,
          ),
          WritingDailyStat(
            date: '2026-05-20',
            sceneScopeId: 'project-a::scene-c',
            projectId: 'project-a',
            charCount: 250,
            deltaChars: 250,
            chaptersCompleted: 0,
            goalReached: false,
            updatedAtMs: 3,
          ),
        ],
        projectStat: WritingProjectStat(
          projectId: 'project-a',
          totalCharCount: 2250,
          totalDeltaChars: 2250,
          totalChapters: 1,
          totalSessions: 3,
          firstWriteAtMs: 1,
          lastWriteAtMs: 3,
          bestDayChars: 1050,
          bestDayDate: '2026-05-20',
        ),
        goals: [],
        todayCharCount: 0,
        todayDeltaChars: 0,
        weekCharCount: 2250,
      ),
    );

    expect(snapshot.totalChapters, 1);
    expect(snapshot.totalScenes, 3);
    expect(snapshot.completedScenes, 1);
    expect(snapshot.inFlightScenes, 1);
    expect(snapshot.needsWorkScenes, 1);
    expect(snapshot.totalWordCount, 2250);
    expect(snapshot.dailyWordTrend, hasLength(2));
    expect(snapshot.dailyWordTrend.last.date, '2026-05-20');
    expect(snapshot.dailyWordTrend.last.deltaChars, 1050);
    expect(snapshot.chapters.single.firstSceneId, 'scene-a');
    expect(snapshot.chapters.single.firstSceneLocation, '第 1 章 · 码头截停');
    expect(snapshot.recentRun.statusLabel, '已完成');
    expect(snapshot.lanes[ProductionBoardLane.approved]!.single.title, '码头截停');
    expect(
      snapshot.lanes[ProductionBoardLane.reviewing]!.single.statusLabel,
      '审查中',
    );
    expect(
      snapshot.lanes[ProductionBoardLane.needsWork]!.single.statusLabel,
      '受阻',
    );
  });

  test(
    'production board falls back to draft word count without persisted stats',
    () {
      const builder = ProductionBoardSnapshotBuilder();
      const project = ProjectRecord(
        id: 'project-a',
        sceneId: 'scene-a',
        title: '海港月潮',
        genre: '悬疑',
        summary: '',
        recentLocation: '',
        lastOpenedAtMs: 1,
      );

      final snapshot = builder.build(
        project: project,
        workspaceScenes: const [
          SceneRecord(
            id: 'scene-a',
            chapterLabel: '第 1 章 / 场景 01',
            title: '码头截停',
            summary: '主角遇到阻拦。',
          ),
        ],
        outline: StoryOutlineSnapshot.empty('project-a'),
        generation: StoryGenerationSnapshot.empty('project-a'),
        run: const StoryGenerationRunSnapshot(
          status: StoryGenerationRunStatus.idle,
          sceneId: '',
          sceneLabel: '',
          headline: '',
          summary: '',
          stageSummary: '',
        ),
        draftText: '柳溪 推开 门。\n风声很急。',
      );

      expect(snapshot.totalWordCount, 11);
      expect(snapshot.chapters.single.canOpen, isTrue);
      expect(
        snapshot.chapters.single.firstSceneLocation,
        '第 1 章 / 场景 01 · 码头截停',
      );
    },
  );
}
