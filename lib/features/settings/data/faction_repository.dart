import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide Faction, FactionMember, StoryEvent;
import '../domain/faction.dart' as domain;

class FactionRepository {
  final AppDatabase _db;

  FactionRepository(this._db);

  Future<List<domain.Faction>> getFactionsByWorkId(
    String workId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.factions)..where((t) => t.workId.equals(workId));

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Faction?> getFactionById(String id) async {
    final query = _db.select(_db.factions)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result == null ? null : _toDomain(result);
  }

  Future<List<domain.Faction>> searchFactions(String workId, String query) async {
    final searchPattern = '%$query%';
    final results = await (_db.select(_db.factions)
          ..where(
            (t) =>
                t.workId.equals(workId) &
                (t.name.like(searchPattern) | t.description.like(searchPattern)),
          ))
        .get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Faction> createFaction({
    required String workId,
    required String name,
    String? type,
    String? description,
    List<String>? traits,
    String? leaderId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.factions).insert(
          FactionsCompanion.insert(
            id: id,
            workId: workId,
            name: name,
            type: Value<String?>(type),
            description: Value<String?>(description),
            traits: Value<String?>(traits == null ? null : jsonEncode(traits)),
            leaderId: Value<String?>(leaderId),
            isArchived: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (await getFactionById(id))!;
  }

  Future<void> updateFaction(
    String id, {
    String? name,
    String? type,
    String? description,
    List<String>? traits,
    String? leaderId,
  }) async {
    await (_db.update(_db.factions)..where((t) => t.id.equals(id))).write(
      FactionsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        type: Value<String?>(type),
        description: Value<String?>(description),
        traits: Value<String?>(traits == null ? null : jsonEncode(traits)),
        leaderId: Value<String?>(leaderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archiveFaction(String id) async {
    await (_db.update(_db.factions)..where((t) => t.id.equals(id))).write(
      const FactionsCompanion(isArchived: Value(true)),
    );
  }

  Future<void> deleteFaction(String id) async {
    await (_db.delete(_db.factions)..where((t) => t.id.equals(id))).go();
  }

  Future<List<domain.FactionMember>> getFactionMembers(String factionId) async {
    final query = _db.select(_db.factionMembers)
      ..where((t) => t.factionId.equals(factionId));

    final results = await query.get();
    return results
        .map(
          (row) => domain.FactionMember(
            id: row.id,
            factionId: row.factionId,
            characterId: row.characterId,
            role: row.role,
            joinChapterId: row.joinChapterId,
            leaveChapterId: row.leaveChapterId,
            status: row.status,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  Future<void> addMember({
    required String factionId,
    required String characterId,
    String? role,
    String? joinChapterId,
  }) async {
    final id = const Uuid().v4();

    await _db.into(_db.factionMembers).insert(
          FactionMembersCompanion.insert(
            id: id,
            factionId: factionId,
            characterId: characterId,
            role: Value<String?>(role),
            joinChapterId: Value<String?>(joinChapterId),
            status: const Value('active'),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> removeMember(String memberId, {String? leaveChapterId}) async {
    await (_db.update(_db.factionMembers)..where((t) => t.id.equals(memberId))).write(
      FactionMembersCompanion(
        status: const Value('left'),
        leaveChapterId: Value<String?>(leaveChapterId),
      ),
    );
  }

  Future<List<domain.Faction>> getFactionsByCharacter(String characterId) async {
    final memberQuery = _db.select(_db.factionMembers)
      ..where((t) => t.characterId.equals(characterId) & t.status.equals('active'));

    final members = await memberQuery.get();
    final factionIds = members.map((m) => m.factionId).toSet();
    if (factionIds.isEmpty) {
      return const [];
    }

    final factionQuery = _db.select(_db.factions)
      ..where((t) => t.id.isIn(factionIds) & t.isArchived.equals(false));

    final results = await factionQuery.get();
    return results.map(_toDomain).toList();
  }

  domain.Faction _toDomain(dynamic row) {
    return domain.Faction(
      id: row.id,
      workId: row.workId,
      name: row.name,
      type: row.type,
      emblemPath: row.emblemPath,
      description: row.description,
      traits: row.traits == null
          ? const []
          : (jsonDecode(row.traits) as List<dynamic>)
              .map((e) => e.toString())
              .toList(),
      leaderId: row.leaderId,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
