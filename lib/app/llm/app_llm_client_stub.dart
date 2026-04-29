import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

AppLlmClient createAppLlmClient() => _UnsupportedAppLlmClient();

class _UnsupportedAppLlmClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return const AppLlmChatResult.failure(
      failureKind: AppLlmFailureKind.unsupportedPlatform,
      detail: '当前平台不支持真实大模型网络请求。',
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    return Stream<String>.error(
      const AppLlmStreamException(
        failureKind: AppLlmFailureKind.unsupportedPlatform,
        detail: '当前平台不支持真实大模型网络请求。',
      ),
    );
  }
}
