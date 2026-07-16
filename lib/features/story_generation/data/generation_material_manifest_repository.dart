import 'dart:convert';

import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../app/state/authoring_table_definitions.dart';
import '../domain/scene_models.dart';

/// SQLite-native MaterialDigest.v1 source journal. Source adapters write only
/// stable identity/revision/hash triples; raw prompt material stays in its
/// authoritative store and is never copied into the ledger.
class GenerationMaterialManifestRepository {
  GenerationMaterialManifestRepository({required this.db});

  final Database db;

  void ensureTables() => createStoryGenerationMaterialManifestTables(db);

  void upsertSource({
    required String projectId,
    required String sceneId,
    required String sourceKind,
    required String sourceId,
    required String revisionToken,
    required String contentHash,
    required int updatedAtMs,
  }) {
    _require(projectId, 'projectId');
    _require(sceneId, 'sceneId');
    _require(sourceKind, 'sourceKind');
    _require(sourceId, 'sourceId');
    _require(revisionToken, 'revisionToken');
    _require(contentHash, 'contentHash');
    ensureTables();
    db.execute(
      '''
      INSERT INTO story_generation_material_sources (
        project_id, scene_id, source_kind, source_id, revision_token,
        content_hash, updated_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(project_id, scene_id, source_kind, source_id) DO UPDATE SET
        revision_token = excluded.revision_token,
        content_hash = excluded.content_hash,
        updated_at_ms = excluded.updated_at_ms
      ''',
      [
        projectId,
        sceneId,
        sourceKind,
        sourceId,
        revisionToken,
        contentHash,
        updatedAtMs,
      ],
    );
  }

  void replaceCanonicalSource({
    required String projectId,
    required String sceneId,
    required String sourceKind,
    required String sourceId,
    required Object? canonicalContent,
    required int updatedAtMs,
  }) {
    final canonical = _canonicalJson(canonicalContent);
    final hash = _hash(canonical);
    upsertSource(
      projectId: projectId,
      sceneId: sceneId,
      sourceKind: sourceKind,
      sourceId: sourceId,
      revisionToken: hash,
      contentHash: hash,
      updatedAtMs: updatedAtMs,
    );
  }

  void deleteSource({
    required String projectId,
    required String sceneId,
    required String sourceKind,
    required String sourceId,
  }) {
    ensureTables();
    db.execute(
      '''DELETE FROM story_generation_material_sources
         WHERE project_id = ? AND scene_id = ?
           AND source_kind = ? AND source_id = ?''',
      [projectId, sceneId, sourceKind, sourceId],
    );
  }

  GenerationMaterialManifest buildCurrent({
    required String projectId,
    required String sceneId,
  }) {
    ensureTables();
    final sources = db.select(
      '''
      SELECT source_kind, source_id, revision_token, content_hash
      FROM story_generation_material_sources
      WHERE project_id = ? AND (scene_id = ? OR scene_id = '*')
      ORDER BY source_kind, source_id
      ''',
      [projectId, sceneId],
    );
    final entries = [
      for (final row in sources)
        <String, Object?>{
          'kind': row['source_kind'],
          'id': row['source_id'],
          'revision': row['revision_token'],
          'hash': row['content_hash'],
        },
    ];
    final manifest = _canonicalJson({
      'version': 'MaterialDigest.v1',
      'projectId': projectId,
      'sceneId': sceneId,
      'sources': entries,
    });
    return GenerationMaterialManifest(
      materialDigest: _hash(manifest),
      manifestJson: manifest,
    );
  }

  bool hasFrozenManifest(String runId) {
    ensureTables();
    return db.select(
      'SELECT 1 FROM story_generation_material_manifests WHERE run_id = ?',
      [runId],
    ).isNotEmpty;
  }

  GenerationMaterialManifest freezeSnapshot({
    required String runId,
    required String projectId,
    required String sceneId,
    required ProjectMaterialSnapshot materials,
    required int nowMs,
  }) {
    ensureTables();
    final existing = db.select(
      '''SELECT material_digest, manifest_json
         FROM story_generation_material_manifests WHERE run_id = ?''',
      [runId],
    );
    if (existing.length == 1) {
      return GenerationMaterialManifest(
        materialDigest: existing.single['material_digest'] as String,
        manifestJson: existing.single['manifest_json'] as String,
      );
    }
    _journalSnapshot(
      projectId: projectId,
      sceneId: sceneId,
      materials: materials,
      nowMs: nowMs,
    );
    final manifest = buildCurrent(projectId: projectId, sceneId: sceneId);
    db.execute(
      '''
      INSERT INTO story_generation_material_manifests (
        run_id, project_id, scene_id, material_digest, manifest_json, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(run_id) DO NOTHING
      ''',
      [
        runId,
        projectId,
        sceneId,
        manifest.materialDigest,
        manifest.manifestJson,
        nowMs,
      ],
    );
    return manifest;
  }

  void _journalSnapshot({
    required String projectId,
    required String sceneId,
    required ProjectMaterialSnapshot materials,
    required int nowMs,
  }) {
    final groups = <String, List<String>>{
      'world': materials.worldFacts,
      'characterProfile': materials.characterProfiles,
      'relationship': materials.relationshipHints,
      'outline': materials.outlineBeats,
      'sceneContext': materials.sceneSummaries,
      'review': materials.reviewFindings,
      'acceptedState': materials.acceptedStates,
    };
    for (final group in groups.entries) {
      for (final content in group.value) {
        final hash = _hash(content);
        upsertSource(
          projectId: projectId,
          sceneId: sceneId,
          sourceKind: group.key,
          sourceId: hash,
          revisionToken: hash,
          contentHash: hash,
          updatedAtMs: nowMs,
        );
      }
    }
  }

  void _require(String value, String field) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, field);
  }
}

class GenerationMaterialManifest {
  const GenerationMaterialManifest({
    required this.materialDigest,
    required this.manifestJson,
  });

  final String materialDigest;
  final String manifestJson;
}

String _hash(String input) {
  final digest = const DartSha256().hashSync(utf8.encode(input));
  return 'sha256:${digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in entries) entry.key: _canonical(entry.value)};
  }
  if (value is Iterable) return [for (final entry in value) _canonical(entry)];
  return value;
}
