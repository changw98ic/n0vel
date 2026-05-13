import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/characters/data/character_relation_storage_io.dart';

/// 用内存 DB 创建一个已跑过 migration 的 storage
CharacterRelationStorageIO _openStorage() {
  final db = sqlite3.openInMemory();
  DatabaseSchemaManager(
    migrations: authoringSchemaMigrations,
  ).ensureSchema(db);
  return CharacterRelationStorageIO(db: db);
}

void main() {
  group('CharacterRelationStorageIO', () {
    late CharacterRelationStorageIO storage;
    late Database db;

    setUp(() {
      storage = _openStorage();
      db = storage.db;
    });

    tearDown(() {
      db.dispose();
    });

    test('save and load single relation', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final relation = CharacterRelationRecord(
        id: 'rel-1',
        projectId: 'proj-a',
        fromCharacterId: 'char-mei',
        toCharacterId: 'char-han',
        relationType: '师徒',
        note: '传授武艺',
        createdAtMs: now,
      );

      await storage.save(relation);
      final loaded = await storage.loadByProject('proj-a');

      expect(loaded, hasLength(1));
      expect(loaded.first.fromCharacterId, 'char-mei');
      expect(loaded.first.toCharacterId, 'char-han');
      expect(loaded.first.relationType, '师徒');
      expect(loaded.first.note, '传授武艺');
    });

    test('saveAll 批量插入', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-b',
          relationType: '朋友',
        ),
        CharacterRelationRecord(
          id: 'rel-2',
          projectId: 'proj-a',
          fromCharacterId: 'char-b',
          toCharacterId: 'char-c',
          relationType: '敌人',
        ),
        CharacterRelationRecord(
          id: 'rel-3',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-c',
          relationType: '父女',
        ),
      ]);

      final loaded = await storage.loadByProject('proj-a');
      expect(loaded, hasLength(3));
    });

    test('upsert 更新已有关系', () async {
      await storage.save(CharacterRelationRecord(
        id: 'rel-1',
        projectId: 'proj-a',
        fromCharacterId: 'char-a',
        toCharacterId: 'char-b',
        relationType: '朋友',
        note: '相识多年',
      ));

      await storage.save(CharacterRelationRecord(
        id: 'rel-1-updated',
        projectId: 'proj-a',
        fromCharacterId: 'char-a',
        toCharacterId: 'char-b',
        relationType: '恋人',
        note: '日久生情',
      ));

      final loaded = await storage.loadByProject('proj-a');
      expect(loaded, hasLength(1));
      expect(loaded.first.relationType, '恋人');
      expect(loaded.first.note, '日久生情');
      expect(loaded.first.id, 'rel-1-updated');
    });

    test('loadByFromCharacter 按出发方查询', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-b',
          relationType: '朋友',
        ),
        CharacterRelationRecord(
          id: 'rel-2',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-c',
          relationType: '敌人',
        ),
        CharacterRelationRecord(
          id: 'rel-3',
          projectId: 'proj-a',
          fromCharacterId: 'char-b',
          toCharacterId: 'char-c',
          relationType: '恋人',
        ),
      ]);

      final fromA = await storage.loadByFromCharacter('proj-a', 'char-a');
      expect(fromA, hasLength(2));
      expect(fromA.every((r) => r.fromCharacterId == 'char-a'), isTrue);
    });

    test('loadByToCharacter 按目标方查询', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-c',
          relationType: '朋友',
        ),
        CharacterRelationRecord(
          id: 'rel-2',
          projectId: 'proj-a',
          fromCharacterId: 'char-b',
          toCharacterId: 'char-c',
          relationType: '敌人',
        ),
      ]);

      final toC = await storage.loadByToCharacter('proj-a', 'char-c');
      expect(toC, hasLength(2));
      expect(toC.every((r) => r.toCharacterId == 'char-c'), isTrue);
    });

    test('loadAllForCharacter 查找涉及某角色的所有关系', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-b',
          relationType: '朋友',
        ),
        CharacterRelationRecord(
          id: 'rel-2',
          projectId: 'proj-a',
          fromCharacterId: 'char-b',
          toCharacterId: 'char-c',
          relationType: '敌人',
        ),
        CharacterRelationRecord(
          id: 'rel-3',
          projectId: 'proj-a',
          fromCharacterId: 'char-c',
          toCharacterId: 'char-a',
          relationType: '恋人',
        ),
      ]);

      final allForB = await storage.loadAllForCharacter('proj-a', 'char-b');
      expect(allForB, hasLength(2));
      // char-b 作为 from 在 rel-1，作为 to 在 rel-2
      expect(
        allForB.any((r) => r.id == 'rel-1'),
        isTrue,
      );
      expect(
        allForB.any((r) => r.id == 'rel-2'),
        isTrue,
      );
    });

    test('delete 删除指定关系', () async {
      await storage.save(CharacterRelationRecord(
        id: 'rel-1',
        projectId: 'proj-a',
        fromCharacterId: 'char-a',
        toCharacterId: 'char-b',
        relationType: '朋友',
      ));

      final deleted = await storage.delete('proj-a', 'char-a', 'char-b');
      expect(deleted, isTrue);

      final loaded = await storage.loadByProject('proj-a');
      expect(loaded, isEmpty);
    });

    test('delete 不存在的关系返回 false', () async {
      final deleted = await storage.delete('proj-a', 'char-x', 'char-y');
      expect(deleted, isFalse);
    });

    test('clearProject 只清除指定项目', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-a1',
          projectId: 'proj-a',
          fromCharacterId: 'a1',
          toCharacterId: 'a2',
          relationType: '朋友',
        ),
        CharacterRelationRecord(
          id: 'rel-b1',
          projectId: 'proj-b',
          fromCharacterId: 'b1',
          toCharacterId: 'b2',
          relationType: '敌人',
        ),
      ]);

      await storage.clearProject('proj-a');

      final a = await storage.loadByProject('proj-a');
      final b = await storage.loadByProject('proj-b');
      expect(a, isEmpty);
      expect(b, hasLength(1));
    });

    test('clearForCharacter 删除涉及某角色的所有关系', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-b',
          relationType: '朋友',
        ),
        CharacterRelationRecord(
          id: 'rel-2',
          projectId: 'proj-a',
          fromCharacterId: 'char-b',
          toCharacterId: 'char-c',
          relationType: '敌人',
        ),
        CharacterRelationRecord(
          id: 'rel-3',
          projectId: 'proj-a',
          fromCharacterId: 'char-c',
          toCharacterId: 'char-a',
          relationType: '恋人',
        ),
      ]);

      final removed = await storage.clearForCharacter('proj-a', 'char-b');
      expect(removed, 2);

      final remaining = await storage.loadByProject('proj-a');
      expect(remaining, hasLength(1));
      expect(remaining.first.id, 'rel-3');
    });

    test('项目隔离：不同项目的关系互不影响', () async {
      await storage.save(CharacterRelationRecord(
        id: 'rel-a',
        projectId: 'proj-a',
        fromCharacterId: 'x',
        toCharacterId: 'y',
        relationType: '朋友',
      ));
      await storage.save(CharacterRelationRecord(
        id: 'rel-b',
        projectId: 'proj-b',
        fromCharacterId: 'x',
        toCharacterId: 'y',
        relationType: '敌人',
      ));

      final a = await storage.loadByProject('proj-a');
      final b = await storage.loadByProject('proj-b');
      expect(a.single.relationType, '朋友');
      expect(b.single.relationType, '敌人');
    });

    test('一对多关系：一个角色可以有多个关系', () async {
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-hero',
          toCharacterId: 'char-mentor',
          relationType: '师徒',
        ),
        CharacterRelationRecord(
          id: 'rel-2',
          projectId: 'proj-a',
          fromCharacterId: 'char-hero',
          toCharacterId: 'char-love',
          relationType: '恋人',
        ),
        CharacterRelationRecord(
          id: 'rel-3',
          projectId: 'proj-a',
          fromCharacterId: 'char-hero',
          toCharacterId: 'char-rival',
          relationType: '宿敌',
        ),
      ]);

      final fromHero = await storage.loadByFromCharacter(
        'proj-a',
        'char-hero',
      );
      expect(fromHero, hasLength(3));
    });

    test('多对多关系：双方互有指向', () async {
      // A→B 和 B→A 表示双向关系
      await storage.saveAll([
        CharacterRelationRecord(
          id: 'rel-ab',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-b',
          relationType: '盟友',
        ),
        CharacterRelationRecord(
          id: 'rel-ba',
          projectId: 'proj-a',
          fromCharacterId: 'char-b',
          toCharacterId: 'char-a',
          relationType: '盟友',
        ),
      ]);

      final fromA = await storage.loadByFromCharacter('proj-a', 'char-a');
      final toA = await storage.loadByToCharacter('proj-a', 'char-a');
      expect(fromA, hasLength(1));
      expect(toA, hasLength(1));
    });

    test('自反关系（角色指向自己）允许保存', () async {
      final relation = CharacterRelationRecord(
        id: 'rel-self',
        projectId: 'proj-a',
        fromCharacterId: 'char-a',
        toCharacterId: 'char-a',
        relationType: '自我认知',
      );

      await storage.save(relation);
      expect(relation.isSelfRelation, isTrue);

      final loaded = await storage.loadByProject('proj-a');
      expect(loaded, hasLength(1));
      expect(loaded.first.isSelfRelation, isTrue);
    });

    group('validateAndRepair', () {
      test('删除引用不存在角色的孤儿关系', () async {
        await storage.saveAll([
          CharacterRelationRecord(
            id: 'rel-valid',
            projectId: 'proj-a',
            fromCharacterId: 'char-a',
            toCharacterId: 'char-b',
            relationType: '朋友',
          ),
          CharacterRelationRecord(
            id: 'rel-orphan-from',
            projectId: 'proj-a',
            fromCharacterId: 'char-ghost',
            toCharacterId: 'char-a',
            relationType: '幽灵',
          ),
          CharacterRelationRecord(
            id: 'rel-orphan-to',
            projectId: 'proj-a',
            fromCharacterId: 'char-a',
            toCharacterId: 'char-vanished',
            relationType: '消失',
          ),
        ]);

        final repairs = await storage.validateAndRepair(
          'proj-a',
          {'char-a', 'char-b'},
        );

        expect(repairs, hasLength(2));
        expect(repairs[0], contains('孤儿关系'));
        expect(repairs[1], contains('孤儿关系'));

        final remaining = await storage.loadByProject('proj-a');
        expect(remaining, hasLength(1));
        expect(remaining.first.id, 'rel-valid');
      });

      test('所有角色都存在时无修复', () async {
        await storage.save(CharacterRelationRecord(
          id: 'rel-1',
          projectId: 'proj-a',
          fromCharacterId: 'char-a',
          toCharacterId: 'char-b',
          relationType: '朋友',
        ));

        final repairs = await storage.validateAndRepair(
          'proj-a',
          {'char-a', 'char-b'},
        );

        expect(repairs, isEmpty);
      });

      test('空项目无修复', () async {
        final repairs = await storage.validateAndRepair('proj-a', {'char-a'});
        expect(repairs, isEmpty);
      });
    });
  });

  group('schema migration v3', () {
    test('character_relations 表在 migration 后存在', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final tables = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'character_relations'",
          )
          .map((r) => r['name'] as String)
          .toList();

      expect(tables, contains('character_relations'));
      expect(
        db.select('PRAGMA user_version').first['user_version'],
        3,
      );
    });

    test('character_relations 索引在 migration 后存在', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      final indexes = db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'index' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();

      expect(indexes, containsAll([
        'idx_character_relations_project',
        'idx_character_relations_from',
        'idx_character_relations_to',
      ]));
    });

    test('PK 约束阻止同一对角色的重复关系', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(db);

      db.execute(
        '''INSERT INTO character_relations
          (id, project_id, from_character_id, to_character_id, relation_type, note, created_at_ms)
          VALUES ('r1', 'p1', 'a', 'b', '朋友', '', 0)''',
      );

      // 同一对角色再次插入应走 upsert（ON CONFLICT DO UPDATE）
      db.execute(
        '''INSERT INTO character_relations
          (id, project_id, from_character_id, to_character_id, relation_type, note, created_at_ms)
          VALUES ('r2', 'p1', 'a', 'b', '敌人', '翻脸', 100)
          ON CONFLICT(project_id, from_character_id, to_character_id)
          DO UPDATE SET id = excluded.id, relation_type = excluded.relation_type,
                        note = excluded.note, created_at_ms = excluded.created_at_ms''',
      );

      final rows = db.select(
        'SELECT * FROM character_relations WHERE project_id = ?',
        ['p1'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'r2');
      expect(rows.first['relation_type'], '敌人');
    });

    test('数据在重复 ensureSchema 调用后保留', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);

      final manager = DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      );
      manager.ensureSchema(db);

      db.execute(
        '''INSERT INTO character_relations
          (id, project_id, from_character_id, to_character_id, relation_type, note, created_at_ms)
          VALUES ('r1', 'p1', 'a', 'b', '朋友', '', 0)''',
      );

      manager.ensureSchema(db);

      final rows = db.select('SELECT * FROM character_relations');
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'r1');
    });
  });
}
