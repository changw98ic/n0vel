import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client_io.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_candidate_identity.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_receipt.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/scene_hard_gates.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

int _formalEvaluationFixtureSerial = 0;
int _sealedRunnerFixtureSerial = 0;

const String sealedRunnerFixtureFinalProse =
    '危险的脚步声逼近码头。“仓库编号。”阿岚把账页压在灯下，挡住线人的退路。'
    '线人退到生锈的护栏边：“我不知道。”'
    '“你知道。账页的墨还没干，门锁刮痕也对得上。”'
    '线人盯着雨幕，终于低声说：“七号仓。钥匙在码头主管手里。”'
    '阿岚收起账页：“带路，别碰警报。”'
    '局面从僵持转入追查，远处的脚步声却正在逼近。';

final class FormalEvaluationFixtureRun<T> {
  const FormalEvaluationFixtureRun({
    required this.value,
    required this.attempts,
    required this.providerCallCount,
  });

  final T value;
  final List<StoryGenerationAttemptEvidence> attempts;
  final int providerCallCount;
}

/// Exercises the real platform HTTP client, formal dispatch authority, and
/// durable evidence journal before returning a parsed evaluator DTO.
Future<FormalEvaluationFixtureRun<T>> runFormalEvaluationProvenanceFixture<T>({
  required List<String> responses,
  required Future<T> Function(AppSettingsStore settingsStore) body,
}) async {
  final serial = _formalEvaluationFixtureSerial += 1;
  final directory = await Directory.systemTemp.createTemp(
    'novel-writer-formal-evaluation-$serial-',
  );
  final protocol = await _FormalEvaluationProtocol.start(responses: responses);
  final log = PipelineEventLogImpl(
    jsonlPath: '${directory.path}/pipeline-evidence.jsonl',
  );
  final settings = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: createAppLlmClient(),
    eventLog: AppEventLog(storage: _DiscardingAppEventLogStorage()),
  );
  try {
    await settings.save(
      providerName: 'OpenAI Compatible Formal Evaluation Fixture',
      baseUrl: protocol.baseUrl,
      model: _FormalEvaluationProtocol.model,
      apiKey: '',
      timeoutMs: 10000,
      maxConcurrentRequests: 1,
    );
    final evidenceRunId = 'formal-evaluation-run-$serial';
    final sceneId = 'formal-evaluation-scene-$serial';
    final preparedBriefDigest = AppLlmCanonicalHash.domainHash(
      'formal-evaluation-fixture-prepared-brief-v1',
      <String, Object?>{'serial': serial},
    );
    final journal = await log.openStoryGenerationEvidenceJournal(
      evidenceRunId: evidenceRunId,
      sceneId: sceneId,
      preparedBriefDigest: preparedBriefDigest,
      generationArmPolicy: 'formal-evaluation-fixture-arm-v1',
    );
    final capture = StoryGenerationAttemptEvidenceCapture();
    final value = await StoryGenerationRetryScope.run<Future<T>>(
      policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
        maxTotalAttempts: 1,
      ),
      onAttemptEvidence: capture.record,
      persistAttemptIntent: journal.persistIntent,
      persistAttemptEvidence: journal.persistAttempt,
      generationArmPolicy: 'formal-evaluation-fixture-arm-v1',
      evidenceRunId: evidenceRunId,
      evidenceSceneId: sceneId,
      preparedBriefDigest: preparedBriefDigest,
      body: () => body(settings),
    );
    final attempts = capture.attempts;
    if (attempts.length != protocol.callCount ||
        attempts.any((attempt) => !attempt.evidenceComplete)) {
      throw StateError('formal evaluation fixture evidence is incomplete');
    }
    return FormalEvaluationFixtureRun<T>(
      value: value,
      attempts: attempts,
      providerCallCount: protocol.callCount,
    );
  } finally {
    await settings.quiesceLlmDispatches();
    settings.dispose();
    await log.dispose();
    await protocol.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

/// Live resources and exact runtime capabilities returned by the production
/// sealed runner. Callers must invoke [close] after consuming the output in a
/// finalizer test.
final class RealSealedRunnerFixture {
  RealSealedRunnerFixture._({
    required this.runId,
    required this.projectId,
    required this.sceneId,
    required this.prepared,
    required this.capture,
    required this.output,
    required this.ledger,
    required this.finalizer,
    required this.providerCallCount,
    required Directory directory,
    required AppSettingsStore settings,
    required PipelineEventLogImpl eventLog,
    required _FormalEvaluationProtocol protocol,
    required Database database,
  }) : _directory = directory,
       _settings = settings,
       _eventLog = eventLog,
       _protocol = protocol,
       _database = database;

  final String runId;
  final String projectId;
  final String sceneId;
  final PreparedSceneBrief prepared;
  final GenerationRunCapture capture;
  final SceneRuntimeOutput output;
  final GenerationLedgerSqliteStore ledger;
  final GenerationLedgerCandidateFinalizer finalizer;
  final int providerCallCount;

  final Directory _directory;
  final AppSettingsStore _settings;
  final PipelineEventLogImpl _eventLog;
  final _FormalEvaluationProtocol _protocol;
  final Database _database;
  bool _closed = false;

  GenerationEvidenceReceipt get receipt =>
      output.generationEvidenceReceipt ??
      (throw StateError('sealed runner fixture has no receipt'));

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _settings.quiesceLlmDispatches();
    _settings.dispose();
    await _eventLog.dispose();
    await _protocol.close();
    _database.dispose();
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }
}

/// Runs the concrete sealed production dependency graph against a real local
/// OpenAI-compatible HTTP server and one durable JSONL journal.
///
/// No proof, parsed DTO, receipt, or runner admission is constructed by this
/// fixture. They all come from the public production runner/finalizer path.
Future<RealSealedRunnerFixture> prepareRealSealedRunnerFixture() async {
  final serial = _sealedRunnerFixtureSerial += 1;
  final runId = 'sealed-runner-fixture-run-$serial';
  final projectId = 'sealed-runner-fixture-project-$serial';
  final sceneId = 'sealed-runner-fixture-scene-$serial';
  const generationArmPolicy = 'sealed-runner-fixture-arm-v1';
  final directory = await Directory.systemTemp.createTemp(
    'novel-writer-sealed-runner-$serial-',
  );
  final protocol = await _FormalEvaluationProtocol.start(
    responses: _sealedRunnerResponses,
  );
  final eventLog = PipelineEventLogImpl(
    jsonlPath: '${directory.path}/pipeline-evidence.jsonl',
  );
  final settings = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: createAppLlmClient(),
    eventLog: AppEventLog(storage: _DiscardingAppEventLogStorage()),
  );
  final database = sqlite3.openInMemory();
  database.execute('PRAGMA foreign_keys = ON');
  final ledger = GenerationLedgerSqliteStore(db: database)..ensureTables();
  final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
  try {
    await settings.save(
      providerName: 'OpenAI Compatible Sealed Runner Fixture',
      baseUrl: protocol.baseUrl,
      model: _FormalEvaluationProtocol.model,
      apiKey: '',
      timeoutMs: 10000,
      maxConcurrentRequests: 1,
    );
    final runner = PipelineStageRunnerImpl.sealedProduction(
      settingsStore: settings,
      eventLog: eventLog,
      pipelineConfig: GenerationPipelineConfig(
        maxProseRetries: 0,
        maxQualityRepairRetries: 0,
        maxSceneReplanRetries: 0,
        hardGatesEnabled: true,
        sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
        generationArmPolicy: generationArmPolicy,
        evidenceRunId: runId,
      ),
    );
    const materials = ProjectMaterialSnapshot(
      outlineBeats: <String>['阿岚逼问线人，并取得仓库编号。'],
      sceneSummaries: <String>['雨夜码头的逼问从僵持转入追查。'],
    );
    final brief = SceneBrief(
      projectId: projectId,
      chapterId: 'sealed-runner-fixture-chapter-$serial',
      chapterTitle: '第一章 雨夜码头',
      sceneId: sceneId,
      sceneTitle: '账页与仓库编号',
      sceneSummary: '阿岚在雨夜逼问线人，取得仓库编号。',
      targetBeat: '阿岚逼问线人，得到仓库编号，局面转入追查。',
      targetLength: 120,
      formalExecution: true,
      metadata: const <String, Object?>{
        'continuityLedger': <Object?>[],
        'requiredOutlineBeats': <Object?>[
          <String, Object?>{
            'id': 'beat-warehouse-number',
            'description': '阿岚逼问线人，取得仓库编号并转入追查。',
            'evidenceGroups': <Object?>[
              <String>['阿岚'],
              <String>['线人'],
              <String>['仓库编号', '七号仓'],
              <String>['追查', '带路'],
            ],
          },
        ],
      },
    );
    final prepared = runner.prepareSceneBrief(brief, materials: materials);
    final hardGateViolation = sceneHardGateViolationText(
      brief: prepared.brief,
      proseText: sealedRunnerFixtureFinalProse,
    );
    if (hardGateViolation.isNotEmpty) {
      throw StateError(
        'sealed fixture prose failed hard gates: $hardGateViolation',
      );
    }
    final capture = finalizer.startRun(
      runId: runId,
      requestId: 'sealed-runner-fixture-request-$serial',
      projectId: projectId,
      chapterId: prepared.brief.chapterId,
      sceneId: sceneId,
      sceneScopeId: '$projectId::$sceneId',
      baseDraft: '作者原始草稿',
      brief: prepared.brief,
      materials: prepared.materials!,
      nowMs: 1000 + serial,
      preparedBriefDigest: prepared.digest,
      generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
      generationArmPolicy: generationArmPolicy,
    );
    runner
      ..generationLedger = ledger
      ..checkpointRunId = runId
      ..deferFinalizationCheckpointToCandidateLedger = true;

    final output = await runner.runPreparedScene(prepared);
    if (protocol.callCount != _sealedRunnerResponses.length ||
        output.prose.text != sealedRunnerFixtureFinalProse ||
        output.generationEvidenceReceipt?.finalEvaluationManifest == null) {
      throw StateError('sealed runner fixture did not close exact production');
    }
    return RealSealedRunnerFixture._(
      runId: runId,
      projectId: projectId,
      sceneId: sceneId,
      prepared: prepared,
      capture: capture,
      output: output,
      ledger: ledger,
      finalizer: finalizer,
      providerCallCount: protocol.callCount,
      directory: directory,
      settings: settings,
      eventLog: eventLog,
      protocol: protocol,
      database: database,
    );
  } on Object {
    await settings.quiesceLlmDispatches();
    settings.dispose();
    await eventLog.dispose();
    await protocol.close();
    database.dispose();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    rethrow;
  }
}

const String _sealedRunnerQualityResponse =
    '文笔：98\n连贯：98\n角色：98\n完整：98\n文风：98\n修辞：98\n'
    '节奏：98\n忠实：98\n综合：98\n总结：正文完整且忠于场景任务。';
const String _sealedRunnerStageResponse =
    '舞台事实：阿岚把账页压在灯下\n'
    '环境氛围：雨水持续敲打铁棚\n'
    '可见证据：线人退到生锈护栏边\n'
    '边界：不替角色决定下一步';

final List<String> _sealedRunnerResponses = <String>[
  SceneDirectorPlan(
    target: '逼问线人取得仓库编号',
    conflict: '线人拒绝开口',
    progression: '线人交出编号，局面转入追查',
    constraints: '不改动主线事实',
  ).toText(),
  _sealedRunnerStageResponse,
  '[动作] @narrator 阿岚挡住线人的退路\n[事实] @narrator 线人交出仓库编号',
  sealedRunnerFixtureFinalProse,
  '决定：PASS\n原因：目标、阻碍与局面变化均已落在正文中。',
  '决定：PASS\n原因：正文与场景计划及已知事实一致。',
  '决定：PASS\n原因：阅读动线清楚，信息释放顺序稳定。',
  '决定：PASS\n原因：用词具体，没有模板化占位表达。',
  sealedRunnerFixtureFinalProse,
  '决定：PASS\n原因：润色后的正文保持目标、阻碍与局面变化。',
  '决定：PASS\n原因：润色后的正文与场景计划及已知事实一致。',
  '决定：PASS\n原因：润色后的阅读动线清楚。',
  '决定：PASS\n原因：润色后的用词具体且稳定。',
  _sealedRunnerQualityResponse,
];

final class _FormalEvaluationProtocol {
  _FormalEvaluationProtocol._({
    required HttpServer server,
    required StreamSubscription<HttpRequest> subscription,
    required List<String> responses,
  }) : _server = server,
       _subscription = subscription,
       _responses = List<String>.unmodifiable(responses);

  static const String model = 'formal-evaluation-fixture-model';

  final HttpServer _server;
  // ignore: cancel_subscriptions
  final StreamSubscription<HttpRequest> _subscription;
  final List<String> _responses;
  int callCount = 0;

  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';

  static Future<_FormalEvaluationProtocol> start({
    required List<String> responses,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final _FormalEvaluationProtocol protocol;
    // Ownership moves into [protocol], whose [close] cancels the listener.
    // ignore: cancel_subscriptions
    final subscription = server.listen((request) async {
      await protocol._handle(request);
    });
    protocol = _FormalEvaluationProtocol._(
      server: server,
      subscription: subscription,
      responses: responses,
    );
    return protocol;
  }

  Future<void> _handle(HttpRequest request) async {
    final requestIndex = callCount;
    callCount += 1;
    try {
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body);
      if (request.method != 'POST' ||
          request.uri.path != '/v1/chat/completions' ||
          decoded is! Map ||
          decoded['model'] != model ||
          decoded['messages'] is! List ||
          requestIndex >= _responses.length) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('invalid formal evaluation fixture request');
        return;
      }
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'id': 'formal-evaluation-response-${requestIndex + 1}',
          'object': 'chat.completion',
          'created': 1,
          'model': model,
          'choices': <Object?>[
            <String, Object?>{
              'index': 0,
              'message': <String, Object?>{
                'role': 'assistant',
                'content': _responses[requestIndex],
              },
              'finish_reason': 'stop',
            },
          ],
          'usage': const <String, Object?>{
            'prompt_tokens': 10,
            'completion_tokens': 20,
            'total_tokens': 30,
          },
        }),
      );
    } finally {
      await request.response.close();
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }
}

final class _DiscardingAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
