import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';

class InspirationRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  InspirationRepository(this._db);

  // === Inspirations CRUD ===

  /// 获取所有素材（跨作品）
  Future<List<Inspiration>> getAll() async {
    final query = _db.select(_db.inspirations)
      ..orderBy([
        (t) => OrderingTerm.desc(t.priority),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.get();
  }

  /// 按分类获取所有素材（跨作品）
  Future<List<Inspiration>> getByCategoryAll(String category) async {
    final query = _db.select(_db.inspirations)
      ..where((t) => t.category.equals(category))
      ..orderBy([
        (t) => OrderingTerm.desc(t.priority),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.get();
  }

  /// 全文搜索所有素材（跨作品）
  Future<List<Inspiration>> searchAll(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final searchPattern = '%$normalized%';
    final q = _db.select(_db.inspirations)
      ..where(
        (t) =>
            (t.title.like(searchPattern) |
                t.content.like(searchPattern) |
                t.source.like(searchPattern)),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.priority),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return q.get();
  }

  /// 获取作品的所有素材
  Future<List<Inspiration>> getByWorkId(String? workId) async {
    final query = _db.select(_db.inspirations);

    if (workId == null) {
      query.where((t) => t.workId.isNull());
    } else {
      query.where((t) => t.workId.equals(workId));
    }

    query.orderBy([
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);

    return query.get();
  }

  /// 按分类获取
  Future<List<Inspiration>> getByCategory(
    String? workId,
    String category,
  ) async {
    final query = _db.select(_db.inspirations)
      ..where((t) => t.category.equals(category));

    if (workId == null) {
      query.where((t) => t.workId.isNull());
    } else {
      query.where((t) => t.workId.equals(workId));
    }

    query.orderBy([
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);

    return query.get();
  }

  /// 按标签搜索
  Future<List<Inspiration>> searchByTag(String? workId, String tag) async {
    // Tags are stored as a JSON array string, e.g. '["fantasy","magic"]'.
    // Use LIKE to match the tag within the JSON string.
    final tagPattern = '%$tag%';
    final query = _db.select(_db.inspirations)
      ..where((t) => t.tags.like(tagPattern));

    if (workId == null) {
      query.where((t) => t.workId.isNull());
    } else {
      query.where((t) => t.workId.equals(workId));
    }

    query.orderBy([
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);

    final results = await query.get();

    // Post-filter to ensure exact tag match (avoid partial LIKE matches)
    return results.where((row) {
      final tags = _decodeStringList(row.tags);
      return tags.contains(tag);
    }).toList();
  }

  /// 全文搜索
  Future<List<Inspiration>> search(String? workId, String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final searchPattern = '%$normalized%';
    final q = _db.select(_db.inspirations)
      ..where(
        (t) =>
            (t.title.like(searchPattern) |
                t.content.like(searchPattern) |
                t.source.like(searchPattern)),
      );

    if (workId == null) {
      q.where((t) => t.workId.isNull());
    } else {
      q.where((t) => t.workId.equals(workId));
    }

    q.orderBy([
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);

    return q.get();
  }

  /// 创建素材
  Future<Inspiration> create({
    required String title,
    required String content,
    String? workId,
    String category = 'idea',
    List<String>? tags,
    String? source,
    int priority = 0,
    String? color,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.inspirations).insert(
          InspirationsCompanion.insert(
            id: id,
            title: title,
            content: content,
            workId: Value(workId),
            category: Value(category),
            tags: Value(_encodeStringList(tags ?? [])),
            source: Value(source),
            priority: Value(priority),
            color: Value(color),
            createdAt: now,
            updatedAt: Value(now),
          ),
        );

    return (await (_db.select(_db.inspirations)
          ..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 更新素材
  Future<void> update(
    String id, {
    String? title,
    String? content,
    String? category,
    List<String>? tags,
    String? source,
    int? priority,
    String? color,
  }) async {
    await (_db.update(_db.inspirations)..where((t) => t.id.equals(id))).write(
      InspirationsCompanion(
        title: title == null ? const Value.absent() : Value(title),
        content: content == null ? const Value.absent() : Value(content),
        category:
            category == null ? const Value.absent() : Value(category),
        tags: tags == null ? const Value.absent() : Value(_encodeStringList(tags)),
        source: source == null ? const Value.absent() : Value(source),
        priority: priority == null ? const Value.absent() : Value(priority),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 删除素材
  Future<void> delete(String id) async {
    await (_db.delete(_db.inspirations)..where((t) => t.id.equals(id))).go();
  }

  // === Collections ===

  /// 获取所有集合
  Future<List<InspirationCollection>> getCollections(String? workId) async {
    final query = _db.select(_db.inspirationCollections);

    if (workId == null) {
      query.where((t) => t.workId.isNull());
    } else {
      query.where((t) => t.workId.equals(workId));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.sortOrder),
      (t) => OrderingTerm.desc(t.createdAt),
    ]);

    return query.get();
  }

  /// 创建集合
  Future<InspirationCollection> createCollection({
    required String name,
    String? workId,
    String? description,
    String? icon,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.into(_db.inspirationCollections).insert(
          InspirationCollectionsCompanion.insert(
            id: id,
            name: name,
            workId: Value(workId),
            description: Value(description),
            icon: Value(icon),
            createdAt: now,
          ),
        );

    return (await (_db.select(_db.inspirationCollections)
          ..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// 删除集合（不删素材）
  Future<void> deleteCollection(String collectionId) async {
    // First remove all items in the collection
    await (_db.delete(_db.inspirationCollectionItems)
          ..where((t) => t.collectionId.equals(collectionId)))
        .go();

    // Then delete the collection itself
    await (_db.delete(_db.inspirationCollections)
          ..where((t) => t.id.equals(collectionId)))
        .go();
  }

  /// 添加素材到集合
  Future<void> addToCollection(
    String collectionId,
    String inspirationId,
  ) async {
    final id = _uuid.v4();

    await _db.into(_db.inspirationCollectionItems).insert(
          InspirationCollectionItemsCompanion.insert(
            id: id,
            collectionId: collectionId,
            inspirationId: inspirationId,
          ),
        );
  }

  /// 从集合移除素材
  Future<void> removeFromCollection(
    String collectionId,
    String inspirationId,
  ) async {
    await (_db.delete(_db.inspirationCollectionItems)
          ..where(
            (t) =>
                t.collectionId.equals(collectionId) &
                t.inspirationId.equals(inspirationId),
          ))
        .go();
  }

  /// 获取集合中的所有素材
  Future<List<Inspiration>> getCollectionItems(String collectionId) async {
    final query = _db.select(_db.inspirations).join([
      innerJoin(
        _db.inspirationCollectionItems,
        _db.inspirationCollectionItems.inspirationId
            .equalsExp(_db.inspirations.id),
      ),
    ])
      ..where(_db.inspirationCollectionItems.collectionId.equals(collectionId))
      ..orderBy([
        OrderingTerm.asc(_db.inspirationCollectionItems.sortOrder),
        OrderingTerm.desc(_db.inspirations.priority),
      ]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.inspirations)).toList();
  }

  // === 统计 ===

  /// 获取各分类的数量
  Future<Map<String, int>> getCategoryCounts(String? workId) async {
    final query = _db.select(_db.inspirations);

    if (workId == null) {
      query.where((t) => t.workId.isNull());
    } else {
      query.where((t) => t.workId.equals(workId));
    }

    final results = await query.get();

    final counts = <String, int>{};
    for (final row in results) {
      counts[row.category] = (counts[row.category] ?? 0) + 1;
    }
    return counts;
  }

  /// 获取所有标签及其频率
  Future<Map<String, int>> getTagFrequency(String? workId) async {
    final query = _db.select(_db.inspirations);

    if (workId == null) {
      query.where((t) => t.workId.isNull());
    } else {
      query.where((t) => t.workId.equals(workId));
    }

    final results = await query.get();

    final frequency = <String, int>{};
    for (final row in results) {
      final tags = _decodeStringList(row.tags);
      for (final tag in tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }
    return frequency;
  }

  // === Helpers ===

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return const [];
  }

  String _encodeStringList(List<String> values) {
    return jsonEncode(values);
  }
}
