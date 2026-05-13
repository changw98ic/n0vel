import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../logging/app_event_log.dart';
import 'app_settings_store.dart';
import 'llm_provider_service.dart';

const Duration _llmPoolTransientFailureCooldown = Duration(seconds: 3);

/// AI 请求执行与连接测试服务。
///
/// 从 AppSettingsStore 中提取，专门负责 LLM 请求调度、trace 记录、
/// 连接测试、模型名规范化、provider 类型推断。
/// AppSettingsStore 通过组合持有本实例，对外公开 API 签名不变。
class AiRequestService {
  AiRequestService({
    required AppLlmClient llmClient,
    AppLlmCallTraceSink? llmTraceSink,
    AppEventLog? eventLog,
  }) : _llmClient = llmClient,
       _llmTraceSink = llmTraceSink,
       _eventLog = eventLog ?? AppEventLog();

  final AppLlmClient _llmClient;
  final AppLlmCallTraceSink? _llmTraceSink;
  final AppEventLog _eventLog;
  final Map<String, AppLlmClientGateway> _failoverGateways =
      <String, AppLlmClientGateway>{};

  /// 执行一次 AI 补全请求，附带 trace 记录和瞬态故障冷却。
  ///
  /// 当主 provider 失败且有可用备用 provider 时，自动按
  /// [FailoverStrategy.localFirst] 顺序尝试下一个 provider。
  /// Failover 是可选功能：不配置备用 provider 时行为与之前完全一致。
  Future<AppLlmChatResult> requestCompletion({
    required AppSettingsSnapshot snapshot,
    required ResolvedProviderRoute route,
    required AppLlmRequestPool requestPool,
    AppLlmRequestPool Function(String? providerProfileId)?
    requestPoolForProvider,
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    List<FailoverEndpoint>? failoverEndpoints,
    PromptVersion? promptVersion,
    String? schemaType,
    bool? schemaValid,
    List<String>? schemaViolations,
  }) async {
    final resolvedTraceName = traceName ?? _inferLlmTraceName(messages);
    final request = AppLlmChatRequest(
      baseUrl: route.baseUrl.trim(),
      apiKey: route.apiKey.trim(),
      model: normalizeRequestedModel(route.model),
      timeout: snapshot.timeout,
      maxTokens: AppLlmChatRequest.normalizeMaxTokens(
        maxTokens ?? snapshot.maxTokens,
      ),
      provider: providerForSettings(route.providerName, route.baseUrl),
      messages: messages,
    );

    // 没有备用 provider，走原有路径（单次请求 + retry）。
    if (failoverEndpoints == null || failoverEndpoints.isEmpty) {
      return requestPool.run(() async {
        final result = await _llmClient.chat(request);
        await _recordLlmCallTrace(
          request: request,
          result: result,
          traceName: resolvedTraceName,
          traceMetadata: {
            ...traceMetadata,
            if (route.providerProfileId != null)
              'providerProfileId': route.providerProfileId,
          },
          promptVersion: promptVersion,
          schemaType: schemaType,
          schemaValid: schemaValid,
          schemaViolations: schemaViolations,
        );
        if (_shouldCoolDownLlmRequestPool(result)) {
          requestPool.coolDownFor(_llmPoolTransientFailureCooldown);
        }
        return result;
      });
    }

    // 有备用 provider：构建 failover chain（主 provider + 备用 provider）。
    final allEndpoints = [
      FailoverEndpoint(
        id: route.providerProfileId ?? 'primary',
        baseUrl: route.baseUrl.trim(),
        apiKey: route.apiKey.trim(),
        model: normalizeRequestedModel(route.model),
        provider: providerForSettings(route.providerName, route.baseUrl),
        isLocal: _isLocalCompatibleEndpoint(route.baseUrl),
        providerProfileId: route.providerProfileId,
      ),
      ...failoverEndpoints,
    ];

    // 过滤掉与主 provider 相同的 endpoint（避免重复请求）。
    final primaryId = allEndpoints.first.id;
    final dedupedEndpoints = [
      allEndpoints.first,
      for (final ep in allEndpoints.skip(1))
        if (ep.id != primaryId && ep.baseUrl != allEndpoints.first.baseUrl) ep,
    ];

    final chain = LlmFailoverChain(
      endpoints: dedupedEndpoints,
      delegate: _llmClient,
      strategy: FailoverStrategy.configOrder,
      gatewayProvider: _gatewayForEndpoint,
      endpointRunner: (endpoint, operation) async {
        final endpointPool =
            requestPoolForProvider?.call(endpoint.providerProfileId) ??
            requestPool;
        final result = await endpointPool.run(operation);
        if (_shouldCoolDownLlmRequestPool(result)) {
          endpointPool.coolDownFor(_llmPoolTransientFailureCooldown);
        }
        return result;
      },
    );

    final attempts = <FailoverAttemptResult>[];
    final result = await chain.executeWithFailover(request, attempts: attempts);

    // 记录 trace：主请求。
    await _recordLlmCallTrace(
      request: request,
      result: attempts.isNotEmpty ? attempts.first.result : result,
      traceName: resolvedTraceName,
      traceMetadata: {
        ...traceMetadata,
        if (route.providerProfileId != null)
          'providerProfileId': route.providerProfileId,
        'failover': attempts.length > 1,
        if (attempts.length > 1)
          'failoverAttempts': [
            for (final a in attempts)
              {
                'endpointId': a.endpointId,
                'succeeded': a.result.succeeded,
                'attemptIndex': a.attemptIndex,
                if (a.result.failureKind != null)
                  'failureKind': a.result.failureKind!.name,
              },
          ],
      },
      promptVersion: promptVersion,
      schemaType: schemaType,
      schemaValid: schemaValid,
      schemaViolations: schemaViolations,
    );

    // 如果 failover 切换到了备用 provider，额外记录一条 fallback trace。
    if (attempts.length > 1) {
      final successfulAttempt = attempts.lastWhere(
        (a) => a.result.succeeded,
        orElse: () => attempts.last,
      );
      if (successfulAttempt.wasFallback) {
        await _recordFailoverTrace(
          fromEndpointId: attempts.first.endpointId,
          toEndpointId: successfulAttempt.endpointId,
          succeeded: successfulAttempt.result.succeeded,
          traceName: resolvedTraceName,
          latencyMs: successfulAttempt.result.latencyMs,
        );
      }
    }

    return result;
  }

  /// 执行连接测试请求。
  Future<AppLlmChatResult> testConnection({
    required String baseUrl,
    required String model,
    required String apiKey,
    required AppLlmTimeoutConfig timeout,
    required int maxTokens,
    required String providerName,
  }) {
    final normalizedModel = normalizeRequestedModel(model);
    return _llmClient.chat(
      AppLlmChatRequest(
        baseUrl: baseUrl.trim(),
        apiKey: apiKey.trim(),
        model: normalizedModel,
        timeout: timeout,
        maxTokens: AppLlmChatRequest.normalizeMaxTokens(maxTokens),
        provider: providerForSettings(providerName, baseUrl),
        messages: const [
          AppLlmChatMessage(role: 'user', content: '连接测试：请回复 pong'),
        ],
      ),
    );
  }

  /// 根据连接测试结果生成连接状态。
  AppSettingsConnectionTestState connectionStateFromResult({
    required String baseUrl,
    required String model,
    required AppLlmChatResult result,
  }) {
    if (result.succeeded) {
      return AppSettingsConnectionTestState(
        status: AppSettingsConnectionTestStatus.success,
        outcome: AppSettingsConnectionTestOutcome.success,
        title: '连接测试成功',
        message: '$model · ${result.latencyMs ?? 0}ms',
      );
    }

    final host = Uri.tryParse(baseUrl.trim())?.host ?? baseUrl.trim();
    switch (result.failureKind) {
      case AppLlmFailureKind.unauthorized:
        return const AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.unauthorized,
          title: '连接测试失败：鉴权失败',
          message: '401 / 403：请检查密钥、组织权限或账号状态。',
        );
      case AppLlmFailureKind.timeout:
        return const AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.timeout,
          title: '连接测试失败：连接超时',
          message: '最小化请求超时，请检查接口响应时间或调大等待时间。',
        );
      case AppLlmFailureKind.modelNotFound:
        return AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.modelNotFound,
          title: '连接测试失败：模型不存在',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail
              : '未找到模型 "$model"。请检查模型名拼写或改用可用模型。',
        );
      case AppLlmFailureKind.network:
        return AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.networkError,
          title: '连接测试失败：网络错误',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail
              : '无法连接到 $host。请检查网络环境、代理或接口可达性。',
        );
      case AppLlmFailureKind.insecureScheme:
        return AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.networkError,
          title: '连接测试失败：接口地址不安全',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail
              : '请使用 https:// 地址；本地调试仅允许 localhost 或 127.0.0.1 使用 http://。',
        );
      case AppLlmFailureKind.rateLimited:
        return AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.networkError,
          title: '连接测试失败：请求频率过高',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail
              : '模型服务返回 429，请稍后重试。',
        );
      case AppLlmFailureKind.invalidResponse:
      case AppLlmFailureKind.server:
      case AppLlmFailureKind.unsupportedPlatform:
      case null:
        return AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.networkError,
          title: '连接测试失败：服务异常',
          message: result.detail?.trim().isNotEmpty == true
              ? result.detail
              : '模型服务返回了无法解析的响应。',
        );
    }
  }

  /// 规范化用户输入的模型名。
  String normalizeRequestedModel(String model) {
    final trimmed = model.trim();
    final normalized = trimmed.toLowerCase();
    return switch (normalized) {
      'kimi-2.6' => 'kimi-k2.6',
      'mimo-v25-pro' => 'mimo-v2.5-pro',
      'mimo-v25' => 'mimo-v2.5',
      _ => trimmed,
    };
  }

  /// 根据 providerName 和 baseUrl 推断实际的 LlmProvider 类型。
  AppLlmProvider providerForSettings(String providerName, String baseUrl) {
    final parsedProvider = providerName.toAppLlmProvider();
    if (parsedProvider != AppLlmProvider.openaiCompatible) {
      return parsedProvider;
    }
    final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase() ?? '';
    if (host.contains('xiaomimimo.com')) {
      return AppLlmProvider.mimo;
    }
    if (_isZhipuBaseUrl(baseUrl)) {
      return AppLlmProvider.zhipu;
    }
    return parsedProvider;
  }

  /// 判断 baseUrl 是否指向智谱服务。
  bool isZhipuBaseUrl(String baseUrl) => _isZhipuBaseUrl(baseUrl);

  /// 判断 baseUrl 是否为本地兼容端点（localhost / 127.0.0.1 / ::1）。
  bool isLocalCompatibleEndpoint(String baseUrl) =>
      _isLocalCompatibleEndpoint(baseUrl);

  /// 记录最佳努力的 LLM 事件日志。
  Future<void> logBestEffort({
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    AppEventLogLevel level = AppEventLogLevel.info,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const {},
  }) {
    return _eventLog.logBestEffort(
      level: level,
      category: AppEventLogCategory.ai,
      action: action,
      status: status,
      message: message,
      correlationId: correlationId,
      errorCode: errorCode,
      errorDetail: errorDetail,
      metadata: metadata,
    );
  }

  // ---- Failover 辅助方法 ----

  /// 从 snapshot 的 providerProfiles 构建 failover endpoint 列表。
  ///
  /// 排除已作为主 provider 的 profile（通过 [excludeProfileId] 指定），
  /// 只返回可用的备用 endpoint。
  List<FailoverEndpoint> buildFailoverEndpoints({
    required List<AppLlmProviderProfile> profiles,
    required String? excludeProfileId,
  }) {
    return [
      for (final profile in profiles)
        if (profile.id != excludeProfileId && _isUsableProfile(profile))
          FailoverEndpoint(
            id: profile.id,
            baseUrl: profile.baseUrl,
            apiKey: profile.apiKey,
            model: normalizeRequestedModel(profile.model),
            provider: providerForSettings(
              profile.providerName,
              profile.baseUrl,
            ),
            isLocal: _isLocalCompatibleEndpoint(profile.baseUrl),
            providerProfileId: profile.id,
          ),
    ];
  }

  // ---- 私有方法 ----

  bool _isUsableProfile(AppLlmProviderProfile profile) {
    final hasBaseUrl = profile.baseUrl.trim().isNotEmpty;
    final hasModel = profile.model.trim().isNotEmpty;
    final hasApiKey =
        profile.apiKey.trim().isNotEmpty ||
        _isLocalCompatibleEndpoint(profile.baseUrl);
    return hasBaseUrl && hasModel && hasApiKey;
  }

  AppLlmClientGateway _gatewayForEndpoint(FailoverEndpoint endpoint) {
    final key = _gatewayKey(endpoint);
    return _failoverGateways.putIfAbsent(
      key,
      () => AppLlmClientGateway(delegate: _llmClient),
    );
  }

  String _gatewayKey(FailoverEndpoint endpoint) {
    return [
      endpoint.providerProfileId ?? endpoint.id,
      endpoint.baseUrl.trim(),
      endpoint.model.trim(),
    ].join('|');
  }

  Future<void> _recordFailoverTrace({
    required String fromEndpointId,
    required String toEndpointId,
    required bool succeeded,
    required String traceName,
    int? latencyMs,
  }) async {
    try {
      await _eventLog.logBestEffort(
        level: succeeded ? AppEventLogLevel.info : AppEventLogLevel.warn,
        category: AppEventLogCategory.ai,
        action: 'llm.failover',
        status: succeeded
            ? AppEventLogStatus.succeeded
            : AppEventLogStatus.failed,
        message: succeeded
            ? 'Failover: $fromEndpointId → $toEndpointId succeeded'
            : 'Failover: $fromEndpointId → $toEndpointId failed',
        metadata: {
          'fromEndpointId': fromEndpointId,
          'toEndpointId': toEndpointId,
          if (latencyMs != null) 'latencyMs': latencyMs,
        },
      );
    } on Object {
      // Failover trace should never block generation.
    }
  }

  Future<void> _recordLlmCallTrace({
    required AppLlmChatRequest request,
    required AppLlmChatResult result,
    required String traceName,
    required Map<String, Object?> traceMetadata,
    PromptVersion? promptVersion,
    String? schemaType,
    bool? schemaValid,
    List<String>? schemaViolations,
  }) async {
    final entry = AppLlmCallTraceEntry.fromRequestResult(
      request: request,
      result: result,
      traceName: traceName,
      metadata: traceMetadata,
      promptVersion: promptVersion,
      schemaType: schemaType,
      schemaValid: schemaValid,
      schemaViolations: schemaViolations,
    );

    try {
      await _llmTraceSink?.record(entry);
    } on Object {
      // LLM tracing should never block generation.
    }

    final metadata = entry.toJson();
    await _eventLog.logBestEffort(
      level: result.succeeded ? AppEventLogLevel.info : AppEventLogLevel.warn,
      category: AppEventLogCategory.ai,
      action: 'llm.chat',
      status: result.succeeded
          ? AppEventLogStatus.succeeded
          : AppEventLogStatus.failed,
      message: result.succeeded
          ? '${request.model}: ${entry.completionChars} chars in '
                '${entry.latencyMs ?? 0}ms'
          : '${request.model}: ${result.failureKind?.name ?? "unknown"}',
      errorCode: result.failureKind?.name,
      errorDetail: result.detail,
      metadata: metadata,
    );
  }

  String _inferLlmTraceName(List<AppLlmChatMessage> messages) {
    for (final message in messages.reversed) {
      for (final rawLine in message.content.split('\n')) {
        final value = _extractLlmTaskLineValue(rawLine);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }
    return 'ai_completion';
  }

  String? _extractLlmTaskLineValue(String rawLine) {
    final line = rawLine.trim();
    for (final prefix in const ['任务类型', '任务']) {
      if (line.startsWith('$prefix:') || line.startsWith('$prefix：')) {
        return line.substring(prefix.length + 1).trim();
      }
    }
    return null;
  }

  bool _shouldCoolDownLlmRequestPool(AppLlmChatResult result) {
    if (result.succeeded) return false;
    if (result.statusCode == 429) return true;

    switch (result.failureKind) {
      case AppLlmFailureKind.rateLimited:
        return true;
      case AppLlmFailureKind.server:
      case AppLlmFailureKind.invalidResponse:
        return _hasTransientPressureDetail(result.detail);
      case AppLlmFailureKind.unauthorized:
      case AppLlmFailureKind.timeout:
      case AppLlmFailureKind.modelNotFound:
      case AppLlmFailureKind.network:
      case AppLlmFailureKind.unsupportedPlatform:
      case AppLlmFailureKind.insecureScheme:
      case null:
        return false;
    }
  }

  bool _hasTransientPressureDetail(String? detail) {
    final normalized = (detail ?? '').toLowerCase();
    return normalized.contains('server overloaded') ||
        normalized.contains('overloaded') ||
        normalized.contains('please retry shortly') ||
        normalized.contains('too many requests') ||
        normalized.contains('rate limit') ||
        normalized.contains('rate-limit') ||
        normalized.contains('temporarily unavailable') ||
        normalized.contains('resource exhausted') ||
        normalized.contains('capacity');
  }

  static bool _isZhipuBaseUrl(String baseUrl) {
    final host = Uri.tryParse(baseUrl.trim())?.host.toLowerCase() ?? '';
    return host.contains('bigmodel.cn') || host.contains('zhipuai.cn');
  }

  static bool _isLocalCompatibleEndpoint(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }
}
