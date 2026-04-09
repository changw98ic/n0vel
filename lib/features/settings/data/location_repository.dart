import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide Item, Location;
import '../domain/location.dart' as domain;

class LocationRepository {
  final AppDatabase _db;

  LocationRepository(this._db);

  Future<List<domain.Location>> getLocationsByWorkId(
    String workId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.locations)..where((t) => t.workId.equals(workId));

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<List<domain.Location>> getTopLevelLocations(String workId) async {
    final query = _db.select(_db.locations)
      ..where(
        (t) =>
            t.workId.equals(workId) &
            t.parentId.isNull() &
            t.isArchived.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<List<domain.Location>> getChildLocations(String parentId) async {
    final query = _db.select(_db.locations)
      ..where((t) => t.parentId.equals(parentId) & t.isArchived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Location?> getLocationById(String id) async {
    final query = _db.select(_db.locations)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result == null ? null : _toDomain(result);
  }

  Future<List<domain.Location>> searchLocations(String workId, String query) async {
    final searchPattern = '%$query%';
    final results = await (_db.select(_db.locations)
          ..where(
            (t) =>
                t.workId.equals(workId) &
                (t.name.like(searchPattern) | t.description.like(searchPattern)),
          ))
        .get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Location> createLocation({
    required String workId,
    required String name,
    String? type,
    String? parentId,
    String? description,
    List<String>? importantPlaces,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.locations).insert(
          LocationsCompanion.insert(
            id: id,
            workId: workId,
            name: name,
            type: Value<String?>(type),
            parentId: Value<String?>(parentId),
            description: Value<String?>(description),
            importantPlaces: Value<String?>(
              importantPlaces == null ? null : jsonEncode(importantPlaces),
            ),
            isArchived: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (await getLocationById(id))!;
  }

  Future<void> updateLocation(
    String id, {
    String? name,
    String? type,
    String? parentId,
    String? description,
    List<String>? importantPlaces,
  }) async {
    await (_db.update(_db.locations)..where((t) => t.id.equals(id))).write(
      LocationsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        type: Value<String?>(type),
        parentId: Value<String?>(parentId),
        description: Value<String?>(description),
        importantPlaces: Value<String?>(
          importantPlaces == null ? null : jsonEncode(importantPlaces),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archiveLocation(String id) async {
    await (_db.update(_db.locations)..where((t) => t.id.equals(id))).write(
      const LocationsCompanion(isArchived: Value(true)),
    );
  }

  Future<void> deleteLocation(String id) async {
    await (_db.delete(_db.locations)..where((t) => t.id.equals(id))).go();
  }

  /// 查找重复地点（按 workId 分组，名称相似）
  Future<List<List<domain.Location>>> findDuplicateLocations(
    String workId,
  ) async {
    final allLocations = await getLocationsByWorkId(workId, includeArchived: true);
    final groups = <String, List<domain.Location>>{};

    // 按名称精确分组
    for (final loc in allLocations) {
      final key = loc.name.trim().toLowerCase();
      groups.putIfAbsent(key, () => []).add(loc);
    }

    // 只返回有重复的组（>= 2个）
    return groups.values.where((g) => g.length >= 2).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// 合并重复地点
  /// [keepId] 保留的地点 ID
  /// [removeIds] 要合并删除的地点 ID 列表
  Future<void> mergeLocations(
    String keepId,
    List<String> removeIds,
  ) async {
    await _db.transaction(() async {
      // 1. 获取保留地点的 importantPlaces
      final keepLoc = await getLocationById(keepId);
      final keepPlaces = <String>{
        ...?keepLoc?.importantPlaces,
      };

      for (final removeId in removeIds) {
        // 2. 合并 importantPlaces
        final removeLoc = await getLocationById(removeId);
        if (removeLoc != null) {
          keepPlaces.addAll(removeLoc.importantPlaces);
        }

        // 3. 重定向子地点的 parentId
        await (_db.update(_db.locations)
              ..where((t) => t.parentId.equals(removeId)))
            .write(
          LocationsCompanion(
            parentId: Value(keepId),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // 4. 重定向 LocationCharacters 关联
        await (_db.update(_db.locationCharacters)
              ..where((t) => t.locationId.equals(removeId)))
            .write(
          LocationCharactersCompanion(
            locationId: Value(keepId),
          ),
        );

        // 5. 删除重复地点
        await (_db.delete(_db.locations)..where((t) => t.id.equals(removeId)))
            .go();
      }

      // 6. 更新保留地点的 importantPlaces（去重合并）
      await (_db.update(_db.locations)..where((t) => t.id.equals(keepId)))
          .write(
        LocationsCompanion(
          importantPlaces: Value(jsonEncode(keepPlaces.toList())),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<LocationNode>> getLocationTree(String workId) async {
    final allLocations = await getLocationsByWorkId(workId);
    final topLevel = allLocations.where((location) => location.parentId == null).toList();
    return topLevel.map((location) => _buildNode(location, allLocations)).toList();
  }

  LocationNode _buildNode(
    domain.Location location,
    List<domain.Location> allLocations,
  ) {
    final children = allLocations
        .where((child) => child.parentId == location.id)
        .map((child) => _buildNode(child, allLocations))
        .toList();

    return LocationNode(location: location, children: children);
  }

  domain.Location _toDomain(dynamic row) {
    return domain.Location(
      id: row.id,
      workId: row.workId,
      name: row.name,
      type: row.type,
      parentId: row.parentId,
      description: row.description,
      importantPlaces: row.importantPlaces == null
          ? const []
          : (jsonDecode(row.importantPlaces) as List<dynamic>)
              .map((e) => e.toString())
              .toList(),
      characterIds: const [],
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

class LocationNode {
  final domain.Location location;
  final List<LocationNode> children;

  LocationNode({
    required this.location,
    required this.children,
  });
}
