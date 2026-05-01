import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/local_settings_file.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_quality_scorer.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_scheduler.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_formatter_trace.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

Future<void> main() async {
  final outputRoot = _newOutputRoot();
  await outputRoot.create(recursive: true);
  final latestFile = File(
    'artifacts/real_validation/one_chapter_probe/latest_path.txt',
  );
  await latestFile.parent.create(recursive: true);
  await latestFile.writeAsString('${outputRoot.path}\n');

  final rawIoFile = File('${outputRoot.path}/runtime/llm-raw-io.jsonl');
  final callTraceFile = File('${outputRoot.path}/runtime/llm-call-trace.jsonl');
  final formatterFile = File(
    '${outputRoot.path}/runtime/formatter-output.jsonl',
  );
  final statusFile = File('${outputRoot.path}/runtime/status.log');
  final statusWriter = _SerializedLineWriter(statusFile);

  Future<void> status(String message) async {
    final line = '${DateTime.now().toIso8601String()} $message';
    stdout.writeln(line);
    await statusWriter.append(line);
  }

  await status('starting real one-chapter probe');

  final config = await _loadLocalConfig(File('setting.json'));
  final settings = _resolveSettings(Platform.environment, config);
  if (settings.apiKey.isEmpty) {
    await _writeFailureReport(
      outputRoot: outputRoot,
      reason:
          'Missing ZHIPU_API_KEY, MIMO_API_KEY, or OLLAMA_API_KEY in setting.json or environment.',
    );
    stderr.writeln(
      'Missing ZHIPU_API_KEY, MIMO_API_KEY, or OLLAMA_API_KEY in setting.json or environment.',
    );
    exitCode = 2;
    return;
  }

  final rawLogger = RawIoLoggingAppLlmClient(
    delegate: createDefaultAppLlmClient(),
    file: rawIoFile,
  );
  final settingsStore = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: rawLogger,
    llmTraceSink: FileAppLlmCallTraceSink(callTraceFile),
  );

  await settingsStore.saveWithFeedback(
    providerName: settings.providerName,
    baseUrl: settings.baseUrl,
    model: settings.model,
    apiKey: settings.apiKey,
    timeout: const AppLlmTimeoutConfig(
      connectTimeoutMs: 10000,
      sendTimeoutMs: 30000,
      receiveTimeoutMs: 180000,
      idleTimeoutMs: 60000,
    ),
    maxConcurrentRequests: settings.maxConcurrentRequests,
    maxTokens: settings.maxTokens,
  );

  await status('testing provider connection model=${settings.model}');
  await settingsStore.testConnection(
    baseUrl: settings.baseUrl,
    model: settings.model,
    apiKey: settings.apiKey,
    timeout: const AppLlmTimeoutConfig(
      connectTimeoutMs: 10000,
      sendTimeoutMs: 30000,
      receiveTimeoutMs: 60000,
      idleTimeoutMs: 30000,
    ),
    maxTokens: settings.maxTokens,
  );
  if (settingsStore.connectionTestState.status !=
      AppSettingsConnectionTestStatus.success) {
    await _writeFailureReport(
      outputRoot: outputRoot,
      reason:
          'Connection failed: ${settingsStore.connectionTestState.title} / ${settingsStore.connectionTestState.message}',
    );
    stderr.writeln(
      'Connection failed: ${settingsStore.connectionTestState.title} / ${settingsStore.connectionTestState.message}',
    );
    exitCode = 3;
    return;
  }

  final formatterTraceSink = FileStoryGenerationFormatterTraceSink(
    formatterFile,
  );
  ChapterGenerationOrchestrator createOrchestrator() =>
      ChapterGenerationOrchestrator(
        settingsStore: settingsStore,
        maxProseRetries: 1,
        reviewCoordinator: SceneReviewCoordinator(
          settingsStore: settingsStore,
          formatterTraceSink: formatterTraceSink,
        ),
        qualityScorer: SceneQualityScorer(settingsStore: settingsStore),
        onStatus: (message) {
          unawaited(status(message));
        },
      );

  final sceneOutputs = <SceneRuntimeOutput>[];
  final scenes = _chapterScenes();
  final chapterStarted = DateTime.now();
  final scheduler = ScenePipelineScheduler<SceneBrief, SceneRuntimeOutput>(
    maxConcurrentScenes: settings.maxConcurrentScenes,
  );
  try {
    final outputs = await scheduler.run(
      scenes: scenes,
      runScene: (brief, {required onSpeculationReady}) async {
        await status('running scene ${brief.sceneId} ${brief.sceneTitle}');
        final output = await createOrchestrator().runScene(
          brief,
          materials: _materials(_plannedPriorSceneSummaries(scenes, brief)),
          onSpeculationReady: () {
            onSpeculationReady();
            unawaited(
              status(
                'scene ${brief.sceneId} roleplay complete -> releasing next scene',
              ),
            );
          },
          onStatus: (message) {
            unawaited(status(message));
          },
        );
        sceneOutputs.add(output);
        await _writeSceneArtifact(outputRoot: outputRoot, output: output);
        await status(
          'scene ${brief.sceneId} done decision=${output.review.decision.name} chars=${output.prose.text.length}',
        );
        return output;
      },
    );
    sceneOutputs
      ..clear()
      ..addAll(outputs);
  } on Object catch (error) {
    await status('chapter probe failed error=${_oneLine(error.toString())}');
    final elapsedMs = DateTime.now().difference(chapterStarted).inMilliseconds;
    final orderedOutputs = _orderedOutputs(
      scenes: scenes,
      outputs: sceneOutputs,
    );
    await _writeChapterArtifact(
      outputRoot: outputRoot,
      outputs: orderedOutputs,
    );
    final summary = await _buildSummary(
      outputRoot: outputRoot,
      settings: settings,
      outputs: orderedOutputs,
      elapsedMs: elapsedMs,
      failureReason: 'Chapter probe failed: $error',
    );
    await File('${outputRoot.path}/run-report.md').writeAsString(summary);
    settingsStore.dispose();
    exitCode = 4;
    return;
  }

  final elapsedMs = DateTime.now().difference(chapterStarted).inMilliseconds;
  await _writeChapterArtifact(outputRoot: outputRoot, outputs: sceneOutputs);
  final summary = await _buildSummary(
    outputRoot: outputRoot,
    settings: settings,
    outputs: sceneOutputs,
    elapsedMs: elapsedMs,
  );
  await File('${outputRoot.path}/run-report.md').writeAsString(summary);
  settingsStore.dispose();
  await status('probe complete output=${outputRoot.path}');
  stdout.writeln('REAL_CHAIN_PROBE_OUTPUT=${outputRoot.path}');
}

Directory _newOutputRoot() {
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '-');
  return Directory('artifacts/real_validation/one_chapter_probe/run-$stamp');
}

List<SceneBrief> _chapterScenes() {
  final cast = [
    SceneCastCandidate(
      characterId: 'char-lin',
      name: '林澈',
      role: '城市声学调查员',
      participation: const SceneCastParticipation(
        action: '追踪无声区的异常频率',
        dialogue: '质疑旧电台留下的记录',
        interaction: '逼迫守门人交出监听日志',
      ),
    ),
    SceneCastCandidate(
      characterId: 'char-yan',
      name: '严泊',
      role: '旧电台守门人',
      participation: const SceneCastParticipation(
        action: '守住地下机房入口',
        dialogue: '用半真半假的解释拖住林澈',
        interaction: '试探林澈是否知道十五年前的事故',
      ),
    ),
    SceneCastCandidate(
      characterId: 'char-qiao',
      name: '乔眠',
      role: '失踪调音师的女儿',
      participation: const SceneCastParticipation(
        action: '带来父亲留下的调音叉',
        dialogue: '要求进入无声区确认真相',
        interaction: '在林澈和严泊之间施加情感压力',
      ),
    ),
  ];
  return [
    SceneBrief(
      projectId: 'real-chain-probe',
      chapterId: 'chapter-01',
      chapterTitle: '第一章 无声区的回响',
      sceneId: 'scene-01',
      sceneTitle: '旧电台门厅',
      targetLength: 800,
      targetBeat: '林澈发现无声区扩张，严泊被迫承认监听日志存在。',
      sceneSummary:
          '雨夜里，林澈循着消失的城市噪声来到废弃电台。严泊守在门厅，声称机器早已停摆；乔眠带着父亲的调音叉赶到，迫使严泊露出破绽。',
      worldNodeIds: const ['silent-zone', 'old-radio'],
      cast: cast,
      metadata: const {
        'roleplayRounds': 1,
        'parallelRoleplayTurns': true,
        'roleplayMaxSpeakersPerRound': 3,
      },
    ),
    SceneBrief(
      projectId: 'real-chain-probe',
      chapterId: 'chapter-01',
      chapterTitle: '第一章 无声区的回响',
      sceneId: 'scene-02',
      sceneTitle: '地下监听室',
      targetLength: 800,
      targetBeat: '三人听到十五年前的残留频率，确认无声区不是自然现象。',
      sceneSummary:
          '林澈、严泊和乔眠进入地下监听室。旧磁带里只剩断续波形，乔眠的调音叉却让波形复原，暴露出当年事故中被遮掩的一段求救声。',
      worldNodeIds: const ['silent-zone', 'resonance-log'],
      cast: cast,
      metadata: const {
        'roleplayRounds': 1,
        'parallelRoleplayTurns': true,
        'roleplayMaxSpeakersPerRound': 3,
      },
    ),
    SceneBrief(
      projectId: 'real-chain-probe',
      chapterId: 'chapter-01',
      chapterTitle: '第一章 无声区的回响',
      sceneId: 'scene-03',
      sceneTitle: '天线塔顶',
      targetLength: 800,
      targetBeat: '林澈决定公开日志，严泊选择留下拖延无声区扩张，乔眠听见父亲的最后留言。',
      sceneSummary:
          '无声区开始吞没电台外缘，三人爬上天线塔发送监听日志。严泊承认自己多年守门是为了阻止频率外泄，乔眠在最后一段回响里听见父亲留下的坐标。',
      worldNodeIds: const ['silent-zone', 'antenna-tower'],
      cast: cast,
      metadata: const {
        'roleplayRounds': 1,
        'parallelRoleplayTurns': true,
        'roleplayMaxSpeakersPerRound': 3,
      },
    ),
  ];
}

ProjectMaterialSnapshot _materials(List<String> acceptedSceneSummaries) {
  return ProjectMaterialSnapshot(
    worldFacts: const [
      '无声区会吞没环境声，但保留被特定频率激活的旧录音。',
      '旧电台十五年前发生过调音事故，官方记录只保留设备故障结论。',
      '调音叉能短暂恢复残留波形，但会让无声区向声源靠近。',
    ],
    characterProfiles: const [
      '林澈：城市声学调查员，习惯从可观测噪声变化判断风险。',
      '严泊：旧电台守门人，知道事故真相的一部分，倾向用拖延保护现场。',
      '乔眠：失踪调音师的女儿，想确认父亲是否真的死于设备故障。',
    ],
    relationshipHints: const [
      '林澈不信任严泊，但需要他打开旧系统。',
      '乔眠对严泊有旧怨，也担心林澈把父亲当成案件线索处理。',
    ],
    outlineBeats: const ['第一章目标：从无声区异常进入旧电台真相。', '第一章钩子：最后留言指向城市另一处仍在发声的坐标。'],
    acceptedStates: acceptedSceneSummaries,
  );
}

Future<void> _writeSceneArtifact({
  required Directory outputRoot,
  required SceneRuntimeOutput output,
}) async {
  final file = File('${outputRoot.path}/scenes/${output.brief.sceneId}.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'sceneId': output.brief.sceneId,
      'sceneTitle': output.brief.sceneTitle,
      'targetLength': output.brief.targetLength,
      'proseChars': output.prose.text.length,
      'proseAttempts': output.proseAttempts,
      'softFailureCount': output.softFailureCount,
      'reviewDecision': output.review.decision.name,
      'reviewFeedback': output.review.editorialFeedback,
      'qualityScore': output.qualityScore?.toJson(),
      'director': output.director.text,
      'roleOutputs': [
        for (final role in output.roleOutputs)
          {
            'characterId': role.characterId,
            'name': role.name,
            'text': role.text,
          },
      ],
      'resolvedBeats': [
        for (final beat in output.resolvedBeats)
          {
            'beatIndex': beat.beatIndex,
            'actorId': beat.actorId,
            'actionAccepted': beat.actionAccepted,
            'acceptedSpeech': beat.acceptedSpeech,
            'acceptedAction': beat.acceptedAction,
            'rejectionReason': beat.rejectionReason,
            'stateDelta': beat.stateDelta,
            'newPublicFacts': beat.newPublicFacts,
            'continuityNotes': beat.continuityNotes,
          },
      ],
      'prose': output.prose.text,
    }),
  );
}

Future<void> _writeChapterArtifact({
  required Directory outputRoot,
  required List<SceneRuntimeOutput> outputs,
}) async {
  final buffer = StringBuffer('# 第一章 无声区的回响\n\n');
  for (final output in outputs) {
    buffer
      ..writeln('## ${output.brief.sceneTitle}')
      ..writeln()
      ..writeln(output.prose.text.trim())
      ..writeln();
  }
  await File(
    '${outputRoot.path}/chapter-01.md',
  ).writeAsString(buffer.toString());
}

Future<String> _buildSummary({
  required Directory outputRoot,
  required _ResolvedSettings settings,
  required List<SceneRuntimeOutput> outputs,
  required int elapsedMs,
  String? failureReason,
}) async {
  final rawRecords = await _readJsonl(
    File('${outputRoot.path}/runtime/llm-raw-io.jsonl'),
  );
  final traceRecords = await _readJsonl(
    File('${outputRoot.path}/runtime/llm-call-trace.jsonl'),
  );
  final formatterRecords = await _readJsonl(
    File('${outputRoot.path}/runtime/formatter-output.jsonl'),
  );
  final succeeded = rawRecords.where((r) => r['succeeded'] == true).length;
  final failed = rawRecords.length - succeeded;
  final totalPromptTokens = _sumTrace(traceRecords, 'promptTokens');
  final totalCompletionTokens = _sumTrace(traceRecords, 'completionTokens');
  final estimatedPromptTokens = _sumTrace(
    traceRecords,
    'estimatedPromptTokens',
  );
  final estimatedCompletionTokens = _sumTrace(
    traceRecords,
    'estimatedCompletionTokens',
  );
  final byTrace = <String, _TraceStats>{};
  for (final record in traceRecords) {
    final name = record['traceName']?.toString() ?? 'unknown';
    byTrace.putIfAbsent(name, _TraceStats.new).add(record);
  }
  final slowest = [...traceRecords]
    ..sort((a, b) {
      final lb = (b['latencyMs'] as int?) ?? 0;
      final la = (a['latencyMs'] as int?) ?? 0;
      return lb.compareTo(la);
    });
  final chapterChars = outputs.fold<int>(
    0,
    (sum, o) => sum + o.prose.text.length,
  );
  final buffer = StringBuffer()
    ..writeln('# Real Chain Probe Report')
    ..writeln()
    ..writeln('- output: `${outputRoot.path}`')
    ..writeln(
      '- provider host: `${Uri.tryParse(settings.baseUrl)?.host ?? settings.baseUrl}`',
    )
    ..writeln('- model: `${settings.model}`')
    ..writeln('- max concurrent requests: ${settings.maxConcurrentRequests}')
    ..writeln('- max concurrent scenes: ${settings.maxConcurrentScenes}')
    ..writeln('- elapsed: ${(elapsedMs / 1000).toStringAsFixed(1)}s')
    ..writeln(
      '- llm calls: ${rawRecords.length} succeeded=$succeeded failed=$failed',
    )
    ..writeln('- formatter records: ${formatterRecords.length}')
    ..writeln('- chapter chars: $chapterChars')
    ..writeln('- status: ${failureReason == null ? 'complete' : 'failed'}')
    ..writeln(
      '- token usage: prompt=${totalPromptTokens ?? 'n/a'} completion=${totalCompletionTokens ?? 'n/a'}',
    )
    ..writeln(
      '- estimated tokens: prompt=$estimatedPromptTokens completion=$estimatedCompletionTokens',
    );
  if (failureReason != null) {
    buffer.writeln('- failure: `${_oneLine(failureReason)}`');
  }
  buffer
    ..writeln()
    ..writeln('## Scenes')
    ..writeln()
    ..writeln('| Scene | Chars | Attempts | Review | Quality |')
    ..writeln('| --- | ---: | ---: | --- | --- |');
  for (final output in outputs) {
    final quality = output.qualityScore == null
        ? 'n/a'
        : output.qualityScore!.overall.toStringAsFixed(1);
    buffer.writeln(
      '| ${output.brief.sceneId} ${output.brief.sceneTitle} | ${output.prose.text.length} | ${output.proseAttempts} | ${output.review.decision.name} | $quality |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Calls By Trace')
    ..writeln()
    ..writeln(
      '| Trace | Calls | Success | Latency ms | Prompt tok | Completion tok | Est prompt | Est completion |',
    )
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (final entry
      in byTrace.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final s = entry.value;
    buffer.writeln(
      '| ${entry.key} | ${s.calls} | ${s.successes} | ${s.latencyMs} | ${s.promptTokens ?? 0} | ${s.completionTokens ?? 0} | ${s.estimatedPromptTokens} | ${s.estimatedCompletionTokens} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Slowest Calls')
    ..writeln()
    ..writeln('| Trace | Scene | Latency ms | Completion chars | Max tokens |')
    ..writeln('| --- | --- | ---: | ---: | ---: |');
  for (final record in slowest.take(8)) {
    final metadata = record['metadata'];
    final sceneId = metadata is Map
        ? metadata['sceneId']?.toString() ?? ''
        : '';
    buffer.writeln(
      '| ${record['traceName']} | $sceneId | ${record['latencyMs'] ?? 0} | ${record['completionChars'] ?? 0} | ${record['maxTokens'] ?? 0} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## Files')
    ..writeln()
    ..writeln('- raw IO: `runtime/llm-raw-io.jsonl`')
    ..writeln('- call trace: `runtime/llm-call-trace.jsonl`')
    ..writeln('- formatter trace: `runtime/formatter-output.jsonl`')
    ..writeln('- chapter prose: `chapter-01.md`')
    ..writeln('- scene details: `scenes/*.json`');
  return buffer.toString();
}

Future<List<Map<String, Object?>>> _readJsonl(File file) async {
  if (!await file.exists()) return const [];
  final records = <Map<String, Object?>>[];
  for (final line in await file.readAsLines()) {
    if (line.trim().isEmpty) continue;
    final decoded = jsonDecode(line);
    if (decoded is Map) {
      records.add(decoded.cast<String, Object?>());
    }
  }
  return records;
}

int? _sumTrace(List<Map<String, Object?>> records, String key) {
  var sawValue = false;
  var sum = 0;
  for (final record in records) {
    final value = record[key];
    if (value is int) {
      sawValue = true;
      sum += value;
    }
  }
  return sawValue ? sum : null;
}

List<String> _plannedPriorSceneSummaries(
  List<SceneBrief> scenes,
  SceneBrief brief,
) {
  final sceneIndex = scenes.indexWhere(
    (scene) => scene.sceneId == brief.sceneId,
  );
  if (sceneIndex <= 0) {
    return const [];
  }
  return [
    for (final scene in scenes.take(sceneIndex))
      '${scene.sceneTitle}: ${_oneLine(scene.sceneSummary)}',
  ];
}

List<SceneRuntimeOutput> _orderedOutputs({
  required List<SceneBrief> scenes,
  required List<SceneRuntimeOutput> outputs,
}) {
  final outputBySceneId = {
    for (final output in outputs) output.brief.sceneId: output,
  };
  return [
    for (final scene in scenes)
      if (outputBySceneId[scene.sceneId] case final output?) output,
  ];
}

String _oneLine(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length <= 140
      ? normalized
      : '${normalized.substring(0, 140)}...';
}

Future<void> _writeFailureReport({
  required Directory outputRoot,
  required String reason,
}) async {
  await File(
    '${outputRoot.path}/run-report.md',
  ).writeAsString('# Real Chain Probe Failed\n\n$reason\n');
}

Future<Map<String, String>> _loadLocalConfig(File file) {
  return loadLocalSettingsFile(file: file);
}

_ResolvedSettings _resolveSettings(
  Map<String, String> environment,
  Map<String, String> localConfig,
) {
  final baseUrl = _firstNonEmpty([
    environment['ZHIPU_BASE_URL'],
    environment['MIMO_BASE_URL'],
    environment['OLLAMA_BASE_URL'],
    localConfig['ZHIPU_BASE_URL'],
    localConfig['MIMO_BASE_URL'],
    localConfig['OLLAMA_BASE_URL'],
    localConfig['baseUrl'],
    'https://ollama.com/v1',
  ]);
  final apiKey = _firstNonEmpty([
    environment['ZHIPU_API_KEY'],
    environment['MIMO_API_KEY'],
    environment['OLLAMA_API_KEY'],
    localConfig['ZHIPU_API_KEY'],
    localConfig['MIMO_API_KEY'],
    localConfig['OLLAMA_API_KEY'],
    localConfig['apiKey'],
  ]);
  final model = _firstNonEmpty([
    environment['ZHIPU_MODEL'],
    environment['MIMO_MODEL'],
    environment['REAL_AI_MODEL'],
    localConfig['ZHIPU_MODEL'],
    localConfig['MIMO_MODEL'],
    localConfig['REAL_AI_MODEL'],
    localConfig['model'],
    'kimi-k2.6',
  ]);
  final providerName = _firstNonEmpty([
    localConfig['providerName'],
    _isZhipuBaseUrl(baseUrl) ? '智谱 GLM' : null,
    baseUrl.contains('xiaomimimo.com') ? 'Xiaomi MiMo' : null,
    'Ollama Cloud',
  ]);
  final maxConcurrent =
      int.tryParse(
        _firstNonEmpty([
          environment['REAL_AI_MAX_CONCURRENT'],
          environment['REAL_AI_MAX_CONCURRENT_REQUESTS'],
          localConfig['REAL_AI_MAX_CONCURRENT'],
          localConfig['REAL_AI_MAX_CONCURRENT_REQUESTS'],
          localConfig['maxConcurrentRequests'],
          '3',
        ]),
      ) ??
      3;
  final maxConcurrentScenes =
      int.tryParse(
        _firstNonEmpty([
          environment['REAL_AI_MAX_CONCURRENT_SCENES'],
          environment['REAL_AI_MAX_CONCURRENT_SCENE_RUNS'],
          localConfig['REAL_AI_MAX_CONCURRENT_SCENES'],
          localConfig['REAL_AI_MAX_CONCURRENT_SCENE_RUNS'],
          localConfig['maxConcurrentScenes'],
          '2',
        ]),
      ) ??
      2;
  final maxTokens =
      int.tryParse(
        _firstNonEmpty([
          environment['REAL_AI_MAX_TOKENS'],
          localConfig['REAL_AI_MAX_TOKENS'],
          localConfig['maxTokens'],
          '${AppLlmChatRequest.unlimitedMaxTokens}',
        ]),
      ) ??
      AppLlmChatRequest.unlimitedMaxTokens;
  return _ResolvedSettings(
    providerName: providerName,
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    maxConcurrentRequests: maxConcurrent.clamp(1, 6),
    maxConcurrentScenes: maxConcurrentScenes.clamp(1, 4),
    maxTokens: AppLlmChatRequest.normalizeMaxTokens(maxTokens),
  );
}

bool _isZhipuBaseUrl(String baseUrl) {
  final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase() ?? '';
  return host.contains('bigmodel.cn') || host.contains('zhipuai.cn');
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

class _ResolvedSettings {
  const _ResolvedSettings({
    required this.providerName,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.maxConcurrentRequests,
    required this.maxConcurrentScenes,
    required this.maxTokens,
  });

  final String providerName;
  final String baseUrl;
  final String apiKey;
  final String model;
  final int maxConcurrentRequests;
  final int maxConcurrentScenes;
  final int maxTokens;
}

class RawIoLoggingAppLlmClient implements AppLlmClient {
  RawIoLoggingAppLlmClient({required this.delegate, required File file})
    : _writer = _SerializedLineWriter(file);

  final AppLlmClient delegate;
  final _SerializedLineWriter _writer;
  int _sequence = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final sequence = ++_sequence;
    final started = DateTime.now();
    AppLlmChatResult result;
    Object? thrown;
    try {
      result = await delegate.chat(request);
    } catch (error) {
      thrown = error;
      result = AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: error.toString(),
      );
    }
    await _writeRecord(
      sequence: sequence,
      started: started,
      request: request,
      result: result,
      thrown: thrown,
    );
    if (thrown != null) {
      Error.throwWithStackTrace(thrown, StackTrace.current);
    }
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return delegate.chatStream(request);
  }

  Future<void> _writeRecord({
    required int sequence,
    required DateTime started,
    required AppLlmChatRequest request,
    required AppLlmChatResult result,
    required Object? thrown,
  }) async {
    final promptChars = request.messages.fold<int>(
      0,
      (sum, message) => sum + message.role.length + message.content.length,
    );
    final completion = result.text ?? '';
    final record = <String, Object?>{
      'sequence': sequence,
      'timestamp': started.toIso8601String(),
      'traceName': _inferTraceName(request.messages),
      'provider': request.provider.name,
      'host': Uri.tryParse(request.baseUrl)?.host ?? request.baseUrl,
      'model': request.model,
      'maxTokens': request.effectiveMaxTokens,
      'timeoutMs': {
        'connect': request.timeout.connectTimeoutMs,
        'send': request.timeout.sendTimeoutMs,
        'receive': request.timeout.receiveTimeoutMs,
        'idle': request.timeout.idleTimeoutMs,
      },
      'messages': [
        for (final message in request.messages)
          {'role': message.role, 'content': message.content},
      ],
      'promptChars': promptChars,
      'estimatedPromptTokens': (promptChars / 4).ceil(),
      'succeeded': result.succeeded,
      if (result.failureKind != null) 'failureKind': result.failureKind!.name,
      if (result.statusCode != null) 'statusCode': result.statusCode,
      if (result.detail != null) 'detail': result.detail,
      if (result.latencyMs != null) 'latencyMs': result.latencyMs,
      if (result.promptTokens != null) 'promptTokens': result.promptTokens,
      if (result.completionTokens != null)
        'completionTokens': result.completionTokens,
      if (result.totalTokens != null) 'totalTokens': result.totalTokens,
      'completionChars': completion.length,
      'estimatedCompletionTokens': (completion.length / 4).ceil(),
      'responseText': completion,
      if (thrown != null) 'thrown': thrown.toString(),
    };
    await _writer.appendJson(record);
  }
}

String _inferTraceName(List<AppLlmChatMessage> messages) {
  final taskPattern = RegExp(r'^(任务|任务类型)[:：]\s*(.+)$');
  for (final message in messages.reversed) {
    for (final line in message.content.split('\n')) {
      final match = taskPattern.firstMatch(line.trim());
      final value = match?.group(2)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
  }
  return 'llm_chat';
}

class FileAppLlmCallTraceSink implements AppLlmCallTraceSink {
  FileAppLlmCallTraceSink(File file) : _writer = _SerializedLineWriter(file);

  final _SerializedLineWriter _writer;

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    await _writer.appendJson(entry.toJson());
  }
}

class FileStoryGenerationFormatterTraceSink
    implements StoryGenerationFormatterTraceSink {
  FileStoryGenerationFormatterTraceSink(File file)
    : _writer = _SerializedLineWriter(file);

  final _SerializedLineWriter _writer;

  @override
  Future<void> record(StoryGenerationFormatterTraceEntry entry) async {
    await _writer.appendJson(entry.toJson());
  }
}

class _SerializedLineWriter {
  _SerializedLineWriter(this.file);

  final File file;
  Future<void> _pending = Future<void>.value();

  Future<void> appendJson(Object? value) => append(jsonEncode(value));

  Future<void> append(String line) {
    final write = _pending.then((_) async {
      await file.parent.create(recursive: true);
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    });
    _pending = write.catchError((Object _) {});
    return write;
  }
}

class _TraceStats {
  var calls = 0;
  var successes = 0;
  var latencyMs = 0;
  int? promptTokens;
  int? completionTokens;
  var estimatedPromptTokens = 0;
  var estimatedCompletionTokens = 0;

  void add(Map<String, Object?> record) {
    calls += 1;
    if (record['succeeded'] == true) successes += 1;
    latencyMs += (record['latencyMs'] as int?) ?? 0;
    final prompt = record['promptTokens'];
    if (prompt is int) promptTokens = (promptTokens ?? 0) + prompt;
    final completion = record['completionTokens'];
    if (completion is int) {
      completionTokens = (completionTokens ?? 0) + completion;
    }
    estimatedPromptTokens += (record['estimatedPromptTokens'] as int?) ?? 0;
    estimatedCompletionTokens +=
        (record['estimatedCompletionTokens'] as int?) ?? 0;
  }
}
