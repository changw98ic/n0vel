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

/// Optional runtime declaration for clients that can prove whether the
/// single-physical-dispatch contract is supported on the current platform.
///
/// Adaptive requests retain their historical behavior. Single-dispatch
/// requests fail closed when this marker is absent; production clients,
/// decorators, and intended test doubles must declare and propagate support so
/// an unsupported runtime cannot be hidden behind a wrapper and admitted as a
/// zero-dispatch attempt.
abstract interface class AppLlmSinglePhysicalDispatchCapability {
  bool get supportsSinglePhysicalDispatch;
}

/// Async lifecycle used by owners that must prove no background provider work
/// survives a runtime or experiment arm.
abstract interface class AppLlmPhysicalDispatchLifecycle {
  Future<void> shutdownPhysicalDispatches();
}

Future<void> shutdownAppLlmClientPhysicalDispatches(AppLlmClient client) async {
  if (client is AppLlmPhysicalDispatchLifecycle) {
    await (client as AppLlmPhysicalDispatchLifecycle)
        .shutdownPhysicalDispatches();
  }
}

bool appLlmClientSupportsSinglePhysicalDispatch(AppLlmClient client) {
  if (client is AppLlmSinglePhysicalDispatchCapability) {
    return (client as AppLlmSinglePhysicalDispatchCapability)
        .supportsSinglePhysicalDispatch;
  }
  return false;
}

void validateAppLlmSinglePhysicalDispatchCapability({
  required AppLlmClient client,
  required AppLlmChatRequest request,
}) {
  if (request.physicalDispatchPolicy != AppLlmPhysicalDispatchPolicy.single ||
      appLlmClientSupportsSinglePhysicalDispatch(client)) {
    return;
  }
  throw const AppLlmPhysicalDispatchPreflightException(
    'unsupported-runtime-capability',
    'the active LLM runtime cannot perform a physical provider dispatch',
  );
}
