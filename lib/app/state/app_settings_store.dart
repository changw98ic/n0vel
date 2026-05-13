import 'dart:async';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import 'ai_request_service.dart';
import 'app_settings_provider_management.dart';
import 'app_settings_store_feedback.dart';
import 'app_settings_store_utils.dart';
import 'app_settings_store_validation.dart';
import 'app_store_listenable.dart';
import 'app_settings_storage.dart';
import 'llm_provider_service.dart';
import '../../domain/prompt_language.dart';
import 'settings/settings_models.dart';

export 'settings/default_provider_config.dart';
export 'settings/settings_models.dart';

class AppSettingsStore extends AppStoreListenable
    with AppSettingsProviderManagement {
  AppSettingsStore({
    AppSettingsStorage? storage,
    AppLlmClient? llmClient,
    AppLlmRequestPool? requestPool,
    AppEventLog? eventLog,
    AppEventBus? eventBus,
    AppLlmCallTraceSink? llmTraceSink,
  }) : _storage =
           storage ?? createDefaultAppSettingsStorage(),
       _llmClient =
           llmClient ?? createDefaultAppLlmClient(),
       _requestPool = requestPool ?? AppLlmRequestPool(maxConcurrent: 3),
       _eventLog = eventLog ?? AppEventLog(),
       _eventBus = eventBus,
       _llmTraceSink = llmTraceSink,
       _providerService = LlmProviderService(maxConcurrentRequests: 1),
       _snapshot = const AppSettingsSnapshot(
         providerName: 'OpenAI 兼容服务',
         baseUrl: 'https://api.example.com/v1',
         model: 'gpt-4.1-mini',
         apiKey: '',
         timeout: AppLlmTimeoutConfig.defaults,
         maxConcurrentRequests: 1,
         maxTokens: AppLlmChatRequest.unlimitedMaxTokens,
         hasApiKey: false,
         themePreference: AppThemePreference.light,
       ) {
    _aiRequestService = AiRequestService(
      llmClient: _llmClient,
      llmTraceSink: _llmTraceSink,
      eventLog: _eventLog,
    );
    _restore();
  }


  final AppSettingsStorage _storage;
  final AppLlmClient _llmClient;
  final AppLlmRequestPool _requestPool;
  final AppEventLog _eventLog;
  final AppEventBus? _eventBus;
  final AppLlmCallTraceSink? _llmTraceSink;
  final LlmProviderService _providerService;
  late final AiRequestService _aiRequestService;
  AppSettingsSnapshot _snapshot;
  AppSettingsFeedback _feedback = const AppSettingsFeedback();
  AppSettingsConnectionTestState _connectionTestState =
      const AppSettingsConnectionTestState.idle();
  AppSettingsPersistenceIssue _activePersistenceIssue =
      AppSettingsPersistenceIssue.none;
  String? _activePersistenceSummary;
  String? _activePersistenceDetail;
  bool _hasLocalMutations = false;

  // --- AppSettingsProviderManagement mixin 访问器 ---
  @override
  AppSettingsSnapshot get providerManagementSnapshot => _snapshot;
  @override
  set providerManagementSnapshot(AppSettingsSnapshot value) {
    _snapshot = value;
  }
  @override
  LlmProviderService get providerService => _providerService;
  @override
  AiRequestService get aiRequestServiceForProviderManagement =>
      _aiRequestService;
  @override
  bool get hasLocalMutations => _hasLocalMutations;
  @override
  set hasLocalMutations(bool value) {
    _hasLocalMutations = value;
  }
  @override
  Future<AppSettingsSaveResult> persistSnapshot() => _persist();
  @override
  void syncRequestPoolLimits() => _syncRequestPoolLimits();

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
  bool get _allowsEmptyApiKey =>
      _aiRequestService.isLocalCompatibleEndpoint(_snapshot.baseUrl);
  bool get _hasRequiredApiKey =>
      _snapshot.apiKey.trim().isNotEmpty || _allowsEmptyApiKey;

  bool isSupportedModel(String model) =>
      isSupportedModelFromUtils(model);

  bool get hasSupportedModel =>
      isSupportedModel(_snapshot.model) || _allowsEmptyApiKey;
  bool get hasReadyConfiguration =>
      _hasRequiredApiKey && hasValidBaseUrl && hasModel && hasSupportedModel;

  bool get hasAnyReadyConfiguration =>
      hasReadyConfiguration ||
      _snapshot.providerProfiles.any(
        (p) => _providerService.isUsableProfile(
          p,
          isLocalCompatibleEndpoint:
              _aiRequestService.isLocalCompatibleEndpoint,
        ),
      );
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
      issueCode: issueCode(_activePersistenceIssue),
      title: _feedback.title!,
      summary: _activePersistenceSummary!,
      detail: _activePersistenceDetail,
    );
  }

  String? get diagnosticReport {
    return diagnostic?.report;
  }

  String providerSummaryForTrace(String traceName) {
    final routedSettings = _resolveRequestSettings(traceName);
    final source = routedSettings.providerProfileId == null
        ? '默认配置'
        : '路由：${routedSettings.providerProfileId}';
    return '${routedSettings.providerName} · '
        '${_aiRequestService.normalizeRequestedModel(routedSettings.model)}（$source）';
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

  Future<AppSettingsSaveResult> save({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    AppLlmTimeoutConfig? timeout,
    int? timeoutMs,
    int? maxConcurrentRequests,
    int? maxTokens,
    List<AppLlmProviderProfile>? providerProfiles,
    List<AppLlmRequestProviderRoute>? requestProviderRoutes,
    bool notify = true,
  }) async {
    final normalizedModel = _aiRequestService.normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    _hasLocalMutations = true;
    final nextProfiles = _providerService.syncPrimaryProfile(
      providerProfiles ?? _snapshot.providerProfiles,
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
    );
    _snapshot = _snapshot.copyWith(
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      maxTokens: AppLlmChatRequest.normalizeMaxTokens(
        maxTokens ?? _snapshot.maxTokens,
      ),
      hasApiKey: apiKey.isNotEmpty,
      providerProfiles: nextProfiles,
      requestProviderRoutes: requestProviderRoutes,
    );
    _syncRequestPoolLimits();
    final persistResult = await _persist();
    if (notify) {
      notifyListeners();
    }
    if (persistResult.issue == AppSettingsPersistenceIssue.none) {
      _eventBus?.publish(
        SettingsSavedEvent(providerName: providerName, model: normalizedModel),
      );
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
    int? maxTokens,
  }) async {
    final normalizedModel = _aiRequestService.normalizeRequestedModel(model);
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
    final validationFeedback = validateInputs(
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      forConnectionTest: false,
      isLocalCompatibleEndpoint: _aiRequestService.isLocalCompatibleEndpoint,
      isSupportedModel: isSupportedModel,
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
        errorCode: validationOutcomeFor(
          baseUrl: baseUrl,
          model: normalizedModel,
          apiKey: apiKey,
          maxConcurrentRequests:
              maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
          fallbackMaxConcurrentRequests: _snapshot.maxConcurrentRequests,
          isLocalCompatibleEndpoint: _aiRequestService.isLocalCompatibleEndpoint,
          isSupportedModel: isSupportedModel,
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
      maxTokens: AppLlmChatRequest.normalizeMaxTokens(
        maxTokens ?? _snapshot.maxTokens,
      ),
      notify: false,
    );
    final saveFeedback = feedbackForSaveResult(persistResult);
    _activePersistenceIssue = saveFeedback.issue;
    _activePersistenceDetail = saveFeedback.detail;
    _activePersistenceSummary = saveFeedback.summary;
    _feedback = saveFeedback.feedback;
    _scheduleSettingsLog(
      action: actionForResult(
        prefix: 'settings.save',
        issue: persistResult.issue,
      ),
      status: statusForResult(persistResult.issue),
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
    String? providerName,
    AppLlmTimeoutConfig? timeout,
    int? timeoutMs,
    int? maxConcurrentRequests,
    int? maxTokens,
  }) async {
    final normalizedModel = _aiRequestService.normalizeRequestedModel(model);
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
    final validationFeedback = validateInputs(
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
      forConnectionTest: true,
      isLocalCompatibleEndpoint: _aiRequestService.isLocalCompatibleEndpoint,
      isSupportedModel: isSupportedModel,
    );
    if (validationFeedback != null) {
      _clearPersistenceIssueState();
      _feedback = validationFeedback;
      _connectionTestState = AppSettingsConnectionTestState(
        status: AppSettingsConnectionTestStatus.error,
        outcome: validationOutcomeFor(
          baseUrl: baseUrl,
          model: normalizedModel,
          apiKey: apiKey,
          maxConcurrentRequests:
              maxConcurrentRequests ?? _snapshot.maxConcurrentRequests,
          fallbackMaxConcurrentRequests: _snapshot.maxConcurrentRequests,
          isLocalCompatibleEndpoint: _aiRequestService.isLocalCompatibleEndpoint,
          isSupportedModel: isSupportedModel,
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

    final result = await _aiRequestService.testConnection(
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxTokens: maxTokens ?? _snapshot.maxTokens,
      providerName: providerName ?? _snapshot.providerName,
    );
    _connectionTestState = _aiRequestService.connectionStateFromResult(
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
        if (result.text != null) 'responsePreview': preview(result.text!, 80),
      },
    );
    notifyListeners();
  }

  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
  }) {
    final resolvedTraceName = traceName ?? _inferTraceName(messages);
    final resolved = _resolveRequestSettings(resolvedTraceName);
    final requestPool = _requestPoolForProviderProfile(
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
    final failoverEndpoints = _aiRequestService.buildFailoverEndpoints(
      profiles: _snapshot.providerProfiles,
      excludeProfileId: resolved.providerProfileId,
    );

    return _aiRequestService.requestCompletion(
      snapshot: _snapshot,
      route: route,
      requestPool: requestPool,
      requestPoolForProvider: _requestPoolForProviderProfile,
      messages: messages,
      maxTokens: maxTokens,
      traceName: resolvedTraceName,
      traceMetadata: traceMetadata,
      failoverEndpoints: failoverEndpoints,
    );
  }

  /// 推断 trace 名称（委托给 AiRequestService）。
  String _inferTraceName(List<AppLlmChatMessage> messages) {
    // AiRequestService 内部已有 _inferLlmTraceName 逻辑，
    // 但此处保持 store 层的轻量调用入口以减少不必要参数传递。
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

  void _syncRequestPoolLimits() {
    final limit = _snapshot.maxConcurrentRequests;
    _requestPool.maxConcurrent = limit;
    final activeProfileIds = [
      for (final profile in _snapshot.providerProfiles) profile.id,
    ];
    _providerService.syncPoolLimits(limit, activeProfileIds);
  }

  AppLlmRequestPool _requestPoolForProviderProfile(String? providerProfileId) {
    if (providerProfileId == null ||
        providerProfileId.isEmpty ||
        providerProfileId == 'primary') {
      return _requestPool;
    }
    return _providerService.requestPoolForProfile(providerProfileId);
  }

  Future<AppSettingsSaveResult> setThemePreference(
    AppThemePreference themePreference,
  ) async {
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(themePreference: themePreference);
    notifyListeners();
    return _persist();
  }

  Future<AppSettingsSaveResult> setPromptLanguage(
    PromptLanguage language,
  ) async {
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(promptLanguage: language);
    notifyListeners();
    return _persist();
  }

  // upsertProviderProfile, addProviderFromCatalog, setPrimaryProviderProfile,
  // removeProviderProfile, upsertRequestProviderRoute,
  // applySingleChapterGenerationProviderPreset, removeRequestProviderRoute
  // 均由 AppSettingsProviderManagement mixin 提供。

  Future<void> _restore() async {
    final restored = await _storage.load();
    if (restored == null) {
      return;
    }

    final hasLoadIssue =
        _storage.lastLoadIssue != AppSettingsPersistenceIssue.none;
    if (!_hasLocalMutations) {
      _snapshot = AppSettingsSnapshot.fromJson(restored);
      _syncRequestPoolLimits();
    }

    if (hasLoadIssue) {
      final loadFeedback = feedbackForLoadIssue(
        _storage.lastLoadIssue,
        _storage.lastLoadDetail,
      );
      _activePersistenceIssue = loadFeedback.issue;
      _activePersistenceDetail = loadFeedback.detail;
      _activePersistenceSummary = loadFeedback.summary;
      _feedback = loadFeedback.feedback;
    } else if (!_hasLocalMutations) {
      _activePersistenceIssue = AppSettingsPersistenceIssue.none;
      _activePersistenceSummary = null;
      _activePersistenceDetail = null;
      _hasLocalMutations = false;
    }
    notifyListeners();
  }

  Future<AppSettingsSaveResult> _persist() async {
    final result = await _storage.save(_snapshot.toJson());
    if (result.issue == AppSettingsPersistenceIssue.none) {
      _hasLocalMutations = false;
    }
    return result;
  }

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
          message: '本地配置文件已更新。',
          tone: AppSettingsFeedbackTone.success,
        );
      } else {
        final saveFeedback = feedbackForSaveResult(result);
        _activePersistenceDetail = saveFeedback.detail;
        _activePersistenceSummary = saveFeedback.summary;
        _feedback = saveFeedback.feedback;
      }
      _scheduleSettingsLog(
        action: actionForResult(
          prefix: 'settings.secure_store_retry',
          issue: result.issue,
        ),
        status: statusForResult(result.issue),
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
        _snapshot = _hasLocalMutations
            ? _snapshot.copyWith(
                apiKey: restoredSnapshot.apiKey,
                hasApiKey: restoredSnapshot.hasApiKey,
              )
            : restoredSnapshot;
        _syncRequestPoolLimits();
      }
      _activePersistenceSummary = null;
      _activePersistenceDetail = null;
      _feedback = const AppSettingsFeedback(
        title: '配置已重新加载',
        message: '本地配置文件已重新读取，当前配置已同步。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      final loadFeedback = feedbackForLoadIssue(
        _activePersistenceIssue,
        _storage.lastLoadDetail,
      );
      _activePersistenceDetail = loadFeedback.detail;
      _activePersistenceSummary = loadFeedback.summary;
      _feedback = loadFeedback.feedback;
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
        message: '本地配置文件已更新。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      final saveFeedback = feedbackForSaveResult(result);
      _activePersistenceDetail = saveFeedback.detail;
      _activePersistenceSummary = saveFeedback.summary;
      _feedback = saveFeedback.feedback;
    }
    _scheduleSettingsLog(
      action: actionForResult(
        prefix: 'settings.secure_store_retry',
        issue: result.issue,
      ),
      status: statusForResult(result.issue),
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
      'apiKeyPreview': apiKeyPreview(apiKey),
    };
  }

  void _clearPersistenceIssueState() {
    _activePersistenceIssue = AppSettingsPersistenceIssue.none;
    _activePersistenceSummary = null;
    _activePersistenceDetail = null;
  }

  /// 解析请求路由，返回用于 AI 请求的配置。
  /// 委托给 LlmProviderService.resolveRoute。
  ResolvedRequestSettings _resolveRequestSettings(String traceName) {
    final route = _providerService.resolveRoute(
      traceName,
      _snapshot.requestProviderRoutes,
      _snapshot.providerProfiles,
      isLocalCompatibleEndpoint: _aiRequestService.isLocalCompatibleEndpoint,
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
      providerName: _snapshot.providerName,
      baseUrl: _snapshot.baseUrl,
      model: _snapshot.model,
      apiKey: _snapshot.apiKey,
    );
  }
}
