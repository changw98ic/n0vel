import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';

void main() {
  // -- Validation helpers -----------------------------------------------------

  group('validatePlanId', () {
    test('accepts alphanumeric IDs', () {
      expect(validatePlanId('scene-01'), isTrue);
      expect(validatePlanId('chapter_02'), isTrue);
      expect(validatePlanId('ABC123'), isTrue);
      expect(validatePlanId('a'), isTrue);
    });

    test('rejects empty strings', () {
      expect(validatePlanId(''), isFalse);
    });

    test('rejects IDs with spaces or special characters', () {
      expect(validatePlanId('scene 01'), isFalse);
      expect(validatePlanId('scene.01'), isFalse);
      expect(validatePlanId('scene@01'), isFalse);
      expect(validatePlanId('scene/01'), isFalse);
    });
  });

  group('isValidBeatSequence', () {
    test('accepts sequential beats starting from 1', () {
      final beats = [
        BeatPlan(
            id: 'b1',
            scenePlanId: 's1',
            sequence: 1,
            beatType: 'action',
            content: 'a'),
        BeatPlan(
            id: 'b2',
            scenePlanId: 's1',
            sequence: 2,
            beatType: 'dialogue',
            content: 'b'),
        BeatPlan(
            id: 'b3',
            scenePlanId: 's1',
            sequence: 3,
            beatType: 'reflection',
            content: 'c'),
      ];
      expect(isValidBeatSequence(beats), isTrue);
    });

    test('accepts empty beat list', () {
      expect(isValidBeatSequence([]), isTrue);
    });

    test('rejects beats with gaps', () {
      final beats = [
        BeatPlan(
            id: 'b1',
            scenePlanId: 's1',
            sequence: 1,
            beatType: 'action',
            content: 'a'),
        BeatPlan(
            id: 'b3',
            scenePlanId: 's1',
            sequence: 3,
            beatType: 'action',
            content: 'c'),
      ];
      expect(isValidBeatSequence(beats), isFalse);
    });

    test('rejects beats with duplicate sequences', () {
      final beats = [
        BeatPlan(
            id: 'b1',
            scenePlanId: 's1',
            sequence: 1,
            beatType: 'action',
            content: 'a'),
        BeatPlan(
            id: 'b2',
            scenePlanId: 's1',
            sequence: 1,
            beatType: 'dialogue',
            content: 'b'),
      ];
      expect(isValidBeatSequence(beats), isFalse);
    });

    test('rejects beats not starting at 1', () {
      final beats = [
        BeatPlan(
            id: 'b2',
            scenePlanId: 's1',
            sequence: 2,
            beatType: 'action',
            content: 'a'),
      ];
      expect(isValidBeatSequence(beats), isFalse);
    });
  });

  group('validateTransitionReferences', () {
    test('returns empty list for valid scene with no transitions', () {
      final plan = ScenePlan(
        id: 'scene-01',
        chapterPlanId: 'ch-01',
        title: 'Test',
        summary: 'Test scene',
        povCharacterId: 'char-1',
      );
      expect(validateTransitionReferences(plan), isEmpty);
    });

    test('reports issues when transition references unknown scene IDs', () {
      final plan = ScenePlan(
        id: 'scene-01',
        chapterPlanId: 'ch-01',
        title: 'Test',
        summary: 'Test scene',
        povCharacterId: 'char-1',
        beats: [
          BeatPlan(
            id: 'beat-01',
            scenePlanId: 'scene-01',
            sequence: 1,
            beatType: 'transition',
            content: 'Time passes',
            transitionTarget: StateTransitionTarget(
              id: 't-01',
              fromSceneId: 'scene-01',
              toSceneId: 'scene-99',
              kind: 'time_skip',
            ),
          ),
        ],
      );
      final issues = validateTransitionReferences(plan);
      // scene-01 is in knownSceneIds, scene-99 is not
      expect(issues, isNotEmpty);
      expect(issues.any((s) => s.contains('scene-99')), isTrue);
    });

    test('accepts transitions that reference sibling scene IDs', () {
      final plan = ScenePlan(
        id: 'scene-01',
        chapterPlanId: 'ch-01',
        title: 'Test',
        summary: 'Test scene',
        povCharacterId: 'char-1',
        metadata: {
          'siblingSceneIds': ['scene-01', 'scene-02'],
        },
        beats: [
          BeatPlan(
            id: 'beat-01',
            scenePlanId: 'scene-01',
            sequence: 1,
            beatType: 'transition',
            content: 'Move to scene 2',
            transitionTarget: StateTransitionTarget(
              id: 't-01',
              fromSceneId: 'scene-01',
              toSceneId: 'scene-02',
              kind: 'exit',
            ),
          ),
        ],
      );
      expect(validateTransitionReferences(plan), isEmpty);
    });
  });

  // -- StateTransitionTarget --------------------------------------------------

  group('StateTransitionTarget', () {
    test('constructs with required fields', () {
      const t = StateTransitionTarget(
        id: 't-1',
        fromSceneId: 'scene-01',
        toSceneId: 'scene-02',
        kind: 'time_skip',
      );
      expect(t.id, 't-1');
      expect(t.fromSceneId, 'scene-01');
      expect(t.toSceneId, 'scene-02');
      expect(t.kind, 'time_skip');
      expect(t.constraints, isEmpty);
    });

    test('serializes and deserializes round-trip', () {
      const original = StateTransitionTarget(
        id: 't-1',
        fromSceneId: 'scene-01',
        toSceneId: 'scene-02',
        kind: 'flashback',
        constraints: {'minHours': 4, 'location': 'harbor'},
      );
      final json = original.toJson();
      final restored = StateTransitionTarget.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson handles empty map with defaults', () {
      final restored = StateTransitionTarget.fromJson({});
      expect(restored.id, '');
      expect(restored.fromSceneId, '');
      expect(restored.toSceneId, '');
      expect(restored.kind, '');
      expect(restored.constraints, isEmpty);
    });

    test('fromJson handles wrong types gracefully', () {
      final restored = StateTransitionTarget.fromJson({
        'id': 123,
        'fromSceneId': null,
        'toSceneId': true,
        'kind': ['a'],
        'constraints': 'not-a-map',
      });
      expect(restored.id, '123');
      expect(restored.fromSceneId, '');
      expect(restored.toSceneId, 'true');
      expect(restored.constraints, isEmpty);
    });

    test('equality and hashCode work', () {
      const a = StateTransitionTarget(
        id: 't-1',
        fromSceneId: 's1',
        toSceneId: 's2',
        kind: 'entry',
      );
      const b = StateTransitionTarget(
        id: 't-1',
        fromSceneId: 's1',
        toSceneId: 's2',
        kind: 'entry',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith preserves unmodified fields', () {
      const original = StateTransitionTarget(
        id: 't-1',
        fromSceneId: 's1',
        toSceneId: 's2',
        kind: 'entry',
        constraints: {'key': 'val'},
      );
      final copied = original.copyWith(kind: 'exit');
      expect(copied.kind, 'exit');
      expect(copied.id, 't-1');
      expect(copied.constraints, {'key': 'val'});
    });
  });

  // -- BeatPlan ---------------------------------------------------------------

  group('BeatPlan', () {
    test('constructs with required fields and defaults', () {
      final beat = BeatPlan(
        id: 'beat-01',
        scenePlanId: 'scene-01',
        sequence: 1,
        beatType: 'action',
        content: 'Character opens the door',
      );
      expect(beat.id, 'beat-01');
      expect(beat.povCharacterId, isNull);
      expect(beat.requiredCognitionIds, isEmpty);
      expect(beat.transitionTarget, isNull);
      expect(() => (beat.requiredCognitionIds as List).add('x'),
          throwsUnsupportedError);
    });

    test('serializes and deserializes round-trip without transition', () {
      final original = BeatPlan(
        id: 'beat-01',
        scenePlanId: 'scene-01',
        sequence: 2,
        beatType: 'dialogue',
        content: '柳溪问岳人旧港记录在哪。',
        povCharacterId: 'char-liuxi',
        requiredCognitionIds: ['cog-01', 'cog-02'],
      );
      final json = original.toJson();
      expect(json.containsKey('transitionTarget'), isFalse);
      final restored = BeatPlan.fromJson(json);
      expect(restored, equals(original));
    });

    test('serializes and deserializes round-trip with transition', () {
      final original = BeatPlan(
        id: 'beat-02',
        scenePlanId: 'scene-01',
        sequence: 3,
        beatType: 'transition',
        content: 'Time skip to next morning',
        transitionTarget: StateTransitionTarget(
          id: 't-01',
          fromSceneId: 'scene-01',
          toSceneId: 'scene-02',
          kind: 'time_skip',
        ),
      );
      final json = original.toJson();
      expect(json.containsKey('transitionTarget'), isTrue);
      final restored = BeatPlan.fromJson(json);
      expect(restored, equals(original));
      expect(restored.transitionTarget?.kind, 'time_skip');
    });

    test('fromJson handles missing fields with safe defaults', () {
      final restored = BeatPlan.fromJson({});
      expect(restored.id, '');
      expect(restored.scenePlanId, '');
      expect(restored.sequence, 0);
      expect(restored.beatType, '');
      expect(restored.content, '');
      expect(restored.povCharacterId, isNull);
      expect(restored.requiredCognitionIds, isEmpty);
      expect(restored.transitionTarget, isNull);
    });

    test('fromJson handles wrong types for sequence', () {
      final restored = BeatPlan.fromJson({
        'id': 'b1',
        'sequence': 'not-a-number',
      });
      expect(restored.sequence, 0);
    });

    test('equality and hashCode work', () {
      final a = BeatPlan(
        id: 'b1',
        scenePlanId: 's1',
        sequence: 1,
        beatType: 'action',
        content: 'test',
        requiredCognitionIds: ['c1'],
      );
      final b = BeatPlan(
        id: 'b1',
        scenePlanId: 's1',
        sequence: 1,
        beatType: 'action',
        content: 'test',
        requiredCognitionIds: ['c1'],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith preserves unmodified fields', () {
      final original = BeatPlan(
        id: 'b1',
        scenePlanId: 's1',
        sequence: 1,
        beatType: 'action',
        content: 'old',
        requiredCognitionIds: ['c1'],
      );
      final copied = original.copyWith(content: 'new');
      expect(copied.content, 'new');
      expect(copied.id, 'b1');
      expect(copied.requiredCognitionIds, ['c1']);
    });
  });

  // -- ScenePlan --------------------------------------------------------------

  group('ScenePlan', () {
    test('constructs with required fields and immutable collections', () {
      final scene = ScenePlan(
        id: 'scene-01',
        chapterPlanId: 'ch-01',
        title: '码头黎明',
        summary: '柳溪在旧港码头等待线索。',
        povCharacterId: 'char-liuxi',
        castIds: ['char-liuxi', 'char-yueren'],
      );
      expect(scene.targetLength, 0);
      expect(scene.narrativeArc, '');
      expect(scene.metadata, isEmpty);
      expect(() => (scene.castIds as List).add('x'), throwsUnsupportedError);
      expect(() => (scene.beats as List).add(BeatPlan(
            id: '',
            scenePlanId: '',
            sequence: 0,
            beatType: '',
            content: '',
          )),
          throwsUnsupportedError);
    });

    test('serializes and deserializes round-trip', () {
      final original = ScenePlan(
        id: 'scene-01',
        chapterPlanId: 'ch-01',
        title: '旧港对峙',
        summary: '柳溪与岳人在码头对峙。',
        targetLength: 3000,
        povCharacterId: 'char-liuxi',
        castIds: ['char-liuxi', 'char-yueren'],
        worldNodeIds: ['world-harbor', 'world-warehouse'],
        beats: [
          BeatPlan(
            id: 'beat-01',
            scenePlanId: 'scene-01',
            sequence: 1,
            beatType: 'action',
            content: '柳溪推开门',
          ),
          BeatPlan(
            id: 'beat-02',
            scenePlanId: 'scene-01',
            sequence: 2,
            beatType: 'dialogue',
            content: '你到底在隐瞒什么？',
          ),
        ],
        narrativeArc: 'tension-rise',
        metadata: {'intensity': 0.8},
      );
      final json = original.toJson();
      final restored = ScenePlan.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson handles missing fields with safe defaults', () {
      final restored = ScenePlan.fromJson({});
      expect(restored.id, '');
      expect(restored.chapterPlanId, '');
      expect(restored.title, '');
      expect(restored.summary, '');
      expect(restored.targetLength, 0);
      expect(restored.povCharacterId, '');
      expect(restored.castIds, isEmpty);
      expect(restored.worldNodeIds, isEmpty);
      expect(restored.beats, isEmpty);
      expect(restored.narrativeArc, '');
      expect(restored.metadata, isEmpty);
    });

    test('fromJson handles malformed types', () {
      final restored = ScenePlan.fromJson({
        'id': 42,
        'targetLength': 'three-thousand',
        'castIds': 'not-a-list',
        'beats': [null, 'string', 123],
        'metadata': 'not-a-map',
      });
      expect(restored.id, '42');
      expect(restored.targetLength, 0);
      expect(restored.castIds, isEmpty);
      expect(restored.beats, isEmpty);
      expect(restored.metadata, isEmpty);
    });

    test('equality and hashCode work', () {
      final a = ScenePlan(
        id: 's1',
        chapterPlanId: 'c1',
        title: 'T',
        summary: 'S',
        povCharacterId: 'p1',
      );
      final b = ScenePlan(
        id: 's1',
        chapterPlanId: 'c1',
        title: 'T',
        summary: 'S',
        povCharacterId: 'p1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith preserves unmodified fields', () {
      final original = ScenePlan(
        id: 's1',
        chapterPlanId: 'c1',
        title: 'Old',
        summary: 'S',
        povCharacterId: 'p1',
        castIds: ['a', 'b'],
      );
      final copied = original.copyWith(title: 'New');
      expect(copied.title, 'New');
      expect(copied.id, 's1');
      expect(copied.castIds, ['a', 'b']);
    });
  });

  // -- ChapterPlan ------------------------------------------------------------

  group('ChapterPlan', () {
    test('constructs with required fields and immutable scenes', () {
      final chapter = ChapterPlan(
        id: 'ch-01',
        novelPlanId: 'plan-01',
        title: '第一章 暗流',
        summary: '柳溪发现旧港的秘密。',
        targetSceneCount: 5,
      );
      expect(chapter.scenes, isEmpty);
      expect(() => (chapter.scenes as List).add(ScenePlan(
            id: '',
            chapterPlanId: '',
            title: '',
            summary: '',
            povCharacterId: '',
          )),
          throwsUnsupportedError);
    });

    test('serializes and deserializes round-trip', () {
      final original = ChapterPlan(
        id: 'ch-01',
        novelPlanId: 'plan-01',
        title: '第一章 暗流',
        summary: '柳溪开始调查旧港。',
        targetSceneCount: 3,
        scenes: [
          ScenePlan(
            id: 'scene-01',
            chapterPlanId: 'ch-01',
            title: '码头黎明',
            summary: '柳溪到达旧港。',
            povCharacterId: 'char-liuxi',
          ),
        ],
      );
      final json = original.toJson();
      final restored = ChapterPlan.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson handles empty map with defaults', () {
      final restored = ChapterPlan.fromJson({});
      expect(restored.id, '');
      expect(restored.novelPlanId, '');
      expect(restored.title, '');
      expect(restored.summary, '');
      expect(restored.targetSceneCount, 0);
      expect(restored.scenes, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      final original = ChapterPlan(
        id: 'ch-01',
        novelPlanId: 'plan-01',
        title: 'Old',
        summary: 'S',
      );
      final copied = original.copyWith(title: 'New');
      expect(copied.title, 'New');
      expect(copied.id, 'ch-01');
      expect(copied.novelPlanId, 'plan-01');
    });
  });

  // -- NovelPlan --------------------------------------------------------------

  group('NovelPlan', () {
    test('constructs with required fields and immutable collections', () {
      final plan = NovelPlan(
        id: 'plan-01',
        projectId: 'proj-01',
        title: '共振世界',
        premise: '一个关于旧港秘密的故事。',
      );
      expect(plan.targetChapterCount, 0);
      expect(plan.chapters, isEmpty);
      expect(plan.metadata, isEmpty);
      expect(() => (plan.chapters as List).add(ChapterPlan(
            id: '',
            novelPlanId: '',
            title: '',
            summary: '',
          )),
          throwsUnsupportedError);
    });

    test('serializes and deserializes full hierarchy round-trip', () {
      final original = NovelPlan(
        id: 'plan-01',
        projectId: 'proj-01',
        title: '共振世界',
        premise: '一个关于旧港秘密的故事。',
        targetChapterCount: 10,
        chapters: [
          ChapterPlan(
            id: 'ch-01',
            novelPlanId: 'plan-01',
            title: '第一章 暗流',
            summary: '柳溪开始调查。',
            targetSceneCount: 3,
            scenes: [
              ScenePlan(
                id: 'scene-01',
                chapterPlanId: 'ch-01',
                title: '码头黎明',
                summary: '柳溪到达旧港码头。',
                targetLength: 2000,
                povCharacterId: 'char-liuxi',
                castIds: ['char-liuxi', 'char-yueren'],
                worldNodeIds: ['world-harbor'],
                beats: [
                  BeatPlan(
                    id: 'beat-01',
                    scenePlanId: 'scene-01',
                    sequence: 1,
                    beatType: 'action',
                    content: '柳溪推开铁门。',
                    povCharacterId: 'char-liuxi',
                    requiredCognitionIds: ['cog-01'],
                  ),
                  BeatPlan(
                    id: 'beat-02',
                    scenePlanId: 'scene-01',
                    sequence: 2,
                    beatType: 'transition',
                    content: '时间跳转到凌晨。',
                    transitionTarget: StateTransitionTarget(
                      id: 't-01',
                      fromSceneId: 'scene-01',
                      toSceneId: 'scene-02',
                      kind: 'time_skip',
                      constraints: {'hours': 3},
                    ),
                  ),
                ],
                narrativeArc: 'opening-tension',
                metadata: {'draft': true},
              ),
            ],
          ),
        ],
        metadata: {'genre': 'thriller', 'version': 2},
      );

      final json = original.toJson();
      final restored = NovelPlan.fromJson(json);
      expect(restored, equals(original));

      // Deep-verify nested structure survived the round trip.
      expect(restored.chapters.length, 1);
      expect(restored.chapters[0].scenes.length, 1);
      expect(restored.chapters[0].scenes[0].beats.length, 2);
      expect(restored.chapters[0].scenes[0].beats[1].transitionTarget?.kind,
          'time_skip');
      expect(restored.metadata['genre'], 'thriller');
    });

    test('fromJson handles empty map with defaults', () {
      final restored = NovelPlan.fromJson({});
      expect(restored.id, '');
      expect(restored.projectId, '');
      expect(restored.title, '');
      expect(restored.premise, '');
      expect(restored.targetChapterCount, 0);
      expect(restored.chapters, isEmpty);
      expect(restored.metadata, isEmpty);
    });

    test('fromJson handles malformed types gracefully', () {
      final restored = NovelPlan.fromJson({
        'id': null,
        'targetChapterCount': 'ten',
        'chapters': 'not-a-list',
        'metadata': [1, 2, 3],
      });
      expect(restored.id, '');
      expect(restored.targetChapterCount, 0);
      expect(restored.chapters, isEmpty);
      expect(restored.metadata, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      final original = NovelPlan(
        id: 'plan-01',
        projectId: 'proj-01',
        title: 'Old',
        premise: 'P',
        metadata: {'k': 'v'},
      );
      final copied = original.copyWith(title: 'New');
      expect(copied.title, 'New');
      expect(copied.id, 'plan-01');
      expect(copied.premise, 'P');
      expect(copied.metadata, {'k': 'v'});
    });

    test('equality and hashCode work for complex plans', () {
      final a = NovelPlan(
        id: 'p1',
        projectId: 'pr1',
        title: 'T',
        premise: 'P',
        metadata: {'x': 1},
      );
      final b = NovelPlan(
        id: 'p1',
        projectId: 'pr1',
        title: 'T',
        premise: 'P',
        metadata: {'x': 1},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
