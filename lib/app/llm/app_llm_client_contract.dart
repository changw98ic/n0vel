import 'app_llm_client_types.dart';

/// LLM 客户端的契约接口。
///
/// 所有 LLM 提供者实现必须满足此接口。
/// 使用 [abstract interface class] 确保纯接口语义——
/// 不允许携带方法实现，消费方必须通过 [implements] 而非 [extends] 使用。
abstract interface class AppLlmClient {
  /// 向 LLM 发送聊天补全请求。
  Future<AppLlmChatResult> chat(AppLlmChatRequest request);

  /// 向 LLM 发送流式聊天补全请求。
  Stream<String> chatStream(AppLlmChatRequest request);
}
