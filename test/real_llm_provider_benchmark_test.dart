// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_providers.dart' as providers;
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

/// 真实 LLM 供应商工作流集成测试。
///
/// 测试完整的 PipelineStageRunnerImpl 9 步流水线：
///   ContextEnrichment → ScenePlanning → Roleplay → StageNarration →
///   BeatResolution → Editorial → Review → Polish → Finalization
///
/// 运行方式（需要至少一个供应商的 API key）：
///   flutter test test/real_llm_provider_benchmark_test.dart --timeout=10m
///
/// 环境变量：
///   ANTHROPIC_AUTH_TOKEN — 智谱 GLM Coding Plan API key
///   XIAOMI_API_KEY — 小米 MiMo API key
///   OLLAMA_CLOUD_URL — Ollama Cloud URL（默认 https://ollama.com）
///   OLLAMA_CLOUD_KEY — Ollama Cloud API key（Kimi）
///   OLLAMA_CLOUD_MODEL — Ollama Cloud 模型名（默认 kimi-k2.6）
void main() {
  final legacyRealProviderDecision =
      AgentEvaluationRealProviderEntryGate.legacyDecision(
        entryPoint: 'test/real_llm_provider_benchmark_test.dart',
        environment: Platform.environment,
      );
  final realProviderRunAuthorized = legacyRealProviderDecision.authorized;
  final anthropicKey = Platform.environment['ANTHROPIC_AUTH_TOKEN'];
  final xiaomiKey = Platform.environment['XIAOMI_API_KEY'];
  final ollamaCloudUrl = Platform.environment['OLLAMA_CLOUD_URL'];
  final ollamaCloudKey = Platform.environment['OLLAMA_CLOUD_KEY'];
  final ollamaCloudModel =
      Platform.environment['OLLAMA_CLOUD_MODEL'] ?? 'kimi-k2.6';

  final hasZhipu =
      realProviderRunAuthorized &&
      anthropicKey != null &&
      anthropicKey.isNotEmpty;
  final hasMimo =
      realProviderRunAuthorized && xiaomiKey != null && xiaomiKey.isNotEmpty;
  final hasKimi =
      realProviderRunAuthorized &&
      ollamaCloudKey != null &&
      ollamaCloudKey.isNotEmpty;

  group('GLM 工作流', () {
    test('glm-5.1 完整 9 步流水线', () async {
      if (!hasZhipu) {
        markTestSkipped(legacyRealProviderDecision.denialReason);
        return;
      }

      const provider = providers.AppLlmProviderRegistry.zhipuCodingPlanCn;
      final result = await _runWorkflowBenchmark(
        providerName: '智谱 GLM',
        baseUrl: provider.defaultBaseUrl,
        apiKey: anthropicKey,
        model: 'glm-5.1',
      );

      _printWorkflowResult('智谱 GLM', 'glm-5.1', result);
      expect(result.succeeded, isTrue, reason: 'GLM 流水线应成功完成');
      expect(
        result.output!.prose.text.trim().length,
        greaterThan(100),
        reason: '正文输出应超过 100 字',
      );
    }, timeout: const Timeout(Duration(minutes: 20)));
  });

  group('MiMo 工作流', () {
    test('mimo-v2.5-pro 完整 9 步流水线', () async {
      if (!hasMimo) {
        markTestSkipped(legacyRealProviderDecision.denialReason);
        return;
      }

      const provider = providers.AppLlmProviderRegistry.mimo;
      final result = await _runWorkflowBenchmark(
        providerName: '小米 MiMo',
        baseUrl: provider.defaultBaseUrl,
        apiKey: xiaomiKey,
        model: 'mimo-v2.5-pro',
      );

      _printWorkflowResult('小米 MiMo', 'mimo-v2.5-pro', result);
      expect(result.succeeded, isTrue, reason: 'MiMo 流水线应成功完成');
      expect(
        result.output!.prose.text.trim().length,
        greaterThan(100),
        reason: '正文输出应超过 100 字',
      );
    }, timeout: const Timeout(Duration(minutes: 20)));
  });

  group('Kimi 工作流', () {
    test('$ollamaCloudModel 完整 9 步流水线', () async {
      if (!hasKimi) {
        markTestSkipped(legacyRealProviderDecision.denialReason);
        return;
      }

      final baseUrl = ollamaCloudUrl != null && ollamaCloudUrl.isNotEmpty
          ? '$ollamaCloudUrl/v1'
          : 'https://ollama.com/v1';

      final result = await _runWorkflowBenchmark(
        providerName: 'Kimi',
        baseUrl: baseUrl,
        apiKey: ollamaCloudKey,
        model: ollamaCloudModel,
      );

      _printWorkflowResult('Kimi', ollamaCloudModel, result);
      expect(result.succeeded, isTrue, reason: 'Kimi 流水线应成功完成');
      expect(
        result.output!.prose.text.trim().length,
        greaterThan(100),
        reason: '正文输出应超过 100 字',
      );
    }, timeout: const Timeout(Duration(minutes: 20)));
  });

  group('三供应商并行工作流对比', () {
    test('GLM vs MiMo vs Kimi 完整流水线对比', () async {
      final available = <String>[];
      if (hasZhipu) available.add('GLM');
      if (hasMimo) available.add('MiMo');
      if (hasKimi) available.add('Kimi');
      if (available.length < 2) {
        markTestSkipped(legacyRealProviderDecision.denialReason);
        return;
      }

      const zhipuProvider = providers.AppLlmProviderRegistry.zhipuCodingPlanCn;
      const mimoProvider = providers.AppLlmProviderRegistry.mimo;
      final kimiBaseUrl = ollamaCloudUrl != null && ollamaCloudUrl.isNotEmpty
          ? '$ollamaCloudUrl/v1'
          : 'https://ollama.com/v1';

      final futures = <Future<_WorkflowBenchmarkResult>>[];
      final labels = <String>[];

      if (hasZhipu) {
        futures.add(
          _runWorkflowBenchmark(
            providerName: '智谱 GLM',
            baseUrl: zhipuProvider.defaultBaseUrl,
            apiKey: anthropicKey,
            model: 'glm-5.1',
          ),
        );
        labels.add('GLM');
      }
      if (hasMimo) {
        futures.add(
          _runWorkflowBenchmark(
            providerName: '小米 MiMo',
            baseUrl: mimoProvider.defaultBaseUrl,
            apiKey: xiaomiKey,
            model: 'mimo-v2.5-pro',
          ),
        );
        labels.add('MiMo');
      }
      if (hasKimi) {
        futures.add(
          _runWorkflowBenchmark(
            providerName: 'Kimi',
            baseUrl: kimiBaseUrl,
            apiKey: ollamaCloudKey,
            model: ollamaCloudModel,
          ),
        );
        labels.add('Kimi');
      }

      final sw = Stopwatch()..start();
      final results = await Future.wait(futures);
      sw.stop();

      print('');
      print('═══ 工作流并行对比 (总耗时: ${sw.elapsedMilliseconds}ms) ═══');
      print('');

      const colWidth = 18;
      final header = labels.map((l) => l.padLeft(colWidth)).join(' │ ');
      print('│ 指标${' ' * 12} │ $header │');
      print(
        '├${'─' * 17}┼${labels.map((_) => '─' * (colWidth + 2)).join('┼')}┤',
      );

      // 模型名
      final modelNames = <String>[];
      if (hasZhipu) modelNames.add('glm-5.1');
      if (hasMimo) modelNames.add('mimo-v2.5-pro');
      if (hasKimi) modelNames.add(ollamaCloudModel);
      print(
        '│ 模型${' ' * 12} │ ${modelNames.map((m) => m.padLeft(colWidth)).join(' │ ')} │',
      );

      // 成功状态
      print(
        '│ 成功${' ' * 12} │ ${results.map((r) => (r.succeeded ? "✅" : "❌").padLeft(colWidth)).join(' │ ')} │',
      );

      // 总耗时
      print(
        '│ 总耗时${' ' * 10} │ ${results.map((r) => "${r.totalMs}ms".padLeft(colWidth)).join(' │ ')} │',
      );

      // 总 LLM 调用次数
      print(
        '│ LLM 调用次数${' ' * 4} │ ${results.map((r) => r.llmCallCount.toString().padLeft(colWidth)).join(' │ ')} │',
      );

      // 输出字数
      final allOk = results.every((r) => r.succeeded);
      if (allOk) {
        final chars = results
            .map(
              (r) => (r.output?.prose.text ?? '')
                  .replaceAll(RegExp(r'\s'), '')
                  .length,
            )
            .toList();
        print(
          '│ 输出字数${' ' * 8} │ ${chars.map((c) => c.toString().padLeft(colWidth)).join(' │ ')} │',
        );

        // Review 决定
        final decisions = results
            .map((r) => r.output?.review.decision.name ?? 'N/A')
            .toList();
        print(
          '│ Review 决定${' ' * 5} │ ${decisions.map((d) => d.padLeft(colWidth)).join(' │ ')} │',
        );

        // Prose 尝试次数
        final attempts = results
            .map((r) => (r.output?.prose.attempt ?? 0))
            .toList();
        print(
          '│ Prose 尝试${' ' * 5} │ ${attempts.map((a) => a.toString().padLeft(colWidth)).join(' │ ')} │',
        );

        // 质量评分
        final scores = results
            .map(
              (r) => r.output?.qualityScore != null
                  ? r.output!.qualityScore!.overall.toStringAsFixed(1)
                  : 'N/A',
            )
            .toList();
        print(
          '│ 质量评分${' ' * 8} │ ${scores.map((s) => s.padLeft(colWidth)).join(' │ ')} │',
        );
      }
      print('');

      // 输出正文预览
      for (var i = 0; i < results.length; i++) {
        final out = results[i].output;
        if (results[i].succeeded && out != null) {
          print('── ${labels[i]} 正文输出 (前 300 字) ──');
          final text = out.prose.text;
          print(text.substring(0, text.length > 300 ? 300 : text.length));
          print('');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 45)));
  });
}

// ---------------------------------------------------------------------------
// 工作流执行引擎
// ---------------------------------------------------------------------------

class _WorkflowBenchmarkResult {
  const _WorkflowBenchmarkResult({
    required this.providerName,
    required this.model,
    required this.succeeded,
    required this.totalMs,
    required this.llmCallCount,
    this.output,
    this.error,
  });

  final String providerName;
  final String model;
  final bool succeeded;
  final int totalMs;
  final int llmCallCount;
  final SceneRuntimeOutput? output;
  final String? error;
}

/// 创建一个追踪 LLM 调用次数的 client wrapper。
class _TrackingLlmClient implements AppLlmClient {
  _TrackingLlmClient(this._inner);

  final AppLlmClient _inner;
  int callCount = 0;
  final callDurations = <int>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    callCount++;
    final sw = Stopwatch()..start();
    final result = await _inner.chat(request);
    sw.stop();
    callDurations.add(sw.elapsedMilliseconds);
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    callCount++;
    return _inner.chatStream(request);
  }
}

Future<_WorkflowBenchmarkResult> _runWorkflowBenchmark({
  required String providerName,
  required String baseUrl,
  required String apiKey,
  required String model,
}) async {
  final totalSw = Stopwatch()..start();

  try {
    // 创建真实 LLM client 并包装追踪器
    final realClient = createDefaultAppLlmClient();
    final trackingClient = _TrackingLlmClient(realClient);

    // 配置 settings store
    final settingsStore = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: trackingClient,
    );

    await settingsStore.save(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: const AppLlmTimeoutConfig.uniform(180000),
      maxConcurrentRequests: 1,
    );

    // 创建 orchestrator
    final orchestrator = PipelineStageRunnerImpl(
      settingsStore: settingsStore,
      pipelineConfig: const GenerationPipelineConfig(maxProseRetries: 2),
    );

    // 运行完整 9 步流水线
    final output = await orchestrator.runScene(_workflowBrief());

    totalSw.stop();
    settingsStore.dispose();

    return _WorkflowBenchmarkResult(
      providerName: providerName,
      model: model,
      succeeded: true,
      totalMs: totalSw.elapsedMilliseconds,
      llmCallCount: trackingClient.callCount,
      output: output,
    );
  } catch (e) {
    totalSw.stop();
    return _WorkflowBenchmarkResult(
      providerName: providerName,
      model: model,
      succeeded: false,
      totalMs: totalSw.elapsedMilliseconds,
      llmCallCount: 0,
      error: e.toString(),
    );
  }
}

/// 构造一个真实的场景 brief，用于测试完整流水线。
SceneBrief _workflowBrief() {
  return SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '第一章 雨夜码头',
    sceneId: 'scene-01',
    sceneTitle: '码头对峙',
    sceneSummary:
        '柳溪在封港前夜赶到旧码头，拦住准备带着账本线索离开的沈渡。'
        '暴雨将至，她必须在清场广播落下前从沈渡口中撬出账本去向。'
        '沈渡表面抗拒，实则在试探柳溪是否值得信任。',
    targetBeat: '柳溪逼出沈渡的底线，双方达成脆弱的临时合作协议。',
    targetLength: 800,
    worldNodeIds: const ['old-harbor', 'customs-yard'],
    cast: [
      SceneCastCandidate(
        characterId: 'char-liuxi',
        name: '柳溪',
        role: '调查记者',
        participation: const SceneCastParticipation(
          action: '顶着风雨冲下栈桥，抢在封港前堵住沈渡',
          dialogue: '"你今晚走不了。账本的事，我全知道。"',
          interaction: '先切断退路，再逼对方停下来听她说话',
        ),
      ),
      SceneCastCandidate(
        characterId: 'char-shendu',
        name: '沈渡',
        role: '港区向导',
        participation: const SceneCastParticipation(
          action: '脚步犹豫，试图判断柳溪的来意',
          dialogue: '"你不该来这里。今晚港区不安全。"',
          interaction: '试探柳溪到底掌握了多少证据',
        ),
      ),
    ],
  );
}

void _printWorkflowResult(
  String providerName,
  String model,
  _WorkflowBenchmarkResult result,
) {
  print('');
  print('═══ $providerName ($model) 完整工作流 ═══');

  if (!result.succeeded) {
    print('❌ 失败: ${result.error}');
    print('');
    return;
  }

  final output = result.output;
  if (output == null) {
    print('❌ 无输出');
    print('');
    return;
  }
  final proseText = output.prose.text;
  final charCount = proseText.replaceAll(RegExp(r'\s'), '').length;

  print(
    '总耗时: ${result.totalMs} ms '
    '(${(result.totalMs / 1000).toStringAsFixed(1)}s)',
  );
  print('LLM 调用次数: ${result.llmCallCount}');
  print(
    '平均每次调用: ${(result.totalMs / result.llmCallCount).toStringAsFixed(0)} ms',
  );
  print('输出字数: $charCount 字');
  print('Review 决定: ${output.review.decision.name}');
  print('Prose 尝试次数: ${output.prose.attempt}');
  print('Soft failure 次数: ${output.softFailureCount}');

  if (output.qualityScore != null) {
    final q = output.qualityScore!;
    print(
      '质量评分: 综合=${q.overall.toStringAsFixed(1)} '
      '文笔=${q.prose.toStringAsFixed(1)} '
      '连贯=${q.coherence.toStringAsFixed(1)} '
      '角色=${q.character.toStringAsFixed(1)} '
      '完整=${q.completeness.toStringAsFixed(1)}',
    );
    if (q.summary.isNotEmpty) {
      print('质量评语: ${q.summary}');
    }
  }

  // 流水线各阶段输出摘要
  print('─────────────────────────────');
  print(
    '导演计划 (前 100 字): '
    '${_truncate(output.director.text, 100)}',
  );
  print('角色输出数: ${output.roleOutputs.length}');
  for (final role in output.roleOutputs) {
    print('  - ${role.name}: ${_truncate(role.text, 80)}');
  }
  print('Beat 解析数: ${output.resolvedBeats.length}');
  print('正文 (前 300 字):');
  print(
    proseText.substring(0, proseText.length > 300 ? 300 : proseText.length),
  );
  print('');
}

String _truncate(String? s, int maxLen) {
  if (s == null) return 'N/A';
  final clean = s.replaceAll('\n', ' ').trim();
  return clean.length > maxLen ? '${clean.substring(0, maxLen)}...' : clean;
}
