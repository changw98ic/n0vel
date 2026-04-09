import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../domain/relationship.dart' as domain;
import '../../../core/models/value_objects/emotion_dimensions.dart';

class RelationshipRepository {
  final AppDatabase _db;

  RelationshipRepository(this._db);

  /// 获取角色的所有关系
  Future<List<domain.RelationshipHead>> getRelationshipsByCharacterId(
    String characterId,
  ) async {
    final query = _db.select(_db.relationshipHeads)
      ..where(
        (t) =>
            t.characterAId.equals(characterId) |
            t.characterBId.equals(characterId),
      );

    final results = await query.get();
    return results.map(_toDomainHead).toList();
  }

  /// 获取关系的所有事件
  Future<List<domain.RelationshipEvent>> getEventsByHeadId(
    String headId,
  ) async {
    final query = _db.select(_db.relationshipEvents)
      ..where((t) => t.headId.equals(headId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final results = await query.get();
    return results.map(_toDomainEvent).toList();
  }

  /// 获取两个角色之间的关系
  Future<domain.RelationshipHead?> getRelationshipBetween(
    String characterAId,
    String characterBId,
  ) async {
    final key = domain.RelationshipHead.getKey(characterAId, characterBId);
    final query = _db.select(_db.relationshipHeads)
      ..where((t) => t.id.equals(key));

    final result = await query.getSingleOrNull();
    return result == null ? null : _toDomainHead(result);
  }

  /// 创建关系
  Future<domain.RelationshipHead> createRelationship({
    required String workId,
    required String characterAId,
    required String characterBId,
    required domain.RelationType relationType,
    EmotionDimensions? emotionDimensions,
    String? chapterId,
    String? changeReason,
  }) async {
    // 规范化：确保 id 小的是 A
    final sortedIds = [characterAId, characterBId]..sort();
    final normalizedA = sortedIds[0];
    final normalizedB = sortedIds[1];

    final id = domain.RelationshipHead.getKey(normalizedA, normalizedB);
    final now = DateTime.now();

    final companion = RelationshipHeadsCompanion.insert(
      id: id,
      workId: workId,
      characterAId: normalizedA,
      characterBId: normalizedB,
      relationType: relationType.name,
      emotionDimensions: Value<String?>(
        emotionDimensions == null
            ? null
            : jsonEncode(emotionDimensions.toJson()),
      ),
      firstChapterId: Value<String?>(chapterId),
      latestChapterId: Value<String?>(chapterId),
      eventCount: const Value(1),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.relationshipHeads).insert(companion);

    // 创建初始事件
    await _createRelationshipEvent(
      headId: id,
      chapterId: chapterId ?? '',
      changeType: domain.ChangeType.create,
      newRelationType: relationType,
      newEmotionDimensions: emotionDimensions,
      changeReason: changeReason,
      isKeyEvent: true,
    );

    return (await getRelationshipBetween(characterAId, characterBId))!;
  }

  /// 更新关系
  Future<void> updateRelationship({
    required String headId,
    required domain.RelationType newRelationType,
    EmotionDimensions? newEmotionDimensions,
    String? chapterId,
    String? changeReason,
    domain.ChangeType changeType = domain.ChangeType.update,
    bool isKeyEvent = false,
  }) async {
    final now = DateTime.now();

    // 获取当前关系状态
    final current = await (_db.select(
      _db.relationshipHeads,
    )..where((t) => t.id.equals(headId))).getSingleOrNull();
    if (current == null) return;

    // 更新关系头
    await (_db.update(
      _db.relationshipHeads,
    )..where((t) => t.id.equals(headId))).write(
      RelationshipHeadsCompanion(
        relationType: Value(newRelationType.name),
        emotionDimensions: Value<String?>(
          newEmotionDimensions == null
              ? null
              : jsonEncode(newEmotionDimensions.toJson()),
        ),
        latestChapterId: Value<String?>(chapterId),
        eventCount: Value(current.eventCount + 1),
        updatedAt: Value(now),
      ),
    );

    // 创建变更事件
    await _createRelationshipEvent(
      headId: headId,
      chapterId: chapterId ?? current.latestChapterId ?? '',
      changeType: changeType,
      prevRelationType: domain.RelationType.values.firstWhere(
        (e) => e.name == current.relationType,
        orElse: () => domain.RelationType.neutral,
      ),
      newRelationType: newRelationType,
      prevEmotionDimensions: current.emotionDimensions == null
          ? null
          : EmotionDimensions.fromJson(
              jsonDecode(current.emotionDimensions!) as Map<String, dynamic>,
            ),
      newEmotionDimensions: newEmotionDimensions,
      changeReason: changeReason,
      isKeyEvent: isKeyEvent,
    );
  }

  Future<void> _createRelationshipEvent({
    required String headId,
    required String chapterId,
    required domain.ChangeType changeType,
    domain.RelationType? prevRelationType,
    required domain.RelationType newRelationType,
    EmotionDimensions? prevEmotionDimensions,
    EmotionDimensions? newEmotionDimensions,
    String? changeReason,
    required bool isKeyEvent,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final companion = RelationshipEventsCompanion.insert(
      id: id,
      headId: headId,
      chapterId: chapterId,
      changeType: changeType.name,
      prevRelationType: Value<String?>(prevRelationType?.name),
      newRelationType: newRelationType.name,
      prevEmotionDimensions: Value<String?>(
        prevEmotionDimensions == null
            ? null
            : jsonEncode(prevEmotionDimensions.toJson()),
      ),
      newEmotionDimensions: Value<String?>(
        newEmotionDimensions == null
            ? null
            : jsonEncode(newEmotionDimensions.toJson()),
      ),
      changeReason: Value<String?>(changeReason),
      isKeyEvent: Value(isKeyEvent),
      createdAt: now,
    );

    await _db.into(_db.relationshipEvents).insert(companion);
  }

  /// 获取作品的关系列表
  Future<List<domain.RelationshipHead>> getRelationshipsByWorkId(
    String workId,
  ) async {
    final query = _db.select(_db.relationshipHeads)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    final results = await query.get();
    return results.map(_toDomainHead).toList();
  }

  /// 删除关系及其所有事件
  Future<void> deleteRelationship(String headId) async {
    await (_db.delete(
      _db.relationshipEvents,
    )..where((t) => t.headId.equals(headId))).go();
    await (_db.delete(
      _db.relationshipHeads,
    )..where((t) => t.id.equals(headId))).go();
  }

  domain.RelationshipHead _toDomainHead(dynamic row) {
    return domain.RelationshipHead(
      id: row.id,
      workId: row.workId,
      characterAId: row.characterAId,
      characterBId: row.characterBId,
      relationType: domain.RelationType.values.firstWhere(
        (e) => e.name == row.relationType,
        orElse: () => domain.RelationType.neutral,
      ),
      emotionDimensions: row.emotionDimensions == null
          ? null
          : EmotionDimensions.fromJson(
              jsonDecode(row.emotionDimensions) as Map<String, dynamic>,
            ),
      firstChapterId: row.firstChapterId,
      latestChapterId: row.latestChapterId,
      eventCount: row.eventCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  domain.RelationshipEvent _toDomainEvent(dynamic row) {
    return domain.RelationshipEvent(
      id: row.id,
      headId: row.headId,
      chapterId: row.chapterId,
      changeType: domain.ChangeType.values.firstWhere(
        (e) => e.name == row.changeType,
        orElse: () => domain.ChangeType.update,
      ),
      prevRelationType: row.prevRelationType == null
          ? null
          : domain.RelationType.values.firstWhere(
              (e) => e.name == row.prevRelationType,
              orElse: () => domain.RelationType.neutral,
            ),
      newRelationType: domain.RelationType.values.firstWhere(
        (e) => e.name == row.newRelationType,
        orElse: () => domain.RelationType.neutral,
      ),
      prevEmotionDimensions: row.prevEmotionDimensions == null
          ? null
          : EmotionDimensions.fromJson(
              jsonDecode(row.prevEmotionDimensions) as Map<String, dynamic>,
            ),
      newEmotionDimensions: row.newEmotionDimensions == null
          ? null
          : EmotionDimensions.fromJson(
              jsonDecode(row.newEmotionDimensions) as Map<String, dynamic>,
            ),
      changeReason: row.changeReason,
      isKeyEvent: row.isKeyEvent,
      createdAt: row.createdAt,
    );
  }
}
