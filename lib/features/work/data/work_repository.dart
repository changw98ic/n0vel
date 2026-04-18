import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide Work, Volume;
import '../domain/work.dart' as domain;

class WorkRepository {
  final AppDatabase _db;

  WorkRepository(this._db);

  Future<List<domain.Work>> getAllWorks({bool includeArchived = false}) async {
    final query = _db.select(_db.works);

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }

    query.orderBy([
      (t) => OrderingTerm.desc(t.isPinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Stream<List<domain.Work>> watchAllWorks({bool includeArchived = false}) {
    final query = _db.select(_db.works);

    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }

    query.orderBy([
      (t) => OrderingTerm.desc(t.isPinned),
      (t) => OrderingTerm.desc(t.updatedAt),
    ]);

    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<domain.Work?> getWorkById(String id) async {
    final query = _db.select(_db.works)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _toDomain(result) : null;
  }

  Future<domain.Work?> getById(String id) => getWorkById(id);

  Future<List<domain.Work>> searchWorks(String query) async {
    final searchPattern = '%$query%';
    final results = await (_db.select(_db.works)
          ..where(
            (t) => t.name.like(searchPattern) | t.description.like(searchPattern),
          ))
        .get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Work> createWork(CreateWorkParams params) async {
    final id = params.id ?? _generateId();
    final now = DateTime.now();

    await _db.into(_db.works).insert(
          WorksCompanion.insert(
            id: id,
            name: params.name,
            type: Value(params.type),
            description: Value(params.description),
            coverPath: Value(params.coverPath),
            targetWords: Value(params.targetWords),
            status: const Value('draft'),
            isPinned: const Value(false),
            isArchived: const Value(false),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (await getWorkById(id))!;
  }

  Future<domain.Work> updateWork(String id, UpdateWorkParams params) async {
    await (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        name: params.name == null ? const Value.absent() : Value(params.name!),
        type: Value(params.type),
        description: Value(params.description),
        coverPath: Value(params.coverPath),
        targetWords: Value(params.targetWords),
        status: params.status == null ? const Value.absent() : Value(params.status!),
        isPinned: params.isPinned == null ? const Value.absent() : Value(params.isPinned!),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return (await getWorkById(id))!;
  }

  Future<void> updateWordCount(String id, int wordCount) async {
    await (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        currentWords: Value(wordCount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> togglePin(String id) async {
    final work = await getWorkById(id);
    if (work == null) {
      return;
    }

    await (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        isPinned: Value(!work.isPinned),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archiveWork(String id) async {
    await (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreWork(String id) async {
    await (_db.update(_db.works)..where((t) => t.id.equals(id))).write(
      WorksCompanion(
        isArchived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteWork(String id) async {
    await (_db.delete(_db.works)..where((t) => t.id.equals(id))).go();
  }

  domain.Work _toDomain(dynamic data) {
    return domain.Work(
      id: data.id,
      name: data.name,
      type: data.type,
      description: data.description,
      coverPath: data.coverPath,
      targetWords: data.targetWords,
      currentWords: data.currentWords,
      status: data.status,
      isPinned: data.isPinned,
      isArchived: data.isArchived,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    );
  }

  String _generateId() => const Uuid().v4();
}

class CreateWorkParams {
  final String? id;
  final String name;
  final String? type;
  final String? description;
  final String? coverPath;
  final int? targetWords;

  CreateWorkParams({
    this.id,
    required this.name,
    this.type,
    this.description,
    this.coverPath,
    this.targetWords,
  });
}

class UpdateWorkParams {
  final String? name;
  final String? type;
  final String? description;
  final String? coverPath;
  final int? targetWords;
  final String? status;
  final bool? isPinned;

  UpdateWorkParams({
    this.name,
    this.type,
    this.description,
    this.coverPath,
    this.targetWords,
    this.status,
    this.isPinned,
  });
}
