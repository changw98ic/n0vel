import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/structured_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuredProfile', () {
    test('round-trip serialization', () {
      const profile = StructuredProfile(
        id: 'char-1',
        name: '林默',
        personality: PersonalityVector(
          openness: 0.8,
          conscientiousness: 0.6,
          extraversion: 0.3,
          agreeableness: 0.7,
          neuroticism: 0.4,
        ),
        voicePrint: VoicePrint(
          vocabularyLevel: 'literary',
          sentenceLength: 'short',
          speakingPatterns: ['反问', '省略主语'],
          catchphrases: ['没必要解释'],
        ),
        behaviorBounds: BehaviorBounds(
          forbiddenActions: ['背叛朋友', '抛弃弱者'],
          mandatoryResponses: ['保护同伴'],
          emotionalRange: EmotionalRange(
            maxIntensity: 0.9,
            forbiddenEmotions: ['狂喜'],
            defaultState: 'calm',
          ),
        ),
        soul: SoulContract(
          coreValues: ['正义', '忠诚'],
          forbiddenActions: ['杀人'],
          emotionalRange: EmotionalContract(
            maxIntensity: 0.8,
            forbiddenEmotions: ['恐惧'],
            defaultState: '坚定',
          ),
          decisionPattern: DecisionPattern.principled,
          unbreakablePromises: ['保护无辜者'],
          identityAnchors: ['永不放弃'],
        ),
        backstory: '曾是一名刑警',
        relationships: [
          RelationshipEdge(targetId: 'char-2', type: 'ally', strength: 0.8),
          RelationshipEdge(targetId: 'char-3', type: 'rival', strength: 0.6),
        ],
      );

      final json = profile.toJson();
      final restored = StructuredProfile.fromJson(json);

      expect(restored.id, 'char-1');
      expect(restored.name, '林默');
      expect(restored.personality.openness, 0.8);
      expect(restored.voicePrint.vocabularyLevel, 'literary');
      expect(restored.voicePrint.speakingPatterns, ['反问', '省略主语']);
      expect(restored.behaviorBounds.forbiddenActions, ['背叛朋友', '抛弃弱者']);
      expect(restored.behaviorBounds.emotionalRange.maxIntensity, 0.9);
      expect(restored.soul.coreValues, ['正义', '忠诚']);
      expect(restored.soul.forbiddenActions, ['杀人']);
      expect(restored.soul.emotionalRange.maxIntensity, 0.8);
      expect(restored.soul.emotionalRange.forbiddenEmotions, ['恐惧']);
      expect(restored.soul.decisionPattern, DecisionPattern.principled);
      expect(restored.soul.unbreakablePromises, ['保护无辜者']);
      expect(restored.soul.identityAnchors, ['永不放弃']);
      expect(restored.backstory, '曾是一名刑警');
      expect(restored.relationships, hasLength(2));
      expect(restored.relationships[0].targetId, 'char-2');
      expect(restored.relationships[1].type, 'rival');
    });

    test('tokenEstimate is non-negative', () {
      const profile = StructuredProfile(
        id: 'x',
        name: 'test',
        personality: PersonalityVector(),
        voicePrint: VoicePrint(),
        behaviorBounds: BehaviorBounds(),
      );
      expect(profile.tokenEstimate, greaterThan(0));
    });

    test('defaults handle empty/null JSON gracefully', () {
      final profile = StructuredProfile.fromJson({});
      expect(profile.id, '');
      expect(profile.name, '');
      expect(profile.personality.openness, 0.5);
      expect(profile.relationships, isEmpty);
      expect(profile.backstory, '');
    });
  });

  group('PersonalityVector', () {
    test('defaults are 0.5', () {
      const pv = PersonalityVector();
      expect(pv.openness, 0.5);
      expect(pv.conscientiousness, 0.5);
      expect(pv.extraversion, 0.5);
      expect(pv.agreeableness, 0.5);
      expect(pv.neuroticism, 0.5);
    });

    test('round-trip', () {
      const pv = PersonalityVector(openness: 0.9, neuroticism: 0.1);
      final json = pv.toJson();
      final restored = PersonalityVector.fromJson(json);
      expect(restored.openness, 0.9);
      expect(restored.neuroticism, 0.1);
    });
  });

  group('RelationshipEdge', () {
    test('round-trip', () {
      const edge = RelationshipEdge(
        targetId: 't1',
        type: 'mentor',
        strength: 0.75,
      );
      final restored = RelationshipEdge.fromJson(edge.toJson());
      expect(restored.targetId, 't1');
      expect(restored.type, 'mentor');
      expect(restored.strength, 0.75);
    });
  });
}
