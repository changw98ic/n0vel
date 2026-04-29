import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/features/story_generation/domain/character_cognition_models.dart';
import 'package:novel_writer/features/story_generation/data/character_cognition_snapshot_builder.dart';

void main() {
  group('CharacterBelief', () {
    test('constructs with required fields', () {
      final belief = CharacterBelief(
        subjectId: 'liuxi',
        targetId: 'yueren',
        claim: '岳人隐瞒了交通调度的真实记录',
      );
      expect(belief.subjectId, 'liuxi');
      expect(belief.targetId, 'yueren');
      expect(belief.claim, '岳人隐瞒了交通调度的真实记录');
      expect(belief.confidence, 1.0);
      expect(belief.source, '');
    });

    test('clamps confidence to 0.0-1.0 range', () {
      expect(
        CharacterBelief(
          subjectId: 'a',
          targetId: 'b',
          claim: 'x',
          confidence: 2.0,
        ).confidence,
        1.0,
      );
      expect(
        CharacterBelief(
          subjectId: 'a',
          targetId: 'b',
          claim: 'x',
          confidence: -0.5,
        ).confidence,
        0.0,
      );
    });

    test('serializes and deserializes round-trip', () {
      final original = CharacterBelief(
        subjectId: 'liuxi',
        targetId: 'fuxingzhou',
        claim: '傅行舟对旧港规则有最终解释权',
        confidence: 0.8,
        source: 'scene-03',
      );
      final json = original.toJson();
      final restored = CharacterBelief.fromJson(json);
      expect(restored, equals(original));
    });

    test('fromJson handles missing and malformed fields', () {
      final restored = CharacterBelief.fromJson({});
      expect(restored.subjectId, '');
      expect(restored.targetId, '');
      expect(restored.claim, '');
      expect(restored.confidence, 1.0);
      expect(restored.source, '');
    });

    test('copyWith preserves unmodified fields', () {
      final original = CharacterBelief(
        subjectId: 'a',
        targetId: 'b',
        claim: 'original',
        confidence: 0.7,
        source: 'test',
      );
      final copied = original.copyWith(claim: 'updated');
      expect(copied.claim, 'updated');
      expect(copied.subjectId, 'a');
      expect(copied.confidence, 0.7);
    });

    test('equality and hashCode work correctly', () {
      final a = CharacterBelief(
        subjectId: 'x',
        targetId: 'y',
        claim: 'z',
      );
      final b = CharacterBelief(
        subjectId: 'x',
        targetId: 'y',
        claim: 'z',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('RelationshipSlice', () {
    test('constructs with defaults', () {
      final rel = RelationshipSlice(
        characterId: 'liuxi',
        otherId: 'yueren',
        kind: 'ally',
      );
      expect(rel.trust, 0.5);
      expect(rel.tension, 0.0);
      expect(rel.notes, '');
    });

    test('clamps trust and tension to valid range', () {
      final rel = RelationshipSlice(
        characterId: 'a',
        otherId: 'b',
        kind: 'rival',
        trust: 1.5,
        tension: -0.3,
      );
      expect(rel.trust, 1.0);
      expect(rel.tension, 0.0);
    });

    test('serializes round-trip', () {
      final original = RelationshipSlice(
        characterId: 'liuxi',
        otherId: 'fuxingzhou',
        kind: 'rival',
        trust: 0.3,
        tension: 0.8,
        notes: '不信任保全主管',
      );
      final restored = RelationshipSlice.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('fromJson falls back to defaults for missing fields', () {
      final restored = RelationshipSlice.fromJson({});
      expect(restored.characterId, '');
      expect(restored.trust, 0.5);
      expect(restored.tension, 0.0);
    });

    test('copyWith works', () {
      final original = RelationshipSlice(
        characterId: 'a',
        otherId: 'b',
        kind: 'ally',
      );
      final updated = original.copyWith(trust: 0.9, tension: 0.1);
      expect(updated.trust, 0.9);
      expect(updated.tension, 0.1);
      expect(updated.kind, 'ally');
    });
  });

  group('SocialPositionSlice', () {
    test('constructs with defaults', () {
      final pos = SocialPositionSlice(
        characterId: 'liuxi',
        contextId: 'scene-03',
        role: '调查者',
      );
      expect(pos.rank, 0);
      expect(pos.notes, '');
    });

    test('serializes round-trip', () {
      final original = SocialPositionSlice(
        characterId: 'fuxingzhou',
        contextId: 'scene-03',
        role: '保全主管',
        rank: 3,
        notes: '拥有码头出入最高权限',
      );
      final restored = SocialPositionSlice.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('fromJson handles missing rank', () {
      final restored = SocialPositionSlice.fromJson({});
      expect(restored.rank, 0);
    });
  });

  group('PresentationState', () {
    test('detects deception when both target and content are set', () {
      const state = PresentationState(
        characterId: 'yueren',
        displayedEmotion: '平静',
        hiddenEmotion: '恐惧',
        deceptionTarget: 'liuxi',
        deceptionContent: '隐瞒了当晚真实调度记录',
      );
      expect(state.isDeceiving, isTrue);
    });

    test('is not deceiving when target is empty', () {
      const state = PresentationState(
        characterId: 'yueren',
        displayedEmotion: '平静',
        deceptionContent: 'some content',
      );
      expect(state.isDeceiving, isFalse);
    });

    test('is not deceiving when content is empty', () {
      const state = PresentationState(
        characterId: 'yueren',
        deceptionTarget: 'liuxi',
      );
      expect(state.isDeceiving, isFalse);
    });

    test('serializes round-trip', () {
      const original = PresentationState(
        characterId: 'yueren',
        displayedEmotion: '配合',
        hiddenEmotion: '紧张',
        deceptionTarget: 'liuxi',
        deceptionContent: '隐藏调度时间',
      );
      final restored = PresentationState.fromJson(original.toJson());
      expect(restored, equals(original));
    });
  });

  group('CharacterCognitionSnapshot', () {
    final liuxi = CharacterRecord(
      id: 'character-liuxi',
      name: '柳溪',
      role: '调查记者',
      note: '失去搭档后的控制欲',
      need: '承认她也会判断失误',
      summary: '冷静、急迫、对线索高度敏感',
    );

    test('constructs with immutable lists', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: liuxi.id,
        name: liuxi.name,
        role: liuxi.role,
        beliefs: [
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'yueren',
            claim: '岳人知道更多信息',
          ),
        ],
      );
      expect(snapshot.beliefs.length, 1);
      expect(() => (snapshot.beliefs as List).add(CharacterBelief(
        subjectId: '',
        targetId: '',
        claim: '',
      )), throwsA(isA<UnsupportedError>()));
    });

    test('defaults presentation to characterId when empty', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'liuxi',
        name: '柳溪',
        role: '调查记者',
        presentation: const PresentationState(characterId: ''),
      );
      expect(snapshot.presentation.characterId, 'liuxi');
    });

    test('beliefsAbout filters by target', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'liuxi',
        name: '柳溪',
        role: '调查记者',
        beliefs: [
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'yueren',
            claim: '岳人隐瞒了信息',
          ),
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'fuxingzhou',
            claim: '傅行舟在阻挠调查',
          ),
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'yueren',
            claim: '岳人可能被威胁',
          ),
        ],
      );
      final aboutYueren = snapshot.beliefsAbout('yueren');
      expect(aboutYueren.length, 2);
      expect(aboutYueren.every((b) => b.targetId == 'yueren'), isTrue);
    });

    test('relationshipWith returns matching relationship', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'liuxi',
        name: '柳溪',
        role: '调查记者',
        relationships: [
          RelationshipSlice(
            characterId: 'liuxi',
            otherId: 'yueren',
            kind: 'ally',
            trust: 0.6,
          ),
          RelationshipSlice(
            characterId: 'liuxi',
            otherId: 'fuxingzhou',
            kind: 'rival',
            trust: 0.2,
          ),
        ],
      );
      expect(snapshot.relationshipWith('yueren')?.kind, 'ally');
      expect(snapshot.relationshipWith('fuxingzhou')?.trust, 0.2);
      expect(snapshot.relationshipWith('nonexistent'), isNull);
    });

    test('positionIn returns matching social position', () {
      final snapshot = CharacterCognitionSnapshot(
        characterId: 'liuxi',
        name: '柳溪',
        role: '调查记者',
        socialPositions: [
          SocialPositionSlice(
            characterId: 'liuxi',
            contextId: 'scene-03',
            role: '追索者',
            rank: 2,
          ),
          SocialPositionSlice(
            characterId: 'liuxi',
            contextId: 'scene-05',
            role: '对峙方',
            rank: 1,
          ),
        ],
      );
      expect(snapshot.positionIn('scene-03')?.role, '追索者');
      expect(snapshot.positionIn('scene-05')?.rank, 1);
      expect(snapshot.positionIn('scene-99'), isNull);
    });

    test('serializes and deserializes full snapshot round-trip', () {
      final original = CharacterCognitionSnapshot(
        characterId: 'liuxi',
        name: '柳溪',
        role: '调查记者',
        beliefs: [
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'yueren',
            claim: '岳人隐瞒了信息',
            confidence: 0.9,
            source: 'scene-03',
          ),
        ],
        relationships: [
          RelationshipSlice(
            characterId: 'liuxi',
            otherId: 'fuxingzhou',
            kind: 'rival',
            trust: 0.2,
            tension: 0.8,
          ),
        ],
        socialPositions: [
          SocialPositionSlice(
            characterId: 'liuxi',
            contextId: 'scene-03',
            role: '追索者',
            rank: 2,
          ),
        ],
        presentation: const PresentationState(
          characterId: 'liuxi',
          displayedEmotion: '冷静',
          hiddenEmotion: '焦虑',
        ),
      );
      final json = original.toJson();
      final restored = CharacterCognitionSnapshot.fromJson(json);
      expect(restored.characterId, original.characterId);
      expect(restored.name, original.name);
      expect(restored.role, original.role);
      expect(restored.beliefs.length, 1);
      expect(restored.beliefs.first, equals(original.beliefs.first));
      expect(restored.relationships.length, 1);
      expect(
        restored.relationships.first,
        equals(original.relationships.first),
      );
      expect(restored.socialPositions.length, 1);
      expect(
        restored.socialPositions.first,
        equals(original.socialPositions.first),
      );
      expect(restored.presentation, equals(original.presentation));
    });

    test('fromJson handles missing nested collections gracefully', () {
      final restored = CharacterCognitionSnapshot.fromJson({
        'characterId': 'liuxi',
        'name': '柳溪',
        'role': '调查记者',
      });
      expect(restored.characterId, 'liuxi');
      expect(restored.beliefs, isEmpty);
      expect(restored.relationships, isEmpty);
      expect(restored.socialPositions, isEmpty);
      expect(restored.presentation.characterId, 'liuxi');
    });

    test('copyWith preserves all fields', () {
      final original = CharacterCognitionSnapshot(
        characterId: 'liuxi',
        name: '柳溪',
        role: '调查记者',
        beliefs: [
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'yueren',
            claim: '旧信念',
          ),
        ],
      );
      final copied = original.copyWith(
        beliefs: [
          CharacterBelief(
            subjectId: 'liuxi',
            targetId: 'yueren',
            claim: '新信念',
          ),
        ],
      );
      expect(copied.characterId, 'liuxi');
      expect(copied.name, '柳溪');
      expect(copied.beliefs.first.claim, '新信念');
    });
  });

  group('CharacterCognitionSnapshotBuilder', () {
    final liuxi = CharacterRecord(
      id: 'character-liuxi',
      name: '柳溪',
      role: '调查记者',
      note: '失去搭档后的控制欲',
      need: '承认她也会判断失误',
      summary: '冷静、急迫、对线索高度敏感',
    );
    final yueren = CharacterRecord(
      id: 'character-yueren',
      name: '岳人',
      role: '线人',
      note: '把自己放进最危险的交汇点',
      need: '在保命和忠诚之间做一次明确选择',
      summary: '说话更快，信息密度高',
    );

    test('buildMinimal creates snapshot from CharacterRecord', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshot = builder.buildMinimal(liuxi);
      expect(snapshot.characterId, 'character-liuxi');
      expect(snapshot.name, '柳溪');
      expect(snapshot.role, '调查记者');
      expect(snapshot.beliefs, isEmpty);
      expect(snapshot.relationships, isEmpty);
      expect(snapshot.socialPositions, isEmpty);
      expect(snapshot.presentation.characterId, 'character-liuxi');
    });

    test('build populates cognition from arguments', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshot = builder.build(
        record: liuxi,
        beliefs: [
          CharacterBelief(
            subjectId: 'character-liuxi',
            targetId: 'character-yueren',
            claim: '岳人知道更多',
          ),
        ],
        relationships: [
          RelationshipSlice(
            characterId: 'character-liuxi',
            otherId: 'character-yueren',
            kind: 'uneasy_ally',
          ),
        ],
      );
      expect(snapshot.beliefs.length, 1);
      expect(snapshot.relationships.length, 1);
    });

    test('build defaults presentation to characterId when empty', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshot = builder.build(record: liuxi);
      expect(snapshot.presentation.characterId, 'character-liuxi');
    });

    test('buildForScene partitions cognition per character', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshots = builder.buildForScene(
        characters: [liuxi, yueren],
        sceneId: 'scene-03',
        beliefs: [
          CharacterBelief(
            subjectId: 'character-liuxi',
            targetId: 'character-yueren',
            claim: '岳人隐瞒了调度记录',
          ),
          CharacterBelief(
            subjectId: 'character-yueren',
            targetId: 'character-liuxi',
            claim: '柳溪可能被跟踪',
          ),
        ],
        relationships: [
          RelationshipSlice(
            characterId: 'character-liuxi',
            otherId: 'character-yueren',
            kind: 'ally',
            trust: 0.6,
          ),
          RelationshipSlice(
            characterId: 'character-yueren',
            otherId: 'character-liuxi',
            kind: 'wary_ally',
            trust: 0.4,
          ),
        ],
        socialPositions: [
          SocialPositionSlice(
            characterId: 'character-liuxi',
            contextId: 'scene-03',
            role: '追索者',
          ),
          SocialPositionSlice(
            characterId: 'character-yueren',
            contextId: 'scene-05',
            role: '信息源',
          ),
        ],
        presentations: [
          const PresentationState(
            characterId: 'character-yueren',
            displayedEmotion: '配合',
            hiddenEmotion: '恐惧',
          ),
        ],
      );

      expect(snapshots.length, 2);

      final liuxiSnap = snapshots[0];
      expect(liuxiSnap.characterId, 'character-liuxi');
      expect(liuxiSnap.beliefs.length, 1);
      expect(liuxiSnap.beliefs.first.claim, '岳人隐瞒了调度记录');
      expect(liuxiSnap.relationships.length, 1);
      expect(liuxiSnap.socialPositions.length, 1);
      expect(liuxiSnap.socialPositions.first.role, '追索者');

      final yuerenSnap = snapshots[1];
      expect(yuerenSnap.characterId, 'character-yueren');
      expect(yuerenSnap.beliefs.length, 1);
      expect(yuerenSnap.beliefs.first.claim, '柳溪可能被跟踪');
      expect(yuerenSnap.presentation.displayedEmotion, '配合');
      expect(yuerenSnap.presentation.hiddenEmotion, '恐惧');
    });

    test('buildForScene filters social positions by scene', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshots = builder.buildForScene(
        characters: [liuxi],
        sceneId: 'scene-03',
        socialPositions: [
          SocialPositionSlice(
            characterId: 'character-liuxi',
            contextId: 'scene-03',
            role: '追索者',
          ),
          SocialPositionSlice(
            characterId: 'character-liuxi',
            contextId: 'scene-05',
            role: '对峙方',
          ),
        ],
      );
      expect(snapshots.single.socialPositions.length, 1);
      expect(snapshots.single.socialPositions.first.role, '追索者');
    });

    test('buildForScene preserves empty-context social positions', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshots = builder.buildForScene(
        characters: [liuxi],
        sceneId: 'scene-03',
        socialPositions: [
          SocialPositionSlice(
            characterId: 'character-liuxi',
            contextId: '',
            role: '全局观察者',
          ),
        ],
      );
      expect(snapshots.single.socialPositions.length, 1);
      expect(snapshots.single.socialPositions.first.role, '全局观察者');
    });

    test('factual boundaries: beliefs do not leak between characters', () {
      final builder = CharacterCognitionSnapshotBuilder();
      final snapshots = builder.buildForScene(
        characters: [liuxi, yueren],
        sceneId: 'scene-03',
        beliefs: [
          CharacterBelief(
            subjectId: 'character-liuxi',
            targetId: 'character-yueren',
            claim: '岳人不可信',
          ),
        ],
      );
      expect(snapshots[0].beliefs.length, 1);
      expect(snapshots[1].beliefs, isEmpty);
    });
  });
}
