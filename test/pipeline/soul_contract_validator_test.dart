import 'package:novel_writer/features/story_generation/data/profile_structured_store.dart';
import 'package:novel_writer/features/story_generation/data/soul_contract_validator.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart'
    as gate;
import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/structured_profile.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileStructuredStore', () {
    late Database db;
    late ProfileStructuredStore store;

    setUp(() {
      db = sqlite3.openInMemory();
      store = ProfileStructuredStore(db: db);
    });

    tearDown(() {
      db.dispose();
    });

    test('round-trips a profile with nested fields', () async {
      const profile = StructuredProfile(
        id: 'char-1',
        name: '林月',
        personality: PersonalityVector(
          openness: 0.8,
          conscientiousness: 0.6,
          extraversion: 0.3,
          agreeableness: 0.7,
          neuroticism: 0.2,
        ),
        voicePrint: VoicePrint(
          vocabularyLevel: 'literary',
          sentenceLength: 'long',
          speakingPatterns: ['uses metaphors', 'pauses before answering'],
          catchphrases: ['如你所见'],
          toneModifiers: ['gentle'],
        ),
        behaviorBounds: BehaviorBounds(
          forbiddenActions: ['kill', 'betray allies'],
          mandatoryResponses: ['help the weak'],
          emotionalRange: EmotionalRange(
            maxIntensity: 0.8,
            forbiddenEmotions: ['rage'],
            defaultState: 'calm',
          ),
        ),
        backstory: '出生于书香世家',
        relationships: [
          RelationshipEdge(targetId: 'char-2', type: 'mentor', strength: 0.9),
        ],
        metadata: {'source': 'chapter-1'},
      );

      await store.saveProfile(projectId: 'proj-A', profile: profile);
      final loaded = await store.loadProfile(
        projectId: 'proj-A',
        profileId: 'char-1',
      );

      expect(loaded, isNotNull);
      expect(loaded!.id, 'char-1');
      expect(loaded.name, '林月');
      expect(loaded.personality.openness, 0.8);
      expect(loaded.voicePrint.vocabularyLevel, 'literary');
      expect(loaded.voicePrint.speakingPatterns, [
        'uses metaphors',
        'pauses before answering',
      ]);
      expect(loaded.voicePrint.catchphrases, ['如你所见']);
      expect(loaded.behaviorBounds.forbiddenActions, ['kill', 'betray allies']);
      expect(loaded.behaviorBounds.emotionalRange.maxIntensity, 0.8);
      expect(loaded.behaviorBounds.emotionalRange.forbiddenEmotions, ['rage']);
      expect(loaded.backstory, '出生于书香世家');
      expect(loaded.relationships, hasLength(1));
      expect(loaded.relationships[0].targetId, 'char-2');
      expect(loaded.metadata['source'], 'chapter-1');
    });

    test('replaces profile on re-save', () async {
      final v1 = _makeProfile(id: 'p1', name: 'Version 1');
      final v2 = _makeProfile(id: 'p1', name: 'Version 2');

      await store.saveProfile(projectId: 'proj-X', profile: v1);
      await store.saveProfile(projectId: 'proj-X', profile: v2);

      final loaded = await store.loadProfile(
        projectId: 'proj-X',
        profileId: 'p1',
      );
      expect(loaded!.name, 'Version 2');
    });

    test('loadProfiles returns all profiles for a project', () async {
      await store.saveProfile(
        projectId: 'proj-A',
        profile: _makeProfile(id: 'a1', name: 'A1'),
      );
      await store.saveProfile(
        projectId: 'proj-A',
        profile: _makeProfile(id: 'a2', name: 'A2'),
      );

      final profiles = await store.loadProfiles(projectId: 'proj-A');
      expect(profiles, hasLength(2));
      final names = profiles.map((p) => p.name).toSet();
      expect(names, containsAll(['A1', 'A2']));
    });

    test('isolates profiles across projects', () async {
      await store.saveProfile(
        projectId: 'proj-A',
        profile: _makeProfile(id: 'x', name: 'Only-A'),
      );
      await store.saveProfile(
        projectId: 'proj-B',
        profile: _makeProfile(id: 'y', name: 'Only-B'),
      );

      final aProfiles = await store.loadProfiles(projectId: 'proj-A');
      final bProfiles = await store.loadProfiles(projectId: 'proj-B');
      expect(aProfiles, hasLength(1));
      expect(aProfiles.first.name, 'Only-A');
      expect(bProfiles, hasLength(1));
      expect(bProfiles.first.name, 'Only-B');
    });

    test('loadProfile returns null for missing profile', () async {
      final loaded = await store.loadProfile(
        projectId: 'proj-A',
        profileId: 'nonexistent',
      );
      expect(loaded, isNull);
    });

    test('deleteProfile removes a single profile', () async {
      await store.saveProfile(
        projectId: 'proj-A',
        profile: _makeProfile(id: 'del-me', name: 'Delete'),
      );
      await store.deleteProfile(projectId: 'proj-A', profileId: 'del-me');
      final loaded = await store.loadProfile(
        projectId: 'proj-A',
        profileId: 'del-me',
      );
      expect(loaded, isNull);
    });

    test('clearProject removes all profiles for a project', () async {
      await store.saveProfile(
        projectId: 'proj-A',
        profile: _makeProfile(id: 'a1', name: 'A1'),
      );
      await store.saveProfile(
        projectId: 'proj-A',
        profile: _makeProfile(id: 'a2', name: 'A2'),
      );
      await store.saveProfile(
        projectId: 'proj-B',
        profile: _makeProfile(id: 'b1', name: 'B1'),
      );

      await store.clearProject('proj-A');

      expect(await store.loadProfiles(projectId: 'proj-A'), isEmpty);
      final bProfiles = await store.loadProfiles(projectId: 'proj-B');
      expect(bProfiles, hasLength(1));
    });
  });

  group('SoulContractValidator', () {
    test('returns no violations for valid actions', () {
      const contract = SoulContract(
        forbiddenActions: ['kill'],
        coreValues: ['善良'],
      );
      const validator = SoulContractValidator(contract);

      final violations = validator.validate('帮助了朋友');
      expect(violations, isEmpty);
    });

    test('catches forbidden action violations', () {
      const contract = SoulContract(forbiddenActions: ['kill']);
      const validator = SoulContractValidator(contract);

      final violations = validator.validate('he decided to kill the enemy');
      expect(violations, hasLength(1));
      expect(violations.first.rule, contains('forbidden:kill'));
      expect(violations.first.severity, 1.0);
    });

    test('catches core value contradictions', () {
      const contract = SoulContract(coreValues: ['善良']);
      const validator = SoulContractValidator(contract);

      final violations = validator.validate('他不善良');
      expect(violations, hasLength(1));
      expect(violations.first.rule, contains('coreValue:善良'));
    });

    test('catches forbidden emotions', () {
      const contract = SoulContract(
        emotionalRange: EmotionalContract(forbiddenEmotions: ['rage']),
      );
      const validator = SoulContractValidator(contract);

      final violations = validator.validate('she felt rage');
      expect(violations, hasLength(1));
      expect(violations.first.rule, contains('emotion:rage'));
    });

    test('catches broken promises', () {
      const contract = SoulContract(unbreakablePromises: ['保护妹妹']);
      const validator = SoulContractValidator(contract);

      final violations = validator.validate('他违背保护妹妹的誓言');
      expect(violations, hasLength(1));
      expect(violations.first.rule, contains('promise:保护妹妹'));
      expect(violations.first.severity, 1.0);
    });

    test('writeback adapter maps violations to SoulViolationRef', () {
      const contract = SoulContract(
        forbiddenActions: ['kill'],
        coreValues: ['善良'],
      );
      const validator = SoulContractValidator(contract);
      final adapter = validator.asWritebackValidator();

      final refs = adapter('he would kill and 不善良');
      expect(refs, hasLength(2));
      expect(refs.any((r) => r.rule.contains('forbidden:kill')), isTrue);
      expect(refs.any((r) => r.rule.contains('coreValue:善良')), isTrue);
      for (final ref in refs) {
        expect(ref, isA<gate.SoulViolationRef>());
      }
    });

    test('writeback adapter returns empty list for valid content', () {
      const contract = SoulContract(forbiddenActions: ['kill']);
      const validator = SoulContractValidator(contract);
      final adapter = validator.asWritebackValidator();

      expect(adapter('she helped everyone'), isEmpty);
    });
  });
}

StructuredProfile _makeProfile({required String id, required String name}) {
  return StructuredProfile(
    id: id,
    name: name,
    personality: const PersonalityVector(),
    voicePrint: const VoicePrint(),
    behaviorBounds: const BehaviorBounds(),
  );
}
