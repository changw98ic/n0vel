import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../domain/contracts/structured_profile.dart';

class ProfileStructuredStore {
  ProfileStructuredStore({required this.db});

  final Database db;
  bool _migrated = false;

  Future<void> ensureTables() async {
    if (_migrated) return;
    db.execute('''
      CREATE TABLE IF NOT EXISTS structured_profiles (
        project_id TEXT NOT NULL,
        profile_id TEXT NOT NULL,
        name TEXT NOT NULL,
        data TEXT NOT NULL,
        PRIMARY KEY (project_id, profile_id)
      )
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_structured_profiles_project
      ON structured_profiles (project_id)
    ''');
    _migrated = true;
  }

  Future<void> saveProfile({
    required String projectId,
    required StructuredProfile profile,
  }) async {
    await ensureTables();
    db.execute(
      '''
      INSERT OR REPLACE INTO structured_profiles (project_id, profile_id, name, data)
      VALUES (?, ?, ?, ?)
      ''',
      [projectId, profile.id, profile.name, jsonEncode(profile.toJson())],
    );
  }

  Future<StructuredProfile?> loadProfile({
    required String projectId,
    required String profileId,
  }) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM structured_profiles WHERE project_id = ? AND profile_id = ?',
      [projectId, profileId],
    );
    if (rows.isEmpty) return null;
    return _decode(rows.first['data'] as String);
  }

  Future<List<StructuredProfile>> loadProfiles({
    required String projectId,
  }) async {
    await ensureTables();
    final rows = db.select(
      'SELECT data FROM structured_profiles WHERE project_id = ? ORDER BY profile_id',
      [projectId],
    );
    return [for (final row in rows) _decode(row['data'] as String)];
  }

  Future<void> deleteProfile({
    required String projectId,
    required String profileId,
  }) async {
    await ensureTables();
    db.execute(
      'DELETE FROM structured_profiles WHERE project_id = ? AND profile_id = ?',
      [projectId, profileId],
    );
  }

  Future<void> clearProject(String projectId) async {
    await ensureTables();
    db.execute('DELETE FROM structured_profiles WHERE project_id = ?', [
      projectId,
    ]);
  }

  StructuredProfile _decode(String raw) {
    return StructuredProfile.fromJson(
      Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
  }
}
