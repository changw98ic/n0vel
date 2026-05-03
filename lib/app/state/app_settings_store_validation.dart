import 'app_settings_models.dart';

AppSettingsFeedback? validateInputs({
  required String baseUrl,
  required String model,
  required String apiKey,
  required int timeoutMs,
  required int maxConcurrentRequests,
  required bool forConnectionTest,
  required bool Function(String) isSupportedModel,
}) {
  if (timeoutMs <= 0) {
    return const AppSettingsFeedback(
      title: '超时时间必须大于 0',
      message: '请填写有效的 timeout_ms，再继续保存或测试连接。',
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
  final allowsEmptyApiKey = isLocalCompatibleEndpoint(baseUrl);
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
      message:
          '请改用受支持模型：gpt-4.1-mini、gpt-5.4-mini、kimi-k2.6、mimo-v2.5-pro 或 glm-5.1。',
      tone: AppSettingsFeedbackTone.error,
    );
  }

  return null;
}

AppSettingsConnectionTestOutcome validationOutcomeFor({
  required String baseUrl,
  required String model,
  required String apiKey,
  int? maxConcurrentRequests,
  required int fallbackMaxConcurrentRequests,
  required bool Function(String) isSupportedModel,
}) {
  if ((maxConcurrentRequests ?? fallbackMaxConcurrentRequests) <= 0) {
    return AppSettingsConnectionTestOutcome.networkError;
  }
  final allowsEmptyApiKey = isLocalCompatibleEndpoint(baseUrl);
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

bool isLocalCompatibleEndpoint(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || !uri.hasAuthority) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}
