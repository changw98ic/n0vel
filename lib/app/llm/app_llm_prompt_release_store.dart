import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../state/authoring_table_definitions.dart';
import 'app_llm_canonical_hash.dart';
import 'app_llm_prompt_release.dart';

final class PromptReleaseLifecycleEvent {
  const PromptReleaseLifecycleEvent({
    required this.releaseRef,
    required this.event,
    required this.reason,
    required this.occurredAt,
  });

  final PromptReleaseRef releaseRef;
  final String event;
  final String reason;
  final DateTime occurredAt;
}

/// SQLite persistence for immutable prompt and bundle identities.
///
/// Inserts are idempotent only when the full canonical snapshot is identical.
/// An existing logical identity with different content is treated as a
/// collision and fails closed. Reads reconstruct every object through its
/// hash-checking constructor before returning it.
final class AppLlmPromptReleaseStore {
  AppLlmPromptReleaseStore({required this.db});

  static final String releaseHash = AppLlmCanonicalHash.domainHash(
    'app-llm-prompt-release-store-release-v1',
    const <String, Object?>{
      'write': 'immutable-logical-identity-with-canonical-snapshot-check',
      'read': 'constructor-reconstruction-and-content-hash-verification',
      'database': 'sqlite-trigger-and-foreign-key-authority',
    },
  );

  final Database db;

  void ensureTables() => createAgentEvaluationTables(db);

  void putPromptRelease(PromptRelease release) {
    ensureTables();
    if (!release.hasValidContentHash) {
      throw StateError('PromptRelease failed in-memory hash validation');
    }
    final variables = AppLlmCanonicalHash.canonicalJson(
      release.variablesSchemaSnapshot,
    );
    final output = AppLlmCanonicalHash.canonicalJson(
      release.outputSchemaSnapshot,
    );
    final repair = AppLlmCanonicalHash.canonicalJson(
      release.repairPolicySnapshot,
    );
    db.execute(
      '''
      INSERT OR IGNORE INTO prompt_releases (
        release_id, template_id, semantic_version, language, content_hash,
        system_template, user_template, variables_schema_json,
        output_schema_json, renderer_release, parser_release,
        repair_policy_json, variables_schema_hash, output_schema_hash,
        owner, change_note, created_at_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        _releaseId(release.ref),
        release.templateId,
        release.semanticVersion,
        release.language,
        _rawHash(release.contentHash),
        release.systemTemplate,
        release.userTemplate,
        variables,
        output,
        release.rendererRelease,
        release.parserRelease,
        repair,
        _rawDomainHash(
          'prompt-variables-schema-v1',
          release.variablesSchemaSnapshot,
        ),
        _rawDomainHash('prompt-output-schema-v1', release.outputSchemaSnapshot),
        release.owner,
        release.changeNote,
        release.createdAt.toUtc().millisecondsSinceEpoch,
      ],
    );
    final stored = getPromptRelease(release.ref);
    if (!_samePromptSnapshot(stored, release)) {
      throw StateError(
        'immutable PromptRelease identity already contains different content: '
        '${release.templateId}@${release.semanticVersion}/${release.language}',
      );
    }
  }

  PromptRelease getPromptRelease(PromptReleaseRef ref) {
    ensureTables();
    final rows = db.select(
      '''
      SELECT * FROM prompt_releases
      WHERE template_id = ? AND semantic_version = ? AND language = ?
      ''',
      [ref.templateId, ref.semanticVersion, ref.language],
    );
    if (rows.length != 1) {
      throw StateError('unknown PromptRelease: ${ref.templateId}');
    }
    final release = _promptFromRow(rows.single);
    if (release.contentHash != ref.contentHash) {
      throw StateError('PromptRelease ref/hash mismatch: ${ref.templateId}');
    }
    return release;
  }

  void appendLifecycleEvent(PromptReleaseLifecycleEvent event) {
    ensureTables();
    getPromptRelease(event.releaseRef);
    final kind = event.event.trim();
    final reason = event.reason.trim();
    if (kind.isEmpty || reason.isEmpty) {
      throw ArgumentError('lifecycle event and reason are required');
    }
    db.execute(
      '''
      INSERT INTO prompt_release_lifecycle_events (
        event_id, release_id, event, reason, created_at_ms
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [
        _rawDomainHash('prompt-release-lifecycle-event-v1', <Object?>[
          event.releaseRef.toJson(),
          kind,
          reason,
          event.occurredAt.toUtc().millisecondsSinceEpoch,
        ]),
        _releaseId(event.releaseRef),
        kind,
        reason,
        event.occurredAt.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  List<PromptReleaseLifecycleEvent> lifecycleEvents(PromptReleaseRef ref) {
    getPromptRelease(ref);
    return List<PromptReleaseLifecycleEvent>.unmodifiable(
      db
          .select(
            '''
            SELECT event, reason, created_at_ms
            FROM prompt_release_lifecycle_events
            WHERE release_id = ?
            ORDER BY created_at_ms, event_id
            ''',
            [_releaseId(ref)],
          )
          .map(
            (row) => PromptReleaseLifecycleEvent(
              releaseRef: ref,
              event: row['event'] as String,
              reason: row['reason'] as String,
              occurredAt: DateTime.fromMillisecondsSinceEpoch(
                row['created_at_ms'] as int,
                isUtc: true,
              ),
            ),
          ),
    );
  }

  void putGenerationBundle(GenerationBundle bundle) {
    ensureTables();
    _inImmediateTransaction(() {
      for (final binding in bundle.releases) {
        getPromptRelease(binding.promptReleaseRef);
      }
      final releasesJson = AppLlmCanonicalHash.canonicalJson([
        for (final binding in bundle.releases) binding.toJson(),
      ]);
      final existing = db.select(
        'SELECT bundle_hash FROM generation_bundles WHERE bundle_id = ?',
        <Object?>[bundle.bundleId],
      );
      if (existing.isNotEmpty &&
          (existing.length != 1 ||
              existing.single['bundle_hash'] != _rawHash(bundle.bundleHash))) {
        throw StateError(
          'immutable GenerationBundle id already refers to another hash',
        );
      }
      db.execute(
        '''INSERT OR IGNORE INTO generation_bundles
           (bundle_hash, bundle_id, releases_json, created_at_ms)
           VALUES (?, ?, ?, ?)''',
        [_rawHash(bundle.bundleHash), bundle.bundleId, releasesJson, _nowMs()],
      );
      for (final binding in bundle.releases) {
        db.execute(
          '''INSERT OR IGNORE INTO generation_bundle_releases (
               bundle_hash, stage_id, call_site_id, variant_id, prompt_release_id
             ) VALUES (?, ?, ?, ?, ?)''',
          <Object?>[
            _rawHash(bundle.bundleHash),
            binding.stageId,
            binding.callSiteId,
            binding.variantId,
            _releaseId(binding.promptReleaseRef),
          ],
        );
      }
      final stored = getGenerationBundle(bundle.bundleId);
      if (stored.bundleHash != bundle.bundleHash ||
          AppLlmCanonicalHash.canonicalJson([
                for (final binding in stored.releases) binding.toJson(),
              ]) !=
              releasesJson) {
        throw StateError(
          'immutable GenerationBundle identity already contains different content',
        );
      }
    });
  }

  GenerationBundle getGenerationBundle(String bundleId) {
    ensureTables();
    final rows = db.select(
      'SELECT * FROM generation_bundles WHERE bundle_id = ?',
      [bundleId],
    );
    if (rows.length != 1) {
      throw StateError('unknown GenerationBundle: $bundleId');
    }
    final row = rows.single;
    final releases = _jsonList(row['releases_json'] as String)
        .map((value) {
          final json = _jsonMap(value);
          return GenerationBundleBinding(
            stageId: json['stageId'] as String,
            callSiteId: json['callSiteId'] as String,
            variantId: json['variantId'] as String,
            promptReleaseRef: _promptRef(_jsonMap(json['promptReleaseRef'])),
          );
        })
        .toList(growable: false);
    for (final binding in releases) {
      getPromptRelease(binding.promptReleaseRef);
    }
    return GenerationBundle(
      bundleId: row['bundle_id'] as String,
      releases: releases,
      expectedBundleHash: _prefixedHash(row['bundle_hash'] as String),
    );
  }

  void putEvaluationBundle(EvaluationBundle bundle) {
    ensureTables();
    _inImmediateTransaction(() {
      for (final ref in bundle.judgePromptReleases) {
        getPromptRelease(ref);
      }
      final judgesJson = AppLlmCanonicalHash.canonicalJson(<String, Object?>{
        'judgePromptReleases': [
          for (final ref in bundle.judgePromptReleases) ref.toJson(),
        ],
        'judgeModelRoutes': bundle.judgeModelRoutes,
      });
      final existing = db.select(
        '''SELECT evaluation_bundle_hash FROM evaluation_bundles
           WHERE evaluator_bundle_id = ?''',
        <Object?>[bundle.evaluatorBundleId],
      );
      if (existing.isNotEmpty &&
          (existing.length != 1 ||
              existing.single['evaluation_bundle_hash'] !=
                  _rawHash(bundle.evaluatorBundleHash))) {
        throw StateError(
          'immutable EvaluationBundle id already refers to another hash',
        );
      }
      db.execute(
        '''INSERT OR IGNORE INTO evaluation_bundles
           (evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
            judges_json, rubric_release_hash, aggregator_release_hash,
            failure_taxonomy_hash, blinding_policy_version, created_at_ms)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          _rawHash(bundle.evaluatorBundleHash),
          bundle.evaluatorBundleId,
          AppLlmCanonicalHash.canonicalJson(
            bundle.deterministicVerifierReleases,
          ),
          judgesJson,
          _rawHash(bundle.rubricReleaseHash),
          _rawHash(bundle.aggregatorReleaseHash),
          _rawHash(bundle.failureTaxonomyHash),
          bundle.blindingPolicyVersion,
          _nowMs(),
        ],
      );
      final stored = getEvaluationBundle(bundle.evaluatorBundleId);
      if (stored.evaluatorBundleHash != bundle.evaluatorBundleHash) {
        throw StateError(
          'immutable EvaluationBundle identity already contains different content',
        );
      }
    });
  }

  EvaluationBundle getEvaluationBundle(String evaluatorBundleId) {
    ensureTables();
    final rows = db.select(
      'SELECT * FROM evaluation_bundles WHERE evaluator_bundle_id = ?',
      [evaluatorBundleId],
    );
    if (rows.length != 1) {
      throw StateError('unknown EvaluationBundle: $evaluatorBundleId');
    }
    final row = rows.single;
    final judges = _jsonMap(jsonDecode(row['judges_json'] as String));
    final prompts = _jsonList(
      judges['judgePromptReleases'],
    ).map((value) => _promptRef(_jsonMap(value))).toList(growable: false);
    for (final ref in prompts) {
      getPromptRelease(ref);
    }
    return EvaluationBundle(
      evaluatorBundleId: row['evaluator_bundle_id'] as String,
      deterministicVerifierReleases: _stringList(
        jsonDecode(row['verifiers_json'] as String),
      ),
      judgePromptReleases: prompts,
      judgeModelRoutes: _stringList(judges['judgeModelRoutes']),
      rubricReleaseHash: _prefixedHash(row['rubric_release_hash'] as String),
      aggregatorReleaseHash: _prefixedHash(
        row['aggregator_release_hash'] as String,
      ),
      failureTaxonomyHash: _prefixedHash(
        row['failure_taxonomy_hash'] as String,
      ),
      blindingPolicyVersion: row['blinding_policy_version'] as String,
      expectedEvaluatorBundleHash: _prefixedHash(
        row['evaluation_bundle_hash'] as String,
      ),
    );
  }

  T _inImmediateTransaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  PromptRelease _promptFromRow(Row row) => PromptRelease(
    templateId: row['template_id'] as String,
    semanticVersion: row['semantic_version'] as String,
    language: row['language'] as String,
    systemTemplate: row['system_template'] as String,
    userTemplate: row['user_template'] as String,
    variablesSchemaSnapshot: jsonDecode(row['variables_schema_json'] as String),
    outputSchemaSnapshot: jsonDecode(row['output_schema_json'] as String),
    rendererRelease: row['renderer_release'] as String,
    parserRelease: row['parser_release'] as String,
    repairPolicySnapshot: jsonDecode(row['repair_policy_json'] as String),
    owner: row['owner'] as String,
    changeNote: row['change_note'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at_ms'] as int,
      isUtc: true,
    ),
    expectedContentHash: _prefixedHash(row['content_hash'] as String),
  );
}

bool _samePromptSnapshot(PromptRelease left, PromptRelease right) =>
    left.contentHash == right.contentHash &&
    left.owner == right.owner &&
    left.changeNote == right.changeNote &&
    left.createdAt == right.createdAt;

PromptReleaseRef _promptRef(Map<String, Object?> json) => PromptReleaseRef(
  templateId: json['templateId'] as String,
  semanticVersion: json['semanticVersion'] as String,
  language: json['language'] as String,
  contentHash: json['contentHash'] as String,
);

Map<String, Object?> _jsonMap(Object? value) =>
    (value as Map).cast<String, Object?>();

List<Object?> _jsonList(Object? value) =>
    (value is String
            ? jsonDecode(value) as List<Object?>
            : value as List<Object?>)
        .toList(growable: false);

List<String> _stringList(Object? value) =>
    _jsonList(value).cast<String>().toList(growable: false);

String _releaseId(PromptReleaseRef ref) =>
    _rawDomainHash('prompt-release-ref-v1', ref.toJson());

String _rawDomainHash(String domainTag, Object? value) =>
    _rawHash(AppLlmCanonicalHash.domainHash(domainTag, value));

String _rawHash(String value) {
  if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'hash', 'invalid prefixed SHA-256');
  }
  return value.substring('sha256:'.length);
}

String _prefixedHash(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw StateError('invalid stored SHA-256 digest');
  }
  return 'sha256:$value';
}

int _nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;
