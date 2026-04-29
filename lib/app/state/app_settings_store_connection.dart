import '../llm/app_llm_client.dart';
import 'app_settings_models.dart';

AppSettingsConnectionTestState connectionStateFromChatResult({
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
        title: '连接测试失败：请求受限',
        message: result.detail?.trim().isNotEmpty == true
            ? result.detail
            : '模型服务暂时限制请求，请稍后重试或降低请求频率。',
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
