import '../../../app/logging/app_event_log.dart';
import '../../../app/llm/app_llm_client.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../presentation/workbench_ai_revision_helpers.dart';

class AiRequestMetadata {
  const AiRequestMetadata({
    required this.providerSummary,
    required this.endpointLabel,
    required this.styleSummary,
    required this.sceneSummary,
    required this.characterSummary,
    required this.worldSummary,
    required this.simulationSummary,
  });

  final String providerSummary;
  final String endpointLabel;
  final String styleSummary;
  final String sceneSummary;
  final String characterSummary;
  final String worldSummary;
  final String simulationSummary;
}

class AiRequestException implements Exception {
  const AiRequestException({required this.title, required this.message});

  final String title;
  final String message;
}

class WorkbenchAiController {
  WorkbenchAiController({
    required this.settingsStore,
    required this.workspaceStore,
    required this.eventLog,
  });

  final AppSettingsStore settingsStore;
  final AppWorkspaceStore workspaceStore;
  final AppEventLog eventLog;

  AiRequestMetadata buildRequestMetadata({
    required AppSettingsSnapshot settings,
    required AppSceneContextSnapshot sceneContext,
    required AppSimulationSnapshot simulation,
  }) {
    final endpoint =
        Uri.tryParse(settings.baseUrl.trim())?.host.isNotEmpty == true
            ? Uri.tryParse(settings.baseUrl.trim())!.host
            : settings.baseUrl.trim();
    final simulationSummary = switch (simulation.status) {
      SimulationStatus.none => '还没有 AI 试写记录',
      SimulationStatus.running =>
        '${simulation.headline} · ${simulation.stageSummary}',
      SimulationStatus.completed =>
        '${simulation.headline} · ${simulation.summary}',
      SimulationStatus.failed =>
        '${simulation.headline} · ${simulation.summary}',
    };
    return AiRequestMetadata(
      providerSummary: '${settings.providerName} · ${settings.model}',
      endpointLabel: endpoint,
      styleSummary: activeStyleSummary(),
      sceneSummary: sceneContext.sceneSummary,
      characterSummary: sceneContext.characterSummary,
      worldSummary: sceneContext.worldSummary,
      simulationSummary: simulationSummary,
    );
  }

  String activeStyleSummary() {
    if (workspaceStore.styleIntensity <= 0) {
      return '未启用动态风格';
    }
    final profile = workspaceStore.selectedStyleProfile;
    if (profile == null) {
      return '未选择动态风格';
    }
    return '${profile.name} · 强度 ${workspaceStore.styleIntensity}';
  }

  Future<String> requestAiOutput({
    required String prompt,
    required bool continueMode,
    required AiRequestMetadata metadata,
    required String originalText,
    required String previousText,
    required String nextText,
    required String taskType,
    String? correlationId,
  }) async {
    final effectivePrompt = prompt.isEmpty
        ? WorkbenchAiRevisionHelpers.defaultIntent(continueMode: continueMode)
        : prompt;
    await logEvent(
      category: AppEventLogCategory.ai,
      action: 'ai.chat.request.started',
      status: AppEventLogStatus.started,
      message: 'Started AI chat request.',
      correlationId: correlationId,
      metadata: _aiRequestLogMetadata(
        metadata: metadata,
        prompt: effectivePrompt,
        taskType: taskType,
      ),
    );
    final result = await settingsStore.requestAiCompletion(
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content: continueMode
              ? '你是中文小说续写助手。只输出需要追加的新内容，不要解释，不要重复原文，不要使用 Markdown、标题、编号或引号。'
              : '你是中文小说改写助手。只输出最终改写结果，不要解释，不要使用 Markdown、标题、编号或引号。',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务类型：$taskType',
            '作者意图：$effectivePrompt',
            '请求配置：${metadata.providerSummary}',
            '接口：${metadata.endpointLabel}',
            '风格约束：${metadata.styleSummary}',
            '章节上下文：${metadata.sceneSummary}',
            metadata.characterSummary,
            metadata.worldSummary,
            '模拟摘要：${metadata.simulationSummary}',
            '上一段：$previousText',
            '原文：\n$originalText',
            '下一段：$nextText',
          ].join('\n\n'),
        ),
      ],
    );
    if (result.succeeded) {
      final text = result.text!.trim();
      await logEvent(
        category: AppEventLogCategory.ai,
        action: 'ai.chat.request.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'AI chat request succeeded.',
        correlationId: correlationId,
        metadata: {
          ..._aiRequestLogMetadata(
            metadata: metadata,
            prompt: effectivePrompt,
            taskType: taskType,
            response: text,
          ),
          if (result.latencyMs != null) 'latencyMs': result.latencyMs,
        },
      );
      return text;
    }
    await logEvent(
      category: AppEventLogCategory.ai,
      action: 'ai.chat.request.failed',
      status: AppEventLogStatus.failed,
      message: 'AI chat request failed.',
      correlationId: correlationId,
      level: AppEventLogLevel.error,
      errorCode: result.failureKind?.name,
      errorDetail: result.detail,
      metadata: _aiRequestLogMetadata(
        metadata: metadata,
        prompt: effectivePrompt,
        taskType: taskType,
      ),
    );
    throw buildRequestException(result);
  }

  Future<List<WorkbenchAiReviewBlock>> requestSelectionReviewBlocks(
    String original,
    List<WorkbenchAiSelectionDraft> selections,
    AiRequestMetadata metadata,
    String? correlationId,
  ) async {
    final sorted = List<WorkbenchAiSelectionDraft>.from(selections)
      ..sort((left, right) => left.start.compareTo(right.start));
    final blocks = <WorkbenchAiReviewBlock>[];
    for (var index = 0; index < sorted.length; index += 1) {
      final previousText = WorkbenchAiRevisionHelpers.contextWindow(
        original,
        end: sorted[index].start,
        backwards: true,
      );
      final originalText = original.substring(
        sorted[index].start,
        sorted[index].end,
      );
      final nextText = WorkbenchAiRevisionHelpers.contextWindow(
        original,
        start: sorted[index].end,
      );
      final suggestionText = await requestAiOutput(
        prompt: sorted[index].prompt,
        continueMode: false,
        metadata: metadata,
        originalText: originalText,
        previousText: previousText,
        nextText: nextText,
        taskType: '选区改写',
        correlationId: correlationId,
      );
      blocks.add(
        WorkbenchAiReviewBlock(
          blockLabel: '修改块 ${index + 1}',
          previousText: previousText,
          originalText: originalText,
          nextText: nextText,
          authorPrompt: sorted[index].prompt,
          suggestionText: suggestionText,
          selection: sorted[index],
        ),
      );
    }
    return blocks;
  }

  Future<List<WorkbenchAiReviewBlock>> requestFallbackReviewBlocks({
    required String original,
    required String prompt,
    required bool continueMode,
    required AiRequestMetadata metadata,
    String? correlationId,
  }) async {
    final effectivePrompt = prompt.isEmpty
        ? WorkbenchAiRevisionHelpers.defaultIntent(continueMode: continueMode)
        : prompt;
    final suggestionText = await requestAiOutput(
      prompt: effectivePrompt,
      continueMode: continueMode,
      metadata: metadata,
      originalText: original,
      previousText: '夜雨还没有停。',
      nextText: '她听见码头深处传来金属回响。',
      taskType: continueMode ? '续写' : '整段改写',
      correlationId: correlationId,
    );
    return [
      WorkbenchAiReviewBlock(
        blockLabel: continueMode ? '续写块 1' : '修改块 1',
        previousText: '上一段预览：夜雨还没有停。',
        originalText: original,
        nextText: '下一段预览：她听见码头深处传来金属回响。',
        authorPrompt: effectivePrompt,
        suggestionText: suggestionText,
      ),
    ];
  }

  Future<void> logEvent({
    required AppEventLogCategory category,
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    AppEventLogLevel level = AppEventLogLevel.info,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return eventLog.log(
      level: level,
      category: category,
      action: action,
      status: status,
      message: message,
      correlationId: correlationId,
      projectId: workspaceStore.currentProject.id,
      sceneId: workspaceStore.currentProject.sceneId,
      errorCode: errorCode,
      errorDetail: errorDetail,
      metadata: metadata,
    );
  }

  AiRequestException buildRequestException(AppLlmChatResult result) {
    return switch (result.failureKind) {
      AppLlmFailureKind.unauthorized => const AiRequestException(
          title: 'AI 请求失败：鉴权失败',
          message: '401 / 403：请检查密钥、账号权限或服务端授权状态。',
        ),
      AppLlmFailureKind.timeout => const AiRequestException(
          title: 'AI 请求失败：连接超时',
          message: '模型服务在超时时间内未返回结果，请稍后重试或调大等待时间。',
        ),
      AppLlmFailureKind.modelNotFound => AiRequestException(
          title: 'AI 请求失败：模型不存在',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail!
              : '当前模型不可用，请检查 model 配置。',
        ),
      AppLlmFailureKind.network => AiRequestException(
          title: 'AI 请求失败：网络错误',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail!
              : '无法连接到模型服务，请检查网络环境与接口地址。',
        ),
      AppLlmFailureKind.insecureScheme => AiRequestException(
          title: 'AI 请求失败：接口地址不安全',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail!
              : '请使用 https:// 地址；本地调试仅允许 localhost 或 127.0.0.1 使用 http://。',
        ),
      AppLlmFailureKind.rateLimited => AiRequestException(
          title: 'AI 请求失败：请求受限',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail!
              : '模型服务暂时限制请求，请稍后重试或降低请求频率。',
        ),
      AppLlmFailureKind.invalidResponse ||
      AppLlmFailureKind.server ||
      AppLlmFailureKind.unsupportedPlatform ||
      null => AiRequestException(
          title: 'AI 请求失败：服务异常',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail!
              : '模型服务返回了无法解析的响应。',
        ),
    };
  }

  Map<String, Object?> _aiRequestLogMetadata({
    required AiRequestMetadata metadata,
    required String prompt,
    required String taskType,
    String? response,
  }) {
    return {
      'provider': metadata.providerSummary,
      'endpoint': metadata.endpointLabel,
      'taskType': taskType,
      'promptLength': prompt.length,
      'promptPreview': WorkbenchAiRevisionHelpers.previewText(prompt, 160),
      if (response != null) 'responseLength': response.length,
      if (response != null)
        'responsePreview': WorkbenchAiRevisionHelpers.previewText(
          response,
          160,
        ),
    };
  }
}
