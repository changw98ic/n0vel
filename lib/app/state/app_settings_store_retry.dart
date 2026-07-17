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

  AppSettingsSnapshot get storeSnapshot;
  set storeSnapshot(AppSettingsSnapshot value);
  bool get storeHasLocalMutations;
  set storeHasLocalMutations(bool value);
  AppSettingsFeedback get storeFeedback;
  set storeFeedback(AppSettingsFeedback value);

  Future<AppSettingsSaveResult> storePersist();
  void storeSyncRequestPoolLimits();

  // --- 重试方法 ---

  Future<void> retrySecureStoreAccess() async {
    final originalIssue = storeActivePersistenceIssue;
    final correlationId = storeEventLog.newCorrelationId('settings-retry');
    scheduleSettingsLog(
      action: 'settings.secure_store_retry.started',
      status: AppEventLogStatus.started,
      message: 'Started secure store retry.',
      correlationId: correlationId,
      metadata: {'issue': originalIssue.name},
    );

    if (originalIssue == AppSettingsPersistenceIssue.fileWriteFailed) {
      final result = await storePersist();
      storeActivePersistenceIssue = result.issue;
      if (result.issue == AppSettingsPersistenceIssue.none) {
        storeActivePersistenceSummary = null;
        storeActivePersistenceDetail = null;
        storeFeedback = const AppSettingsFeedback(
          title: '配置已重新保存',
          message: '本地配置文件已更新。',
          tone: AppSettingsFeedbackTone.success,
        );
      } else {
        final saveFeedback = feedbackForSaveResult(result);
        storeActivePersistenceDetail = saveFeedback.detail;
        storeActivePersistenceSummary = saveFeedback.summary;
        storeFeedback = saveFeedback.feedback;
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
    final restored = await storeStorage.load();
    final loadIssue = storeStorage.lastLoadIssue;
    storeActivePersistenceIssue = loadIssue;
    if (loadIssue == AppSettingsPersistenceIssue.none) {
      if (restored != null) {
        final restoredSnapshot = AppSettingsSnapshot.fromJson(restored);
        storeSnapshot = storeHasLocalMutations
            ? storeSnapshot.copyWith(
                apiKey: restoredSnapshot.apiKey,
                hasApiKey: restoredSnapshot.hasApiKey,
              )
            : restoredSnapshot;
        storeSyncRequestPoolLimits();
      }
      storeActivePersistenceSummary = null;
      storeActivePersistenceDetail = null;
      storeFeedback = const AppSettingsFeedback(
        title: '配置已重新加载',
        message: '本地配置文件已重新读取，当前配置已同步。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      final loadFeedback = feedbackForLoadIssue(
        loadIssue,
        storeStorage.lastLoadDetail,
      );
      storeActivePersistenceDetail = loadFeedback.detail;
      storeActivePersistenceSummary = loadFeedback.summary;
      storeFeedback = loadFeedback.feedback;
    }
    scheduleSettingsLog(
      action: storeActivePersistenceIssue == AppSettingsPersistenceIssue.none
          ? 'settings.secure_store_retry.succeeded'
          : 'settings.secure_store_retry.warning',
      status: storeActivePersistenceIssue == AppSettingsPersistenceIssue.none
          ? AppEventLogStatus.succeeded
          : AppEventLogStatus.warning,
      message: storeActivePersistenceIssue == AppSettingsPersistenceIssue.none
          ? 'Secure store retry succeeded.'
          : 'Secure store retry completed with read warning.',
      correlationId: correlationId,
      level: storeActivePersistenceIssue == AppSettingsPersistenceIssue.none
          ? AppEventLogLevel.info
          : AppEventLogLevel.warn,
      errorCode: storeActivePersistenceIssue == AppSettingsPersistenceIssue.none
          ? null
          : storeActivePersistenceIssue.name,
      errorDetail: storeStorage.lastLoadDetail,
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
    final correlationId = storeEventLog.newCorrelationId('settings-retry');
    final metadata = settingsMetadata(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? storeSnapshot.maxConcurrentRequests,
    );
    scheduleSettingsLog(
      action: 'settings.secure_store_retry.started',
      status: AppEventLogStatus.started,
      message: 'Started secure store retry with current settings values.',
      correlationId: correlationId,
      metadata: metadata,
    );
    final result = await storeSave(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? storeSnapshot.maxConcurrentRequests,
      notify: false,
    );
    storeActivePersistenceIssue = result.issue;
    if (result.issue == AppSettingsPersistenceIssue.none) {
      storeFeedback = const AppSettingsFeedback(
        title: '配置已重新保存',
        message: '本地配置文件已更新。',
        tone: AppSettingsFeedbackTone.success,
      );
    } else {
      final saveFeedback = feedbackForSaveResult(result);
      storeActivePersistenceDetail = saveFeedback.detail;
      storeActivePersistenceSummary = saveFeedback.summary;
      storeFeedback = saveFeedback.feedback;
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
  AppSettingsStorage get storeStorage;

  Future<AppSettingsSaveResult> storeSave({
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
