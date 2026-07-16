import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/ai_cliche_detector.dart';
import 'package:novel_writer/features/story_generation/data/scene_hard_gates.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_reporter.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('authoritative outline fidelity', () {
    test('missing required outline beat blocks the final prose', () {
      final brief = SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章 雨夜码头',
        sceneId: 'scene-04',
        sceneTitle: '封港前的离场',
        sceneSummary: '合作刚刚立住，封港警报再次响起。',
        sceneIndex: 2,
        totalScenesInChapter: 4,
        targetBeat: '发现追踪器后进入集装箱暗巷，并揭示档案楼暗门。',
        metadata: const <String, Object?>{
          'requiredOutlineBeats': <Object?>[
            <String, Object?>{
              'id': 'chapter-01-tracker-reveal',
              'description': '沈渡发现风衣纽扣里的微型定位器，把柳溪拉进集装箱暗巷，说明底册在档案楼暗门。',
              'evidenceGroups': <Object?>[
                <String>['微型定位器', '定位器'],
                <String>['风衣纽扣', '纽扣'],
                <String>['集装箱暗巷', '集装箱'],
                <String>['底册不在账本', '档案楼暗门'],
              ],
            },
          ],
        },
      );

      // Regression excerpt: the generated chapter only made an appointment;
      // none of the authoritative turn/hook evidence survived into prose.
      const prose =
          '「丑时，档案楼后墙。」沈渡压低声音。'
          '柳溪点头：「我不连累你。」两人就此定下潜入之约。';

      final violations = sceneHardGateViolations(
        brief: brief,
        proseText: prose,
      );

      expect(
        violations,
        contains(
          isA<HardGateViolation>().having(
            (item) => item.text,
            'text',
            allOf(contains('chapter-01-tracker-reveal'), contains('大纲')),
          ),
        ),
        reason: 'A simplified scene brief must not erase authoritative beats.',
      );
    });

    test('a short resolved exit is not accepted as a chapter hook', () {
      final brief = SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章 雨夜码头',
        sceneId: 'scene-04',
        sceneTitle: '封港前的离场',
        sceneSummary: '双方约好下次行动。',
        sceneIndex: 3,
        totalScenesInChapter: 4,
      );

      final violations = sceneHardGateViolations(
        brief: brief,
        proseText: '「丑时，档案楼后墙。」柳溪点头。\n\n两人随后各自离开码头。',
      );

      expect(
        violations.any(
          (item) => item.text.contains('章尾') && item.text.contains('钩子'),
        ),
        isTrue,
        reason: 'Shortness alone is not evidence of an unresolved hook.',
      );
    });
  });

  test(
    'continuity ledger blocks an unexplained prop rename and holder jump',
    () {
      final brief = SceneBrief(
        chapterId: 'chapter-03',
        chapterTitle: '第三章 天台交锋',
        sceneId: 'scene-04',
        sceneTitle: '转折与余波',
        sceneSummary: '两人分头逃亡。',
        sceneIndex: 2,
        totalScenesInChapter: 4,
        cast: <SceneCastCandidate>[
          SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '记者'),
          SceneCastCandidate(characterId: 'shendu', name: '沈渡', role: '线人'),
        ],
        metadata: const <String, Object?>{
          'continuityLedger': <Object?>[
            <String, Object?>{
              'entityId': 'evidence-drive',
              'aliases': <String>['U盘', '存储卡'],
              'holder': '柳溪',
              'status': 'held',
              'sourceSceneId': 'scene-03',
            },
          ],
        },
      );

      // In the real artifact scene-03 ends with the evidence in 柳溪's hand,
      // while the next scene has 沈渡 produce it from his own inner pocket.
      const prose =
          '沈渡从贴身内袋取出存储卡，反手拍进柳溪掌心。'
          '「你带东西走，我引开他们。」';
      final violations = sceneHardGateViolations(
        brief: brief,
        proseText: prose,
      );
      final violationText = violations.map((item) => item.text).join('\n');

      expect(
        violationText,
        allOf(contains('evidence-drive'), contains('持有')),
        reason:
            'Aliases may normalize a prop name, but cannot invent a transfer.',
      );
    },
  );

  group('deterministic repetition audit', () {
    test('detects Chinese self repetition within one sentence', () {
      final report = AiClicheDetector().detect(
        '雨水顺着桌角汇成一道细流，水痕蜿蜒如线，蜿蜒出几寸便被木板吸干。',
      );

      expect(
        report.findingsOf(AiClicheKind.selfRepeat),
        contains(
          isA<AiClicheFinding>().having(
            (item) => item.matched,
            'matched',
            contains('蜿蜒'),
          ),
        ),
      );
    });

    test('detects a repeated action template across ordered scenes', () {
      final report = AiClicheDetector().detectAcrossScenes(const {
        'chapter-01/scene-03': '她压低声音，目光笔直地钉住沈渡。',
        'chapter-02/scene-03': '他把声音压得极低，目光死死钉在柳溪脸上。',
        'chapter-03/scene-04': '她的声音被风撕得发颤，目光仍钉在他脸上。',
      });

      expect(
        report.findingsOf(AiClicheKind.crossSceneTemplate),
        contains(
          isA<AiClicheFinding>()
              .having((item) => item.matched, 'matched', contains('目光'))
              .having(
                (item) => item.context,
                'context',
                allOf(
                  contains('chapter-01/scene-03'),
                  contains('chapter-03/scene-04'),
                ),
              ),
        ),
      );
    });
  });

  test('quality report exposes the 95 gate and preserves every replan', () {
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '最终版本通过。',
      rawText: '决定：PASS\n原因：最终版本通过。',
    );
    final reviewAttempts = <SceneReviewAttempt>[
      SceneReviewAttempt(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.preliminary,
        decision: SceneReviewDecision.replanScene,
        reason: '正文未约定潜入时间，核心剧情功能缺失。',
      ),
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 1,
        phase: SceneReviewPhase.preliminary,
        decision: SceneReviewDecision.replanScene,
        reason: '九点与丑时冲突，双方尚未达成共识。',
      ),
      SceneReviewAttempt(
        round: 3,
        proseAttempt: 1,
        phase: SceneReviewPhase.finalCouncil,
        decision: SceneReviewDecision.pass,
        reason: '最终版本通过。',
      ),
    ];
    final output = SceneRuntimeOutput(
      brief: SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章 雨夜码头',
        sceneId: 'scene-04',
        sceneTitle: '封港前的离场',
        sceneSummary: '锁定潜入约定。',
      ),
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: '锁定潜入约定。'),
      roleOutputs: const [],
      prose: const SceneProseDraft(text: '「丑时见。」两人定下约定。', attempt: 1),
      review: const SceneReviewResult(
        judge: pass,
        consistency: pass,
        decision: SceneReviewDecision.pass,
      ),
      reviewAttempts: reviewAttempts,
      proseAttempts: 1,
      softFailureCount: 0,
      qualityScore: const SceneQualityScore(
        overall: 94,
        prose: 96,
        coherence: 95,
        character: 95,
        completeness: 95,
        summary: '最终 council 通过，但未达到项目综合门槛。',
      ),
    );

    final scene =
        ((jsonDecode(SceneQualityReporter.toJson([output])) as Map)['scenes']
                    as List)
                .single
            as Map;
    final qualityGate = scene['qualityGate'] as Map;
    expect(qualityGate['passed'], isFalse);
    expect(qualityGate['overallMinimum'], 95);
    expect(qualityGate['criticalMinimum'], 90);

    final history = scene['reviewAttempts'] as List;
    expect(history, hasLength(3));
    expect(history.map((item) => (item as Map)['decision']), [
      'replanScene',
      'replanScene',
      'pass',
    ]);
    expect((history[0] as Map)['reason'], contains('核心剧情功能缺失'));
    expect((history[1] as Map)['reason'], contains('九点与丑时冲突'));
  });
}
