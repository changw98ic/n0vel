import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import 'ai_request_service.dart';
import 'app_store_listenable.dart';
import 'llm_provider_service.dart';
import 'settings/settings_models.dart';

/// Settings store AI 请求路由与 trace 摘要。
///
/// 从 AppSettingsStore 中提取，通过 mixin 组合保持 store 公开 API 不变。
mixin AppSettingsStoreAiRouting on AppStoreListenable {
  // --- Store 字段访问器（由 AppSettingsStore 实现） ---

  AppSettingsSnapshot get storeSnapshot;
  AiRequestService get storeAiRequestService;
  LlmProviderService get storeProviderService;
  AppLlmRequestPool get storeRequestPool;

  /// 根据 providerProfileId 获取对应的请求池。
  AppLlmRequestPool storeRequestPoolForProfile(String? providerProfileId);

  // --- AI 请求路由 ---

  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
  }) {
    final resolvedTraceName = traceName ?? _inferTraceName(messages);
    final resolved = _resolveRequestSettings(resolvedTraceName);
    final requestPool = storeRequestPoolForProfile(
      resolved.providerProfileId,
    );
    final route = ResolvedProviderRoute(
      providerName: resolved.providerName,
      baseUrl: resolved.baseUrl,
      model: resolved.model,
      apiKey: resolved.apiKey,
      providerProfileId: resolved.providerProfileId,
    );

    // 构建备用 provider 列表用于 failover。
    final failoverEndpoints =
        storeAiRequestService.buildFailoverEndpoints(
      profiles: storeSnapshot.providerProfiles,
      excludeProfileId: resolved.providerProfileId,
    );

    return storeAiRequestService.requestCompletion(
      snapshot: storeSnapshot,
      route: route,
      requestPool: requestPool,
      requestPoolForProvider: storeRequestPoolForProfile,
      messages: messages,
      maxTokens: maxTokens,
      traceName: resolvedTraceName,
      traceMetadata: traceMetadata,
      failoverEndpoints: failoverEndpoints,
    );
  }

  /// 推断 trace 名称。
  String _inferTraceName(List<AppLlmChatMessage> messages) {
    for (final message in messages.reversed) {
      for (final rawLine in message.content.split('\n')) {
        final line = rawLine.trim();
        for (final prefix in const ['任务类型', '任务']) {
          if (line.startsWith('$prefix:') || line.startsWith('$prefix：')) {
            final value = line.substring(prefix.length + 1).trim();
            if (value.isNotEmpty) return value;
          }
        }
      }
    }
    return 'ai_completion';
  }

  String providerSummaryForTrace(String traceName) {
    final routedSettings = _resolveRequestSettings(traceName);
    final source = routedSettings.providerProfileId == null
        ? '默认配置'
        : '路由：${routedSettings.providerProfileId}';
    return '${routedSettings.providerName} · '
        '${storeAiRequestService.normalizeRequestedModel(routedSettings.model)}（$source）';
  }

  String generationProviderSummary() {
    const traceNames = [
      'scene_generation',
      'scene_roleplay_turn',
      'scene_roleplay_arbitrate',
      'scene_editorial',
      'scene_review',
    ];
    final summaries = <String>{
      for (final traceName in traceNames) providerSummaryForTrace(traceName),
    };
    if (summaries.length == 1) {
      return summaries.single;
    }
    return summaries.join('；');
  }

  /// 解析请求路由，返回用于 AI 请求的配置。
  /// 委托给 LlmProviderService.resolveRoute。
  ResolvedRequestSettings _resolveRequestSettings(String traceName) {
    final route = storeProviderService.resolveRoute(
      traceName,
      storeSnapshot.requestProviderRoutes,
      storeSnapshot.providerProfiles,
      isLocalCompatibleEndpoint:
          storeAiRequestService.isLocalCompatibleEndpoint,
    );
    if (route != null) {
      return ResolvedRequestSettings(
        providerName: route.providerName,
        baseUrl: route.baseUrl,
        model: route.model,
        apiKey: route.apiKey,
        providerProfileId: route.providerProfileId,
      );
    }
    return ResolvedRequestSettings(
      providerName: storeSnapshot.providerName,
      baseUrl: storeSnapshot.baseUrl,
      model: storeSnapshot.model,
      apiKey: storeSnapshot.apiKey,
    );
  }
}
