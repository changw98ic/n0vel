import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release_store.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late AppLlmPromptReleaseStore store;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    store = AppLlmPromptReleaseStore(db: db)..ensureTables();
  });

  tearDown(() => db.dispose());

  test('keeps old releases readable and lifecycle events append-only', () {
    final v1 = _release(version: '1.0.0', system: 'v1');
    final v2 = _release(version: '2.0.0', system: 'v2');
    store.putPromptRelease(v1);
    store.putPromptRelease(v2);
    store.appendLifecycleEvent(
      PromptReleaseLifecycleEvent(
        releaseRef: v1.ref,
        event: 'deprecated',
        reason: 'v2 promoted',
        occurredAt: DateTime.utc(2026, 7, 12),
      ),
    );

    expect(store.getPromptRelease(v1.ref).systemTemplate, 'v1');
    expect(store.getPromptRelease(v2.ref).systemTemplate, 'v2');
    expect(store.lifecycleEvents(v1.ref).single.event, 'deprecated');
    expect(
      db.select('SELECT COUNT(*) AS n FROM prompt_releases').single['n'],
      2,
    );
  });

  test('same release identity cannot be overwritten', () {
    final original = _release(system: 'original');
    store.putPromptRelease(original);

    expect(
      () => store.putPromptRelease(_release(system: 'replacement')),
      throwsStateError,
    );
    expect(store.getPromptRelease(original.ref).systemTemplate, 'original');
  });

  test('read fails closed after prompt snapshot tampering', () {
    final release = _release();
    store.putPromptRelease(release);
    expect(
      () => db.execute(
        '''UPDATE prompt_releases SET system_template = 'tampered'
           WHERE template_id = ? AND semantic_version = ? AND language = ?''',
        [release.templateId, release.semanticVersion, release.language],
      ),
      throwsA(isA<SqliteException>()),
    );
    db.execute('DROP TRIGGER prevent_prompt_releases_update');
    db.execute(
      '''UPDATE prompt_releases SET system_template = 'tampered'
         WHERE template_id = ? AND semantic_version = ? AND language = ?''',
      [release.templateId, release.semanticVersion, release.language],
    );

    expect(() => store.getPromptRelease(release.ref), throwsStateError);
  });

  test('persists and verifies generation bundle members', () {
    final release = _release();
    store.putPromptRelease(release);
    final bundle = GenerationBundle(
      bundleId: 'generation-v1',
      releases: [
        GenerationBundleBinding(
          stageId: 'editorial',
          callSiteId: 'draft',
          variantId: 'zh',
          promptReleaseRef: release.ref,
        ),
      ],
    );
    store.putGenerationBundle(bundle);

    final loaded = store.getGenerationBundle(bundle.bundleId);
    expect(loaded.bundleHash, bundle.bundleHash);
    expect(loaded.releases.single.promptReleaseRef, release.ref);

    expect(
      () => db.execute(
        '''UPDATE generation_bundles
           SET releases_json = replace(releases_json, 'editorial', 'tampered')
           WHERE bundle_id = ?''',
        [bundle.bundleId],
      ),
      throwsA(isA<SqliteException>()),
    );
    db.execute('DROP TRIGGER prevent_generation_bundles_update');
    db.execute(
      '''UPDATE generation_bundles
         SET releases_json = replace(releases_json, 'editorial', 'tampered')
         WHERE bundle_id = ?''',
      [bundle.bundleId],
    );
    expect(() => store.getGenerationBundle(bundle.bundleId), throwsStateError);
  });

  test('conflicting generation bundle id rolls back without pollution', () {
    final firstRelease = _release(templateId: 'first');
    final secondRelease = _release(templateId: 'second');
    store.putPromptRelease(firstRelease);
    store.putPromptRelease(secondRelease);
    GenerationBundle bundle(PromptRelease release) => GenerationBundle(
      bundleId: 'stable-generation',
      releases: [
        GenerationBundleBinding(
          stageId: 'editorial',
          callSiteId: 'draft',
          variantId: 'zh',
          promptReleaseRef: release.ref,
        ),
      ],
    );
    final champion = bundle(firstRelease);
    store.putGenerationBundle(champion);

    expect(
      () => store.putGenerationBundle(bundle(secondRelease)),
      throwsStateError,
    );
    expect(
      db.select(
        'SELECT bundle_hash FROM generation_bundles WHERE bundle_id = ?',
        ['stable-generation'],
      ).length,
      1,
    );
    expect(
      store.getGenerationBundle('stable-generation').bundleHash,
      champion.bundleHash,
    );
  });

  test('persists and verifies an independent evaluation bundle', () {
    final judge = _release(templateId: 'judge');
    store.putPromptRelease(judge);
    final bundle = EvaluationBundle(
      evaluatorBundleId: 'evaluation-v1',
      deterministicVerifierReleases: [_hashA],
      judgePromptReleases: [judge.ref],
      judgeModelRoutes: ['glm-judge'],
      rubricReleaseHash: _hashB,
      aggregatorReleaseHash: _hashC,
      failureTaxonomyHash: _hashD,
      blindingPolicyVersion: 'blind-v1',
    );
    store.putEvaluationBundle(bundle);

    expect(
      store.getEvaluationBundle(bundle.evaluatorBundleId).evaluatorBundleHash,
      bundle.evaluatorBundleHash,
    );
    expect(
      () => db.execute(
        '''UPDATE evaluation_bundles
           SET blinding_policy_version = 'blind-v2'
           WHERE evaluator_bundle_id = ?''',
        [bundle.evaluatorBundleId],
      ),
      throwsA(isA<SqliteException>()),
    );
    db.execute('DROP TRIGGER prevent_evaluation_bundles_update');
    db.execute(
      '''UPDATE evaluation_bundles
         SET blinding_policy_version = 'blind-v2'
         WHERE evaluator_bundle_id = ?''',
      [bundle.evaluatorBundleId],
    );
    expect(
      () => store.getEvaluationBundle(bundle.evaluatorBundleId),
      throwsStateError,
    );
  });

  test('conflicting evaluator id rolls back without pollution', () {
    final judge = _release(templateId: 'judge-conflict');
    store.putPromptRelease(judge);
    EvaluationBundle bundle(String blinding) => EvaluationBundle(
      evaluatorBundleId: 'stable-evaluator',
      deterministicVerifierReleases: [_hashA],
      judgePromptReleases: [judge.ref],
      judgeModelRoutes: ['glm-judge'],
      rubricReleaseHash: _hashB,
      aggregatorReleaseHash: _hashC,
      failureTaxonomyHash: _hashD,
      blindingPolicyVersion: blinding,
    );
    final champion = bundle('blind-v1');
    store.putEvaluationBundle(champion);

    expect(
      () => store.putEvaluationBundle(bundle('blind-v2')),
      throwsStateError,
    );
    expect(
      db
          .select(
            '''SELECT evaluation_bundle_hash FROM evaluation_bundles
               WHERE evaluator_bundle_id = ?''',
            ['stable-evaluator'],
          )
          .length,
      1,
    );
    expect(
      store.getEvaluationBundle('stable-evaluator').evaluatorBundleHash,
      champion.evaluatorBundleHash,
    );
  });

  test('bundle write rejects an unregistered prompt member', () {
    final release = _release();
    final bundle = GenerationBundle(
      bundleId: 'generation-v1',
      releases: [
        GenerationBundleBinding(
          stageId: 'editorial',
          callSiteId: 'draft',
          variantId: 'zh',
          promptReleaseRef: release.ref,
        ),
      ],
    );

    expect(() => store.putGenerationBundle(bundle), throwsStateError);
  });
}

PromptRelease _release({
  String templateId = 'scene-editorial',
  String version = '1.0.0',
  String system = 'system',
}) => PromptRelease(
  templateId: templateId,
  semanticVersion: version,
  language: 'zh',
  systemTemplate: system,
  userTemplate: 'user {scene}',
  variablesSchemaSnapshot: const {'type': 'object'},
  outputSchemaSnapshot: const {'type': 'string'},
  rendererRelease: 'renderer-v1',
  parserRelease: 'parser-v1',
  repairPolicySnapshot: const {'maxAttempts': 1},
  owner: 'test',
  changeNote: 'test release',
  createdAt: DateTime.utc(2026, 7, 12),
);

const _hashA =
    'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _hashC =
    'sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _hashD =
    'sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
