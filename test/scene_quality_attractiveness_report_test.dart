import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_reporter.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  test(
    'top-level quality gate blocks cross-scene repetition with evidence',
    () {
      final outputs = <SceneRuntimeOutput>[
        _output(
          sceneId: 'scene-01',
          sceneIndex: 0,
          prose: '「警报响了！」柳溪冲进档案室。潮湿的风从破窗灌进来，把桌上的旧报纸一页页掀起。',
        ),
        _output(
          sceneId: 'scene-02',
          sceneIndex: 1,
          prose: '潮湿的风，从破窗灌进来；把桌上的旧报纸一页页掀起。门外的追兵正在逼近。',
        ),
      ];

      final report = jsonDecode(SceneQualityReporter.toJson(outputs)) as Map;
      final qualityGate = report['qualityGate'] as Map;
      final repetition = report['repetitionAudit'] as Map;

      expect(qualityGate['passed'], isFalse);
      expect(qualityGate['sceneScoreGatePassed'], isTrue);
      expect(qualityGate['deterministicRepetitionGatePassed'], isFalse);
      expect(repetition['findingCount'], greaterThan(0));
      expect(
        (repetition['findings'] as List)
            .map((item) => (item as Map)['context'].toString())
            .join(' '),
        allOf(contains('scene-01'), contains('scene-02')),
      );
      expect(
        SceneQualityReporter.toMarkdown(outputs),
        contains('Deterministic Repetition Gate'),
      );
    },
  );

  test('passing score cannot hide a resolved chapter ending', () {
    final output = _output(
      sceneId: 'scene-02',
      sceneIndex: 1,
      prose: '「终于结束了！」秘密已经公开，所有人都安全了。',
    );

    final report = jsonDecode(SceneQualityReporter.toJson([output])) as Map;
    final scene = (report['scenes'] as List).single as Map;
    final qualityGate = scene['qualityGate'] as Map;
    final attractiveness = scene['chapterAttractivenessAudit'] as Map;

    expect(qualityGate['scorePassed'], isTrue);
    expect(qualityGate['passed'], isFalse);
    expect(attractiveness['endingHookPassed'], isFalse);
    expect((attractiveness['issues'] as List).join(' '), contains('收口'));
  });
}

SceneRuntimeOutput _output({
  required String sceneId,
  required int sceneIndex,
  required String prose,
}) {
  final brief = SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章',
    sceneId: sceneId,
    sceneTitle: '测试场景',
    sceneSummary: '测试场景。',
    sceneIndex: sceneIndex,
    totalScenesInChapter: 2,
    targetLength: 200,
    cast: <SceneCastCandidate>[
      SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '记者'),
    ],
  );
  return SceneRuntimeOutput(
    brief: brief,
    resolvedCast: const [],
    director: const SceneDirectorOutput(text: 'plan'),
    roleOutputs: const [],
    prose: SceneProseDraft(text: prose, attempt: 1),
    review: const SceneReviewResult(
      judge: SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '通过',
        rawText: '',
      ),
      consistency: SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '一致',
        rawText: '',
      ),
      decision: SceneReviewDecision.pass,
    ),
    proseAttempts: 1,
    softFailureCount: 0,
    qualityScore: const SceneQualityScore(
      overall: 96,
      prose: 96,
      coherence: 96,
      character: 96,
      completeness: 96,
      summary: '通过。',
    ),
  );
}
