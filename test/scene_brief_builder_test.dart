import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_brief_builder.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';

void main() {
  group('SceneBriefBuilder', () {
    group('fromScenePlan', () {
      late ScenePlan plan;
      late ChapterPlan chapterPlan;

      setUp(() {
        chapterPlan = ChapterPlan(
          id: 'ch-1',
          novelPlanId: 'novel-1',
          title: 'The Beginning',
          summary: 'First chapter',
        );

        plan = ScenePlan(
          id: 'scene-1',
          chapterPlanId: 'ch-1',
          title: 'The Arrival',
          summary: 'A stranger arrives at the village.',
          targetLength: 800,
          povCharacterId: 'char-1',
          castIds: ['char-1', 'char-2'],
          worldNodeIds: ['loc-village', 'obj-sword'],
          beats: [
            BeatPlan(
              id: 'beat-1',
              scenePlanId: 'scene-1',
              sequence: 1,
              beatType: 'action',
              content: 'Stranger enters the gate',
            ),
            BeatPlan(
              id: 'beat-2',
              scenePlanId: 'scene-1',
              sequence: 2,
              beatType: 'dialogue',
              content: 'Village elder speaks',
            ),
            BeatPlan(
              id: 'beat-3',
              scenePlanId: 'scene-1',
              sequence: 3,
              beatType: 'reflection',
              content: 'Stranger observes the town',
            ),
          ],
          narrativeArc: 'arrival',
          metadata: {'key1': 'value1'},
        );
      });

      test('maps plan fields to SceneBrief correctly', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
          projectId: 'proj-1',
        );

        expect(brief.projectId, 'proj-1');
        expect(brief.chapterId, 'ch-1');
        expect(brief.chapterTitle, 'The Beginning');
        expect(brief.sceneId, 'scene-1');
        expect(brief.sceneTitle, 'The Arrival');
        expect(brief.sceneSummary, 'A stranger arrives at the village.');
        expect(brief.targetLength, 800);
        expect(brief.worldNodeIds, ['loc-village', 'obj-sword']);
      });

      test('extracts target beat from first beat plan', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(brief.targetBeat, 'Stranger enters the gate');
      });

      test('leaves cast empty for later population', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(brief.cast, isEmpty);
      });

      test('leaves narrativeArc null for later population', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(brief.narrativeArc, isNull);
      });

      test('includes _planId in metadata', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(brief.metadata['_planId'], 'scene-1');
      });

      test('includes _beatSummary from first 3 beats', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(
          brief.metadata['_beatSummary'],
          'Stranger enters the gate / Village elder speaks / Stranger observes the town',
        );
      });

      test('preserves original plan metadata', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(brief.metadata['key1'], 'value1');
      });

      test('includes _transitionId when beat has transition target', () {
        final planWithTransition = ScenePlan(
          id: 'scene-t',
          chapterPlanId: 'ch-1',
          title: 'Transition Scene',
          summary: 'A transition occurs.',
          povCharacterId: 'char-1',
          beats: [
            BeatPlan(
              id: 'beat-t1',
              scenePlanId: 'scene-t',
              sequence: 1,
              beatType: 'transition',
              content: 'Time passes',
              transitionTarget: StateTransitionTarget(
                id: 'trans-1',
                fromSceneId: 'scene-t',
                toSceneId: 'scene-2',
                kind: 'time_skip',
              ),
            ),
          ],
        );

        final brief = SceneBriefBuilder.fromScenePlan(
          plan: planWithTransition,
          chapterPlan: chapterPlan,
        );

        expect(brief.metadata['_transitionId'], 'trans-1');
      });

      test('omits _transitionId when no beats have transitions', () {
        final brief = SceneBriefBuilder.fromScenePlan(
          plan: plan,
          chapterPlan: chapterPlan,
        );

        expect(brief.metadata.containsKey('_transitionId'), isFalse);
      });

      test('handles empty beats list gracefully', () {
        final emptyBeatsPlan = ScenePlan(
          id: 'scene-empty',
          chapterPlanId: 'ch-1',
          title: 'Empty Beats',
          summary: 'No beats defined.',
          povCharacterId: 'char-1',
          beats: [],
          narrativeArc: 'some-arc',
        );

        final brief = SceneBriefBuilder.fromScenePlan(
          plan: emptyBeatsPlan,
          chapterPlan: chapterPlan,
        );

        expect(brief.targetBeat, isEmpty);
        expect(brief.metadata['_beatSummary'], isEmpty);
        expect(brief.metadata['_planId'], 'scene-empty');
      });

      test('handles beats fewer than 3 for beatSummary', () {
        final oneBeatPlan = ScenePlan(
          id: 'scene-one',
          chapterPlanId: 'ch-1',
          title: 'One Beat',
          summary: 'Only one beat.',
          povCharacterId: 'char-1',
          beats: [
            BeatPlan(
              id: 'beat-solo',
              scenePlanId: 'scene-one',
              sequence: 1,
              beatType: 'action',
              content: 'Solo action',
            ),
          ],
        );

        final brief = SceneBriefBuilder.fromScenePlan(
          plan: oneBeatPlan,
          chapterPlan: chapterPlan,
        );

        expect(brief.metadata['_beatSummary'], 'Solo action');
      });

      test('sorts beats by sequence before extracting', () {
        final unsortedPlan = ScenePlan(
          id: 'scene-unsorted',
          chapterPlanId: 'ch-1',
          title: 'Unsorted Beats',
          summary: 'Beats are out of order.',
          povCharacterId: 'char-1',
          beats: [
            BeatPlan(
              id: 'beat-3',
              scenePlanId: 'scene-unsorted',
              sequence: 3,
              beatType: 'reflection',
              content: 'Third beat',
            ),
            BeatPlan(
              id: 'beat-1',
              scenePlanId: 'scene-unsorted',
              sequence: 1,
              beatType: 'action',
              content: 'First beat',
            ),
            BeatPlan(
              id: 'beat-2',
              scenePlanId: 'scene-unsorted',
              sequence: 2,
              beatType: 'dialogue',
              content: 'Second beat',
            ),
          ],
        );

        final brief = SceneBriefBuilder.fromScenePlan(
          plan: unsortedPlan,
          chapterPlan: chapterPlan,
        );

        expect(brief.targetBeat, 'First beat');
        expect(
          brief.metadata['_beatSummary'],
          'First beat / Second beat / Third beat',
        );
      });
    });

    group('fromLegacyOutline', () {
      test('maps legacy fields to SceneBrief correctly', () {
        final brief = SceneBriefBuilder.fromLegacyOutline(
          chapterId: 'ch-legacy',
          chapterTitle: 'Legacy Chapter',
          sceneId: 'scene-legacy',
          sceneTitle: 'Legacy Scene',
          sceneSummary: 'A legacy outline summary.',
          projectId: 'proj-legacy',
          worldNodeIds: ['node-1', 'node-2'],
          targetBeat: 'Beat description',
        );

        expect(brief.projectId, 'proj-legacy');
        expect(brief.chapterId, 'ch-legacy');
        expect(brief.chapterTitle, 'Legacy Chapter');
        expect(brief.sceneId, 'scene-legacy');
        expect(brief.sceneTitle, 'Legacy Scene');
        expect(brief.sceneSummary, 'A legacy outline summary.');
        expect(brief.worldNodeIds, ['node-1', 'node-2']);
        expect(brief.targetBeat, 'Beat description');
      });

      test('uses default values for optional parameters', () {
        final brief = SceneBriefBuilder.fromLegacyOutline(
          chapterId: 'ch-2',
          chapterTitle: 'Ch2',
          sceneId: 'sc-2',
          sceneTitle: 'Sc2',
          sceneSummary: 'Summary',
        );

        expect(brief.projectId, isNull);
        expect(brief.worldNodeIds, isEmpty);
        expect(brief.targetBeat, isEmpty);
        expect(brief.targetLength, 400); // SceneBrief default
      });

      test('produces empty cast and null narrative arc', () {
        final brief = SceneBriefBuilder.fromLegacyOutline(
          chapterId: 'ch-x',
          chapterTitle: 'X',
          sceneId: 'sc-x',
          sceneTitle: 'X',
          sceneSummary: 'X',
        );

        expect(brief.cast, isEmpty);
        expect(brief.narrativeArc, isNull);
      });
    });

    group('build', () {
      late ScenePlan plan;
      late ChapterPlan chapterPlan;

      setUp(() {
        chapterPlan = ChapterPlan(
          id: 'ch-build',
          novelPlanId: 'novel-build',
          title: 'Build Chapter',
          summary: 'Build test',
        );

        plan = ScenePlan(
          id: 'scene-build',
          chapterPlanId: 'ch-build',
          title: 'Build Scene',
          summary: 'Build summary.',
          povCharacterId: 'char-1',
          beats: [
            BeatPlan(
              id: 'beat-b1',
              scenePlanId: 'scene-build',
              sequence: 1,
              beatType: 'action',
              content: 'Build beat',
            ),
          ],
        );
      });

      test('prefers ScenePlan when both plan and chapterPlan provided', () {
        final brief = SceneBriefBuilder.build(
          plan: plan,
          chapterPlan: chapterPlan,
          projectId: 'proj-build',
          legacyChapterId: 'legacy-ch',
          legacyChapterTitle: 'Legacy Ch',
          legacySceneId: 'legacy-sc',
          legacySceneTitle: 'Legacy Sc',
          legacySceneSummary: 'Legacy summary',
        );

        expect(brief.sceneId, 'scene-build');
        expect(brief.sceneTitle, 'Build Scene');
        expect(brief.sceneSummary, 'Build summary.');
        expect(brief.chapterId, 'ch-build');
        expect(brief.chapterTitle, 'Build Chapter');
        expect(brief.projectId, 'proj-build');
      });

      test('falls back to legacy when plan is null', () {
        final brief = SceneBriefBuilder.build(
          plan: null,
          chapterPlan: chapterPlan,
          legacyChapterId: 'legacy-ch',
          legacyChapterTitle: 'Legacy Chapter',
          legacySceneId: 'legacy-sc',
          legacySceneTitle: 'Legacy Scene',
          legacySceneSummary: 'Legacy summary.',
          legacyWorldNodeIds: ['wn-1'],
          legacyTargetBeat: 'Legacy beat',
        );

        expect(brief.sceneId, 'legacy-sc');
        expect(brief.sceneTitle, 'Legacy Scene');
        expect(brief.sceneSummary, 'Legacy summary.');
        expect(brief.chapterId, 'legacy-ch');
        expect(brief.chapterTitle, 'Legacy Chapter');
        expect(brief.worldNodeIds, ['wn-1']);
        expect(brief.targetBeat, 'Legacy beat');
      });

      test('falls back to legacy when chapterPlan is null', () {
        final brief = SceneBriefBuilder.build(
          plan: plan,
          chapterPlan: null,
          legacyChapterId: 'legacy-ch',
          legacyChapterTitle: 'Legacy Chapter',
          legacySceneId: 'legacy-sc',
          legacySceneTitle: 'Legacy Scene',
          legacySceneSummary: 'Legacy summary.',
        );

        expect(brief.sceneId, 'legacy-sc');
        expect(brief.sceneTitle, 'Legacy Scene');
        expect(brief.chapterId, 'legacy-ch');
      });

      test('falls back to legacy when both plan and chapterPlan are null', () {
        final brief = SceneBriefBuilder.build(
          legacyChapterId: 'ch-l',
          legacyChapterTitle: 'Late Ch',
          legacySceneId: 'sc-l',
          legacySceneTitle: 'Late Sc',
          legacySceneSummary: 'Late sum.',
          projectId: 'proj-late',
        );

        expect(brief.sceneId, 'sc-l');
        expect(brief.sceneTitle, 'Late Sc');
        expect(brief.projectId, 'proj-late');
      });

      test('uses empty strings for missing legacy args', () {
        final brief = SceneBriefBuilder.build();

        expect(brief.chapterId, isEmpty);
        expect(brief.chapterTitle, isEmpty);
        expect(brief.sceneId, isEmpty);
        expect(brief.sceneTitle, isEmpty);
        expect(brief.sceneSummary, isEmpty);
        expect(brief.projectId, isNull);
      });
    });
  });
}
