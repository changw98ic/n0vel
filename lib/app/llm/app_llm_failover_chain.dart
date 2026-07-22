import 'app_llm_circuit_breaker.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_gateway.dart';
import 'app_llm_client_types.dart';

/// Failover 排序策略。
enum FailoverStrategy {
  /// 本地优先：先尝试 local/localhost provider，再尝试云端。
  localFirst,

  /// 配置顺序：按 provider profile 列表原始顺序。
  configOrder,
}

typedef FailoverEndpointRunner =
    Future<AppLlmChatResult> Function(
      FailoverEndpoint endpoint,
      Future<AppLlmChatResult> Function() operation,
    );

typedef FailoverEndpointGatewayProvider =
    AppLlmClientGateway Function(FailoverEndpoint endpoint);

typedef FailoverPhysicalDispatchRunner =
    Future<AppLlmChatResult> Function({
      required FailoverEndpoint endpoint,
      required AppLlmChatRequest request,
      required int endpointIndex,
      required int gatewayRetryIndex,
      required bool wasFallback,
      required Future<AppLlmChatResult> Function() operation,
    });

/// Failover chain 中的一个 provider 端点。
class FailoverEndpoint {
  const FailoverEndpoint({
    required this.id,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.provider,
    required this.isLocal,
    this.providerProfileId,
  });

  /// 唯一标识（用于 trace 和日志）。
  final String id;

  /// LLM 服务端点地址。
  final String baseUrl;

  /// API 密钥。
  final String apiKey;

  /// 模型名称。
  final String model;

  /// 推断出的 provider 类型。
  final AppLlmProvider provider;

  /// 是否为本地端点。
  final bool isLocal;

  /// 可选的 provider profile id（用于 trace metadata）。
  final String? providerProfileId;
}

/// 单次 failover 尝试的结果。
class FailoverAttemptResult {
  const FailoverAttemptResult({
    required this.endpointId,
    required this.result,
    required this.attemptIndex,
    this.wasFallback = false,
  });

  /// 尝试的 endpoint id。
  final String endpointId;

  /// 该 endpoint 的请求结果。
  final AppLlmChatResult result;

  /// 第几次尝试（0-based）。
  final int attemptIndex;

  /// 是否为回退尝试（非首选 endpoint）。
  final bool wasFallback;
}

/// Provider failover 链，按优先级尝试多个 provider。
///
/// 当主 provider 失败时，自动切换到下一个可用 provider。
/// 每个 provider 有独立的 circuit breaker 状态。
class LlmFailoverChain {
  LlmFailoverChain({
    required this.endpoints,
    required AppLlmClient delegate,
    this.strategy = FailoverStrategy.localFirst,
    this.endpointRunner,
    this.physicalDispatchRunner,
    this.gatewayProvider,
    int maxRetriesPerEndpoint = 3,
    int baseDelayMs = 1000,
  }) : _delegate = delegate,
       _maxRetriesPerEndpoint = maxRetriesPerEndpoint,
       _baseDelayMs = baseDelayMs {
    // 为每个 endpoint 创建独立的 gateway（独立 circuit breaker）。
    for (final endpoint in orderedEndpoints()) {
      _gateways[endpoint.id] =
          gatewayProvider?.call(endpoint) ??
          AppLlmClientGateway(
            delegate: _delegate,
            maxRetries: _maxRetriesPerEndpoint,
            baseDelayMs: _baseDelayMs,
          );
    }
  }

  final List<FailoverEndpoint> endpoints;
  final FailoverStrategy strategy;
  final FailoverEndpointRunner? endpointRunner;
  final FailoverPhysicalDispatchRunner? physicalDispatchRunner;
  final FailoverEndpointGatewayProvider? gatewayProvider;

  final AppLlmClient _delegate;
  final int _maxRetriesPerEndpoint;
  final int _baseDelayMs;

  /// endpoint id → 独立的 gateway（含 circuit breaker）。
  final Map<String, AppLlmClientGateway> _gateways = {};

  /// 按 strategy 排序 provider 列表，返回尝试顺序。
  List<FailoverEndpoint> orderedEndpoints() {
    if (endpoints.length <= 1) return List.of(endpoints);
    final sorted = List<FailoverEndpoint>.of(endpoints);
    switch (strategy) {
      case FailoverStrategy.localFirst:
        sorted.sort((a, b) {
          // 本地排前面。
          if (a.isLocal != b.isLocal) return a.isLocal ? -1 : 1;
          return 0;
        });
      case FailoverStrategy.configOrder:
        // 保持原始顺序。
        break;
    }
    return sorted;
  }

  /// 执行请求，按 failover 顺序依次尝试。
  ///
  /// 返回第一个成功的结果，或最后一个失败结果。
  /// [attempts] 如果非 null，会记录每次尝试的详情。
  Future<AppLlmChatResult> executeWithFailover(
    AppLlmChatRequest requestTemplate, {
    List<FailoverAttemptResult>? attempts,
  }) async {
    final configured = orderedEndpoints();
    final ordered =
        requestTemplate.physicalDispatchPolicy ==
            AppLlmPhysicalDispatchPolicy.single
        ? configured.take(1).toList(growable: false)
        : configured;
    if (ordered.isEmpty) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail: 'No failover endpoints configured.',
      );
    }

    AppLlmChatResult lastResult = const AppLlmChatResult.failure(
      failureKind: AppLlmFailureKind.server,
      detail: 'No failover endpoints available.',
    );

    for (var i = 0; i < ordered.length; i++) {
      final endpoint = ordered[i];
      final gateway = _gateways[endpoint.id];
      if (gateway == null) continue;

      // 如果 circuit breaker open 且不是最后一个，直接跳过。
      final circuitState = gateway.circuitBreaker.state;
      if (circuitState == AppLlmCircuitState.open && i < ordered.length - 1) {
        attempts?.add(
          FailoverAttemptResult(
            endpointId: endpoint.id,
            result: const AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.server,
              detail: 'Circuit breaker open, skipping.',
            ),
            attemptIndex: i,
            wasFallback: i > 0,
          ),
        );
        continue;
      }

      // 构建针对该 endpoint 的请求。
      final request = AppLlmChatRequest(
        baseUrl: endpoint.baseUrl,
        apiKey: endpoint.apiKey,
        model: endpoint.model,
        timeout: requestTemplate.timeout,
        maxTokens: requestTemplate.maxTokens,
        messages: requestTemplate.messages,
        provider: endpoint.provider,
        onPartialText: requestTemplate.onPartialText,
        formalCacheIdentity: requestTemplate.formalCacheIdentity,
        formalDispatchIdentity: requestTemplate.formalDispatchIdentity,
        preferStreaming: requestTemplate.preferStreaming,
        physicalDispatchPolicy: requestTemplate.physicalDispatchPolicy,
        dispatchEvidenceNonce: requestTemplate.dispatchEvidenceNonce,
      );

      Future<AppLlmChatResult> executeGateway() {
        final physicalRunner = physicalDispatchRunner;
        // llm-call-site: boundary.failover.direct
        return gateway.chatWithPhysicalDispatch(
          request,
          dispatchRunner: physicalRunner == null
              ? null
              : ({required request, required retryIndex, required operation}) =>
                    physicalRunner(
                      endpoint: endpoint,
                      request: request,
                      endpointIndex: i,
                      gatewayRetryIndex: retryIndex,
                      wasFallback: i > 0,
                      operation: operation,
                    ),
        );
      }

      final runner = endpointRunner;
      lastResult = runner == null
          ? await executeGateway()
          : await runner(endpoint, executeGateway);

      attempts?.add(
        FailoverAttemptResult(
          endpointId: endpoint.id,
          result: lastResult,
          attemptIndex: i,
          wasFallback: i > 0,
        ),
      );

      if (lastResult.succeeded) {
        return lastResult;
      }

      // 不可重试的错误（如 unauthorized）不继续 failover。
      if (_isTerminalFailure(lastResult.failureKind)) {
        return lastResult;
      }
    }

    return lastResult;
  }

  /// 获取指定 endpoint 的 circuit breaker（用于可观测性）。
  AppLlmCircuitBreaker? circuitBreakerFor(String endpointId) =>
      _gateways[endpointId]?.circuitBreaker;

  /// 判断是否为不应继续 failover 的终端错误。
  static bool _isTerminalFailure(AppLlmFailureKind? kind) {
    switch (kind) {
      case AppLlmFailureKind.unauthorized:
      case AppLlmFailureKind.modelNotFound:
      case AppLlmFailureKind.insecureScheme:
      case AppLlmFailureKind.unsupportedPlatform:
        return true;
      case AppLlmFailureKind.timeout:
      case AppLlmFailureKind.network:
      case AppLlmFailureKind.rateLimited:
      case AppLlmFailureKind.server:
      case AppLlmFailureKind.invalidResponse:
      case null:
        return false;
    }
  }

  /// 判断 baseUrl 是否为本地端点。
  static bool isLocalBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasAuthority) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '0.0.0.0';
  }
}
