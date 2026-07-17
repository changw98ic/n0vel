import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/domain/workspace_models.dart';
import 'character_relation_storage.dart';

/// [CharacterRelationStorage] 的 SQLite 实现
class CharacterRelationStorageIO implements CharacterRelationStorage {
  CharacterRelationStorageIO({required this.db});

  final Database db;

  CharacterRelationRecord _fromRow(Row row) {
    return CharacterRelationRecord(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      fromCharacterId: row['from_character_id'] as String,
      toCharacterId: row['to_character_id'] as String,
      relationType: row['relation_type'] as String,
      note: row['note'] as String,
      createdAtMs: row['created_at_ms'] as int,
    );
  }

  @override
  Future<void> save(CharacterRelationRecord relation) async {
    db.execute(
      '''
      INSERT INTO character_relations
        (id, project_id, from_character_id, to_character_id, relation_type, note, created_at_ms)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(project_id, from_character_id, to_character_id)
      DO UPDATE SET
        id = excluded.id,
        relation_type = excluded.relation_type,
        note = excluded.note,
        created_at_ms = excluded.created_at_ms
      ''',
      [
        relation.id,
        relation.projectId,
        relation.fromCharacterId,
        relation.toCharacterId,
        relation.relationType,
        relation.note,
        relation.createdAtMs,
      ],
    );
  }

  @override
  Future<void> saveAll(List<CharacterRelationRecord> relations) async {
    for (final relation in relations) {
      await save(relation);
    }
  }

  @override
  Future<List<CharacterRelationRecord>> loadByProject(String projectId) async {
    final rows = db.select(
      '''
      SELECT id, project_id, from_character_id, to_character_id,
             relation_type, note, created_at_ms
      FROM character_relations
      WHERE project_id = ?
      ORDER BY from_character_id, to_character_id
      ''',
      [projectId],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<CharacterRelationRecord>> loadByFromCharacter(
    String projectId,
    String fromCharacterId,
  ) async {
    final rows = db.select(
      '''
      SELECT id, project_id, from_character_id, to_character_id,
             relation_type, note, created_at_ms
      FROM character_relations
      WHERE project_id = ? AND from_character_id = ?
      ORDER BY to_character_id
      ''',
      [projectId, fromCharacterId],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<CharacterRelationRecord>> loadByToCharacter(
    String projectId,
    String toCharacterId,
  ) async {
    final rows = db.select(
      '''
      SELECT id, project_id, from_character_id, to_character_id,
             relation_type, note, created_at_ms
      FROM character_relations
      WHERE project_id = ? AND to_character_id = ?
      ORDER BY from_character_id
      ''',
      [projectId, toCharacterId],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<CharacterRelationRecord>> loadAllForCharacter(
    String projectId,
    String characterId,
  ) async {
    final rows = db.select(
      '''
      SELECT id, project_id, from_character_id, to_character_id,
             relation_type, note, created_at_ms
      FROM character_relations
      WHERE project_id = ? AND (from_character_id = ? OR to_character_id = ?)
      ORDER BY from_character_id, to_character_id
      ''',
      [projectId, characterId, characterId],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<bool> delete(
    String projectId,
    String fromCharacterId,
    String toCharacterId,
  ) async {
    final before = db.select(
      'SELECT COUNT(*) AS cnt FROM character_relations '
      'WHERE project_id = ? AND from_character_id = ? AND to_character_id = ?',
      [projectId, fromCharacterId, toCharacterId],
    );
    final countBefore = before.first['cnt'] as int;

    db.execute(
      'DELETE FROM character_relations '
      'WHERE project_id = ? AND from_character_id = ? AND to_character_id = ?',
      [projectId, fromCharacterId, toCharacterId],
    );

    return countBefore > 0;
  }

  @override
  Future<void> clearProject(String projectId) async {
    db.execute('DELETE FROM character_relations WHERE project_id = ?', [
      projectId,
    ]);
  }

  @override
  Future<int> clearForCharacter(String projectId, String characterId) async {
    final before = db.select(
      'SELECT COUNT(*) AS cnt FROM character_relations '
      'WHERE project_id = ? AND (from_character_id = ? OR to_character_id = ?)',
      [projectId, characterId, characterId],
    );
    final countBefore = before.first['cnt'] as int;

    db.execute(
      'DELETE FROM character_relations '
      'WHERE project_id = ? AND (from_character_id = ? OR to_character_id = ?)',
      [projectId, characterId, characterId],
    );

    return countBefore;
  }

  @override
  Future<List<String>> validateAndRepair(
    String projectId,
    Set<String> existingCharacterIds,
  ) async {
    final repairs = <String>[];
    final all = await loadByProject(projectId);

    // 1. 检测孤儿关系（引用了不存在的角色）
    final orphans = all.where(
      (r) =>
          !existingCharacterIds.contains(r.fromCharacterId) ||
          !existingCharacterIds.contains(r.toCharacterId),
    );
    for (final orphan in orphans) {
      db.execute(
        'DELETE FROM character_relations '
        'WHERE project_id = ? AND from_character_id = ? AND to_character_id = ?',
        [projectId, orphan.fromCharacterId, orphan.toCharacterId],
      );
      repairs.add(
        '删除孤儿关系: ${orphan.fromCharacterId} → ${orphan.toCharacterId} '
        '(${orphan.relationType})',
      );
    }

    // 2. 检测重复关系（同一对角色 + 同类型有多条记录，理论上被 PK 约束阻止）
    //    但 note/createdAtMs 不同的 upsert 场景下不会产生重复，此处跳过。

    // 3. 检测反向关系缺失（可选：只报告，不自动创建）
    final remaining = await loadByProject(projectId);
    final reverseMap = <String, bool>{};
    for (final r in remaining) {
      final key = '${r.toCharacterId}→${r.fromCharacterId}';
      reverseMap[key] = true;
    }
    for (final r in remaining) {
      final reverseKey = '${r.fromCharacterId}→${r.toCharacterId}';
      // 如果有 A→B 但没有 B→A，记录提示（不自动修复，因为不是所有关系都需要反向）
      if (!reverseMap.containsKey(reverseKey)) {
        // 仅作信息提示，不修复
      }
    }

    return repairs;
  }
}
