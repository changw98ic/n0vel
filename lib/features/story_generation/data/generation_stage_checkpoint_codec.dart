import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'generation_ledger.dart';
import 'generation_ledger_models.dart';
import 'pipeline_stage_runner_impl.dart';
import 'step_editorial_io.dart';
import 'step_context_enrichment_io.dart';
import 'step_scene_planning_io.dart';
import 'step_roleplay_io.dart';
import 'step_stage_narration_io.dart';
import 'step_beat_resolution_io.dart';
import 'step_polish_io.dart';
import 'step_review_io.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_review_models.dart';
import 'scene_runtime_models.dart';
import 'scene_context_models.dart';
import '../domain/scene_models.dart' show ProjectMaterialSnapshot;
import '../domain/contracts/typed_artifact.dart';

/// Fixed production ordering.  Keep this mapping out of UI snapshots so an
/// unknown stage can never be accidentally resumed as a neighbouring one.
class GenerationStageOrdinals {
  const GenerationStageOrdinals._();

  static const ids = <int, String>{
    0: 'context_enrichment',
    1: 'director',
    2: 'roleplay',
    3: 'stage_narration',
    4: 'beat_resolution',
    5: 'editorial',
    6: 'preliminary_review',
    7: 'polish',
    8: 'deterministic_gate',
    9: 'final_review',
    10: 'prose_derived_extraction',
    11: 'quality_gate',
    12: 'finalization',
  };

  static bool matches(int ordinal, String stageId) => ids[ordinal] == stageId;
}

/// Canonical digest helper shared by checkpoint writer and verifier. SHA-256
/// detects accidental/local tampering; it is not a MAC. Local disk attackers
/// who can edit both SQLite and this process's data can forge SHA values. A
/// future platform-keystore HMAC can be added to this envelope without
/// changing the checkpoint selection contract.
class GenerationCheckpointDigest {
  const GenerationCheckpointDigest._();

  static String canonicalJson(Object? value) => jsonEncode(_canonical(value));

  static Future<String> of(Object? value) async {
    final digest = await Sha256().hash(utf8.encode(canonicalJson(value)));
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final entries =
          value.entries
              .map((entry) => MapEntry(entry.key.toString(), entry.value))
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return {for (final entry in entries) entry.key: _canonical(entry.value)};
    }
    if (value is Iterable) return [for (final item in value) _canonical(item)];
    return value;
  }
}

/// Only allowlisted JSON envelopes reach disk. It deliberately strips fields
/// with names that could carry credentials, raw provider requests/responses,
/// errors, or live store handles. The pipeline's typed artifact codecs may add
/// safe, presentation-independent DTO fields under `payload`.
class GenerationStageCheckpointCodec {
  const GenerationStageCheckpointCodec();

  static const version = 2;

  Future<Map<String, Object?>> encode({
    required int ordinal,
    required String stageId,
    required String artifactType,
    required Map<String, Object?> payload,
  }) async {
    if (!GenerationStageOrdinals.matches(ordinal, stageId)) {
      throw const GenerationLedgerInvariantViolation('unknown stage ordinal');
    }
    final clean = _sanitize(payload);
    final envelope = <String, Object?>{
      'codec': 'generation-stage-artifact',
      'version': version,
      'ordinal': ordinal,
      'stageId': stageId,
      'artifactType': artifactType,
      'payload': clean,
    };
    return envelope;
  }

  Future<bool> validate({
    required PipelineStageCheckpoint checkpoint,
    required GenerationCheckpointProvenance provenance,
    required String expectedUpstreamChainDigest,
  }) async {
    if (!checkpoint.isCompleted ||
        checkpoint.schemaVersion != version ||
        !GenerationStageOrdinals.matches(
          checkpoint.ordinal,
          checkpoint.stageId,
        ) ||
        checkpoint.upstreamChainDigest != expectedUpstreamChainDigest ||
        !_sameProvenance(checkpoint.provenance, provenance)) {
      return false;
    }
    final json = checkpoint.artifactJson;
    if (json['codec'] != 'generation-stage-artifact' ||
        json['version'] != version ||
        json['ordinal'] != checkpoint.ordinal ||
        json['stageId'] != checkpoint.stageId ||
        json['artifactType'] != checkpoint.artifactType ||
        json['payload'] is! Map) {
      return false;
    }
    return checkpoint.artifactDigest ==
        await GenerationCheckpointDigest.of(json);
  }

  /// Returns the newest *continuous* reusable prefix. A duplicate ordinal is
  /// accepted only when its highest attempt validates; malformed/unknown rows,
  /// a gap, or any provenance change terminates the prefix before that stage.
  /// The caller dispatches ordinal `nextOrdinal`, never trusts a suffix.
  Future<GenerationCheckpointResumeSelection> selectLatestCompatible({
    required List<PipelineStageCheckpoint> checkpoints,
    required GenerationCheckpointProvenance provenance,
  }) async {
    final byOrdinal = <int, PipelineStageCheckpoint>{};
    for (final checkpoint in checkpoints) {
      if (!GenerationStageOrdinals.matches(
        checkpoint.ordinal,
        checkpoint.stageId,
      )) {
        continue;
      }
      final previous = byOrdinal[checkpoint.ordinal];
      if (previous == null || checkpoint.stageAttempt > previous.stageAttempt) {
        byOrdinal[checkpoint.ordinal] = checkpoint;
      }
    }
    final reusable = <PipelineStageCheckpoint>[];
    for (var ordinal = 0; ordinal <= 12; ordinal++) {
      final checkpoint = byOrdinal[ordinal];
      if (checkpoint == null) break;
      final upstream = await _chainFor(reusable);
      if (!await validate(
        checkpoint: checkpoint,
        provenance: provenance,
        expectedUpstreamChainDigest: upstream,
      )) {
        break;
      }
      reusable.add(checkpoint);
    }
    return GenerationCheckpointResumeSelection(
      reusable: List.unmodifiable(reusable),
      nextOrdinal: reusable.length,
    );
  }

  Future<String> _chainFor(List<PipelineStageCheckpoint> upstream) {
    return GenerationCheckpointDigest.of({
      'root': 'stage-checkpoint-v2',
      'upstream': [
        for (final checkpoint in upstream)
          {
            'ordinal': checkpoint.ordinal,
            'stageId': checkpoint.stageId,
            'artifactDigest': checkpoint.artifactDigest,
          },
      ],
    });
  }

  bool _sameProvenance(
    GenerationCheckpointProvenance left,
    GenerationCheckpointProvenance right,
  ) =>
      left.baseDraftDigest == right.baseDraftDigest &&
      left.materialDigest == right.materialDigest &&
      left.promptDigest == right.promptDigest &&
      left.modelDigest == right.modelDigest;

  Map<String, Object?> _sanitize(Map<String, Object?> value) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final lower = key.toLowerCase();
      if (lower.contains('credential') ||
          lower.contains('secret') ||
          lower.contains('token') ||
          lower.contains('authorization') ||
          lower.contains('rawrequest') ||
          lower.contains('rawresponse') ||
          lower.contains('error') ||
          lower.contains('store') ||
          lower.contains('handle')) {
        continue;
      }
      result[key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      return _sanitize({
        for (final entry in value.entries) entry.key.toString(): entry.value,
      });
    }
    if (value is Iterable) {
      return [for (final item in value) _sanitizeValue(item)];
    }
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    throw const GenerationLedgerInvariantViolation(
      'checkpoint payload must contain JSON-safe allowlisted DTO values',
    );
  }
}

class GenerationCheckpointResumeSelection {
  const GenerationCheckpointResumeSelection({
    required this.reusable,
    required this.nextOrdinal,
  });

  final List<PipelineStageCheckpoint> reusable;
  final int nextOrdinal;

  PipelineStageCheckpoint? operator [](int ordinal) =>
      ordinal >= 0 && ordinal < reusable.length ? reusable[ordinal] : null;
}

/// The initial allowlist intentionally covers artifacts that contain no
/// provider request/response or private-memory handles. Unsupported shapes
/// return null so the runner recomputes at that exact boundary rather than
/// rebuilding an approximation.
class GenerationStageArtifactRestorer {
  const GenerationStageArtifactRestorer();

  Future<TypedArtifact?> call(
    PipelineStageCheckpoint checkpoint,
    TypedArtifact input,
  ) async {
    final payload = checkpoint.artifactJson['payload'];
    if (payload is! Map) return null;
    final value = {
      for (final entry in payload.entries) entry.key.toString(): entry.value,
    };
    return switch (checkpoint.ordinal) {
      0 => _context(value, input),
      1 => _plan(value, input),
      2 => _roleplay(value),
      3 => _narration(value),
      4 => _beats(value, input),
      5 => _editorial(value),
      6 || 9 => _review(value),
      7 => _polish(value),
      _ => null,
    };
  }

  ContextEnrichmentOutput? _context(
    Map<String, Object?> value,
    TypedArtifact input,
  ) {
    if (value['resumeSafe'] != true || input is! ContextEnrichmentInput) {
      return null;
    }
    return ContextEnrichmentOutput(
      effectiveMaterials: input.materials ?? const ProjectMaterialSnapshot(),
    );
  }

  ScenePlanningOutput? _plan(Map<String, Object?> value, TypedArtifact input) {
    if (input is! ScenePlanningInput || value['resumeSafe'] != true) {
      return null;
    }
    final rawCast = value['cast'];
    if (rawCast is! List) return null;
    final cast = <ResolvedSceneCastMember>[];
    for (final raw in rawCast) {
      if (raw is! Map) return null;
      final entry = {
        for (final item in raw.entries) item.key.toString(): item.value,
      };
      final contributions = <SceneCastContribution>[];
      final names = entry['contributions'];
      if (names is! List) return null;
      for (final name in names) {
        final match = SceneCastContribution.values.where(
          (value) => value.name == name.toString(),
        );
        if (match.length != 1) return null;
        contributions.add(match.single);
      }
      final id = entry['characterId'];
      final name = entry['name'];
      final role = entry['role'];
      if (id is! String || name is! String || role is! String) return null;
      cast.add(
        ResolvedSceneCastMember(
          characterId: id,
          name: name,
          role: role,
          contributions: contributions,
        ),
      );
    }
    final directorText = value['directorText'];
    final directorPlan = value['directorPlan'];
    if (directorText is! String || directorPlan is! String) return null;
    return ScenePlanningOutput(
      resolvedCast: cast,
      consistencyConstraints: value['constraints'] as String?,
      director: SceneDirectorOutput(text: directorText),
      taskCard: pipeline.SceneTaskCard(
        brief: input.brief,
        cast: cast,
        directorPlan: directorPlan,
      ),
    );
  }

  RoleplayOutput? _roleplay(Map<String, Object?> value) {
    // Roleplay sessions may carry private cognition; do not persist/rebuild
    // them unless an explicit future redacted DTO is introduced.
    if (value['resumeSafe'] != true) return null;
    final raw = value['roleOutputs'];
    if (raw is! List) return null;
    final outputs = <DynamicRoleAgentOutput>[];
    for (final item in raw) {
      if (item is! Map) return null;
      final id = item['characterId'];
      final name = item['name'];
      final text = item['text'];
      if (id is! String || name is! String || text is! String) return null;
      outputs.add(
        DynamicRoleAgentOutput(characterId: id, name: name, text: text),
      );
    }
    return RoleplayOutput(roleOutputs: outputs, roleTurns: const []);
  }

  StageNarrationOutput? _narration(Map<String, Object?> value) {
    if (value['resumeSafe'] != true) return null;
    return const StageNarrationOutput(capsules: []);
  }

  BeatResolutionOutput? _beats(
    Map<String, Object?> value,
    TypedArtifact input,
  ) {
    if (value['resumeSafe'] != true || input is! BeatResolutionInput) {
      return null;
    }
    return BeatResolutionOutput(
      resolvedBeats: const [],
      runtimeBeats: const [],
      sceneState: SceneState.initial(sceneId: input.brief.sceneId),
    );
  }

  EditorialOutput? _editorial(Map<String, Object?> value) {
    final text = value['proseText'];
    final draft = value['draftText'];
    final attempt = _int(value['attempt']);
    final beatCount = _int(value['draftBeatCount']);
    if (text is! String || draft is! String || attempt <= 0 || beatCount < 0) {
      return null;
    }
    return EditorialOutput(
      draft: pipeline.SceneEditorialDraft(
        text: draft,
        beatCount: beatCount,
        attempt: _int(value['draftAttempt'], fallback: attempt),
        sourceLogicalAttemptId: value['sourceLogicalAttemptId'] as String?,
        sourceCallSiteId: value['sourceCallSiteId'] as String?,
      ),
      prose: SceneProseDraft(text: text, attempt: attempt),
    );
  }

  PolishOutput? _polish(Map<String, Object?> value) {
    final text = value['proseText'];
    final attempt = _int(value['attempt']);
    if (text is! String || attempt <= 0) return null;
    return PolishOutput(
      prose: SceneProseDraft(text: text, attempt: attempt),
      sourceLogicalAttemptId: value['sourceLogicalAttemptId'] as String?,
      sourceCallSiteId: value['sourceCallSiteId'] as String?,
    );
  }

  ReviewOutput? _review(Map<String, Object?> value) {
    final judge = _pass(value['judge']);
    final consistency = _pass(value['consistency']);
    final action = _decision(value['action']);
    final decision = _decision(value['decision']);
    if (judge == null ||
        consistency == null ||
        action == null ||
        decision == null) {
      return null;
    }
    return ReviewOutput(
      review: SceneReviewResult(
        judge: judge,
        consistency: consistency,
        decision: decision,
      ),
      wasLengthRetry: value['wasLengthRetry'] == true,
      action: action,
    );
  }

  SceneReviewPassResult? _pass(Object? raw) {
    if (raw is! Map) return null;
    final value = {
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    final statusName = value['status']?.toString();
    final status = SceneReviewStatus.values.where(
      (item) => item.name == statusName,
    );
    if (status.length != 1) return null;
    final categories = <SceneReviewCategory>[];
    final rawCategories = value['categories'];
    if (rawCategories is List) {
      for (final item in rawCategories) {
        final found = SceneReviewCategory.values.where(
          (value) => value.name == item.toString(),
        );
        if (found.length != 1) return null;
        categories.add(found.single);
      }
    }
    return SceneReviewPassResult(
      status: status.single,
      reason: value['reason']?.toString() ?? '',
      rawText: value['rawText']?.toString() ?? '',
      categories: categories,
    );
  }

  SceneReviewDecision? _decision(Object? raw) {
    final found = SceneReviewDecision.values.where(
      (item) => item.name == raw?.toString(),
    );
    return found.length == 1 ? found.single : null;
  }

  int _int(Object? raw, {int fallback = 0}) =>
      raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? fallback;
}

/// Durable adapter used by production runs. It retains snapshot compatibility
/// at the UI edge, but resume authority lives in the V10 SQLite ledger.
class GenerationLedgerCheckpointStore implements PipelineCheckpointStore {
  GenerationLedgerCheckpointStore({
    required GenerationLedgerSqliteStore ledger,
    required GenerationCheckpointProvenance provenance,
  }) : _ledger = ledger,
       _provenance = provenance;

  final GenerationLedgerSqliteStore _ledger;
  final GenerationCheckpointProvenance _provenance;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async {
    return [
      for (final row in _ledger.loadStageCheckpoints(runId: runId))
        PipelineStageCheckpoint(
          runId: row.runId,
          proseRevision: row.proseRevision,
          ordinal: row.ordinal,
          stageId: row.stageId,
          stageAttempt: row.stageAttempt,
          schemaVersion: row.codecVersion,
          inputDigest: row.inputDigest,
          artifactDigest: row.artifactDigest,
          upstreamChainDigest: row.upstreamChainDigest,
          provenance: row.provenance,
          status: row.status,
          createdAtMs: row.createdAtMs,
          completedAtMs: row.completedAtMs,
          artifactType: row.artifactType,
          artifactJson: _object(row.artifactJson),
        ),
    ];
  }

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    if (checkpoint.provenance.baseDraftDigest != _provenance.baseDraftDigest ||
        checkpoint.provenance.materialDigest != _provenance.materialDigest ||
        checkpoint.provenance.promptDigest != _provenance.promptDigest ||
        checkpoint.provenance.modelDigest != _provenance.modelDigest) {
      throw const GenerationLedgerInvariantViolation(
        'checkpoint provenance does not belong to this run',
      );
    }
    _ledger.saveStageCheckpoint(
      GenerationStageCheckpointRecord(
        runId: checkpoint.runId,
        proseRevision: checkpoint.proseRevision,
        ordinal: checkpoint.ordinal,
        stageId: checkpoint.stageId,
        stageAttempt: checkpoint.stageAttempt,
        codecVersion: checkpoint.schemaVersion,
        status: checkpoint.status,
        inputDigest: checkpoint.inputDigest,
        artifactDigest: checkpoint.artifactDigest,
        upstreamChainDigest: checkpoint.upstreamChainDigest,
        provenance: checkpoint.provenance,
        createdAtMs: checkpoint.createdAtMs,
        completedAtMs: checkpoint.completedAtMs,
        artifactType: checkpoint.artifactType,
        artifactJson: GenerationCheckpointDigest.canonicalJson(
          checkpoint.artifactJson,
        ),
      ),
    );
  }

  Map<String, Object?> _object(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            entry.key.toString(): entry.value,
        };
      }
    } on FormatException {
      // A malformed disk row is surfaced as an empty envelope, then rejected
      // by the codec's fail-closed selection path.
    }
    return const {};
  }
}
