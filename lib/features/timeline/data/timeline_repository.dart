import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide StoryEvent;
import '../domain/timeline_models.dart' as domain;

class TimelineRepository {
  final AppDatabase _db;

  TimelineRepository(this._db);

  Future<List<domain.StoryEvent>> getEvents(String workId) async {
    final query = _db.select(_db.events)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    final results = await query.get();
    return Future.wait(results.map(_toEvent).toList());
  }

  Future<domain.StoryEvent?> getEventById(String id) async {
    final query = _db.select(_db.events)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result == null ? null : _toEvent(result);
  }

  Future<domain.StoryEvent> createEvent({
    required String workId,
    required String name,
    domain.EventType type = domain.EventType.main,
    domain.EventImportance importance = domain.EventImportance.normal,
    String? storyTime,
    String? relativeTime,
    String? chapterId,
    String? locationId,
    List<String>? characterIds,
    String? description,
    String? consequences,
  }) async {
    final id = const Uuid().v4();

    await _db.into(_db.events).insert(
          EventsCompanion.insert(
            id: id,
            workId: workId,
            name: name,
            type: Value(type.name),
            importance: Value(importance.name),
            storyTime: Value(storyTime),
            relativeTime: Value(relativeTime),
            chapterId: Value(chapterId),
            locationId: Value(locationId),
            description: Value(description),
            consequences: Value(consequences),
            createdAt: DateTime.now(),
          ),
        );

    if (characterIds != null && characterIds.isNotEmpty) {
      for (final characterId in characterIds) {
        await _db.into(_db.eventCharacters).insert(
              EventCharactersCompanion.insert(
                eventId: id,
                characterId: characterId,
              ),
            );
      }
    }

    return (await getEventById(id))!;
  }

  Future<void> updateEvent(domain.StoryEvent event) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(event.id))).write(
      EventsCompanion(
        name: Value(event.name),
        type: Value(event.type.name),
        importance: Value(event.importance.name),
        storyTime: Value(event.storyTime),
        relativeTime: Value(event.relativeTime),
        chapterId: Value(event.chapterId),
        locationId: Value(event.locationId),
        description: Value(event.description),
        consequences: Value(event.consequences),
        predecessorId: Value(event.predecessorId),
        successorId: Value(event.successorId),
      ),
    );

    await (_db.delete(_db.eventCharacters)..where((t) => t.eventId.equals(event.id))).go();
    for (final characterId in event.characterIds) {
      await _db.into(_db.eventCharacters).insert(
            EventCharactersCompanion.insert(
              eventId: event.id,
              characterId: characterId,
            ),
          );
    }
  }

  Future<void> deleteEvent(String id) async {
    await (_db.delete(_db.eventCharacters)..where((t) => t.eventId.equals(id))).go();
    await (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();
  }

  Future<List<String>> getEventCharacters(String eventId) async {
    final query = _db.select(_db.eventCharacters)
      ..where((t) => t.eventId.equals(eventId));
    final results = await query.get();
    return results.map((r) => r.characterId).toList();
  }

  Future<List<domain.StoryEvent>> getCharacterEvents(String characterId) async {
    final links = await (_db.select(_db.eventCharacters)
          ..where((t) => t.characterId.equals(characterId)))
        .get();
    if (links.isEmpty) {
      return const [];
    }

    final eventIds = links.map((e) => e.eventId).toSet();
    final results = await (_db.select(_db.events)..where((t) => t.id.isIn(eventIds))).get();
    return Future.wait(results.map(_toEvent).toList());
  }

  Future<List<domain.TimeConflict>> detectConflicts(String workId) async {
    final conflicts = <domain.TimeConflict>[];
    final events = await getEvents(workId);
    final chapterCharacters = <String, Map<String, String>>{};

    for (final event in events) {
      if (event.chapterId == null || event.locationId == null) {
        continue;
      }

      for (final charId in event.characterIds) {
        final byChapter = chapterCharacters.putIfAbsent(event.chapterId!, () => {});
        final existingLocation = byChapter[charId];
        if (existingLocation != null && existingLocation != event.locationId) {
          conflicts.add(
            domain.TimeConflict(
              id: 'conflict_${conflicts.length}',
              type: domain.ConflictType.locationConflict,
              description:
                  'Character $charId appears in different locations in the same chapter.',
              eventId1: event.id,
              suggestion: 'Check whether the character location is consistent.',
            ),
          );
        }
        byChapter[charId] = event.locationId!;
      }
    }

    return conflicts;
  }

  Future<domain.StoryEvent> _toEvent(dynamic row) async {
    final characterIds = await getEventCharacters(row.id);
    return domain.StoryEvent(
      id: row.id,
      workId: row.workId,
      name: row.name,
      type: domain.EventType.values.firstWhere(
        (e) => e.name == row.type,
        orElse: () => domain.EventType.main,
      ),
      importance: domain.EventImportance.values.firstWhere(
        (e) => e.name == row.importance,
        orElse: () => domain.EventImportance.normal,
      ),
      storyTime: row.storyTime,
      relativeTime: row.relativeTime,
      chapterId: row.chapterId,
      locationId: row.locationId,
      characterIds: characterIds,
      description: row.description,
      consequences: row.consequences,
      predecessorId: row.predecessorId,
      successorId: row.successorId,
      createdAt: row.createdAt,
    );
  }
}
