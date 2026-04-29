import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/character_cognition_models.dart';
import 'package:novel_writer/features/story_generation/data/character_cognition_snapshot_builder.dart';

void main() {
  group('CharacterCognitionSnapshotBuilder.buildSnapshot', () {
    const characterId = 'character-liuxi';
    const name = '柳溪';
    const role = '调查记者';

    test('empty atoms list produces snapshot with character info but empty sections', () {
      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: const [],
      );

      expect(snapshot.characterId, characterId);
      expect(snapshot.name, name);
      expect(snapshot.role, role);
      expect(snapshot.beliefs, isEmpty);
      expect(snapshot.relationships, isEmpty);
      expect(snapshot.socialPositions, isEmpty);
      expect(snapshot.presentation.characterId, characterId);
      expect(snapshot.presentation.displayedEmotion, isEmpty);
    });

    test('perceivedEvent atoms produce belief entries with correct confidence', () {
      final atoms = [
        CharacterCognitionAtom.perceivedEvent(
          id: 'atom-1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '柳溪看到岳人把调度卡塞进袖口。',
          sourceCharacterIds: ['character-yueren'],
          certainty: 0.9,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.length, 1);
      final belief = snapshot.beliefs.first;
      expect(belief.subjectId, characterId);
      expect(belief.targetId, 'character-yueren');
      expect(belief.claim, '柳溪看到岳人把调度卡塞进袖口。');
      expect(belief.confidence, closeTo(0.9, 1e-9));
      expect(belief.source, 'atom-1');
    });

    test('reportedEvent atoms produce belief entries', () {
      final atoms = [
        CharacterCognitionAtom.reportedEvent(
          id: 'atom-r1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '岳人说门禁在零点重置。',
          sourceCharacterIds: ['character-yueren'],
          certainty: 0.7,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.length, 1);
      expect(snapshot.beliefs.first.claim, '岳人说门禁在零点重置。');
      expect(snapshot.beliefs.first.confidence, closeTo(0.7, 1e-9));
      expect(snapshot.beliefs.first.source, 'atom-r1');
    });

    test('acceptedBelief and inference atoms produce belief entries', () {
      final atoms = [
        CharacterCognitionAtom.acceptedBelief(
          id: 'atom-b1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '柳溪相信岳人掌握旧港门禁记录。',
          sourceCharacterIds: ['character-yueren'],
          certainty: 0.85,
        ),
        CharacterCognitionAtom.inference(
          id: 'atom-i1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 2,
          content: '柳溪推断岳人绕开了前门。',
          certainty: 0.6,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.length, 2);
      expect(snapshot.beliefs[0].claim, '柳溪相信岳人掌握旧港门禁记录。');
      expect(snapshot.beliefs[0].confidence, closeTo(0.85, 1e-9));
      expect(snapshot.beliefs[1].claim, '柳溪推断岳人绕开了前门。');
      expect(snapshot.beliefs[1].confidence, closeTo(0.6, 1e-9));
    });

    test('suspicion and uncertainty atoms produce beliefs with reduced confidence', () {
      final atoms = [
        CharacterCognitionAtom.suspicion(
          id: 'atom-s1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '柳溪怀疑傅行舟安排了误导。',
          sourceCharacterIds: ['character-fuxingzhou'],
          certainty: 0.8,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.length, 1);
      // Suspicion confidence should be halved
      expect(snapshot.beliefs.first.confidence, closeTo(0.4, 1e-9));
      expect(snapshot.beliefs.first.source, 'atom-s1');
    });

    test('relationshipView atoms produce relationship slices', () {
      final atoms = [
        CharacterCognitionAtom(
          id: 'atom-rel1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          kind: CognitionKind.relationshipView,
          content: '不信任保全主管',
          sourceCharacterIds: ['character-fuxingzhou'],
          certainty: 0.3,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.relationships.length, 1);
      final rel = snapshot.relationships.first;
      expect(rel.characterId, characterId);
      expect(rel.otherId, 'character-fuxingzhou');
      expect(rel.trust, closeTo(0.3, 1e-9));
      expect(rel.tension, closeTo(0.7, 1e-9));
      expect(rel.notes, '不信任保全主管');
    });

    test('selfState atoms update presentation state', () {
      final atoms = [
        CharacterCognitionAtom.selfState(
          id: 'atom-ss1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '柳溪感到左手发麻。',
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.presentation.characterId, characterId);
      expect(snapshot.presentation.displayedEmotion, '柳溪感到左手发麻。');
    });

    test('goal and intent atoms produce beliefs with kind-prefixed source', () {
      final atoms = [
        CharacterCognitionAtom.goal(
          id: 'atom-g1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '找到调度记录',
          certainty: 1.0,
        ),
        CharacterCognitionAtom.intent(
          id: 'atom-int1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 2,
          content: '今晚潜入码头',
          certainty: 0.9,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.length, 2);
      expect(snapshot.beliefs[0].source, 'goal:atom-g1');
      expect(snapshot.beliefs[0].claim, '找到调度记录');
      expect(snapshot.beliefs[1].source, 'intent:atom-int1');
      expect(snapshot.beliefs[1].claim, '今晚潜入码头');
    });

    test('source trace IDs are preserved in belief source field', () {
      final atoms = [
        CharacterCognitionAtom.acceptedBelief(
          id: 'atom-trace-1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: 'trace test',
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.first.source, 'atom-trace-1');
    });

    test('deterministic ordering by atom sequence', () {
      final atoms = [
        CharacterCognitionAtom.acceptedBelief(
          id: 'atom-late',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 10,
          content: 'later belief',
        ),
        CharacterCognitionAtom.perceivedEvent(
          id: 'atom-early',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: 'early event',
        ),
        CharacterCognitionAtom.inference(
          id: 'atom-mid',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 5,
          content: 'mid inference',
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.length, 3);
      expect(snapshot.beliefs[0].claim, 'early event');
      expect(snapshot.beliefs[1].claim, 'mid inference');
      expect(snapshot.beliefs[2].claim, 'later belief');
    });

    test('presentation and memory atoms are skipped', () {
      final atoms = [
        CharacterCognitionAtom(
          id: 'atom-pres',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          kind: CognitionKind.presentation,
          content: '表面配合',
        ),
        CharacterCognitionAtom(
          id: 'atom-mem',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 2,
          kind: CognitionKind.memory,
          content: '三年前的记忆',
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs, isEmpty);
      expect(snapshot.relationships, isEmpty);
    });

    test('atoms without sourceCharacterIds produce empty targetId in beliefs', () {
      final atoms = [
        CharacterCognitionAtom.perceivedEvent(
          id: 'atom-no-target',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '码头灯闪烁。',
          sourceCharacterIds: [],
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      expect(snapshot.beliefs.first.targetId, isEmpty);
    });

    test('mixed atom kinds populate all snapshot sections correctly', () {
      final atoms = [
        CharacterCognitionAtom.perceivedEvent(
          id: 'atom-1',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 1,
          content: '看到调度卡。',
          sourceCharacterIds: ['character-yueren'],
          certainty: 1.0,
        ),
        CharacterCognitionAtom.suspicion(
          id: 'atom-2',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 2,
          content: '怀疑有内鬼。',
          sourceCharacterIds: ['character-fuxingzhou'],
          certainty: 0.6,
        ),
        CharacterCognitionAtom(
          id: 'atom-3',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 3,
          kind: CognitionKind.relationshipView,
          content: '谨慎合作',
          sourceCharacterIds: ['character-yueren'],
          certainty: 0.7,
        ),
        CharacterCognitionAtom.selfState(
          id: 'atom-4',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 4,
          content: '冷静但急迫',
        ),
        CharacterCognitionAtom.goal(
          id: 'atom-5',
          projectId: 'project-1',
          characterId: characterId,
          sceneId: 'scene-01',
          sequence: 5,
          content: '查清真相',
          certainty: 1.0,
        ),
      ];

      final snapshot = CharacterCognitionSnapshotBuilder.buildSnapshot(
        characterId: characterId,
        name: name,
        role: role,
        atoms: atoms,
      );

      // perceivedEvent + suspicion + goal = 3 beliefs
      // (relationshipView -> relationships, selfState -> presentation)
      expect(snapshot.beliefs.length, 3);
      // 1 relationship
      expect(snapshot.relationships.length, 1);
      // presentation updated
      expect(snapshot.presentation.displayedEmotion, '冷静但急迫');
      // verify beliefs are in sequence order
      expect(snapshot.beliefs[0].source, 'atom-1');
      expect(snapshot.beliefs[1].source, 'atom-2');
      expect(snapshot.beliefs[2].source, 'goal:atom-5');
      // suspicion confidence is halved
      expect(snapshot.beliefs[1].confidence, closeTo(0.3, 1e-9));
    });
  });
}
