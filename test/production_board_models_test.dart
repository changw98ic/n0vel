import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/production_board/domain/production_board_models.dart';

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
        headline: '角色编排已完成',
        summary: '审查通过。',
        stageSummary: '审查通过',
      ),
    );

    expect(snapshot.totalChapters, 1);
    expect(snapshot.totalScenes, 3);
    expect(snapshot.completedScenes, 1);
    expect(snapshot.inFlightScenes, 1);
    expect(snapshot.needsWorkScenes, 1);
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
}
