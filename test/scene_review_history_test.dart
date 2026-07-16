import 'dart:convert';

import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/production_pre_quality_gate.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_quality_reporter.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart'
    show SceneState;
import 'package:novel_writer/features/story_generation/data/story_mechanics_verifier.dart';
import 'package:novel_writer/features/story_generation/data/story_mechanics_gate_authority.dart';
import 'package:novel_writer/features/story_generation/data/step_io.dart';
import 'package:novel_writer/features/story_generation/data/steps/finalization_step.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  test('runtime output snapshots an immutable review history', () {
    final first = SceneReviewAttempt(
      round: 1,
      proseAttempt: 1,
      phase: SceneReviewPhase.preliminary,
      decision: SceneReviewDecision.replanScene,
      reason: '结构目标缺失。',
    );
    final source = <SceneReviewAttempt>[first];
    final output = _output(reviewAttempts: source);

    source.add(
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 1,
        phase: SceneReviewPhase.finalCouncil,
        decision: SceneReviewDecision.pass,
        reason: '通过。',
      ),
    );

    expect(output.reviewAttempts, hasLength(1));
    expect(() => output.reviewAttempts.add(first), throwsUnsupportedError);
  });

  test('review attempt snapshots mutable failure codes at construction', () {
    final codes = <String>['quality.overall_below_95'];
    final attempt = SceneReviewAttempt(
      round: 1,
      proseAttempt: 1,
      phase: SceneReviewPhase.quality,
      decision: SceneReviewDecision.rewriteProse,
      reason: '未通过。',
      failureCodes: codes,
    );

    codes.add('mutated.after.construction');

    expect(attempt.failureCodes, <String>['quality.overall_below_95']);
    expect(
      () => attempt.failureCodes.add('mutated.through.getter'),
      throwsUnsupportedError,
    );
  });

  test('reporter preserves every attempt field and markdown reason', () {
    final mutableCodes = <String>['quality.overall_below_95'];
    final attempt = SceneReviewAttempt.snapshot(
      round: 2,
      proseAttempt: 3,
      phase: SceneReviewPhase.quality,
      decision: SceneReviewDecision.rewriteProse,
      reason: '综合分未达到发布线。',
      failureCodes: mutableCodes,
      timestamp: 123456789,
      proseHash: 'sha256:prose-revision',
      repairScheduled: true,
    );
    mutableCodes.add('mutated.after.snapshot');
    final output = _output(reviewAttempts: <SceneReviewAttempt>[attempt]);

    final scene =
        ((jsonDecode(SceneQualityReporter.toJson(<SceneRuntimeOutput>[output]))
                        as Map<String, Object?>)['scenes']
                    as List<Object?>)
                .single
            as Map<String, Object?>;
    final encoded =
        (scene['reviewAttempts'] as List<Object?>).single
            as Map<String, Object?>;

    expect(encoded, <String, Object?>{
      'round': 2,
      'proseAttempt': 3,
      'phase': 'quality',
      'decision': 'rewriteProse',
      'reason': '综合分未达到发布线。',
      'failureCodes': <Object?>['quality.overall_below_95'],
      'timestamp': 123456789,
      'proseHash': 'sha256:prose-revision',
      'repairScheduled': true,
    });
    expect(
      SceneQualityReporter.toMarkdown(<SceneRuntimeOutput>[output]),
      allOf(contains('quality: rewriteProse'), contains('综合分未达到发布线')),
    );
  });

  test(
    'provider-free finalization carries typed history into output',
    () async {
      final attempt = SceneReviewAttempt(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.finalCouncil,
        decision: SceneReviewDecision.pass,
        reason: '最终 council 通过。',
      );
      final result = await const FinalizationStep().execute(
        _finalizationInput(),
        _pipelineContext(<SceneReviewAttempt>[attempt]),
      );

      expect(result.output.reviewAttempts, <SceneReviewAttempt>[attempt]);
      expect(
        () => result.output.reviewAttempts.add(attempt),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'initial generated candidate cannot synthesize missing gate evidence',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final finalizer = GenerationLedgerCandidateFinalizer(
        ledger: GenerationLedgerSqliteStore(db: db)..ensureTables(),
      );
      final brief = SceneBrief(
        projectId: 'project-generated-evidence',
        chapterId: 'chapter-01',
        chapterTitle: '第一章',
        sceneId: 'scene-01',
        sceneTitle: '旧码头',
        sceneSummary: '柳溪完成证据核对。',
      );
      final capture = finalizer.startRun(
        runId: 'run-generated-evidence',
        requestId: 'request-generated-evidence',
        projectId: brief.projectId!,
        chapterId: brief.chapterId,
        sceneId: brief.sceneId,
        sceneScopeId: 'project-generated-evidence::chapter-01::scene-01',
        baseDraft: '',
        brief: brief,
        materials: _reviewHistoryMaterials,
        nowMs: 100,
      );

      expect(
        () => finalizer.finalize(
          runId: 'run-generated-evidence',
          output: _output(
            brief: brief,
            proseText: '柳溪核对账页后离开旧码头。',
            reviewAttempts: const <SceneReviewAttempt>[],
            includePolishCanonEvidence: false,
            includeStoryMechanicsEvidence: false,
          ),
          capture: capture,
          nowMs: 200,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('supplied polish-canon evidence'),
          ),
        ),
      );
      expect(
        db.select('SELECT * FROM story_generation_candidate_proofs'),
        isEmpty,
      );
    },
  );

  test('ledger payload and proof digest bind the complete review history', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
    final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
    final brief = SceneBrief(
      projectId: 'project-review-history',
      chapterId: 'chapter-01',
      chapterTitle: '第一章',
      sceneId: 'scene-01',
      sceneTitle: '旧码头',
      sceneSummary: '柳溪核对证据后撤离。',
      sceneIndex: 1,
      totalScenesInChapter: 3,
      metadata: const <String, Object?>{'continuityLedger': <Object?>[]},
    );
    const finalProse =
        '雨水敲打铁棚。柳溪把账页压在灯下。'
        '“封口编号对上了，警笛快到了。”她将证据收进内袋。'
        '“现在撤。”沈渡关灯，两人沿货箱阴影离开。';
    final finalReviewHash = _pipelineReviewProseHash(finalProse);
    final mechanicsHash = StoryMechanicsVerifier.proseHash(finalProse);
    final history = <SceneReviewAttempt>[
      SceneReviewAttempt(
        round: 1,
        proseAttempt: 1,
        phase: SceneReviewPhase.preliminary,
        decision: SceneReviewDecision.replanScene,
        reason: '缺少证据交接。',
        proseHash: _pipelineReviewProseHash('缺少证据交接的旧稿。'),
        repairScheduled: true,
      ),
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 1,
        phase: SceneReviewPhase.preliminary,
        decision: SceneReviewDecision.pass,
        reason: '重排后初审通过。',
        proseHash: finalReviewHash,
      ),
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 1,
        phase: SceneReviewPhase.deterministic,
        decision: SceneReviewDecision.pass,
        reason: '确定性门禁通过。',
        proseHash: mechanicsHash,
      ),
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 1,
        phase: SceneReviewPhase.finalCouncil,
        decision: SceneReviewDecision.pass,
        reason: '最终 council 通过。',
        proseHash: finalReviewHash,
      ),
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 1,
        phase: SceneReviewPhase.quality,
        decision: SceneReviewDecision.pass,
        reason: 'Quality gate passed: overall 96.0 >= 95.',
        proseHash: finalReviewHash,
      ),
    ];
    final output = _output(
      brief: brief,
      proseText: finalProse,
      reviewAttempts: history,
    );
    final capture = finalizer.startRun(
      runId: 'run-review-history',
      requestId: 'request-review-history',
      projectId: brief.projectId!,
      chapterId: brief.chapterId,
      sceneId: brief.sceneId,
      sceneScopeId: 'project-review-history::chapter-01::scene-01',
      baseDraft: '',
      brief: brief,
      materials: _reviewHistoryMaterials,
      nowMs: 100,
    );

    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: output.prose.text,
          reviewAttempts: <SceneReviewAttempt>[history[3]],
        ),
        capture: capture,
        nowMs: 150,
      ),
      throwsA(isA<StateError>()),
      reason: 'A lone final PASS must not replace the earlier audit chain.',
    );

    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: finalProse,
          reviewAttempts: history,
          includePolishCanonEvidence: false,
        ),
        capture: capture,
        nowMs: 155,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('polish-canon evidence'),
        ),
      ),
    );
    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: finalProse,
          reviewAttempts: history,
          authorRevisionPreQuality: true,
        ),
        capture: capture,
        nowMs: 158,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('author-revision-pre-quality-only'),
        ),
      ),
      reason:
          'Provider-free author-revision evidence may be independently '
          'reviewed, but cannot self-authorize a durable candidate.',
    );
    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: finalProse,
          reviewAttempts: history,
          includeStoryMechanicsEvidence: false,
        ),
        capture: capture,
        nowMs: 160,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('story-mechanics evidence'),
        ),
      ),
    );

    for (final phase in const <SceneReviewPhase>[
      SceneReviewPhase.preliminary,
      SceneReviewPhase.deterministic,
      SceneReviewPhase.finalCouncil,
      SceneReviewPhase.quality,
    ]) {
      final missingHash = [
        for (final attempt in history)
          if (attempt.phase == phase &&
              attempt.decision == SceneReviewDecision.pass)
            SceneReviewAttempt(
              round: attempt.round,
              proseAttempt: attempt.proseAttempt,
              phase: attempt.phase,
              decision: attempt.decision,
              reason: attempt.reason,
            )
          else
            attempt,
      ];
      expect(
        () => finalizer.finalize(
          runId: 'run-review-history',
          output: _output(
            brief: brief,
            proseText: finalProse,
            reviewAttempts: missingHash,
          ),
          capture: capture,
          nowMs: 165,
        ),
        throwsA(isA<StateError>()),
        reason: '${phase.name} PASS must identify the reviewed prose.',
      );
    }

    final malformedPreliminaryHash = <SceneReviewAttempt>[
      SceneReviewAttempt(
        round: history[1].round,
        proseAttempt: history[1].proseAttempt,
        phase: history[1].phase,
        decision: history[1].decision,
        reason: history[1].reason,
        proseHash: 'not-a-hash',
      ),
      ...history.skip(2),
    ];
    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: finalProse,
          reviewAttempts: malformedPreliminaryHash,
        ),
        capture: capture,
        nowMs: 168,
      ),
      throwsA(isA<StateError>()),
      reason: 'Preliminary PASS must use the canonical pipeline digest shape.',
    );

    for (final phase in const <SceneReviewPhase>[
      SceneReviewPhase.deterministic,
      SceneReviewPhase.finalCouncil,
      SceneReviewPhase.quality,
    ]) {
      final mismatchedHashHistory = [
        for (final attempt in history.skip(1))
          if (attempt.phase == phase)
            SceneReviewAttempt(
              round: attempt.round,
              proseAttempt: attempt.proseAttempt,
              phase: attempt.phase,
              decision: attempt.decision,
              reason: '错误地为其他正文签发。',
              proseHash: phase == SceneReviewPhase.deterministic
                  ? StoryMechanicsVerifier.proseHash('另一版正文。')
                  : _pipelineReviewProseHash('另一版正文。'),
            )
          else
            attempt,
      ];
      expect(
        () => finalizer.finalize(
          runId: 'run-review-history',
          output: _output(
            brief: brief,
            proseText: finalProse,
            reviewAttempts: mismatchedHashHistory,
          ),
          capture: capture,
          nowMs: 170,
        ),
        throwsA(isA<StateError>()),
        reason:
            '${phase.name} PASS for different prose must not certify the candidate.',
      );
    }

    final mismatchedHistory = <SceneReviewAttempt>[
      history[1],
      history[2],
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 2,
        phase: SceneReviewPhase.finalCouncil,
        decision: SceneReviewDecision.pass,
        reason: '另一个正文版本的最终 council 通过。',
        proseHash: finalReviewHash,
      ),
      SceneReviewAttempt(
        round: 2,
        proseAttempt: 2,
        phase: SceneReviewPhase.quality,
        decision: SceneReviewDecision.pass,
        reason: '另一个正文版本的质量门禁通过。',
        proseHash: finalReviewHash,
      ),
    ];
    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: output.prose.text,
          reviewAttempts: mismatchedHistory,
        ),
        capture: capture,
        nowMs: 175,
      ),
      throwsA(isA<StateError>()),
      reason: 'PASS records from different prose attempts cannot be combined.',
    );

    final outOfOrderHistory = <SceneReviewAttempt>[
      history[1],
      history[3],
      history[2],
      history[4],
    ];
    expect(
      () => finalizer.finalize(
        runId: 'run-review-history',
        output: _output(
          brief: brief,
          proseText: output.prose.text,
          reviewAttempts: outOfOrderHistory,
        ),
        capture: capture,
        nowMs: 180,
      ),
      throwsA(isA<StateError>()),
      reason: 'The successful gate phases must remain in production order.',
    );

    expect(
      db.select('SELECT * FROM story_generation_candidate_proofs'),
      isEmpty,
      reason: 'Rejected evidence must not leave a durable proof row.',
    );

    final candidate = finalizer.finalize(
      runId: 'run-review-history',
      output: output,
      capture: capture,
      nowMs: 200,
    );

    final qualityPayload =
        jsonDecode(
              db
                      .select(
                        'SELECT quality_payload_json FROM story_generation_candidate_payloads',
                      )
                      .single['quality_payload_json']
                  as String,
            )
            as Map<String, Object?>;
    final deterministicGate =
        qualityPayload['deterministicGate']! as Map<String, Object?>;
    expect(deterministicGate['algorithm'], 'deterministic-gate-v4');
    expect(
      StoryMechanicsGateAuthority.verifyDeterministicGate(
        encodedGate: deterministicGate,
        finalProse: finalProse,
        deterministicGateEvidenceHash: candidate.deterministicGateEvidenceHash,
      ),
      isTrue,
      reason:
          'The authority must accept the exact v4 payload emitted by finalization.',
    );

    final staleV3Gate = <String, Object?>{
      'algorithm': 'deterministic-gate-v3',
      'finalProseHash': deterministicGate['finalProseHash'],
      'passed': true,
      'polishCanonEvidence': deterministicGate['polishCanonEvidence'],
      'storyMechanicsEvidence': deterministicGate['storyMechanicsEvidence'],
    };
    final staleV3Hash = GenerationLedgerDigest.object(staleV3Gate);
    expect(
      StoryMechanicsGateAuthority.verifyDeterministicGate(
        encodedGate: staleV3Gate,
        finalProse: finalProse,
        deterministicGateEvidenceHash: staleV3Hash,
      ),
      isFalse,
      reason:
          'A rehashed v3 payload lacks the production pre-quality contract.',
    );
    expect(
      StoryMechanicsGateAuthority.verifyReceipt(
        encodedPolishCanonEvidence: staleV3Gate['polishCanonEvidence'],
        encodedStoryMechanicsEvidence: staleV3Gate['storyMechanicsEvidence'],
        gateFinalProseHash: staleV3Gate['finalProseHash']! as String,
        deterministicGateEvidenceHash: staleV3Hash,
      ),
      isFalse,
      reason: 'The legacy receipt projection cannot reconstruct v4 evidence.',
    );

    final tamperedBriefGate =
        jsonDecode(jsonEncode(deterministicGate)) as Map<String, Object?>
          ..['briefRequirementsHash'] =
              'sha256:${List<String>.filled(64, '0').join()}';
    expect(
      StoryMechanicsGateAuthority.verifyDeterministicGate(
        encodedGate: tamperedBriefGate,
        finalProse: finalProse,
        deterministicGateEvidenceHash: GenerationLedgerDigest.object(
          tamperedBriefGate,
        ),
      ),
      isFalse,
      reason:
          'The top-level brief binding must match nested production evidence.',
    );

    final tamperedPreQualityGate =
        jsonDecode(jsonEncode(deterministicGate)) as Map<String, Object?>;
    final tamperedPreQuality =
        tamperedPreQualityGate['productionPreQualityEvidence']!
            as Map<String, Object?>;
    tamperedPreQuality['hardGatesEnabled'] = false;
    expect(
      StoryMechanicsGateAuthority.verifyDeterministicGate(
        encodedGate: tamperedPreQualityGate,
        finalProse: finalProse,
        deterministicGateEvidenceHash: GenerationLedgerDigest.object(
          tamperedPreQualityGate,
        ),
      ),
      isFalse,
      reason:
          'Rehashing cannot authorize disabled or hash-tampered hard gates.',
    );
    expect(
      StoryMechanicsGateAuthority.verifyDeterministicGate(
        encodedGate: deterministicGate,
        finalProse: '$finalProse\n篡改尾句。',
        deterministicGateEvidenceHash: candidate.deterministicGateEvidenceHash,
      ),
      isFalse,
      reason: 'The authority must recompute every exact-prose identity.',
    );

    final authorRevisionEvidence = ProductionPreQualityGate.standard
        .verifyAuthorRevision(
          brief: brief,
          materials: _reviewHistoryMaterials,
          predecessorProse: _reviewHistoryPreQualitySource,
          revisedProse: finalProse,
        );
    final authorRevisionGate =
        jsonDecode(jsonEncode(deterministicGate)) as Map<String, Object?>
          ..['productionPreQualityEvidence'] = authorRevisionEvidence.toJson()
          ..['polishCanonEvidence'] = authorRevisionEvidence.polishCanonEvidence
              .toJson()
          ..['storyMechanicsEvidence'] = authorRevisionEvidence
              .storyMechanicsEvidence
              .toJson();
    expect(
      StoryMechanicsGateAuthority.verifyDeterministicGate(
        encodedGate: authorRevisionGate,
        finalProse: finalProse,
        deterministicGateEvidenceHash: GenerationLedgerDigest.object(
          authorRevisionGate,
        ),
      ),
      isFalse,
      reason:
          'A valid provider-free author revision remains pre-quality-only and '
          'cannot be promoted by rehashing it as a candidate gate.',
    );

    final encodedAttempts = <Object?>[
      for (final attempt in history) attempt.toJson(),
    ];
    final payload =
        jsonDecode(
              db
                      .select(
                        'SELECT review_payload_json FROM story_generation_candidate_payloads',
                      )
                      .single['review_payload_json']
                  as String,
            )
            as Map<String, Object?>;
    expect(payload['schemaVersion'], 'candidate-review-payload-v2');
    expect(payload['reviewAttempts'], encodedAttempts);

    final expectedCouncilHash = GenerationLedgerDigest.object({
      'finalProseHash': candidate.finalProseHash,
      'decision': output.review.decision.name,
      'feedback': output.review.feedback,
      'reviewAttempts': encodedAttempts,
    });
    expect(candidate.finalCouncilEvidenceHash, expectedCouncilHash);
    expect(
      'sha256:$finalReviewHash',
      isNot(candidate.finalProseHash),
      reason:
          'Pipeline review hashes bind a JSON text envelope, while the '
          'ledger prose identity hashes normalized text directly.',
    );
    expect(
      candidate.candidateHash,
      GenerationLedgerDigest.object({
        'runId': candidate.runId,
        'candidateRevision': candidate.candidateRevision,
        'finalProseHash': candidate.finalProseHash,
        'deterministicGateEvidenceHash':
            candidate.deterministicGateEvidenceHash,
        'finalCouncilEvidenceHash': expectedCouncilHash,
        'qualityEvidenceHash': candidate.qualityEvidenceHash,
        'pendingWriteSetHash': candidate.pendingWriteSetHash,
        'materialDigest': capture.materialDigest,
        'inputDigest': capture.inputDigest,
        'generationBundleHash': capture.generationBundleHash,
      }),
    );
    expect(
      expectedCouncilHash,
      isNot(
        GenerationLedgerDigest.object({
          'finalProseHash': candidate.finalProseHash,
          'decision': output.review.decision.name,
          'feedback': output.review.feedback,
          'reviewAttempts': <Object?>[history.last.toJson()],
        }),
      ),
    );
  });

  test(
    'pipeline preserves replan rounds and records every successful gate',
    () async {
      var editorialCalls = 0;
      final client = FakeAppLlmClient(
        responder: (request) {
          final systemPrompt = request.messages.first.content;
          final userPrompt = request.messages.last.content;
          if (systemPrompt.contains('scene plan polisher')) {
            return const AppLlmChatResult.success(
              text: '目标：核对账页\n冲突：警笛逼近\n推进：柳溪确认编号后撤离\n约束：保持旧码头空间',
            );
          }
          if (userPrompt.contains('任务：scene_roleplay_turn')) {
            return const AppLlmChatResult.success(
              text: '意图：确认编号\n可见动作：柳溪把账页压在灯下\n对白：封口编号对上了\n内心：警笛来得太快',
            );
          }
          if (userPrompt.contains('任务：scene_roleplay_arbitrate')) {
            return const AppLlmChatResult.success(
              text: '事实：柳溪确认封口编号\n状态：证据已收好\n压力：警笛逼近\n收束：是',
            );
          }
          if (systemPrompt.contains('scene stage narrator')) {
            return const AppLlmChatResult.success(
              text: '舞台事实：雨水敲打铁棚\n环境氛围：警笛从港区外逼近\n可见证据：账页封口编号清晰\n边界：不替角色决定',
            );
          }
          if (systemPrompt.contains('scene beat resolver')) {
            return const AppLlmChatResult.success(
              text: '[动作] @char-liuxi 柳溪把账页压在灯下\n[事实] @narrator 封口编号得到确认',
            );
          }
          if (systemPrompt.contains('scene editor')) {
            editorialCalls += 1;
            return AppLlmChatResult.success(
              text: editorialCalls == 1
                  ? '柳溪看见账页，却没有核对封口编号。'
                  : '雨水敲打铁棚。柳溪把账页压在灯下，核对封口编号，随后将证据收进内袋。警笛从港区外逼近，她关灯沿货箱阴影撤离。',
            );
          }
          if (systemPrompt.contains('scene judge review') ||
              systemPrompt.contains('scene consistency review') ||
              systemPrompt.contains('scene reader-flow review') ||
              systemPrompt.contains('scene lexicon review') ||
              systemPrompt.contains('scene roleplay fidelity review')) {
            return AppLlmChatResult.success(
              text: editorialCalls == 1
                  ? '决定：REPLAN_SCENE\n原因：缺少核对封口编号这一核心剧情功能。'
                  : '决定：PASS\n原因：证据核对、压力与撤离动作完整。',
            );
          }
          if (systemPrompt.contains(
            'quality scorer for Chinese novel scenes',
          )) {
            return const AppLlmChatResult.success(
              text: '文笔：96\n连贯：96\n角色：96\n完整：96\n综合：96\n总结：质量门通过。',
            );
          }
          throw StateError('Unexpected prompt: $systemPrompt\n$userPrompt');
        },
      );
      final settings = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: client,
      );
      addTearDown(settings.dispose);
      final runner = PipelineStageRunnerImpl(
        settingsStore: settings,
        pipelineConfig: const GenerationPipelineConfig(
          enableWritingReference: false,
          hardGatesEnabled: false,
          maxSceneReplanRetries: 1,
        ),
      );

      final brief = SceneBrief(
        projectId: 'project-pipeline-history',
        chapterId: 'chapter-01',
        chapterTitle: '第一章',
        sceneId: 'scene-01',
        sceneTitle: '旧码头',
        sceneSummary: '柳溪核对账页封口编号后撤离。',
        targetBeat: '确认封口编号。',
        metadata: const <String, Object?>{'localPolishOnly': true},
        cast: [
          SceneCastCandidate(
            characterId: 'char-liuxi',
            name: '柳溪',
            role: '调查记者',
            participation: const SceneCastParticipation(action: '核对账页'),
          ),
        ],
      );
      final output = await runner.runScene(brief);

      expect(
        output.reviewAttempts
            .map((attempt) => (attempt.round, attempt.phase, attempt.decision))
            .toList(),
        <(int, SceneReviewPhase, SceneReviewDecision)>[
          (1, SceneReviewPhase.preliminary, SceneReviewDecision.replanScene),
          (2, SceneReviewPhase.preliminary, SceneReviewDecision.pass),
          (2, SceneReviewPhase.deterministic, SceneReviewDecision.pass),
          (2, SceneReviewPhase.finalCouncil, SceneReviewDecision.pass),
          (2, SceneReviewPhase.quality, SceneReviewDecision.pass),
        ],
      );
      expect(
        output.reviewAttempts.last.reason,
        allOf(contains('overall 96.0 >= 95'), contains('>= 90')),
      );

      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final finalizer = GenerationLedgerCandidateFinalizer(
        ledger: GenerationLedgerSqliteStore(db: db)..ensureTables(),
      );
      final capture = finalizer.startRun(
        runId: 'run-pipeline-history',
        requestId: 'request-pipeline-history',
        projectId: brief.projectId!,
        chapterId: brief.chapterId,
        sceneId: brief.sceneId,
        sceneScopeId: 'project-pipeline-history::chapter-01::scene-01',
        baseDraft: '',
        brief: brief,
        materials: const ProjectMaterialSnapshot(),
        nowMs: 100,
      );
      expect(
        () => finalizer.finalize(
          runId: 'run-pipeline-history',
          output: output,
          capture: capture,
          nowMs: 200,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('pre-quality evidence'), contains('not-passed')),
          ),
        ),
      );
      expect(
        db.select('SELECT * FROM story_generation_candidate_proofs'),
        isEmpty,
      );
    },
  );
}

SceneRuntimeOutput _output({
  required List<SceneReviewAttempt> reviewAttempts,
  SceneBrief? brief,
  String proseText = '正文内容。',
  bool includePolishCanonEvidence = true,
  bool includeStoryMechanicsEvidence = true,
  bool authorRevisionPreQuality = false,
}) {
  const pass = SceneReviewPassResult(
    status: SceneReviewStatus.pass,
    reason: '通过。',
    rawText: '决定：PASS\n原因：通过。',
  );
  final effectiveBrief =
      brief ??
      SceneBrief(
        chapterId: 'chapter-01',
        chapterTitle: '第一章',
        sceneId: 'scene-01',
        sceneTitle: '旧码头',
        sceneSummary: '对峙升级。',
      );
  final preQualityEvidence = authorRevisionPreQuality
      ? ProductionPreQualityGate.standard.verifyAuthorRevision(
          brief: effectiveBrief,
          materials: _reviewHistoryMaterials,
          predecessorProse: _reviewHistoryPreQualitySource,
          revisedProse: proseText,
          hardGatesEnabled: true,
        )
      : ProductionPreQualityGate.standard.verifyPipelinePolish(
          brief: effectiveBrief,
          materials: _reviewHistoryMaterials,
          prePolishProse: _reviewHistoryPreQualitySource,
          finalProse: proseText,
          hardGatesEnabled: true,
        );
  return SceneRuntimeOutput(
    brief: effectiveBrief,
    resolvedCast: const [],
    director: const SceneDirectorOutput(text: '推进冲突。'),
    roleOutputs: const [],
    prose: SceneProseDraft(text: proseText, attempt: 1),
    review: const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    ),
    reviewAttempts: reviewAttempts,
    proseAttempts: 3,
    softFailureCount: 1,
    qualityScore: const SceneQualityScore(
      overall: 96,
      prose: 95,
      coherence: 95,
      character: 95,
      completeness: 95,
      summary: '达到发布线。',
    ),
    polishCanonEvidence: includePolishCanonEvidence
        ? preQualityEvidence.polishCanonEvidence
        : null,
    storyMechanicsEvidence: includeStoryMechanicsEvidence
        ? preQualityEvidence.storyMechanicsEvidence
        : null,
    productionPreQualityEvidence:
        includePolishCanonEvidence && includeStoryMechanicsEvidence
        ? preQualityEvidence.toJson()
        : null,
  );
}

const _reviewHistoryMaterials = ProjectMaterialSnapshot(
  worldFacts: <String>['旧码头的账页封口编号是可核对的正式证据。'],
);

const _reviewHistoryPreQualitySource = '雨水敲打铁棚。柳溪在旧码头核对账页，沈渡提醒警笛逼近。';

String _pipelineReviewProseHash(String prose) {
  final digest = const DartSha256().hashSync(
    utf8.encode(jsonEncode(<String, Object?>{'text': prose})),
  );
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

PipelineContext _pipelineContext(List<SceneReviewAttempt> reviewAttempts) {
  return PipelineContext(
    eventLog: PipelineEventLogImpl(),
    retrievalPolicy: RagRetrievalPolicy.director(),
    writebackGate: const BasicMemoryWritebackGate(),
    sceneBrief: const SceneBriefRef(projectId: 'project', sceneId: 'scene'),
    metadata: <String, Object?>{
      'qualityScore': const SceneQualityScore(
        overall: 96,
        prose: 95,
        coherence: 95,
        character: 95,
        completeness: 95,
        summary: '达到发布线。',
      ),
      'reviewAttempts': reviewAttempts,
    },
  );
}

FinalizationInput _finalizationInput() {
  final brief = SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章',
    sceneId: 'scene-01',
    sceneTitle: '旧码头',
    sceneSummary: '对峙升级。',
  );
  const prose = SceneProseDraft(text: '正文内容。', attempt: 1);
  const pass = SceneReviewPassResult(
    status: SceneReviewStatus.pass,
    reason: '通过。',
    rawText: '决定：PASS\n原因：通过。',
  );
  const review = SceneReviewResult(
    judge: pass,
    consistency: pass,
    decision: SceneReviewDecision.pass,
  );
  return FinalizationInput(
    brief: brief,
    plan: ScenePlanningOutput(
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: '推进冲突。'),
      taskCard: pipeline.SceneTaskCard(brief: brief, cast: const []),
    ),
    roleplay: const RoleplayOutput(roleOutputs: [], roleTurns: []),
    beats: BeatResolutionOutput(
      resolvedBeats: const [],
      runtimeBeats: const [],
      sceneState: SceneState.initial(sceneId: 'scene-01'),
    ),
    editorial: const EditorialOutput(
      draft: pipeline.SceneEditorialDraft(
        text: '正文内容。',
        beatCount: 1,
        attempt: 1,
      ),
      prose: prose,
    ),
    polish: const PolishOutput(prose: prose),
    review: const ReviewOutput(
      review: review,
      wasLengthRetry: false,
      action: SceneReviewDecision.pass,
    ),
    context: const ContextEnrichmentOutput(
      effectiveMaterials: ProjectMaterialSnapshot(),
    ),
    attempt: 1,
    softFailureCount: 0,
    narrativeArcBeforeScene: NarrativeArcState(),
  );
}
