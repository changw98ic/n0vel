import 'dart:async';

import '../llm/app_llm_client.dart';
import '../logging/app_event_log.dart';
import 'app_settings_storage.dart';
import 'app_settings_store_utils.dart';

/// Settings store 日志与事件记录辅助方法。
///
/// 从 AppSettingsStore 中提取，通过 mixin 组合保持 store 公开 API 不变。
/// 需要 store 提供字段访问器（通过抽象 getter）。
mixin AppSettingsStoreLogging {
  AppEventLog get storeEventLog;
  AppSettingsPersistenceIssue get storeActivePersistenceIssue;
  set storeActivePersistenceIssue(AppSettingsPersistenceIssue value);
  String? get storeActivePersistenceSummary;
  set storeActivePersistenceSummary(String? value);
  String? get storeActivePersistenceDetail;
  set storeActivePersistenceDetail(String? value);

  Future<void> settingsLogEvent({
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    AppEventLogLevel level = AppEventLogLevel.info,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return storeEventLog.log(
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

  void scheduleSettingsLog({
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
      settingsLogEvent(
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

  Map<String, Object?> settingsMetadata({
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

  void clearPersistenceIssueState() {
    storeActivePersistenceIssue = AppSettingsPersistenceIssue.none;
    storeActivePersistenceSummary = null;
    storeActivePersistenceDetail = null;
  }
}
