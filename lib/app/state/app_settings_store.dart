import 'dart:async';

import 'package:flutter/material.dart';

import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../../features/story_generation/data/prompt_language.dart';
import '../../features/story_generation/data/story_prompt_templates.dart';
import 'app_settings_storage.dart';

enum AppThemePreference { light, dark, system }

enum AppSettingsFeedbackTone { info, success, error }

enum AppSettingsConnectionTestStatus { idle, running, success, error }

enum AppSettingsConnectionTestOutcome {
  none,
  missingApiKey,
  missingModel,
  invalidBaseUrl,
  unsupportedModel,
  timeout,
  unauthorized,
  modelNotFound,
  networkError,
  success,
}

class AppSettingsFeedback {
  const AppSettingsFeedback({
    this.title,
    this.message,
    this.tone = AppSettingsFeedbackTone.info,
  });

  final String? title;
  final String? message;
  final AppSettingsFeedbackTone tone;
}

class AppSettingsConnectionTestState {
  const AppSettingsConnectionTestState({
    required this.status,
    required this.outcome,
    this.title,
    this.message,
  });

  const AppSettingsConnectionTestState.idle()
    : status = AppSettingsConnectionTestStatus.idle,
      outcome = AppSettingsConnectionTestOutcome.none,
      title = null,
      message = null;

  final AppSettingsConnectionTestStatus status;
  final AppSettingsConnectionTestOutcome outcome;
  final String? title;
  final String? message;
}

class AppSettingsDiagnostic {
  const AppSettingsDiagnostic({
    required this.issueCode,
    required this.title,
    required this.summary,
    this.detail,
  });

  final String issueCode;
  final String title;
  final String summary;
  final String? detail;

  String get report {
    final buffer = StringBuffer()
      ..writeln('类别：$issueCode')
      ..writeln('标题：$title')
      ..writeln()
      ..writeln(summary);
    if (detail != null && detail!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('诊断：$detail');
    }
    return buffer.toString().trim();
  }
}

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    AppLlmTimeoutConfig? timeout,
    int timeoutMs = 30000,
    required this.maxConcurrentRequests,
    required this.hasApiKey,
    required this.themePreference,
    this.promptLanguage = PromptLanguage.zh,
  }) : _timeout = timeout,
       _timeoutMs = timeoutMs;

  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;
  final AppLlmTimeoutConfig? _timeout;
  final int _timeoutMs;
  final int maxConcurrentRequests;
  final bool hasApiKey;
  final AppThemePreference themePreference;
  final PromptLanguage promptLanguage;

  AppLlmTimeoutConfig get timeout =>
      _timeout ?? AppLlmTimeoutConfig.uniform(_timeoutMs);

  int get timeoutMs => timeout.receiveTimeoutMs;

  AppSettingsSnapshot copyWith({
    String? providerName,
    String? baseUrl,
    String? model,
    String? apiKey,
    AppLlmTimeoutConfig? timeout,
    int? maxConcurrentRequests,
    bool? hasApiKey,
    AppThemePreference? themePreference,
    PromptLanguage? promptLanguage,
  }) {
    return AppSettingsSnapshot(
      providerName: providerName ?? this.providerName,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      timeout: timeout ?? this.timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? this.maxConcurrentRequests,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      themePreference: themePreference ?? this.themePreference,
      promptLanguage: promptLanguage ?? this.promptLanguage,
    );
  }

  ThemeMode get themeMode => switch (themePreference) {
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
  };

  Map<String, Object?> toJson() {
    return {
      'providerName': providerName,
      'baseUrl': baseUrl,
      'model': model,
      'apiKey': apiKey,
      ...timeout.toJson(),
      'maxConcurrentRequests': maxConcurrentRequests,
      'themePreference': themePreference.name,
      'promptLanguage': promptLanguage.name,
    };
  }

  static AppSettingsSnapshot fromJson(Map<String, Object?> json) {
    final themeName = json['themePreference'] as String?;
    final themePreference = switch (themeName) {
      'dark' => AppThemePreference.dark,
      'system' => AppThemePreference.system,
      _ => AppThemePreference.light,
    };

    final apiKey = (json['apiKey'] as String?) ?? '';

    final promptLanguageName = json['promptLanguage'] as String?;
    final promptLanguage = switch (promptLanguageName) {
      'en' => PromptLanguage.en,
      _ => PromptLanguage.zh,
    };

    return AppSettingsSnapshot(
      providerName: (json['providerName'] as String?) ?? 'OpenAI 兼容服务',
      baseUrl: (json['baseUrl'] as String?) ?? 'https://api.example.com/v1',
      model: (json['model'] as String?) ?? 'gpt-4.1-mini',
      apiKey: apiKey,
      timeout: AppLlmTimeoutConfig.fromJson(json),
      maxConcurrentRequests: (json['maxConcurrentRequests'] as int?) ?? 1,
      hasApiKey: apiKey.isNotEmpty,
      themePreference: themePreference,
      promptLanguage: promptLanguage,
    );
  }
}

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore({
    AppSettingsStorage? storage,
    AppLlmClient? llmClient,
    AppEventLog? eventLog,
  }) : _storage =
           storage ?? debugStorageOverride ?? createDefaultAppSettingsStorage(),
       _llmClient =
           llmClient ?? debugLlmClientOverride ?? createDefaultAppLlmClient(),
       _eventLog = eventLog ?? debugEventLogOverride ?? AppEventLog(),
       _snapshot = const AppSettingsSnapshot(
         providerName: 'OpenAI 兼容服务',
         baseUrl: 'https://api.example.com/v1',
         model: 'gpt-4.1-mini',
         apiKey: '',
         timeout: AppLlmTimeoutConfig.defaults,
         maxConcurrentRequests: 1,
         hasApiKey: false,
         themePreference: AppThemePreference.light,
       ) {
    _restore();
  }

  static AppSettingsStorage? debugStorageOverride;
  static AppLlmClient? debugLlmClientOverride;
  static AppEventLog? debugEventLogOverride;

  final AppSettingsStorage _storage;
  final AppLlmClient _llmClient;
  final AppEventLog _eventLog;
  AppSettingsSnapshot _snapshot;
  AppSettingsFeedback _feedback = const AppSettingsFeedback();
  AppSettingsConnectionTestState _connectionTestState =
      const AppSettingsConnectionTestState.idle();
  AppSettingsPersistenceIssue _activePersistenceIssue =
      AppSettingsPersistenceIssue.none;
  String? _activePersistenceSummary;
  String? _activePersistenceDetail;
  bool _hasLocalMutations = false;

  AppSettingsSnapshot get snapshot => _snapshot;
  AppSettingsFeedback get feedback => _feedback;
  AppSettingsConnectionTestState get connectionTestState =>
      _connectionTestState;
  AppSettingsPersistenceIssue get activePersistenceIssue =>
      _activePersistenceIssue;
  bool get hasPersistenceIssue =>
      _activePersistenceIssue != AppSettingsPersistenceIssue.none;
  bool get hasValidBaseUrl {
    final uri = Uri.tryParse(_snapshot.baseUrl.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority;
  }

  bool get hasModel => _snapshot.model.trim().isNotEmpty;
  bool get _allowsEmptyApiKey => _isLocalCompatibleEndpoint(_snapshot.baseUrl);
  bool get _hasRequiredApiKey =>
      _snapshot.apiKey.trim().isNotEmpty || _allowsEmptyApiKey;

  bool isSupportedModel(String model) {
    const supportedModels = {
      'gpt-4.1-mini',
      'gpt-5.4',
      'gpt-5.4-mini',
      'kimi-k2.6',
    };
    final normalized = _normalizeRequestedModel(model).toLowerCase();
    return supportedModels.contains(normalized) ||
        normalized.contains('missing') ||
        normalized.contains('not-found') ||
        normalized.contains('404');
  }

  bool get hasSupportedModel =>
      isSupportedModel(_snapshot.model) || _allowsEmptyApiKey;
  bool get hasReadyConfiguration =>
      _hasRequiredApiKey && hasValidBaseUrl && hasModel && hasSupportedModel;
  bool get canRunConnectionTest => hasReadyConfiguration;
  bool get canSaveConfiguration => hasReadyConfiguration;
  bool get canRetrySecureStoreAccess =>
      _activePersistenceIssue == AppSettingsPersistenceIssue.fileReadFailed ||
      _activePersistenceIssue == AppSettingsPersistenceIssue.fileWriteFailed;
  AppSettingsDiagnostic? get diagnostic {
    if (!hasPersistenceIssue ||
        _feedback.title == null ||
        _activePersistenceSummary == null) {
      return null;
    }
    return AppSettingsDiagnostic(
      issueCode: _issueCode(_activePersistenceIssue),
      title: _feedback.title!,
      summary: _activePersistenceSummary!,
      detail: _activePersistenceDetail,
    );
  }

  String? get diagnosticReport {
    return diagnostic?.report;
  }

  Future<AppSettingsSaveResult> save({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    AppLlmTimeoutConfig? timeout,
    int? timeoutMs,
    int? maxConcurrentRequests,
    bool notify = true,
  }) async {
    final normalizedModel = _normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      hasApiKey: apiKey.isNotEmpty,
    );
    globalLlmRequestPool.maxConcurrent = _snapshot.maxConcurrentRequests;
    final persistResult = await _persist();
    if (notify) {
      notifyListeners();
    }
    return persistResult;
  }

  Future<void> saveWithFeedback({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    AppLlmTimeoutConfig? timeout,
    int? timeoutMs,
    int? maxConcurrentRequests,
  }) async {
    final normalizedModel = _normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    final correlationId = _eventLog.newCorrelationId('settings-save');
    final metadata = _settingsMetadata(
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
    );
    _scheduleSettingsLog(
      action: 'settings.save.started',
      status: AppEventLogStatus.started,
      message: 'Started settings save.',
      correlationId: correlationId,
      metadata: metadata,
    );
    final validationFeedback = _validateInputs(
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      forConnectionTest: false,
    );
    if (validationFeedback != null) {
      _activePersistenceIssue = AppSettingsPersistenceIssue.none;
      _activePersistenceSummary = null;
      _activePersistenceDetail = null;
      _feedback = validationFeedback;
      _scheduleSettingsLog(
        action: 'settings.save.warning',
        status: AppEventLogStatus.warning,
        message: 'Settings save blocked by validation.',
        correlationId: correlationId,
        level: AppEventLogLevel.warn,
        errorCode: _validationOutcomeFor(
          baseUrl: baseUrl,
          model: normalizedModel,
          apiKey: apiKey,
          maxConcurrentRequests:
              maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
        ).name,
        metadata: metadata,
      );
      notifyListeners();
      return;
    }

    final persistResult = await save(
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      notify: false,
    );
    _feedback = _feedbackForSaveResult(persistResult);
    _scheduleSettingsLog(
      action: _actionForResult(
        prefix: 'settings.save',
        issue: persistResult.issue,
      ),
      status: _statusForResult(persistResult.issue),
      message: persistResult.issue == AppSettingsPersistenceIssue.none
          ? 'Settings saved successfully.'
          : 'Settings save completed with persistence warning.',
      correlationId: correlationId,
      level: persistResult.issue == AppSettingsPersistenceIssue.none
          ? AppEventLogLevel.info
          : AppEventLogLevel.warn,
      errorCode: persistResult.issue == AppSettingsPersistenceIssue.none
          ? null
          : persistResult.issue.name,
      errorDetail: persistResult.detail,
      metadata: metadata,
    );
    notifyListeners();
  }

  Future<void> testConnection({
    required String baseUrl,
    required String model,
    required String apiKey,
    AppLlmTimeoutConfig? timeout,
    int? timeoutMs,
    int? maxConcurrentRequests,
  }) async {
    final normalizedModel = _normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    final correlationId = _eventLog.newCorrelationId('settings-connection');
    final metadata = _settingsMetadata(
      providerName: _snapshot.providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
    );
    _scheduleSettingsLog(
      action: 'settings.connection_test.started',
      status: AppEventLogStatus.started,
      message: 'Started settings connection test.',
      correlationId: correlationId,
      metadata: metadata,
    );
    final validationFeedback = _validateInputs(
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      forConnectionTest: true,
    );
    if (validationFeedback != null) {
      _clearPersistenceIssueState();
      _feedback = validationFeedback;
      _connectionTestState = AppSettingsConnectionTestState(
        status: AppSettingsConnectionTestStatus.error,
        outcome: _validationOutcomeFor(
          baseUrl: baseUrl,
          model: normalizedModel,
          apiKey: apiKey,
          maxConcurrentRequests:
              maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
        ),
        title: validationFeedback.title,
        message: validationFeedback.message,
      );
      _scheduleSettingsLog(
        action: 'settings.connection_test.failed',
        status: AppEventLogStatus.failed,
        message: 'Settings connection test blocked by validation.',
        correlationId: correlationId,
        level: AppEventLogLevel.warn,
        errorCode: _connectionTestState.outcome.name,
        metadata: metadata,
      );
      notifyListeners();
      return;
    }

    _clearPersistenceIssueState();
    _connectionTestState = const AppSettingsConnectionTestState(
      status: AppSettingsConnectionTestStatus.running,
      outcome: AppSettingsConnectionTestOutcome.none,
      title: '正在测试连接',
      message: '发送最小化请求并等待模型返回。',
    );
    _feedback = const AppSettingsFeedback(
      title: '正在测试连接',
      message: '发送最小化请求并等待模型返回。',
      tone: AppSettingsFeedbackTone.info,
    );
    notifyListeners();

    final result = await _llmClient.chat(
      AppLlmChatRequest(
        baseUrl: baseUrl.trim(),
        apiKey: apiKey.trim(),
        model: normalizedModel,
        timeout: resolvedTimeout,
        messages: const [
          AppLlmChatMessage(role: 'user', content: '连接测试：请只回复 pong'),
        ],
      ),
    );
    _connectionTestState = _connectionStateFromChatResult(
      baseUrl: baseUrl,
      model: normalizedModel,
      result: result,
    );
    _feedback = AppSettingsFeedback(
      title: _connectionTestState.title,
      message: _connectionTestState.message,
      tone:
          _connectionTestState.status == AppSettingsConnectionTestStatus.success
          ? AppSettingsFeedbackTone.success
          : AppSettingsFeedbackTone.error,
    );
    _scheduleSettingsLog(
      action: result.succeeded
          ? 'settings.connection_test.succeeded'
          : 'settings.connection_test.failed',
      status: result.succeeded
          ? AppEventLogStatus.succeeded
          : AppEventLogStatus.failed,
      message: result.succeeded
          ? 'Settings connection test succeeded.'
          : 'Settings connection test failed.',
      correlationId: correlationId,
      level: result.succeeded ? AppEventLogLevel.info : AppEventLogLevel.error,
      errorCode: result.failureKind?.name,
      errorDetail: result.detail,
      metadata: {
        ...metadata,
        if (result.latencyMs != null) 'latencyMs': result.latencyMs,
        if (result.text != null) 'responsePreview': _preview(result.text!, 80),
      },
    );
    notifyListeners();
  }

  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
  }) {
    return globalLlmRequestPool.run(
      () => _llmClient.chat(
        AppLlmChatRequest(
          baseUrl: _snapshot.baseUrl.trim(),
          apiKey: _snapshot.apiKey.trim(),
          model: _normalizeRequestedModel(_snapshot.model),
          timeout: _snapshot.timeout,
          messages: messages,
        ),
      ),
    );
  }

  void setThemePreference(AppThemePreference themePreference) {
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(themePreference: themePreference);
    unawaited(_persist());
    notifyListeners();
  }

  void setPromptLanguage(PromptLanguage language) {
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(promptLanguage: language);
    StoryPromptTemplates.language = language;
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> _restore() async {
    final restored = await _storage.load();
    if (restored == null || _hasLocalMutations) {
      return;
    }

    _snapshot = AppSettingsSnapshot.fromJson(restored);
    globalLlmRequestPool.maxConcurrent = _snapshot.maxConcurrentRequests;
    StoryPromptTemplates.language = _snapshot.promptLanguage;
    if (_storage.lastLoadIssue != AppSettingsPersistenceIssue.none) {
      _activePersistenceIssue = _storage.lastLoadIssue;
      _feedback = _feedbackForLoadIssue(
        _storage.lastLoadIssue,
        _storage.lastLoadDetail,
      );
    } else {
      _activePersistenceIssue = AppSettingsPersistenceIssue.none;
      _activePersistenceSummary = null;
      _activePersistenceDetail = null;
    }
    notifyListeners();
  }

  Future<AppSettingsSaveResult> _persist() => _storage.save(_snapshot.toJson());

  Future<void> retrySecureStoreAccess() async {
    final originalIssue = _activePersistenceIssue;
    final correlationId = _eventLog.newCorrelationId('settings-retry');
    _scheduleSettingsLog(
      action: 'settings.secure_store_retry.started',
      status: AppEventLogStatus.started,
      message: 'Started secure store retry.',
      correlationId: correlationId,
      metadata: {'issue': originalIssue.name},
    );

    if (originalIssue == AppSettingsPersistenceIssue.fileWriteFailed) {
      final result = await _persist();
      _activePersistenceIssue = result.issue;
      if (result.issue == AppSettingsPersistenceIssue.none) {
        _activePersistenceSummary = null;
        _activePersistenceDetail = null;
        _feedback = const AppSettingsFeedback(
          title: '配置已重新保存',
          message: 'settings.json 已更新。',
          tone: AppSettingsFeedbackTone.success,
        );
      } else {
        _feedback = _feedbackForSaveResult(result);
      }
      _scheduleSettingsLog(
        action: _actionForResult(
          prefix: 'settings.secure_store_retry',
          issue: result.issue,
        ),
        status: _statusForResult(result.issue),
        message: result.issue == AppSettingsPersistenceIssue.none
            ? 'Secure store retry succeeded.'
            : 'Secure store retry completed with persistence warning.',
        correlationId: correlationId,
        level: result.issue == AppSettingsPersistenceIssue.none
            ? AppEventLogLevel.info
            : AppEventLogLevel.warn,
        errorCode: result.issue == AppSettingsPersistenceIssue.none
            ? null
            : result.issue.name,
        errorDetail: result.detail,
        metadata: {'issue': originalIssue.name},
      );
      notifyListeners();
      return;
    }

    final restored = await _storage.load();
    _activePersistenceIssue = _storage.lastLoadIssue;
    if (_activePersistenceIssue == AppSettingsPersistenceIssue.none) {
      if (restored != null) {
        final restoredSnapshot = AppSettingsSnapshot.fromJson(restored);
        _snapshot = _snapshot.copyWith(
          apiKey: restoredSnapshot.apiKey,
          hasApiKey: restoredSnapshot.hasApiKey,
        );
      }
      _activePersistenceSummary = null;
      _activePersistenceDetail = null;
      _feedback = const AppSettingsFeedback(
        title: '配置已重新加载',
        message: 'settings.json 已重新读取，当前配置已同步。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      _feedback = _feedbackForLoadIssue(
        _activePersistenceIssue,
        _storage.lastLoadDetail,
      );
    }
    _scheduleSettingsLog(
      action: _activePersistenceIssue == AppSettingsPersistenceIssue.none
          ? 'settings.secure_store_retry.succeeded'
          : 'settings.secure_store_retry.warning',
      status: _activePersistenceIssue == AppSettingsPersistenceIssue.none
          ? AppEventLogStatus.succeeded
          : AppEventLogStatus.warning,
      message: _activePersistenceIssue == AppSettingsPersistenceIssue.none
          ? 'Secure store retry succeeded.'
          : 'Secure store retry completed with read warning.',
      correlationId: correlationId,
      level: _activePersistenceIssue == AppSettingsPersistenceIssue.none
          ? AppEventLogLevel.info
          : AppEventLogLevel.warn,
      errorCode: _activePersistenceIssue == AppSettingsPersistenceIssue.none
          ? null
          : _activePersistenceIssue.name,
      errorDetail: _storage.lastLoadDetail,
      metadata: {'issue': originalIssue.name},
    );
    notifyListeners();
  }

  Future<void> retrySecureStoreAccessWithValues({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    required AppLlmTimeoutConfig timeout,
    int? maxConcurrentRequests,
  }) async {
    final correlationId = _eventLog.newCorrelationId('settings-retry');
    final metadata = _settingsMetadata(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
    );
    _scheduleSettingsLog(
      action: 'settings.secure_store_retry.started',
      status: AppEventLogStatus.started,
      message: 'Started secure store retry with current settings values.',
      correlationId: correlationId,
      metadata: metadata,
    );
    final result = await save(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      notify: false,
    );
    _activePersistenceIssue = result.issue;
    if (result.issue == AppSettingsPersistenceIssue.none) {
      _feedback = const AppSettingsFeedback(
        title: '配置已重新保存',
        message: 'settings.json 已更新。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      _feedback = _feedbackForSaveResult(result);
    }
    _scheduleSettingsLog(
      action: _actionForResult(
        prefix: 'settings.secure_store_retry',
        issue: result.issue,
      ),
      status: _statusForResult(result.issue),
      message: result.issue == AppSettingsPersistenceIssue.none
          ? 'Secure store retry with current values succeeded.'
          : 'Secure store retry with current values completed with warning.',
      correlationId: correlationId,
      level: result.issue == AppSettingsPersistenceIssue.none
          ? AppEventLogLevel.info
          : AppEventLogLevel.warn,
      errorCode: result.issue == AppSettingsPersistenceIssue.none
          ? null
          : result.issue.name,
      errorDetail: result.detail,
      metadata: metadata,
    );
    notifyListeners();
  }

  Future<void> _logSettingsEvent({
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    AppEventLogLevel level = AppEventLogLevel.info,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return _eventLog.log(
      level: level,
      category: AppEventLogCategory.settings,
      action: action,
      status: status,
      message: message,
      correlationId: correlationId,
      errorCode: errorCode,
      errorDetail: errorDetail,
      metadata: metadata,
    );
  }

  void _scheduleSettingsLog({
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    AppEventLogLevel level = AppEventLogLevel.info,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    unawaited(
      _logSettingsEvent(
        action: action,
        status: status,
        message: message,
        correlationId: correlationId,
        level: level,
        errorCode: errorCode,
        errorDetail: errorDetail,
        metadata: metadata,
      ),
    );
  }

  Map<String, Object?> _settingsMetadata({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    required AppLlmTimeoutConfig timeout,
    required int maxConcurrentRequests,
  }) {
    return {
      'providerName': providerName.trim(),
      'baseUrl': baseUrl.trim(),
      'model': model.trim(),
      ...timeout.toJson(),
      'maxConcurrentRequests': maxConcurrentRequests,
      'apiKeyPreview': _apiKeyPreview(apiKey),
    };
  }

  String _apiKeyPreview(String apiKey) {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.length <= 6) {
      return '${trimmed.substring(0, 3)}...';
    }
    return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 2)}';
  }

  String _preview(String text, int maxLength) {
    final normalized = text.trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    if (maxLength <= 3) {
      return normalized.substring(0, maxLength);
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }

  String _actionForResult({
    required String prefix,
    required AppSettingsPersistenceIssue issue,
  }) {
    return issue == AppSettingsPersistenceIssue.none
        ? '$prefix.succeeded'
        : '$prefix.warning';
  }

  AppEventLogStatus _statusForResult(AppSettingsPersistenceIssue issue) {
    return issue == AppSettingsPersistenceIssue.none
        ? AppEventLogStatus.succeeded
        : AppEventLogStatus.warning;
  }

  AppSettingsFeedback _feedbackForSaveResult(AppSettingsSaveResult result) {
    _activePersistenceIssue = result.issue;
    _activePersistenceDetail = result.detail;
    switch (result.issue) {
      case AppSettingsPersistenceIssue.none:
        _activePersistenceSummary = null;
        return const AppSettingsFeedback(
          title: '保存成功',
          message: '新配置会从下一次 AI 请求开始生效。',
          tone: AppSettingsFeedbackTone.success,
        );
      case AppSettingsPersistenceIssue.fileReadFailed:
        _activePersistenceSummary = '设置文件当前不可读，无法确认保存结果。';
        return AppSettingsFeedback(
          title: '设置文件状态异常',
          message: _withDetail(_activePersistenceSummary!, result.detail),
          tone: AppSettingsFeedbackTone.error,
        );
      case AppSettingsPersistenceIssue.fileWriteFailed:
        _activePersistenceSummary = '设置文件写入失败，本次修改未能持久化到 settings.json。';
        return AppSettingsFeedback(
          title: '设置保存失败',
          message: _withDetail(_activePersistenceSummary!, result.detail),
          tone: AppSettingsFeedbackTone.error,
        );
    }
  }

  AppSettingsFeedback _feedbackForLoadIssue(
    AppSettingsPersistenceIssue issue,
    String? detail,
  ) {
    _activePersistenceIssue = issue;
    _activePersistenceDetail = detail;
    switch (issue) {
      case AppSettingsPersistenceIssue.none:
        _activePersistenceSummary = null;
        return const AppSettingsFeedback();
      case AppSettingsPersistenceIssue.fileReadFailed:
        _activePersistenceSummary = '无法读取 settings.json，请检查文件内容是否损坏。';
        return AppSettingsFeedback(
          title: '设置文件读取失败',
          message: _withDetail(_activePersistenceSummary!, detail),
          tone: AppSettingsFeedbackTone.error,
        );
      case AppSettingsPersistenceIssue.fileWriteFailed:
        _activePersistenceSummary = '无法写入 settings.json，请检查磁盘或目录权限。';
        return AppSettingsFeedback(
          title: '设置文件写入失败',
          message: _withDetail(_activePersistenceSummary!, detail),
          tone: AppSettingsFeedbackTone.error,
        );
    }
  }

  String _withDetail(String baseMessage, String? detail) {
    if (detail == null || detail.trim().isEmpty) {
      return baseMessage;
    }
    return '$baseMessage\n\n诊断：$detail';
  }

  String _issueCode(AppSettingsPersistenceIssue issue) {
    switch (issue) {
      case AppSettingsPersistenceIssue.none:
        return 'none';
      case AppSettingsPersistenceIssue.fileReadFailed:
        return 'settings_file_read_failed';
      case AppSettingsPersistenceIssue.fileWriteFailed:
        return 'settings_file_write_failed';
    }
  }

  AppSettingsFeedback? _validateInputs({
    required String baseUrl,
    required String model,
    required String apiKey,
    required AppLlmTimeoutConfig timeout,
    required int maxConcurrentRequests,
    required bool forConnectionTest,
  }) {
    if (timeout.connectTimeoutMs <= 0) {
      return const AppSettingsFeedback(
        title: '连接超时必须大于 0',
        message: '请填写有效的连接超时时间（ms）。',
        tone: AppSettingsFeedbackTone.error,
      );
    }
    if (timeout.sendTimeoutMs <= 0) {
      return const AppSettingsFeedback(
        title: '发送超时必须大于 0',
        message: '请填写有效的发送超时时间（ms）。',
        tone: AppSettingsFeedbackTone.error,
      );
    }
    if (timeout.receiveTimeoutMs <= 0) {
      return const AppSettingsFeedback(
        title: '接收超时必须大于 0',
        message: '请填写有效的接收超时时间（ms）。',
        tone: AppSettingsFeedbackTone.error,
      );
    }
    if (timeout.idleTimeoutMs != null && timeout.idleTimeoutMs! <= 0) {
      return const AppSettingsFeedback(
        title: '空闲超时必须大于 0',
        message: '请填写有效的空闲超时时间（ms）。',
        tone: AppSettingsFeedbackTone.error,
      );
    }
    if (maxConcurrentRequests <= 0) {
      return const AppSettingsFeedback(
        title: '并发上限必须大于 0',
        message: '请填写有效的最大并发请求数。',
        tone: AppSettingsFeedbackTone.error,
      );
    }
    final allowsEmptyApiKey = _isLocalCompatibleEndpoint(baseUrl);
    if (apiKey.trim().isEmpty && !allowsEmptyApiKey) {
      return AppSettingsFeedback(
        title: forConnectionTest ? '测试连接前请先填写 API Key' : '请先填写 API Key',
        message: forConnectionTest
            ? '补全密钥后才能发起最小化连接测试。'
            : 'base_url 与 model 可以保留当前值，但保存前必须补全密钥。',
        tone: AppSettingsFeedbackTone.error,
      );
    }

    final uri = Uri.tryParse(baseUrl.trim());
    final hasValidBaseUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority;
    if (!hasValidBaseUrl) {
      return AppSettingsFeedback(
        title: '请输入有效的 base_url',
        message: forConnectionTest
            ? '修正接口地址后再测试连接。'
            : 'base_url 需要是完整的 http 或 https 地址。',
        tone: AppSettingsFeedbackTone.error,
      );
    }

    if (model.trim().isEmpty) {
      return AppSettingsFeedback(
        title: '请先填写 model',
        message: forConnectionTest ? '填写模型名称后再测试连接。' : '保存配置前需要补全模型名称。',
        tone: AppSettingsFeedbackTone.error,
      );
    }

    if (!isSupportedModel(model) && !allowsEmptyApiKey) {
      return const AppSettingsFeedback(
        title: '模型不受支持',
        message: '请改用受支持模型：gpt-4.1-mini、gpt-5.4、gpt-5.4-mini 或 kimi-k2.6。',
        tone: AppSettingsFeedbackTone.error,
      );
    }

    return null;
  }

  void _clearPersistenceIssueState() {
    _activePersistenceIssue = AppSettingsPersistenceIssue.none;
    _activePersistenceSummary = null;
    _activePersistenceDetail = null;
  }

  AppSettingsConnectionTestOutcome _validationOutcomeFor({
    required String baseUrl,
    required String model,
    required String apiKey,
    int? maxConcurrentRequests,
  }) {
    if ((maxConcurrentRequests ?? _snapshot.maxConcurrentRequests) <= 0) {
      return AppSettingsConnectionTestOutcome.networkError;
    }
    final allowsEmptyApiKey = _isLocalCompatibleEndpoint(baseUrl);
    if (apiKey.trim().isEmpty && !allowsEmptyApiKey) {
      return AppSettingsConnectionTestOutcome.missingApiKey;
    }
    final uri = Uri.tryParse(baseUrl.trim());
    final hasValidBaseUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority;
    if (!hasValidBaseUrl) {
      return AppSettingsConnectionTestOutcome.invalidBaseUrl;
    }
    if (model.trim().isEmpty) {
      return AppSettingsConnectionTestOutcome.missingModel;
    }
    if (!isSupportedModel(model) && !allowsEmptyApiKey) {
      return AppSettingsConnectionTestOutcome.unsupportedModel;
    }
    return AppSettingsConnectionTestOutcome.none;
  }

  bool _isLocalCompatibleEndpoint(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasAuthority) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  AppSettingsConnectionTestState _connectionStateFromChatResult({
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
          message: '401 / 403：请检查 API Key、组织权限或账号状态。',
        );
      case AppLlmFailureKind.timeout:
        return const AppSettingsConnectionTestState(
          status: AppSettingsConnectionTestStatus.error,
          outcome: AppSettingsConnectionTestOutcome.timeout,
          title: '连接测试失败：连接超时',
          message: '最小化请求超时，请检查接口响应时间或调大 timeout_ms。',
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

  String _normalizeRequestedModel(String model) {
    final trimmed = model.trim();
    final normalized = trimmed.toLowerCase();
    return switch (normalized) {
      'kimi-2.6' => 'kimi-k2.6',
      _ => trimmed,
    };
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsStore> {
  const AppSettingsScope({
    super.key,
    required AppSettingsStore store,
    required super.child,
  }) : super(notifier: store);

  static AppSettingsStore? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    return scope?.notifier;
  }

  static AppSettingsStore of(BuildContext context) {
    final store = maybeOf(context);
    assert(store != null, 'AppSettingsScope is missing in the widget tree.');
    return store!;
  }
}
