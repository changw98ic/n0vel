import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import 'ai_request_service.dart';
import 'app_settings_storage.dart';
import 'app_settings_store_feedback.dart';
import 'app_settings_store_logging.dart';
import 'app_settings_store_utils.dart';
import 'app_settings_store_validation.dart';
import 'app_store_listenable.dart';
import 'llm_provider_service.dart';
import 'settings/settings_models.dart';

/// Settings store 保存与连接测试操作。
///
/// 从 AppSettingsStore 中提取，通过 mixin 组合保持 store 公开 API 不变。
/// 依赖 AppSettingsStoreLogging mixin 提供日志辅助。
mixin AppSettingsStoreSave on AppStoreListenable, AppSettingsStoreLogging {
  // --- Store 字段访问器（由 AppSettingsStore 实现） ---

  AppSettingsSnapshot get saveSnapshot;
  set saveSnapshot(AppSettingsSnapshot value);
  bool get saveHasLocalMutations;
  set saveHasLocalMutations(bool value);
  AppSettingsFeedback get saveFeedback;
  set saveFeedback(AppSettingsFeedback value);
  AppSettingsConnectionTestState get saveConnectionTestState;
  set saveConnectionTestState(AppSettingsConnectionTestState value);
  AiRequestService get saveAiRequestService;
  LlmProviderService get saveProviderService;
  AppEventBus? get saveEventBus;

  Future<AppSettingsSaveResult> savePersist();
  void saveSyncRequestPoolLimits();

  bool saveIsSupportedModel(String model);

  // --- 保存方法 ---

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
    final normalizedModel = saveAiRequestService.normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    saveHasLocalMutations = true;
    final nextProfiles = saveProviderService.syncPrimaryProfile(
      providerProfiles ?? saveSnapshot.providerProfiles,
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
    );
    saveSnapshot = saveSnapshot.copyWith(
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
      maxTokens: AppLlmChatRequest.normalizeMaxTokens(
        maxTokens ?? saveSnapshot.maxTokens,
      ),
      hasApiKey: apiKey.isNotEmpty,
      providerProfiles: nextProfiles,
      requestProviderRoutes: requestProviderRoutes,
    );
    saveSyncRequestPoolLimits();
    final persistResult = await savePersist();
    if (notify) {
      notifyListeners();
    }
    if (persistResult.issue == AppSettingsPersistenceIssue.none) {
      saveEventBus?.publish(
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
    final normalizedModel = saveAiRequestService.normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    final correlationId =
        settingsLogEventLog.newCorrelationId('settings-save');
    final metadata = settingsMetadata(
      providerName: providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
    );
    scheduleSettingsLog(
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
          maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
      forConnectionTest: false,
      isLocalCompatibleEndpoint:
          saveAiRequestService.isLocalCompatibleEndpoint,
      isSupportedModel: saveIsSupportedModel,
    );
    if (validationFeedback != null) {
      settingsLogActivePersistenceIssue = AppSettingsPersistenceIssue.none;
      settingsLogActivePersistenceSummary = null;
      settingsLogActivePersistenceDetail = null;
      saveFeedback = validationFeedback;
      scheduleSettingsLog(
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
              maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
          fallbackMaxConcurrentRequests: saveSnapshot.maxConcurrentRequests,
          isLocalCompatibleEndpoint:
              saveAiRequestService.isLocalCompatibleEndpoint,
          isSupportedModel: saveIsSupportedModel,
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
          maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
      maxTokens: AppLlmChatRequest.normalizeMaxTokens(
        maxTokens ?? saveSnapshot.maxTokens,
      ),
      notify: false,
    );
    final saveFeedbackResult = feedbackForSaveResult(persistResult);
    settingsLogActivePersistenceIssue = saveFeedbackResult.issue;
    settingsLogActivePersistenceDetail = saveFeedbackResult.detail;
    settingsLogActivePersistenceSummary = saveFeedbackResult.summary;
    saveFeedback = saveFeedbackResult.feedback;
    scheduleSettingsLog(
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

  // --- 连接测试 ---

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
    final normalizedModel = saveAiRequestService.normalizeRequestedModel(model);
    final resolvedTimeout =
        timeout ?? AppLlmTimeoutConfig.uniform(timeoutMs ?? 30000);
    final correlationId =
        settingsLogEventLog.newCorrelationId('settings-connection');
    final metadata = settingsMetadata(
      providerName: saveSnapshot.providerName,
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
    );
    scheduleSettingsLog(
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
          maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
      forConnectionTest: true,
      isLocalCompatibleEndpoint:
          saveAiRequestService.isLocalCompatibleEndpoint,
      isSupportedModel: saveIsSupportedModel,
    );
    if (validationFeedback != null) {
      clearPersistenceIssueState();
      saveFeedback = validationFeedback;
      saveConnectionTestState = AppSettingsConnectionTestState(
        status: AppSettingsConnectionTestStatus.error,
        outcome: validationOutcomeFor(
          baseUrl: baseUrl,
          model: normalizedModel,
          apiKey: apiKey,
          maxConcurrentRequests:
              maxConcurrentRequests ?? saveSnapshot.maxConcurrentRequests,
          fallbackMaxConcurrentRequests: saveSnapshot.maxConcurrentRequests,
          isLocalCompatibleEndpoint:
              saveAiRequestService.isLocalCompatibleEndpoint,
          isSupportedModel: saveIsSupportedModel,
        ),
        title: validationFeedback.title,
        message: validationFeedback.message,
      );
      scheduleSettingsLog(
        action: 'settings.connection_test.failed',
        status: AppEventLogStatus.failed,
        message: 'Settings connection test blocked by validation.',
        correlationId: correlationId,
        level: AppEventLogLevel.warn,
        errorCode: saveConnectionTestState.outcome.name,
        metadata: metadata,
      );
      notifyListeners();
      return;
    }

    clearPersistenceIssueState();
    saveConnectionTestState = const AppSettingsConnectionTestState(
      status: AppSettingsConnectionTestStatus.running,
      outcome: AppSettingsConnectionTestOutcome.none,
      title: '正在测试连接',
      message: '发送最小化请求并等待模型返回。',
    );
    saveFeedback = const AppSettingsFeedback(
      title: '正在测试连接',
      message: '发送最小化请求并等待模型返回。',
      tone: AppSettingsFeedbackTone.info,
    );
    notifyListeners();

    final result = await saveAiRequestService.testConnection(
      baseUrl: baseUrl,
      model: normalizedModel,
      apiKey: apiKey,
      timeout: resolvedTimeout,
      maxTokens: maxTokens ?? saveSnapshot.maxTokens,
      providerName: providerName ?? saveSnapshot.providerName,
    );
    saveConnectionTestState =
        saveAiRequestService.connectionStateFromResult(
      baseUrl: baseUrl,
      model: normalizedModel,
      result: result,
    );
    saveFeedback = AppSettingsFeedback(
      title: saveConnectionTestState.title,
      message: saveConnectionTestState.message,
      tone: saveConnectionTestState.status ==
              AppSettingsConnectionTestStatus.success
          ? AppSettingsFeedbackTone.success
          : AppSettingsFeedbackTone.error,
    );
    scheduleSettingsLog(
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
}
