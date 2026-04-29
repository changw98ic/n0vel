import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/perception_projector.dart';
import 'package:novel_writer/features/story_generation/domain/character_cognition_models.dart';

void main() {
  group('SceneEvent', () {
    test('fromJson / toJson round-trip', () {
      final event = SceneEvent(
        id: 'evt-1',
        sceneId: 'scene-A',
        type: 'dialogue',
        content: '你好',
        sequence: 0,
        speakerId: 'char-1',
        presentCharacterIds: ['char-1', 'char-2'],
        targetIds: ['char-2'],
        metadata: {'key': 'value'},
      );
      final json = event.toJson();
      final restored = SceneEvent.fromJson(json);

      expect(restored, equals(event));
    });

    test('lists are unmodifiable', () {
      final event = SceneEvent(
        id: 'e1',
        sceneId: 's1',
        type: 'action',
        content: 'jump',
        sequence: 0,
        presentCharacterIds: ['a', 'b'],
      );
      expect(() => event.presentCharacterIds.add('c'), throwsA(anything));
    });
  });

  group('PerceptionProjector', () {
    late PerceptionProjector projector;

    setUp(() {
      projector = PerceptionProjector();
    });

    test('empty events list produces empty atoms list', () {
      final result = projector.project(
        events: const [],
        activeCharacterIds: ['char-1'],
      );
      expect(result, isEmpty);
    });

    test('present character receives perceivedEvent from dialogue', () {
      final events = [
        SceneEvent(
          id: 'evt-1',
          sceneId: 'scene-A',
          type: 'dialogue',
          content: '今天天气不错',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      // Bob should get a perceivedEvent atom
      final bobAtoms =
          atoms.where((a) => a.characterId == 'bob').toList();
      expect(bobAtoms.length, 1);
      expect(bobAtoms.first.kind, CognitionKind.perceivedEvent);
      expect(bobAtoms.first.content, contains('alice'));
      expect(bobAtoms.first.content, contains('今天天气不错'));
      expect(bobAtoms.first.sourceEventIds, ['evt-1']);
    });

    test('present character receives perceivedEvent from action', () {
      final events = [
        SceneEvent(
          id: 'evt-2',
          sceneId: 'scene-A',
          type: 'action',
          content: '猛地推开门',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      final bobAtoms =
          atoms.where((a) => a.characterId == 'bob').toList();
      expect(bobAtoms.length, 1);
      expect(bobAtoms.first.kind, CognitionKind.perceivedEvent);
      expect(bobAtoms.first.content, contains('我观察到'));
      expect(bobAtoms.first.content, contains('猛地推开门'));
    });

    test('absent character has NO atoms generated (privacy constraint)', () {
      final events = [
        SceneEvent(
          id: 'evt-3',
          sceneId: 'scene-A',
          type: 'dialogue',
          content: '这是秘密对话',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob', 'charlie'],
      );

      // charlie is NOT in presentCharacterIds, must have zero atoms
      final charlieAtoms =
          atoms.where((a) => a.characterId == 'charlie').toList();
      expect(charlieAtoms, isEmpty);
    });

    test('speaker gets selfState atom for their own dialogue', () {
      final events = [
        SceneEvent(
          id: 'evt-4',
          sceneId: 'scene-A',
          type: 'dialogue',
          content: '我决定出发',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      final aliceAtoms =
          atoms.where((a) => a.characterId == 'alice').toList();
      expect(aliceAtoms.length, 1);
      expect(aliceAtoms.first.kind, CognitionKind.selfState);
      expect(aliceAtoms.first.content, contains('我说'));
      expect(aliceAtoms.first.content, contains('我决定出发'));
    });

    test('internal events only generate atoms for the subject', () {
      final events = [
        SceneEvent(
          id: 'evt-5',
          sceneId: 'scene-A',
          type: 'internal',
          content: '内心隐隐不安',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      // Only alice gets an atom
      expect(atoms.length, 1);
      expect(atoms.first.characterId, 'alice');
      expect(atoms.first.kind, CognitionKind.selfState);
      expect(atoms.first.content, contains('内心独白'));

      // Bob gets nothing from an internal event
      final bobAtoms =
          atoms.where((a) => a.characterId == 'bob').toList();
      expect(bobAtoms, isEmpty);
    });

    test('event ordering preserved in atom sequence', () {
      final events = [
        SceneEvent(
          id: 'evt-a',
          sceneId: 'scene-A',
          type: 'dialogue',
          content: '第一句话',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice'],
        ),
        SceneEvent(
          id: 'evt-b',
          sceneId: 'scene-A',
          type: 'dialogue',
          content: '第二句话',
          sequence: 1,
          speakerId: 'alice',
          presentCharacterIds: ['alice'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice'],
      );

      expect(atoms.length, 2);
      // First event's atom has lower sequence than second
      expect(atoms[0].sequence, lessThan(atoms[1].sequence));
      expect(atoms[0].content, contains('第一句话'));
      expect(atoms[1].content, contains('第二句话'));
    });

    test('multiple events produce correctly ordered atoms', () {
      final events = [
        SceneEvent(
          id: 'e1',
          sceneId: 's1',
          type: 'description',
          content: '夜色笼罩大地',
          sequence: 0,
          presentCharacterIds: ['alice', 'bob'],
        ),
        SceneEvent(
          id: 'e2',
          sceneId: 's1',
          type: 'dialogue',
          content: '走吧',
          sequence: 1,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
        ),
        SceneEvent(
          id: 'e3',
          sceneId: 's1',
          type: 'action',
          content: '拔剑出鞘',
          sequence: 2,
          speakerId: 'bob',
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      // description: 2 atoms (alice, bob)
      // dialogue: alice(selfState) + bob(perceivedEvent) = 2 atoms
      // action: alice(perceivedEvent) + bob(perceivedEvent) = 2 atoms
      // Total: 6
      expect(atoms.length, 6);

      // Verify strict ordering: every atom's sequence is >= previous
      for (var i = 1; i < atoms.length; i++) {
        expect(
          atoms[i].sequence,
          greaterThanOrEqualTo(atoms[i - 1].sequence),
          reason: 'Atom at index $i has sequence ${atoms[i].sequence} '
              '< previous ${atoms[i - 1].sequence}',
        );
      }
    });

    test('description event creates perceivedEvent for all present', () {
      final events = [
        SceneEvent(
          id: 'e-desc',
          sceneId: 's1',
          type: 'description',
          content: '远处的山峦隐入薄雾',
          sequence: 0,
          presentCharacterIds: ['alice', 'bob', 'carol'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob', 'carol'],
      );

      expect(atoms.length, 3);
      for (final atom in atoms) {
        expect(atom.kind, CognitionKind.perceivedEvent);
        expect(atom.content, contains('场景描述'));
      }

      final ids = atoms.map((a) => a.characterId).toSet();
      expect(ids, containsAll(['alice', 'bob', 'carol']));
    });

    test('transition event creates perceivedEvent for all present', () {
      final events = [
        SceneEvent(
          id: 'e-trans',
          sceneId: 's1',
          type: 'transition',
          content: '三天后',
          sequence: 0,
          presentCharacterIds: ['alice'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice'],
      );

      expect(atoms.length, 1);
      expect(atoms.first.kind, CognitionKind.perceivedEvent);
      expect(atoms.first.content, contains('场景描述'));
    });

    test('action targeted at character marks content differently', () {
      final events = [
        SceneEvent(
          id: 'e-hit',
          sceneId: 's1',
          type: 'action',
          content: '一拳打在脸上',
          sequence: 0,
          speakerId: 'alice',
          presentCharacterIds: ['alice', 'bob'],
          targetIds: ['bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      final bobAtoms =
          atoms.where((a) => a.characterId == 'bob').toList();
      expect(bobAtoms.length, 1);
      // Bob is a target, content uses first-person "我经历了"
      expect(bobAtoms.first.content, contains('我经历了'));

      final aliceAtoms =
          atoms.where((a) => a.characterId == 'alice').toList();
      expect(aliceAtoms.length, 1);
      // Alice is an observer, content uses "我观察到"
      expect(aliceAtoms.first.content, contains('我观察到'));
    });

    test('internal event for absent subject produces no atoms', () {
      final events = [
        SceneEvent(
          id: 'e-absent',
          sceneId: 's1',
          type: 'internal',
          content: '暗中盘算',
          sequence: 0,
          speakerId: 'charlie',
          presentCharacterIds: ['alice', 'bob'], // charlie NOT present
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob', 'charlie'],
      );

      expect(atoms, isEmpty);
    });

    test('dialogue without speaker produces perceivedEvent for all present',
        () {
      final events = [
        SceneEvent(
          id: 'e-nospeaker',
          sceneId: 's1',
          type: 'dialogue',
          content: '远处的钟声响起',
          sequence: 0,
          presentCharacterIds: ['alice', 'bob'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice', 'bob'],
      );

      // No speakerId -> all present get perceivedEvent (narrator voice)
      expect(atoms.length, 2);
      for (final atom in atoms) {
        expect(atom.kind, CognitionKind.perceivedEvent);
      }
    });

    test('projectId is propagated to atoms', () {
      final events = [
        SceneEvent(
          id: 'e1',
          sceneId: 's1',
          type: 'description',
          content: '测试',
          sequence: 0,
          presentCharacterIds: ['alice'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice'],
        projectId: 'proj-42',
      );

      expect(atoms.first.projectId, 'proj-42');
    });

    test('result list is unmodifiable', () {
      final events = [
        SceneEvent(
          id: 'e1',
          sceneId: 's1',
          type: 'description',
          content: 'test',
          sequence: 0,
          presentCharacterIds: ['alice'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['alice'],
      );

      expect(() => (atoms as List).add(atoms.first), throwsA(anything));
    });

    test('sceneId is correctly set on all atoms', () {
      final events = [
        SceneEvent(
          id: 'e1',
          sceneId: 'scene-99',
          type: 'dialogue',
          content: 'hello',
          sequence: 0,
          speakerId: 'a',
          presentCharacterIds: ['a', 'b'],
        ),
      ];

      final atoms = projector.project(
        events: events,
        activeCharacterIds: ['a', 'b'],
      );

      for (final atom in atoms) {
        expect(atom.sceneId, 'scene-99');
      }
    });
  });
}
