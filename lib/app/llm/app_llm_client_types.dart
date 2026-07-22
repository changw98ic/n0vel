enum AppLlmConnectionState { connected, disconnected }

enum AppLlmFailureKind {
  unauthorized,
  timeout,
  network,
  rateLimited,
  modelNotFound,
  invalidResponse,
  server,
  unsupportedPlatform,
  insecureScheme,
}

enum AppLlmProvider { openaiCompatible, kimi, ollama, anthropic, mimo, zhipu }

/// Governs how many real provider requests one logical chat call may cause.
///
/// [adaptive] preserves the product's retry, stream-fallback, and provider
/// failover behavior. [single] is an opt-in experiment contract: the call may
/// dispatch to the selected primary provider at most once.
enum AppLlmPhysicalDispatchPolicy { adaptive, single }

/// Machine-readable provider-completion evidence for a failed dispatch.
///
/// [confirmedNoCompletion] may only be attached by a frozen, provider-specific
/// rejection contract that proves no completion was created. A generic HTTP
/// status (including 429 or 5xx), network failure, timeout, thrown operation,
/// or malformed response is indeterminate and must not authorize a no-redraw
/// retry.
enum AppLlmDispatchFailureDisposition {
  confirmedNoCompletion,
  indeterminateException,
}

/// Evidence emitted when a concrete transport admits the request into its
/// HTTP dispatch operation.
///
/// This proves neither that bytes left the process nor that the provider
/// received or created a completion. Decorators may preserve the value but
/// must never manufacture one. Formal callers must additionally verify the
/// platform-private concrete type; the public fields alone are diagnostic and
/// forgeable.
abstract interface class AppLlmProviderBoundaryReceipt {
  String get contract;
  int get physicalDispatchCount;
  String get requestedBaseUrl;
  String get requestedModel;
  AppLlmProvider get requestedProvider;
  String get transportEndpoint;
  String get dispatchEvidenceNonce;

  Map<String, Object?> toCredentialFreeJson();
}

/// Secret-free immutable identity of the formal request whose transport
/// receipt is being verified downstream.
///
/// The central boundary freezes caller-owned messages before its first await.
/// Later evidence layers use this complete semantic expectation so a genuine
/// receipt from a different request cannot be replayed for the current attempt.
final class AppLlmProviderBoundaryExpectation {
  AppLlmProviderBoundaryExpectation({
    required String baseUrl,
    required String model,
    required this.provider,
    required Iterable<AppLlmChatMessage> messages,
    required int maxTokens,
    required this.physicalDispatchPolicy,
    required String dispatchEvidenceNonce,
  }) : baseUrl = baseUrl.trim(),
       model = model.trim(),
       messages = List<AppLlmChatMessage>.unmodifiable(messages),
       normalizedMaxTokens = AppLlmChatRequest.normalizeMaxTokens(maxTokens),
       dispatchEvidenceNonce = dispatchEvidenceNonce.trim() {
    if (!isCanonicalAppLlmDispatchEvidenceNonce(this.dispatchEvidenceNonce)) {
      throw ArgumentError.value(
        dispatchEvidenceNonce,
        'dispatchEvidenceNonce',
        'must be a canonical sha256 digest',
      );
    }
  }

  final String baseUrl;
  final String model;
  final AppLlmProvider provider;
  final List<AppLlmChatMessage> messages;
  final int normalizedMaxTokens;
  final AppLlmPhysicalDispatchPolicy physicalDispatchPolicy;
  final String dispatchEvidenceNonce;
}

bool isCanonicalAppLlmDispatchEvidenceNonce(String? value) =>
    value != null && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

/// A single-dispatch request was rejected before it could enter the physical
/// provider admission boundary.
final class AppLlmPhysicalDispatchPreflightException implements Exception {
  const AppLlmPhysicalDispatchPreflightException(this.code, this.detail);

  final String code;
  final String detail;

  @override
  String toString() =>
      'AppLlmPhysicalDispatchPreflightException($code: $detail)';
}

void validateAppLlmSinglePhysicalDispatchRoute({
  required String baseUrl,
  required String apiKey,
  required String model,
}) {
  final normalizedBaseUrl = baseUrl.trim();
  final uri = Uri.tryParse(normalizedBaseUrl);
  if (uri == null || uri.scheme.isEmpty) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'invalid-base-url',
      'single physical dispatch requires an absolute provider URL',
    );
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    throw const AppLlmPhysicalDispatchPreflightException(
      'unsupported-url-scheme',
      'single physical dispatch requires an HTTP(S) provider URL',
    );
  }
  if (!uri.hasAuthority || uri.host.trim().isEmpty) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'missing-url-host',
      'single physical dispatch requires a provider URL with a host',
    );
  }
  if (uri.userInfo.isNotEmpty) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'embedded-url-credentials',
      'single physical dispatch rejects credentials embedded in provider URLs',
    );
  }
  if (uri.hasQuery) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'url-query-not-allowed',
      'single physical dispatch requires provider routing outside URL queries',
    );
  }
  if (uri.hasFragment) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'url-fragment-not-allowed',
      'single physical dispatch rejects provider URL fragments',
    );
  }
  final isLocal = isAppLlmLocalCompatibleEndpoint(normalizedBaseUrl);
  if (scheme != 'https' && !isLocal) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'insecure-remote-url',
      'single physical dispatch rejects non-HTTPS remote providers',
    );
  }
  if (model.trim().isEmpty) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'missing-model',
      'single physical dispatch requires a selected model',
    );
  }
  if (!isLocal && apiKey.trim().isEmpty) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'missing-api-key',
      'single physical dispatch requires remote provider credentials',
    );
  }
}

/// Canonical local-route classification shared by settings, preflight, and
/// evidence validation.  A wildcard loopback listener is safe for local test
/// and desktop providers, but must be classified identically at every layer.
bool isAppLlmLocalCompatibleEndpoint(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || !uri.hasAuthority) return false;
  return switch (uri.host.toLowerCase()) {
    'localhost' || '127.0.0.1' || '::1' || '0.0.0.0' => true,
    _ => false,
  };
}

void validateAppLlmSinglePhysicalDispatchRequest(AppLlmChatRequest request) {
  if (request.physicalDispatchPolicy != AppLlmPhysicalDispatchPolicy.single) {
    if (request.dispatchEvidenceNonce != null) {
      throw const AppLlmPhysicalDispatchPreflightException(
        'adaptive-dispatch-evidence-nonce',
        'adaptive requests must not carry formal single-dispatch evidence identity',
      );
    }
    return;
  }
  validateAppLlmSinglePhysicalDispatchRoute(
    baseUrl: request.baseUrl,
    apiKey: request.apiKey,
    model: request.model,
  );
  if (!isCanonicalAppLlmDispatchEvidenceNonce(request.dispatchEvidenceNonce)) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'invalid-dispatch-evidence-nonce',
      'single physical dispatch requires a durable canonical logical attempt id',
    );
  }
}

/// Credential-free structured proof of the endpoint selected for a physical
/// provider request. In single-dispatch mode this is attached to both success
/// and failure results, so provenance never depends on parsing error text.
final class AppLlmDispatchResolution {
  const AppLlmDispatchResolution({
    required this.endpointId,
    required this.baseUrl,
    required this.model,
    required this.provider,
    required this.isLocal,
    required this.physicalDispatchPolicy,
    this.providerProfileId,
  });

  final String endpointId;
  final String baseUrl;
  final String model;
  final AppLlmProvider provider;
  final bool isLocal;
  final AppLlmPhysicalDispatchPolicy physicalDispatchPolicy;
  final String? providerProfileId;

  Map<String, Object?> toCredentialFreeJson() => <String, Object?>{
    'contract': 'app-llm-dispatch-resolution-v1',
    'endpointId': endpointId,
    'baseUrl': baseUrl,
    'model': model,
    'provider': provider.name,
    'isLocal': isLocal,
    'physicalDispatchPolicy': physicalDispatchPolicy.name,
    if (providerProfileId != null) 'providerProfileId': providerProfileId,
  };
}

extension AppLlmProviderParse on String {
  AppLlmProvider toAppLlmProvider() {
    final lower = trim().toLowerCase();
    if (lower.contains('kimi') || lower.contains('moonshot')) {
      return AppLlmProvider.kimi;
    }
    if (lower.contains('ollama')) {
      return AppLlmProvider.ollama;
    }
    if (lower.contains('anthropic') || lower.contains('claude')) {
      return AppLlmProvider.anthropic;
    }
    if (lower.contains('mimo') || lower.contains('xiaomi')) {
      return AppLlmProvider.mimo;
    }
    if (lower.contains('zhipu') ||
        lower.contains('bigmodel') ||
        lower.contains('glm') ||
        lower.contains('智谱')) {
      return AppLlmProvider.zhipu;
    }
    return AppLlmProvider.openaiCompatible;
  }
}

class AppLlmChatMessage {
  const AppLlmChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, Object?> toJson() {
    return {'role': role, 'content': content};
  }
}

class AppLlmTimeoutConfig {
  const AppLlmTimeoutConfig({
    required this.connectTimeoutMs,
    required this.sendTimeoutMs,
    required this.receiveTimeoutMs,
    this.idleTimeoutMs,
  });

  const AppLlmTimeoutConfig.uniform(int ms)
    : connectTimeoutMs = ms,
      sendTimeoutMs = ms,
      receiveTimeoutMs = ms,
      idleTimeoutMs = null;

  static const AppLlmTimeoutConfig quickChat = AppLlmTimeoutConfig(
    connectTimeoutMs: 5000,
    sendTimeoutMs: 10000,
    receiveTimeoutMs: 15000,
    idleTimeoutMs: 5000,
  );

  static const AppLlmTimeoutConfig defaults = AppLlmTimeoutConfig(
    connectTimeoutMs: 10000,
    sendTimeoutMs: 30000,
    receiveTimeoutMs: 60000,
    idleTimeoutMs: 30000,
  );

  static const AppLlmTimeoutConfig longGeneration = AppLlmTimeoutConfig(
    connectTimeoutMs: 10000,
    sendTimeoutMs: 30000,
    receiveTimeoutMs: 180000,
    idleTimeoutMs: 60000,
  );

  final int connectTimeoutMs;
  final int sendTimeoutMs;
  final int receiveTimeoutMs;
  final int? idleTimeoutMs;

  int get effectiveIdleTimeoutMs => idleTimeoutMs ?? receiveTimeoutMs;

  AppLlmTimeoutConfig copyWith({
    int? connectTimeoutMs,
    int? sendTimeoutMs,
    int? receiveTimeoutMs,
    int? idleTimeoutMs,
    bool clearIdleTimeout = false,
  }) {
    return AppLlmTimeoutConfig(
      connectTimeoutMs: connectTimeoutMs ?? this.connectTimeoutMs,
      sendTimeoutMs: sendTimeoutMs ?? this.sendTimeoutMs,
      receiveTimeoutMs: receiveTimeoutMs ?? this.receiveTimeoutMs,
      idleTimeoutMs: clearIdleTimeout
          ? null
          : (idleTimeoutMs ?? this.idleTimeoutMs),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'connectTimeoutMs': connectTimeoutMs,
      'sendTimeoutMs': sendTimeoutMs,
      'receiveTimeoutMs': receiveTimeoutMs,
      if (idleTimeoutMs != null) 'idleTimeoutMs': idleTimeoutMs,
    };
  }

  static AppLlmTimeoutConfig fromJson(Map<String, Object?> json) {
    final legacyTimeout = json['timeoutMs'] as int?;
    if (legacyTimeout != null &&
        json['connectTimeoutMs'] == null &&
        json['sendTimeoutMs'] == null &&
        json['receiveTimeoutMs'] == null) {
      return AppLlmTimeoutConfig.uniform(legacyTimeout);
    }
    return AppLlmTimeoutConfig(
      connectTimeoutMs:
          (json['connectTimeoutMs'] as int?) ?? defaults.connectTimeoutMs,
      sendTimeoutMs: (json['sendTimeoutMs'] as int?) ?? defaults.sendTimeoutMs,
      receiveTimeoutMs:
          (json['receiveTimeoutMs'] as int?) ?? defaults.receiveTimeoutMs,
      idleTimeoutMs: json['idleTimeoutMs'] as int?,
    );
  }
}

/// Non-secret immutable call identity required by the formal evaluation cache.
///
/// Execution, slot, run, and model-route identity are owned by the active
/// evaluation scope. This request-owned half binds the concrete generation
/// stage and parser release to the actual rendered input.
final class AppLlmFormalCacheRequestIdentity {
  const AppLlmFormalCacheRequestIdentity({
    required this.stageId,
    required this.generationBundleHash,
    required this.parserRelease,
  });

  final String stageId;
  final String generationBundleHash;
  final String parserRelease;
}

/// Complete request-owned attribution identity for a formal physical
/// dispatch. It is frozen before the first await and checked again by the IO
/// boundary against the journal-authenticated intent.
final class AppLlmFormalDispatchRequestIdentity {
  AppLlmFormalDispatchRequestIdentity({
    required this.completeIntentDigest,
    required this.stageId,
    required this.callSiteId,
    required this.variantId,
    required this.generationBundleHash,
    required this.promptReleaseContentHash,
    required this.promptReleaseRefDigest,
    required this.renderedMessagesDigest,
    required this.resolvedVariablesDigest,
    required this.rendererContractHash,
    required this.parserRelease,
  }) {
    for (final entry in <String, String>{
      'completeIntentDigest': completeIntentDigest,
      'generationBundleHash': generationBundleHash,
      'promptReleaseContentHash': promptReleaseContentHash,
      'promptReleaseRefDigest': promptReleaseRefDigest,
      'renderedMessagesDigest': renderedMessagesDigest,
      'resolvedVariablesDigest': resolvedVariablesDigest,
      'rendererContractHash': rendererContractHash,
    }.entries) {
      if (!isCanonicalAppLlmDispatchEvidenceNonce(entry.value)) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'must be a canonical sha256 digest',
        );
      }
    }
    for (final entry in <String, String>{
      'stageId': stageId,
      'callSiteId': callSiteId,
      'variantId': variantId,
      'parserRelease': parserRelease,
    }.entries) {
      if (entry.value.isEmpty || entry.value != entry.value.trim()) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'must be non-empty canonical text',
        );
      }
    }
  }

  final String completeIntentDigest;
  final String stageId;
  final String callSiteId;
  final String variantId;
  final String generationBundleHash;
  final String promptReleaseContentHash;
  final String promptReleaseRefDigest;
  final String renderedMessagesDigest;
  final String resolvedVariablesDigest;
  final String rendererContractHash;
  final String parserRelease;
}

class AppLlmChatRequest {
  const AppLlmChatRequest({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    AppLlmTimeoutConfig? timeout,
    int timeoutMs = 30000,
    this.maxTokens = unlimitedMaxTokens,
    required this.messages,
    this.provider = AppLlmProvider.openaiCompatible,
    this.onPartialText,
    this.formalCacheIdentity,
    this.formalDispatchIdentity,
    this.preferStreaming = true,
    this.physicalDispatchPolicy = AppLlmPhysicalDispatchPolicy.adaptive,
    this.dispatchEvidenceNonce,
    Object? formalDispatchPermit,
  }) : _timeout = timeout,
       _formalDispatchPermit = formalDispatchPermit,
       _timeoutMs = timeoutMs;

  static const int unlimitedMaxTokens = 0;
  static const int defaultMaxTokens = 4096;
  static const int maximumMaxTokens = 65536;

  final String baseUrl;
  final String apiKey;
  final String model;
  final AppLlmTimeoutConfig? _timeout;
  final int _timeoutMs;
  final List<AppLlmChatMessage> messages;
  final int maxTokens;
  final AppLlmProvider provider;
  final void Function(String chunk)? onPartialText;
  final AppLlmFormalCacheRequestIdentity? formalCacheIdentity;
  final AppLlmFormalDispatchRequestIdentity? formalDispatchIdentity;

  /// Whether [AppLlmClient.chat] may use a streaming transport internally.
  ///
  /// Formal meters can disable this to require one atomic response containing
  /// exact usage and provider model identity. Direct [chatStream] calls are
  /// unaffected.
  final bool preferStreaming;

  /// Request-owned physical dispatch contract. Every transport wrapper must
  /// preserve this value so nested gateways cannot re-enable retries.
  final AppLlmPhysicalDispatchPolicy physicalDispatchPolicy;

  /// Durable canonical logical-attempt identity for formal single dispatch.
  /// It is intentionally absent from adaptive requests.
  final String? dispatchEvidenceNonce;

  /// Opaque runtime-only capability attached by the formal dispatch entry.
  /// Its concrete IO type is private and isolate-unsendable; this field is
  /// intentionally neither serializable nor part of request semantics.
  final Object? _formalDispatchPermit;

  /// Used only by the central formal dispatch entry to retain an opaque IO
  /// capability while freezing/copying the request. Supplying another object
  /// cannot satisfy the IO transport's private-type check.
  AppLlmChatRequest withFormalDispatchPermit(Object permit) =>
      AppLlmChatRequest(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        timeout: _timeout,
        timeoutMs: _timeoutMs,
        maxTokens: maxTokens,
        messages: messages,
        provider: provider,
        onPartialText: onPartialText,
        formalCacheIdentity: formalCacheIdentity,
        formalDispatchIdentity: formalDispatchIdentity,
        preferStreaming: preferStreaming,
        physicalDispatchPolicy: physicalDispatchPolicy,
        dispatchEvidenceNonce: dispatchEvidenceNonce,
        formalDispatchPermit: permit,
      );

  Object? get formalDispatchPermitForTransport => _formalDispatchPermit;

  AppLlmTimeoutConfig get timeout =>
      _timeout ?? AppLlmTimeoutConfig.uniform(_timeoutMs);

  int get timeoutMs => timeout.receiveTimeoutMs;

  int get effectiveMaxTokens => normalizeMaxTokens(maxTokens);

  static bool shouldOmitMaxTokens(int value) {
    return normalizeMaxTokens(value) == unlimitedMaxTokens;
  }

  static int normalizeMaxTokens(int value) {
    if (value <= unlimitedMaxTokens) {
      return unlimitedMaxTokens;
    }
    if (value < defaultMaxTokens) {
      return defaultMaxTokens;
    }
    if (value > maximumMaxTokens) {
      return maximumMaxTokens;
    }
    return value;
  }

  /// Captures caller-owned prompt data at the physical admission boundary.
  /// The returned request owns both its list and message instances.
  AppLlmChatRequest freezeMessages() => AppLlmChatRequest(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    timeout: _timeout,
    timeoutMs: _timeoutMs,
    maxTokens: maxTokens,
    messages: List<AppLlmChatMessage>.unmodifiable(
      messages.map(
        (message) =>
            AppLlmChatMessage(role: message.role, content: message.content),
      ),
    ),
    provider: provider,
    onPartialText: onPartialText,
    formalCacheIdentity: formalCacheIdentity,
    formalDispatchIdentity: formalDispatchIdentity,
    preferStreaming: preferStreaming,
    physicalDispatchPolicy: physicalDispatchPolicy,
    dispatchEvidenceNonce: dispatchEvidenceNonce,
    formalDispatchPermit: _formalDispatchPermit,
  );
}

class AppLlmChatResult {
  const AppLlmChatResult.success({
    required this.text,
    this.latencyMs,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.tokenUsage,
    this.providerModel,
    this.providerResponseId,
    this.dispatchResolution,
    this.providerBoundaryReceipt,
  }) : failureKind = null,
       statusCode = null,
       detail = null,
       dispatchFailureDisposition = null;

  const AppLlmChatResult.failure({
    required this.failureKind,
    this.statusCode,
    this.detail,
    this.dispatchResolution,
    this.dispatchFailureDisposition,
    this.providerBoundaryReceipt,
  }) : text = null,
       latencyMs = null,
       promptTokens = null,
       completionTokens = null,
       totalTokens = null,
       tokenUsage = null,
       providerModel = null,
       providerResponseId = null;

  /// A provider failure whose conservative usage was sealed by a formal
  /// metering boundary. Ordinary transport failures must keep using
  /// [AppLlmChatResult.failure], because only the meter can truthfully attach
  /// these upper-bound token counts.
  const AppLlmChatResult.meteredFailure({
    required this.failureKind,
    required int meteredPromptTokens,
    required int meteredCompletionTokens,
    this.statusCode,
    this.detail,
    this.dispatchResolution,
    this.dispatchFailureDisposition,
    this.providerBoundaryReceipt,
  }) : text = null,
       latencyMs = null,
       promptTokens = meteredPromptTokens,
       completionTokens = meteredCompletionTokens,
       totalTokens = meteredPromptTokens + meteredCompletionTokens,
       tokenUsage = null,
       providerModel = null,
       providerResponseId = null;

  final String? text;
  final int? latencyMs;
  final AppLlmFailureKind? failureKind;
  final int? statusCode;
  final String? detail;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final Object? tokenUsage;

  /// Exact model identity echoed by the provider response, when available.
  /// This is deliberately distinct from the requested model.
  final String? providerModel;

  /// Non-secret provider response identifier, when the provider returns one.
  final String? providerResponseId;

  /// Structured endpoint identity attached by the central dispatch boundary.
  final AppLlmDispatchResolution? dispatchResolution;

  /// Diagnostic receipt that a concrete transport admitted an HTTP operation.
  /// A null or untrusted value means the dispatch count is unknown (not zero),
  /// and formal evidence must fail closed.
  final AppLlmProviderBoundaryReceipt? providerBoundaryReceipt;

  /// Structured evidence about whether a failed physical dispatch could have
  /// completed at the provider.
  final AppLlmDispatchFailureDisposition? dispatchFailureDisposition;

  bool get succeeded => failureKind == null && text != null;

  AppLlmChatResult withDispatchResolution(
    AppLlmDispatchResolution resolution,
  ) => AppLlmChatResult._(
    text: text,
    latencyMs: latencyMs,
    failureKind: failureKind,
    statusCode: statusCode,
    detail: detail,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: totalTokens,
    tokenUsage: tokenUsage,
    providerModel: providerModel,
    providerResponseId: providerResponseId,
    dispatchResolution: resolution,
    dispatchFailureDisposition: dispatchFailureDisposition,
    providerBoundaryReceipt: providerBoundaryReceipt,
  );

  AppLlmChatResult withProviderBoundaryReceipt(
    AppLlmProviderBoundaryReceipt receipt,
  ) => AppLlmChatResult._(
    text: text,
    latencyMs: latencyMs,
    failureKind: failureKind,
    statusCode: statusCode,
    detail: detail,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    totalTokens: totalTokens,
    tokenUsage: tokenUsage,
    providerModel: providerModel,
    providerResponseId: providerResponseId,
    dispatchResolution: dispatchResolution,
    dispatchFailureDisposition: dispatchFailureDisposition,
    providerBoundaryReceipt: receipt,
  );

  const AppLlmChatResult._({
    required this.text,
    required this.latencyMs,
    required this.failureKind,
    required this.statusCode,
    required this.detail,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.tokenUsage,
    required this.providerModel,
    required this.providerResponseId,
    required this.dispatchResolution,
    required this.dispatchFailureDisposition,
    required this.providerBoundaryReceipt,
  });
}

class AppLlmStreamException implements Exception {
  const AppLlmStreamException({
    required this.failureKind,
    this.statusCode,
    this.detail,
  });

  final AppLlmFailureKind failureKind;
  final int? statusCode;
  final String? detail;

  @override
  String toString() =>
      'AppLlmStreamException($failureKind, $statusCode, $detail)';
}
