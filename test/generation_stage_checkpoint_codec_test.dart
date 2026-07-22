import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_stage_checkpoint_codec.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const codec = GenerationStageCheckpointCodec();
  const provenance = GenerationCheckpointProvenance(
    baseDraftDigest: _a,
    materialDigest: _b,
    promptDigest: _c,
    modelDigest: _d,
  );

  test('selects only the latest continuous, hash-bound prefix', () async {
    final zero = await _completed(
      codec: codec,
      ordinal: 0,
      upstream: await _chain(const []),
    );
    final one = await _completed(
      codec: codec,
      ordinal: 1,
      upstream: await _chain([zero]),
    );
    final selection = await codec.selectLatestCompatible(
      checkpoints: [zero, one],
      provenance: provenance,
    );

    expect(selection.nextOrdinal, 2);
    expect(selection.reusable, hasLength(2));
  });

  test(
    'fails closed at a tampered artifact, leaving valid prefix reusable',
    () async {
      final zero = await _completed(
        codec: codec,
        ordinal: 0,
        upstream: await _chain(const []),
      );
      final one = await _completed(
        codec: codec,
        ordinal: 1,
        upstream: await _chain([zero]),
      );
      final selection = await codec.selectLatestCompatible(
        checkpoints: [
          zero,
          one.copyWith(artifactJson: const {'forged': true}),
        ],
        provenance: provenance,
      );

      expect(selection.nextOrdinal, 1);
      expect(selection.reusable.single.ordinal, 0);
    },
  );

  test(
    'fails closed on upstream gap or changed prompt/model/material',
    () async {
      final two = await _completed(
        codec: codec,
        ordinal: 2,
        upstream: await _chain(const []),
      );
      final gap = await codec.selectLatestCompatible(
        checkpoints: [two],
        provenance: provenance,
      );
      expect(gap.nextOrdinal, 0);

      final zero = await _completed(
        codec: codec,
        ordinal: 0,
        upstream: await _chain(const []),
      );
      final changed = await codec.selectLatestCompatible(
        checkpoints: [zero],
        provenance: const GenerationCheckpointProvenance(
          baseDraftDigest: _a,
          materialDigest: _b,
          promptDigest: _e,
          modelDigest: _d,
        ),
      );
      expect(changed.nextOrdinal, 0);
    },
  );

  test(
    'ledger adapter persists checkpoints in their prose-revision namespace',
    () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      db.execute('PRAGMA foreign_keys = ON');
      final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
      db.execute('''
      INSERT INTO story_generation_runs (
        run_id, request_id, project_id, chapter_id, scene_id, scene_scope_id,
        status, phase, schema_version, created_at_ms, updated_at_ms
      ) VALUES ('run', 'request', 'project', 'chapter', 'scene', 'project::scene',
        'running', 'draft', 13, 1, 1)
    ''');
      db.execute('''
      INSERT INTO story_generation_working_prose_revisions (
        run_id, prose_revision, prose_hash, prose_text, source_kind, created_at_ms
      ) VALUES ('run', 1, 'sha256:test-revision-1', '作者改稿', 'authorEdit', 1)
    ''');
      final adapter = GenerationLedgerCheckpointStore(
        ledger: ledger,
        provenance: provenance,
      );
      await adapter.save(
        await _completed(
          codec: codec,
          ordinal: 0,
          upstream: await _chain(const []),
          proseRevision: 1,
        ),
      );

      final rows = ledger.loadStageCheckpoints(runId: 'run');
      expect(rows, hasLength(1));
      expect(rows.single.proseRevision, 1);
    },
  );
}

Future<PipelineStageCheckpoint> _completed({
  required GenerationStageCheckpointCodec codec,
  required int ordinal,
  required String upstream,
  int proseRevision = 0,
}) async {
  final stageId = GenerationStageOrdinals.ids[ordinal]!;
  final artifact = await codec.encode(
    ordinal: ordinal,
    stageId: stageId,
    artifactType: 'testArtifact',
    payload: {'safe': ordinal},
  );
  return PipelineStageCheckpoint(
    runId: 'run',
    proseRevision: proseRevision,
    ordinal: ordinal,
    stageId: stageId,
    stageAttempt: 1,
    schemaVersion: GenerationStageCheckpointCodec.version,
    inputDigest: _a,
    artifactDigest: await GenerationCheckpointDigest.of(artifact),
    upstreamChainDigest: upstream,
    provenance: const GenerationCheckpointProvenance(
      baseDraftDigest: _a,
      materialDigest: _b,
      promptDigest: _c,
      modelDigest: _d,
    ),
    status: 'completed',
    createdAtMs: 1,
    completedAtMs: 2,
    artifactType: 'testArtifact',
    artifactJson: artifact,
  );
}

Future<String> _chain(List<PipelineStageCheckpoint> checkpoints) =>
    GenerationCheckpointDigest.of({
      'root': 'stage-checkpoint-v2',
      'upstream': [
        for (final checkpoint in checkpoints)
          {
            'ordinal': checkpoint.ordinal,
            'stageId': checkpoint.stageId,
            'artifactDigest': checkpoint.artifactDigest,
          },
      ],
    });

const _a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _c = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _d = 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _e = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

extension on PipelineStageCheckpoint {
  PipelineStageCheckpoint copyWith({Map<String, Object?>? artifactJson}) =>
      PipelineStageCheckpoint(
        runId: runId,
        ordinal: ordinal,
        stageId: stageId,
        stageAttempt: stageAttempt,
        schemaVersion: schemaVersion,
        inputDigest: inputDigest,
        artifactDigest: artifactDigest,
        upstreamChainDigest: upstreamChainDigest,
        provenance: provenance,
        status: status,
        createdAtMs: createdAtMs,
        completedAtMs: completedAtMs,
        artifactType: artifactType,
        artifactJson: artifactJson ?? this.artifactJson,
      );
}
