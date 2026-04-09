import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';

class StoryArcRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  StoryArcRepository(this._db);

  // === StoryArcs CRUD ===

  /// 获取作品的所有弧线
  Future<List<StoryArc>> getArcsByWorkId(String workId) async {
    final query = _db.select(_db.storyArcs)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.get();
  }

  /// 获取单条弧线
  Future<StoryArc?> getArc(String arcId) async {
    final query = _db.select(_db.storyArcs)
      ..where((t) => t.id.equals(arcId));
    return query.getSingleOrNull();
  }

  /// 创建弧线
  Future<StoryArc> createArc({
    required String workId,
    required String name,
    required String arcType,
    String? description,
    String? startChapterId,
    String? endChapterId,
    int sortOrder = 0,
    String status = 'active',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.storyArcs).insert(
          StoryArcsCompanion.insert(
            id: id,
            workId: workId,
            name: name,
            arcType: arcType,
            description: Value(description),
            startChapterId: Value(startChapterId),
            endChapterId: Value(endChapterId),
            sortOrder: Value(sortOrder),
            status: Value(status),
            createdAt: now,
            updatedAt: Value(now),
          ),
        );

    return (await getArc(id))!;
  }

  /// 更新弧线
  Future<void> updateArc(
    String arcId, {
    String? name,
    String? arcType,
    String? description,
    String? startChapterId,
    String? endChapterId,
    int? sortOrder,
    String? status,
    String? metadata,
  }) async {
    await (_db.update(_db.storyArcs)..where((t) => t.id.equals(arcId))).write(
      StoryArcsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        arcType: arcType == null ? const Value.absent() : Value(arcType),
        description: description == null
            ? const Value.absent()
            : Value(description),
        startChapterId: startChapterId == null
            ? const Value.absent()
            : Value(startChapterId),
        endChapterId: endChapterId == null
            ? const Value.absent()
            : Value(endChapterId),
        sortOrder: sortOrder == null
            ? const Value.absent()
            : Value(sortOrder),
        status: status == null ? const Value.absent() : Value(status),
        metadata: metadata == null ? const Value.absent() : Value(metadata),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除弧线（级联删除关联）
  Future<void> deleteArc(String arcId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.arcChapters)
            ..where((t) => t.arcId.equals(arcId)))
          .go();
      await (_db.delete(_db.arcCharacters)
            ..where((t) => t.arcId.equals(arcId)))
          .go();
      await (_db.delete(_db.storyArcs)..where((t) => t.id.equals(arcId)))
          .go();
    });
  }

  // === ArcChapters ===

  /// 获取弧线的所有章节
  Future<List<ArcChapter>> getArcChapters(String arcId) async {
    final query = _db.select(_db.arcChapters)
      ..where((t) => t.arcId.equals(arcId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.get();
  }

  /// 添加章节到弧线
  Future<ArcChapter> addChapterToArc({
    required String arcId,
    required String chapterId,
    String role = 'progression',
    String? note,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();

    await _db.into(_db.arcChapters).insert(
          ArcChaptersCompanion.insert(
            id: id,
            arcId: arcId,
            chapterId: chapterId,
            role: Value(role),
            note: Value(note),
            sortOrder: Value(sortOrder),
          ),
        );

    final query = _db.select(_db.arcChapters)
      ..where((t) => t.id.equals(id));
    return query.getSingle();
  }

  /// 移除章节 from 弧线
  Future<void> removeChapterFromArc(String arcId, String chapterId) async {
    await (_db.delete(_db.arcChapters)
          ..where((t) => t.arcId.equals(arcId) & t.chapterId.equals(chapterId)))
        .go();
  }

  /// 获取章节参与的所有弧线
  Future<List<StoryArc>> getArcsByChapterId(String chapterId) async {
    final query = _db.select(_db.storyArcs).join([
      innerJoin(
        _db.arcChapters,
        _db.arcChapters.arcId.equalsExp(_db.storyArcs.id),
      ),
    ])
      ..where(_db.arcChapters.chapterId.equals(chapterId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.storyArcs)).toList();
  }

  // === ArcCharacters ===

  /// 获取弧线的所有角色
  Future<List<ArcCharacter>> getArcCharacters(String arcId) async {
    final query = _db.select(_db.arcCharacters)
      ..where((t) => t.arcId.equals(arcId));
    return query.get();
  }

  /// 添加角色到弧线
  Future<ArcCharacter> addCharacterToArc({
    required String arcId,
    required String characterId,
    String role = 'participant',
    String? note,
  }) async {
    final id = _uuid.v4();

    await _db.into(_db.arcCharacters).insert(
          ArcCharactersCompanion.insert(
            id: id,
            arcId: arcId,
            characterId: characterId,
            role: Value(role),
            note: Value(note),
          ),
        );

    final query = _db.select(_db.arcCharacters)
      ..where((t) => t.id.equals(id));
    return query.getSingle();
  }

  /// 移除角色 from 弧线
  Future<void> removeCharacterFromArc(
    String arcId,
    String characterId,
  ) async {
    await (_db.delete(_db.arcCharacters)
          ..where(
            (t) => t.arcId.equals(arcId) & t.characterId.equals(characterId),
          ))
        .go();
  }

  /// 获取角色参与的所有弧线
  Future<List<StoryArc>> getArcsByCharacterId(String characterId) async {
    final query = _db.select(_db.storyArcs).join([
      innerJoin(
        _db.arcCharacters,
        _db.arcCharacters.arcId.equalsExp(_db.storyArcs.id),
      ),
    ])
      ..where(_db.arcCharacters.characterId.equals(characterId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.storyArcs)).toList();
  }

  // === Foreshadows ===

  /// 获取作品的所有伏笔
  Future<List<Foreshadow>> getForeshadowsByWorkId(String workId) async {
    final query = _db.select(_db.foreshadows)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  /// 获取未回收的伏笔
  Future<List<Foreshadow>> getUnresolvedForeshadows(String workId) async {
    final query = _db.select(_db.foreshadows)
      ..where(
        (t) =>
            t.workId.equals(workId) &
            t.status.isNotIn(['paid_off', 'abandoned']),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }

  /// 创建伏笔
  Future<Foreshadow> createForeshadow({
    required String workId,
    required String description,
    String? plantChapterId,
    int? plantParagraphIndex,
    String? payoffChapterId,
    int? payoffParagraphIndex,
    String status = 'planted',
    String importance = 'minor',
    String? arcId,
    String? note,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.foreshadows).insert(
          ForeshadowsCompanion.insert(
            id: id,
            workId: workId,
            description: description,
            plantChapterId: Value(plantChapterId),
            plantParagraphIndex: Value(plantParagraphIndex),
            payoffChapterId: Value(payoffChapterId),
            payoffParagraphIndex: Value(payoffParagraphIndex),
            status: Value(status),
            importance: Value(importance),
            arcId: Value(arcId),
            note: Value(note),
            createdAt: now,
            updatedAt: Value(now),
          ),
        );

    final query = _db.select(_db.foreshadows)
      ..where((t) => t.id.equals(id));
    return query.getSingle();
  }

  /// 更新伏笔状态
  Future<void> updateForeshadowStatus(
    String foreshadowId,
    String status, {
    String? payoffChapterId,
    int? payoffParagraphIndex,
  }) async {
    await (_db.update(_db.foreshadows)
          ..where((t) => t.id.equals(foreshadowId)))
        .write(
      ForeshadowsCompanion(
        status: Value(status),
        payoffChapterId: payoffChapterId == null
            ? const Value.absent()
            : Value(payoffChapterId),
        payoffParagraphIndex: payoffParagraphIndex == null
            ? const Value.absent()
            : Value(payoffParagraphIndex),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除伏笔
  Future<void> deleteForeshadow(String foreshadowId) async {
    await (_db.delete(_db.foreshadows)
          ..where((t) => t.id.equals(foreshadowId)))
        .go();
  }

  /// 获取弧线关联的伏笔
  Future<List<Foreshadow>> getForeshadowsByArcId(String arcId) async {
    final query = _db.select(_db.foreshadows)
      ..where((t) => t.arcId.equals(arcId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return query.get();
  }
}
