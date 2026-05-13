import '../logging/app_event_log_types.dart';
import 'app_settings_storage.dart';
import 'settings/default_provider_config.dart';

String apiKeyPreview(String apiKey) {
  final trimmed = apiKey.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.length <= 6) {
    return '${trimmed.substring(0, 3)}...';
  }
  return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 2)}';
}

String preview(String text, int maxLength) {
  final normalized = text.trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }
  if (maxLength <= 3) {
    return normalized.substring(0, maxLength);
  }
  return '${normalized.substring(0, maxLength - 3)}...';
}

String actionForResult({
  required String prefix,
  required AppSettingsPersistenceIssue issue,
}) {
  return issue == AppSettingsPersistenceIssue.none
      ? '$prefix.succeeded'
      : '$prefix.warning';
}

AppEventLogStatus statusForResult(AppSettingsPersistenceIssue issue) {
  return issue == AppSettingsPersistenceIssue.none
      ? AppEventLogStatus.succeeded
      : AppEventLogStatus.warning;
}

String withDetail(String baseMessage, String? detail) {
  if (detail == null || detail.trim().isEmpty) {
    return baseMessage;
  }
  return '$baseMessage\n\n诊断：$detail';
}

String issueCode(AppSettingsPersistenceIssue issue) {
  switch (issue) {
    case AppSettingsPersistenceIssue.none:
      return 'none';
    case AppSettingsPersistenceIssue.fileReadFailed:
      return 'settings_file_read_failed';
    case AppSettingsPersistenceIssue.fileWriteFailed:
      return 'settings_file_write_failed';
  }
}

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

bool isSupportedModelFromUtils(String model) {
  const supportedModels = {
    'gpt-4.1-mini',
    'gpt-5.4',
    'gpt-5.4-mini',
    'kimi-k2.6',
    'deepseek-chat',
    'deepseek-reasoner',
    'mimo-v2.5-pro',
    'mimo-v2.5',
    'mimo-v2-pro',
    'mimo-v2-omni',
    'mimo-v2-flash',
    'glm-5.1',
    'glm-5',
    'glm-5-turbo',
    'glm-4.7',
    'glm-4.7-flash',
    'glm-4.6',
    'glm-4.5',
    'glm-4.5-air',
    'glm-4.5-flash',
    'glm-4-plus',
    'glm-4-flash-250414',
  };
  const supportedModelPrefixes = {
    'glm-',
    'qwen',
    'qwq',
    'doubao-',
    'ark-code-',
    'minimax-',
    'codex-minimax-',
    'hunyuan-',
    'longcat-',
    'xiaomi/mimo-',
  };
  final normalized = normalizeRequestedModel(model).toLowerCase();
  return supportedModels.contains(normalized) ||
      appLlmProviderCatalogEntries.any(
        (entry) =>
            normalizeRequestedModel(entry.model).toLowerCase() == normalized,
      ) ||
      supportedModelPrefixes.any(normalized.startsWith) ||
      normalized.contains('missing') ||
      normalized.contains('not-found') ||
      normalized.contains('404');
}
