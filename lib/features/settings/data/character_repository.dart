import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide Character, CharacterProfile;
import '../domain/character.dart' as domain;
import '../domain/character_profile.dart' as profile_domain;

class CharacterRepository {
  final AppDatabase _db;

  CharacterRepository(this._db);

  Future<List<domain.Character>> getCharactersByWorkId(
    String workId, {
    bool includeArchived = false,
    List<domain.CharacterTier>? tiers,
  }) async {
    final query = _db.select(_db.characters)
      ..where((t) => t.workId.equals(workId));

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }

    if (tiers != null && tiers.isNotEmpty) {
      query.where((t) => t.tier.isIn(tiers.map((e) => e.name)));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.tier)]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Character?> getCharacterById(String id) async {
    final query = _db.select(_db.characters)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result == null ? null : _toDomain(result);
  }

  Future<List<domain.Character>> searchCharacters(
    String workId,
    String query,
  ) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final searchPattern = '%$normalized%';
    final queryBuilder = _db.select(_db.characters)
      ..where(
        (t) =>
            t.workId.equals(workId) &
            t.isArchived.equals(false) &
            (t.name.like(searchPattern) |
                t.aliases.like(searchPattern) |
                t.identity.like(searchPattern) |
                t.bio.like(searchPattern)),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.tier),
        (t) => OrderingTerm.asc(t.name),
      ]);

    final results = await queryBuilder.get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Character?> getById(String id) => getCharacterById(id);

  Future<domain.Character> createCharacter(
    domain.CreateCharacterParams params,
  ) async {
    final id = _generateId();
    final now = DateTime.now();

    final companion = CharactersCompanion.insert(
      id: id,
      workId: params.workId,
      name: params.name,
      tier: params.tier.name,
      createdAt: now,
      updatedAt: now,
      aliases: Value<String?>(_encodeStringList(params.aliases)),
      avatarPath: Value<String?>(params.avatarPath),
      gender: Value<String?>(params.gender),
      age: Value<String?>(params.age),
      identity: Value<String?>(params.identity),
      bio: Value<String?>(params.bio),
    );

    await _db.into(_db.characters).insert(companion);
    return (await getCharacterById(id))!;
  }

  Future<void> updateCharacter(domain.Character character) async {
    await (_db.update(
      _db.characters,
    )..where((t) => t.id.equals(character.id))).write(
      CharactersCompanion(
        name: Value(character.name),
        aliases: Value<String?>(_encodeStringList(character.aliases)),
        tier: Value(character.tier.name),
        avatarPath: Value<String?>(character.avatarPath),
        gender: Value<String?>(character.gender),
        age: Value<String?>(character.age),
        identity: Value<String?>(character.identity),
        bio: Value<String?>(character.bio),
        lifeStatus: Value(character.lifeStatus.name),
        deathChapterId: Value<String?>(character.deathChapterId),
        deathReason: Value<String?>(character.deathReason),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archiveCharacter(String id) async {
    await (_db.update(_db.characters)..where((t) => t.id.equals(id))).write(
      CharactersCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateLifeStatus({
    required String id,
    required domain.LifeStatus status,
    String? deathChapterId,
    String? deathReason,
  }) async {
    await (_db.update(_db.characters)..where((t) => t.id.equals(id))).write(
      CharactersCompanion(
        lifeStatus: Value(status.name),
        deathChapterId: Value<String?>(deathChapterId),
        deathReason: Value<String?>(deathReason),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<profile_domain.CharacterProfile?> getProfile(
    String characterId,
  ) async {
    final query = _db.select(_db.characterProfiles)
      ..where((t) => t.characterId.equals(characterId));
    final result = await query.getSingleOrNull();
    return result == null ? null : _profileToDomain(result);
  }

  Future<void> saveProfile(profile_domain.CharacterProfile profile) async {
    await _db
        .into(_db.characterProfiles)
        .insertOnConflictUpdate(_profileToCompanion(profile));
  }

  String _generateId() => const Uuid().v4();

  domain.Character _toDomain(dynamic row) {
    return domain.Character(
      id: row.id,
      workId: row.workId,
      name: row.name,
      aliases: _decodeStringList(row.aliases),
      tier: domain.CharacterTier.values.firstWhere(
        (e) => e.name == row.tier,
        orElse: () => domain.CharacterTier.supporting,
      ),
      avatarPath: row.avatarPath,
      gender: row.gender,
      age: row.age,
      identity: row.identity,
      bio: row.bio,
      lifeStatus: domain.LifeStatus.values.firstWhere(
        (e) => e.name == row.lifeStatus,
        orElse: () => domain.LifeStatus.alive,
      ),
      deathChapterId: row.deathChapterId,
      deathReason: row.deathReason,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  profile_domain.CharacterProfile _profileToDomain(dynamic row) {
    return profile_domain.CharacterProfile(
      id: row.id,
      characterId: row.characterId,
      mbti: row.mbti == null
          ? null
          : profile_domain.MBTI.values.firstWhere(
              (e) => e.name == row.mbti,
              orElse: () => profile_domain.MBTI.intj,
            ),
      bigFive: row.bigFive == null
          ? null
          : profile_domain.BigFive.fromJson(
              jsonDecode(row.bigFive) as Map<String, dynamic>,
            ),
      personalityKeywords: _decodeStringList(row.personalityKeywords),
      coreValues: row.coreValues,
      fears: row.fears,
      desires: row.desires,
      moralBaseline: row.moralBaseline,
      speechStyle: row.speechStyle == null
          ? null
          : profile_domain.SpeechStyle.fromJson(
              jsonDecode(row.speechStyle) as Map<String, dynamic>,
            ),
      behaviorPatterns: row.behaviorPatterns == null
          ? const <profile_domain.BehaviorPattern>[]
          : (jsonDecode(row.behaviorPatterns) as List<dynamic>)
                .map(
                  (e) => profile_domain.BehaviorPattern.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  CharacterProfilesCompanion _profileToCompanion(
    profile_domain.CharacterProfile profile,
  ) {
    return CharacterProfilesCompanion(
      id: Value(profile.id),
      characterId: Value(profile.characterId),
      mbti: Value(profile.mbti?.name),
      bigFive: Value<String?>(
        profile.bigFive == null ? null : jsonEncode(profile.bigFive!.toJson()),
      ),
      personalityKeywords: Value<String?>(
        _encodeStringList(profile.personalityKeywords),
      ),
      coreValues: Value<String?>(profile.coreValues),
      fears: Value<String?>(profile.fears),
      desires: Value<String?>(profile.desires),
      moralBaseline: Value<String?>(profile.moralBaseline),
      speechStyle: Value<String?>(
        profile.speechStyle == null
            ? null
            : jsonEncode(profile.speechStyle!.toJson()),
      ),
      behaviorPatterns: Value<String?>(
        jsonEncode(profile.behaviorPatterns.map((e) => e.toJson()).toList()),
      ),
      createdAt: Value(profile.createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }

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

  String? _encodeStringList(List<String>? values) {
    if (values == null) {
      return null;
    }
    return jsonEncode(values);
  }
}
