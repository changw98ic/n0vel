import '../llm/app_llm_client.dart';
import '../logging/app_event_log.dart';
import 'app_settings_storage.dart';
import 'app_settings_store_feedback.dart';
import 'app_settings_store_logging.dart';
import 'app_settings_store_utils.dart';
import 'app_store_listenable.dart';
import 'settings/settings_models.dart';

export 'app_settings_storage.dart' show AppSettingsSaveResult;

/// Settings store 重试逻辑。
///
/// 从 AppSettingsStore 中提取，通过 mixin 组合保持 store 公开 API 不变。
/// 依赖 AppSettingsStoreLogging mixin 提供日志辅助。
mixin AppSettingsStoreRetry on AppStoreListenable, AppSettingsStoreLogging {
  // --- Store 字段访问器（由 AppSettingsStore 实现） ---

  AppSettingsSnapshot get retrySnapshot;
  set retrySnapshot(AppSettingsSnapshot value);
  bool get retryHasLocalMutations;
  set retryHasLocalMutations(bool value);
  AppSettingsFeedback get retryFeedback;
  set retryFeedback(AppSettingsFeedback value);

  Future<AppSettingsSaveResult> retryPersist();
  void retrySyncRequestPoolLimits();

  // --- 重试方法 ---

  Future<void> retrySecureStoreAccess() async {
    final originalIssue = settingsLogActivePersistenceIssue;
    final correlationId =
        settingsLogEventLog.newCorrelationId('settings-retry');
    scheduleSettingsLog(
      action: 'settings.secure_store_retry.started',
      status: AppEventLogStatus.started,
      message: 'Started secure store retry.',
      correlationId: correlationId,
      metadata: {'issue': originalIssue.name},
    );

    if (originalIssue == AppSettingsPersistenceIssue.fileWriteFailed) {
      final result = await retryPersist();
      settingsLogActivePersistenceIssue = result.issue;
      if (result.issue == AppSettingsPersistenceIssue.none) {
        settingsLogActivePersistenceSummary = null;
        settingsLogActivePersistenceDetail = null;
        retryFeedback = const AppSettingsFeedback(
          title: '配置已重新保存',
          message: '本地配置文件已更新。',
          tone: AppSettingsFeedbackTone.success,
        );
      } else {
        final saveFeedback = feedbackForSaveResult(result);
        settingsLogActivePersistenceDetail = saveFeedback.detail;
        settingsLogActivePersistenceSummary = saveFeedback.summary;
        retryFeedback = saveFeedback.feedback;
      }
      scheduleSettingsLog(
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

    // fileReadFailed 路径：重新加载
    final restored = await retryLoadStorage();
    final loadIssue = retryStorageLastLoadIssue;
    settingsLogActivePersistenceIssue = loadIssue;
    if (loadIssue == AppSettingsPersistenceIssue.none) {
      if (restored != null) {
        final restoredSnapshot = AppSettingsSnapshot.fromJson(restored);
        retrySnapshot = retryHasLocalMutations
            ? retrySnapshot.copyWith(
                apiKey: restoredSnapshot.apiKey,
                hasApiKey: restoredSnapshot.hasApiKey,
              )
            : restoredSnapshot;
        retrySyncRequestPoolLimits();
      }
      settingsLogActivePersistenceSummary = null;
      settingsLogActivePersistenceDetail = null;
      retryFeedback = const AppSettingsFeedback(
        title: '配置已重新加载',
        message: '本地配置文件已重新读取，当前配置已同步。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      final loadFeedback = feedbackForLoadIssue(
        loadIssue,
        retryStorageLastLoadDetail,
      );
      settingsLogActivePersistenceDetail = loadFeedback.detail;
      settingsLogActivePersistenceSummary = loadFeedback.summary;
      retryFeedback = loadFeedback.feedback;
    }
    scheduleSettingsLog(
      action: settingsLogActivePersistenceIssue ==
              AppSettingsPersistenceIssue.none
          ? 'settings.secure_store_retry.succeeded'
          : 'settings.secure_store_retry.warning',
      status: settingsLogActivePersistenceIssue ==
              AppSettingsPersistenceIssue.none
          ? AppEventLogStatus.succeeded
          : AppEventLogStatus.warning,
      message: settingsLogActivePersistenceIssue ==
              AppSettingsPersistenceIssue.none
          ? 'Secure store retry succeeded.'
          : 'Secure store retry completed with read warning.',
      correlationId: correlationId,
      level: settingsLogActivePersistenceIssue ==
              AppSettingsPersistenceIssue.none
          ? AppEventLogLevel.info
          : AppEventLogLevel.warn,
      errorCode: settingsLogActivePersistenceIssue ==
              AppSettingsPersistenceIssue.none
          ? null
          : settingsLogActivePersistenceIssue.name,
      errorDetail: retryStorageLastLoadDetail,
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
    final correlationId =
        settingsLogEventLog.newCorrelationId('settings-retry');
    final metadata = settingsMetadata(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? retrySnapshot.maxConcurrentRequests,
    );
    scheduleSettingsLog(
      action: 'settings.secure_store_retry.started',
      status: AppEventLogStatus.started,
      message: 'Started secure store retry with current settings values.',
      correlationId: correlationId,
      metadata: metadata,
    );
    final result = await retrySave(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? retrySnapshot.maxConcurrentRequests,
      notify: false,
    );
    settingsLogActivePersistenceIssue = result.issue;
    if (result.issue == AppSettingsPersistenceIssue.none) {
      retryFeedback = const AppSettingsFeedback(
        title: '配置已重新保存',
        message: '本地配置文件已更新。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      final saveFeedback = feedbackForSaveResult(result);
      settingsLogActivePersistenceDetail = saveFeedback.detail;
      settingsLogActivePersistenceSummary = saveFeedback.summary;
      retryFeedback = saveFeedback.feedback;
    }
    scheduleSettingsLog(
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

  // --- Storage 访问器（由 AppSettingsStore 实现） ---
  Future<Map<String, Object?>?> retryLoadStorage();
  AppSettingsPersistenceIssue get retryStorageLastLoadIssue;
  String? get retryStorageLastLoadDetail;

  Future<AppSettingsSaveResult> retrySave({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    required AppLlmTimeoutConfig timeout,
    int? maxConcurrentRequests,
    int? maxTokens,
    bool notify = true,
  });
}
