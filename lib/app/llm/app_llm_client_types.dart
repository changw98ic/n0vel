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
}

enum AppLlmProvider { openaiCompatible, kimi, ollama, anthropic }

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

class AppLlmChatRequest {
  const AppLlmChatRequest({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    AppLlmTimeoutConfig? timeout,
    int timeoutMs = 30000,
    this.maxTokens = 1024,
    required this.messages,
    this.provider = AppLlmProvider.openaiCompatible,
    this.onPartialText,
  }) : _timeout = timeout,
       _timeoutMs = timeoutMs;

  final String baseUrl;
  final String apiKey;
  final String model;
  final AppLlmTimeoutConfig? _timeout;
  final int _timeoutMs;
  final List<AppLlmChatMessage> messages;
  final int maxTokens;
  final AppLlmProvider provider;
  final void Function(String chunk)? onPartialText;

  AppLlmTimeoutConfig get timeout =>
      _timeout ?? AppLlmTimeoutConfig.uniform(_timeoutMs);

  int get timeoutMs => timeout.receiveTimeoutMs;
}

class AppLlmChatResult {
  const AppLlmChatResult.success({
    required this.text,
    this.latencyMs,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.tokenUsage,
  }) : failureKind = null,
       statusCode = null,
       detail = null;

  const AppLlmChatResult.failure({
    required this.failureKind,
    this.statusCode,
    this.detail,
  }) : text = null,
       latencyMs = null,
       promptTokens = null,
       completionTokens = null,
       totalTokens = null,
       tokenUsage = null;

  final String? text;
  final int? latencyMs;
  final AppLlmFailureKind? failureKind;
  final int? statusCode;
  final String? detail;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final Object? tokenUsage;

  bool get succeeded => failureKind == null && text != null;
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
