import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  late AppWorkspaceStore store;

  setUp(() {
    store = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
  });

  tearDown(() {
    store.dispose();
  });

  // ---------------------------------------------------------------------------
  // Group 1: CharacterRecord model
  // ---------------------------------------------------------------------------

  group('CharacterRecord', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      const original = CharacterRecord(
        id: 'char-test-1',
        name: '柳溪',
        role: '调查记者',
        note: '失去搭档后的控制欲',
        need: '承认她也会判断失误',
        summary: '冷静、急迫、对线索高度敏感。',
        referenceSummary: '在雨夜码头保持视角稳定。',
        linkedSceneIds: ['scene-03', 'scene-05'],
      );

      final json = original.toJson();
      final restored = CharacterRecord.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.role, original.role);
      expect(restored.note, original.note);
      expect(restored.need, original.need);
      expect(restored.summary, original.summary);
      expect(restored.referenceSummary, original.referenceSummary);
      expect(restored.linkedSceneIds, original.linkedSceneIds);
    });

    test('fromJson with null values uses defaults', () {
      final restored = CharacterRecord.fromJson({});

      // name defaults to '新角色' when null/empty
      expect(restored.name, '新角色');
      // role, note, need, summary all default to ''
      expect(restored.role, '');
      expect(restored.note, '');
      expect(restored.need, '');
      expect(restored.summary, '');
      expect(restored.referenceSummary, '');
      // id falls back to 'character-fallback' when name is also missing
      expect(restored.id, 'character-fallback');
      // linkedSceneIds defaults to empty list
      expect(restored.linkedSceneIds, isEmpty);
    });

    test('copyWith preserves unchanged fields', () {
      const original = CharacterRecord(
        id: 'char-1',
        name: '岳人',
        role: '线人',
        note: '背景笔记',
        need: '核心需求',
        summary: '人物摘要',
        referenceSummary: '引用摘要',
        linkedSceneIds: ['scene-A'],
      );

      final updated = original.copyWith(name: '林岳人');

      expect(updated.id, 'char-1');
      expect(updated.name, '林岳人');
      expect(updated.role, '线人');
      expect(updated.note, '背景笔记');
      expect(updated.need, '核心需求');
      expect(updated.summary, '人物摘要');
      expect(updated.referenceSummary, '引用摘要');
      expect(updated.linkedSceneIds, ['scene-A']);
    });

    test('linkedSceneIds serialization round-trip', () {
      const record = CharacterRecord(
        id: 'char-links',
        name: '测试',
        role: '角色',
        note: '笔记',
        need: '需求',
        summary: '摘要',
        linkedSceneIds: ['scene-01', 'scene-02', 'scene-03'],
      );

      final json = record.toJson();
      final restored = CharacterRecord.fromJson(json);

      expect(restored.linkedSceneIds, ['scene-01', 'scene-02', 'scene-03']);
      // Ensure order is preserved
      expect(restored.linkedSceneIds[0], 'scene-01');
      expect(restored.linkedSceneIds[2], 'scene-03');
    });
  });

  // ---------------------------------------------------------------------------
  // Group 2: createCharacter
  // ---------------------------------------------------------------------------

  group('createCharacter', () {
    test('creates a new character with default values', () {
      // Default project already has 3 characters (柳溪, 岳人, 傅行舟)
      final countBefore = store.characters.length;

      store.createCharacter();

      expect(store.characters.length, countBefore + 1);
      final newChar = store.characters.first;
      expect(newChar.name, startsWith('新角色'));
      expect(newChar.role, '待定义角色');
      expect(newChar.note, '等待补充人物背景与驱动');
      expect(newChar.need, '等待明确目标与风险');
      expect(newChar.id, isNotEmpty);
    });

    test('increments name index for subsequent creates', () {
      final countBefore = store.characters.length;

      store.createCharacter();
      final first = store.characters.first;
      expect(first.name, '新角色 ${countBefore + 1}');

      store.createCharacter();
      final second = store.characters.first;
      expect(second.name, '新角色 ${countBefore + 2}');
    });

    test('created character appears in store.characters', () {
      store.createCharacter();

      final allChars = store.characters;
      final newChar = allChars.first;

      // The new character should be at the start of the list
      expect(newChar.name, startsWith('新角色'));
      // It should be findable by its generated id
      expect(allChars.any((c) => c.id == newChar.id), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: updateCharacter
  // ---------------------------------------------------------------------------

  group('updateCharacter', () {
    test('updates name field', () {
      store.createCharacter();
      final charId = store.characters.first.id;

      store.updateCharacter(characterId: charId, name: '林晓');

      final updated = store.characters.firstWhere((c) => c.id == charId);
      expect(updated.name, '林晓');
      // Other fields should remain unchanged
      expect(updated.role, '待定义角色');
    });

    test('updates multiple fields at once', () {
      store.createCharacter();
      final charId = store.characters.first.id;

      store.updateCharacter(
        characterId: charId,
        name: '赵明',
        role: '侦探',
        note: '细节补充',
        need: '揭露真相',
        summary: '全新摘要',
        referenceSummary: '新引用',
      );

      final updated = store.characters.firstWhere((c) => c.id == charId);
      expect(updated.name, '赵明');
      expect(updated.role, '侦探');
      expect(updated.note, '细节补充');
      expect(updated.need, '揭露真相');
      expect(updated.summary, '全新摘要');
      expect(updated.referenceSummary, '新引用');
    });

    test('updateCharacter for non-existent id is a no-op', () {
      final countBefore = store.characters.length;
      final namesBefore = store.characters.map((c) => c.name).toList();

      // Use a completely fabricated id that does not exist
      store.updateCharacter(
        characterId: 'non-existent-id-xyz',
        name: '不应该出现',
      );

      // No character was added or removed
      expect(store.characters.length, countBefore);
      // No character data was modified
      final namesAfter = store.characters.map((c) => c.name).toList();
      expect(namesAfter, namesBefore);
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: setCharacterSceneLinked
  // ---------------------------------------------------------------------------

  group('setCharacterSceneLinked', () {
    test('links a scene to a character', () {
      store.createCharacter();
      final charId = store.characters.first.id;

      store.setCharacterSceneLinked(
        characterId: charId,
        sceneId: 'scene-test-link',
        linked: true,
      );

      final updated = store.characters.firstWhere((c) => c.id == charId);
      expect(updated.linkedSceneIds, contains('scene-test-link'));
    });

    test('unlinks a scene from a character', () {
      store.createCharacter();
      final charId = store.characters.first.id;

      // First link, then unlink
      store.setCharacterSceneLinked(
        characterId: charId,
        sceneId: 'scene-test-unlink',
        linked: true,
      );

      store.setCharacterSceneLinked(
        characterId: charId,
        sceneId: 'scene-test-unlink',
        linked: false,
      );

      final updated = store.characters.firstWhere((c) => c.id == charId);
      expect(updated.linkedSceneIds, isNot(contains('scene-test-unlink')));
    });

    test('linking same scene twice does not duplicate', () {
      store.createCharacter();
      final charId = store.characters.first.id;

      store.setCharacterSceneLinked(
        characterId: charId,
        sceneId: 'scene-dedup',
        linked: true,
      );
      store.setCharacterSceneLinked(
        characterId: charId,
        sceneId: 'scene-dedup',
        linked: true,
      );

      final updated = store.characters.firstWhere((c) => c.id == charId);
      final count = updated.linkedSceneIds
          .where((id) => id == 'scene-dedup')
          .length;
      expect(count, 1);
    });
  });
}
