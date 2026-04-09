import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide Item, Location;
import '../domain/item.dart' as domain;

class ItemRepository {
  final AppDatabase _db;

  ItemRepository(this._db);

  Future<List<domain.Item>> getItemsByWorkId(
    String workId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.items)..where((t) => t.workId.equals(workId));

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Item?> getItemById(String id) async {
    final query = _db.select(_db.items)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result == null ? null : _toDomain(result);
  }

  Future<List<domain.Item>> searchItems(String workId, String query) async {
    final searchPattern = '%$query%';
    final results = await (_db.select(_db.items)
          ..where(
            (t) =>
                t.workId.equals(workId) &
                (t.name.like(searchPattern) | t.description.like(searchPattern)),
          ))
        .get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Item> createItem({
    required String workId,
    required String name,
    String? type,
    String? rarity,
    String? description,
    List<String>? abilities,
    String? holderId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.items).insert(
          ItemsCompanion.insert(
            id: id,
            workId: workId,
            name: name,
            type: Value<String?>(type),
            rarity: Value<String?>(rarity),
            description: Value<String?>(description),
            abilities: Value<String?>(abilities == null ? null : jsonEncode(abilities)),
            holderId: Value<String?>(holderId),
            isArchived: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (await getItemById(id))!;
  }

  Future<void> updateItem(
    String id, {
    String? name,
    String? type,
    String? rarity,
    String? description,
    List<String>? abilities,
    String? holderId,
  }) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        type: Value<String?>(type),
        rarity: Value<String?>(rarity),
        description: Value<String?>(description),
        abilities: Value<String?>(abilities == null ? null : jsonEncode(abilities)),
        holderId: Value<String?>(holderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archiveItem(String id) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(isArchived: Value(true)),
    );
  }

  Future<void> restoreItem(String id) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id))).write(
      const ItemsCompanion(isArchived: Value(false)),
    );
  }

  Future<void> deleteItem(String id) async {
    await (_db.delete(_db.items)..where((t) => t.id.equals(id))).go();
  }

  Future<List<domain.Item>> getItemsByHolder(String characterId) async {
    final query = _db.select(_db.items)
      ..where((t) => t.holderId.equals(characterId) & t.isArchived.equals(false));
    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  domain.Item _toDomain(dynamic row) {
    return domain.Item(
      id: row.id,
      workId: row.workId,
      name: row.name,
      type: row.type,
      rarity: row.rarity,
      iconPath: row.iconPath,
      description: row.description,
      abilities: row.abilities == null
          ? const []
          : (jsonDecode(row.abilities) as List<dynamic>)
              .map((e) => e.toString())
              .toList(),
      holderId: row.holderId,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
