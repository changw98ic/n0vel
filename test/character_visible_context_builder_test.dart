import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_builder.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('CharacterVisibleContextBuilder', () {
    const builder = CharacterVisibleContextBuilder();

    test(
      'private briefing surfaces director conflict and constraints before character notes',
      () {
        final brief = SceneBrief(
          chapterId: 'ch02',
          chapterTitle: '第二章',
          sceneId: 's01',
          sceneTitle: '维修通道',
          sceneSummary: '严泊在维修通道中被逼入死角。',
        );
        final member = ResolvedSceneCastMember(
          characterId: 'yanbo',
          name: '严泊',
          role: '逃亡者',
          contributions: [SceneCastContribution.action],
        );
        final director = SceneDirectorOutput(
          text: '',
          plan: SceneDirectorPlan(
            target: '严泊选择维修通道出口',
            conflict: '两条路线的互相施压——前门被堵死',
            progression: '严泊被迫向维修竖井撤退',
            constraints: '只能从维护竖井撤离，前门已被封死',
            characterNotes: [
              DirectorCharacterNote(
                characterId: 'yanbo',
                name: '严泊',
                motivation: '活下来',
                emotionalArc: '从犹豫到决绝',
                keyAction: '跳入竖井',
              ),
            ],
          ),
        );

        final context = builder.build(
          brief: brief,
          member: member,
          director: director,
          publicSceneState: '维修通道内气氛紧张。',
          transcript: [],
        );

        // Conflict and constraints must appear in the private briefing.
        expect(context.privateBriefing, contains('两条路线的互相施压'));
        expect(context.privateBriefing, contains('只能从维护竖井撤离'));

        // Conflict/constraints must appear BEFORE softer character notes.
        final conflictIndex = context.privateBriefing.indexOf('两条路线的互相施压');
        final motivationIndex = context.privateBriefing.indexOf('动机=');
        expect(conflictIndex, greaterThanOrEqualTo(0));
        expect(motivationIndex, greaterThanOrEqualTo(0));
        expect(
          conflictIndex,
          lessThan(motivationIndex),
          reason:
              'Director conflict should precede character motivation in briefing',
        );
      },
    );

    test('private briefing is unchanged when director plan is null', () {
      final brief = SceneBrief(
        chapterId: 'ch02',
        chapterTitle: '第二章',
        sceneId: 's01',
        sceneTitle: '维修通道',
        sceneSummary: '严泊在维修通道中。',
      );
      final member = ResolvedSceneCastMember(
        characterId: 'yanbo',
        name: '严泊',
        role: '逃亡者',
        contributions: [SceneCastContribution.action],
      );
      final director = SceneDirectorOutput(text: '原始导演文本');

      final context = builder.build(
        brief: brief,
        member: member,
        director: director,
        publicSceneState: '维修通道内气氛紧张。',
        transcript: [],
      );

      expect(context.privateBriefing, isNot(contains('冲突')));
      expect(context.privateBriefing, contains('逃亡者'));
    });
  });
}
