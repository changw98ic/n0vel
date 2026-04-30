import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_reporter.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  test('quality reporter renders per-scene scores and review state', () {
    final output = SceneRuntimeOutput(
      brief: SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章',
        sceneId: 'scene-01',
        sceneTitle: '旧码头',
        sceneSummary: '对峙升级。',
      ),
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: 'plan'),
      roleOutputs: const [],
      prose: const SceneProseDraft(text: '正文内容', attempt: 1),
      review: SceneReviewResult(
        judge: const SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '冲突成立',
          rawText: '决定：PASS\n原因：冲突成立',
        ),
        consistency: const SceneReviewPassResult(
          status: SceneReviewStatus.pass,
          reason: '设定一致',
          rawText: '决定：PASS\n原因：设定一致',
        ),
        decision: SceneReviewDecision.pass,
      ),
      proseAttempts: 2,
      softFailureCount: 1,
      qualityScore: const SceneQualityScore(
        overall: 86,
        prose: 88,
        coherence: 84,
        character: 90,
        completeness: 82,
        summary: '张力稳定。',
      ),
    );

    final markdown = SceneQualityReporter.toMarkdown([output]);
    expect(markdown, contains('chapter-01/scene-01'));
    expect(markdown, contains('综合'));
    expect(markdown, contains('86'));
    expect(markdown, contains('张力稳定。'));
    expect(markdown, contains('pass'));
    expect(markdown, contains('冲突成立'));

    final json = jsonDecode(SceneQualityReporter.toJson([output])) as Map;
    final scenes = json['scenes'] as List;
    expect(scenes, hasLength(1));
    final scene = scenes.single as Map;
    expect(scene['sceneId'], 'scene-01');
    expect((scene['qualityScore'] as Map)['overall'], 86);
    expect((scene['review'] as Map)['decision'], 'pass');
  });
}
