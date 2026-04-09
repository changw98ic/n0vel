import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart' hide Work, Volume;
import '../domain/volume.dart' as domain;

class VolumeRepository {
  final AppDatabase _db;

  VolumeRepository(this._db);

  Future<List<domain.Volume>> getVolumesByWorkId(String workId) async {
    final query = _db.select(_db.volumes)
      ..where((t) => t.workId.equals(workId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);

    final results = await query.get();
    return results.map(_toDomain).toList();
  }

  Future<domain.Volume?> getVolumeById(String id) async {
    final query = _db.select(_db.volumes)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? _toDomain(result) : null;
  }

  Future<domain.Volume> createVolume({
    required String workId,
    required String name,
    int sortOrder = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final existingVolumes = await getVolumesByWorkId(workId);
    final maxSortOrder = existingVolumes.isEmpty
        ? 0
        : existingVolumes
            .map((volume) => volume.sortOrder)
            .reduce((a, b) => a > b ? a : b);

    await _db.into(_db.volumes).insert(
          VolumesCompanion.insert(
            id: id,
            workId: workId,
            name: name,
            sortOrder: Value(sortOrder > 0 ? sortOrder : maxSortOrder + 1),
            createdAt: now,
          ),
        );

    return (await getVolumeById(id))!;
  }

  Future<void> updateName(String id, String name) async {
    await (_db.update(_db.volumes)..where((t) => t.id.equals(id))).write(
      VolumesCompanion(name: Value(name)),
    );
  }

  Future<void> updateSortOrder(String id, int sortOrder) async {
    await (_db.update(_db.volumes)..where((t) => t.id.equals(id))).write(
      VolumesCompanion(sortOrder: Value(sortOrder)),
    );
  }

  Future<void> deleteVolume(String id) async {
    await (_db.delete(_db.volumes)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorderVolumes(List<String> volumeIds) async {
    for (var i = 0; i < volumeIds.length; i++) {
      await updateSortOrder(volumeIds[i], i);
    }
  }

  domain.Volume _toDomain(dynamic data) {
    return domain.Volume(
      id: data.id,
      workId: data.workId,
      name: data.name,
      sortOrder: data.sortOrder,
      createdAt: data.createdAt,
    );
  }
}
