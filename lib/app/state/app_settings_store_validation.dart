import '../llm/app_llm_client.dart';
import 'settings/settings_models.dart';

AppSettingsFeedback? validateInputs({
  required String baseUrl,
  required String model,
  required String apiKey,
  required AppLlmTimeoutConfig timeout,
  required int maxConcurrentRequests,
  required bool forConnectionTest,
  required bool Function(String) isLocalCompatibleEndpoint,
  required bool Function(String) isSupportedModel,
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
  final allowsEmptyApiKey = isLocalCompatibleEndpoint(baseUrl);
  if (apiKey.trim().isEmpty && !allowsEmptyApiKey) {
    return AppSettingsFeedback(
      title: forConnectionTest ? '测试连接前请先填写密钥' : '请先填写密钥',
      message: forConnectionTest
          ? '补全密钥后才能发起最小化连接测试。'
          : '接口地址与模型名称可以保留当前值，但保存前必须补全密钥。',
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
      title: '请输入有效的接口地址',
      message: forConnectionTest
          ? '修正接口地址后再测试连接。'
          : '接口地址需要是完整的 http 或 https 地址。',
      tone: AppSettingsFeedbackTone.error,
    );
  }

  if (model.trim().isEmpty) {
    return AppSettingsFeedback(
      title: '请先填写模型名称',
      message: forConnectionTest ? '填写模型名称后再测试连接。' : '保存配置前需要补全模型名称。',
      tone: AppSettingsFeedbackTone.error,
    );
  }

  if (!isSupportedModel(model) && !allowsEmptyApiKey) {
    return const AppSettingsFeedback(
      title: '模型不受支持',
      message:
          '请改用一键供应商目录中的模型，或使用 OpenAI、Kimi、DeepSeek、MiMo、GLM、Qwen、Doubao、MiniMax、Hunyuan、LongCat 系列模型。',
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
  required bool Function(String) isLocalCompatibleEndpoint,
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
