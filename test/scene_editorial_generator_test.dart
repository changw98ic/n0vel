import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_editorial_generator.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';

void main() {
  group('SceneEditorialGenerator prompt building', () {
    // These tests verify that buildUserPrompt injects scene-position
    // warnings. The method does not exist yet — these tests are
    // intentionally failing (compile error) to prove the gap.

    test('first scene prompt contains opening hook warning', () {
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '消失的工人',
        sceneId: 'ch-01-sc-01',
        sceneTitle: '深夜警报',
        sceneSummary: '工厂深夜响起警报',
        sceneIndex: 0,
        totalScenesInChapter: 3,
        targetLength: 500,
      );

      final prompt = SceneEditorialGenerator.buildUserPrompt(
        brief: brief,
        attempt: 1,
      );

      expect(prompt, contains('本章首个场景'));
      expect(prompt, contains('悬念'));
      expect(prompt, contains('最终交稿机械自检'));
      expect(prompt, contains('至少35%'));
      expect(prompt, contains('175个中文对白字'));
      expect(prompt, contains('至少8个'));
      expect(prompt, contains('第1个场景'));
      expect(prompt, contains('共3个'));
    });

    test('last scene prompt contains ending hook warning', () {
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '消失的工人',
        sceneId: 'ch-01-sc-03',
        sceneTitle: '发现真相',
        sceneSummary: '主角发现了真相',
        sceneIndex: 2,
        totalScenesInChapter: 3,
        targetLength: 500,
      );

      final prompt = SceneEditorialGenerator.buildUserPrompt(
        brief: brief,
        attempt: 1,
      );

      expect(prompt, contains('本章最后场景'));
      expect(prompt, contains('悬念'));
      expect(prompt, contains('第3个场景'));
      expect(prompt, contains('共3个'));
    });

    test('normal scene prompt contains position but no hook warnings', () {
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '消失的工人',
        sceneId: 'ch-01-sc-02',
        sceneTitle: '调查线索',
        sceneSummary: '主角开始调查',
        sceneIndex: 1,
        totalScenesInChapter: 3,
        targetLength: 500,
      );

      final prompt = SceneEditorialGenerator.buildUserPrompt(
        brief: brief,
        attempt: 1,
      );

      expect(prompt, contains('第2个场景'));
      expect(prompt, contains('共3个'));
      expect(prompt, isNot(contains('首个场景')));
      expect(prompt, isNot(contains('最后场景')));
    });

    test('scene position is included even for single-scene chapter', () {
      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '消失的工人',
        sceneId: 'ch-01-sc-01',
        sceneTitle: '深夜警报',
        sceneSummary: '工厂深夜响起警报',
        sceneIndex: 0,
        totalScenesInChapter: 1,
        targetLength: 800,
      );

      final prompt = SceneEditorialGenerator.buildUserPrompt(
        brief: brief,
        attempt: 1,
      );

      // Single scene is both first AND last
      expect(prompt, contains('首个场景'));
      expect(prompt, contains('最后场景'));
    });

    test(
      'revision constraint turns quoted rejected evidence into a ban list',
      () {
        final directive =
            SceneEditorialGenerator.buildRejectedEvidenceDirective(
              '关键剧情道具“打印机/纸带”违反物理规则，无法在“断电”期间主动打印。',
            );

        expect(directive, contains('已证伪元素不得复用'));
        expect(directive, contains('打印机/纸带'));
        expect(directive, contains('断电'));
      },
    );
  });
}
