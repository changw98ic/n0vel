import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

AppLlmClient createAppLlmClient() => _UnsupportedAppLlmClient();

bool supportsPlatformFormalDispatch() => false;

Object attachPlatformFormalDispatchPermit({
  required AppLlmChatRequest request,
  required Object committedIntentAuthority,
  required Map<String, Object?> formalDispatchIntent,
  required Object formalDispatchRouteIdentity,
  required Object centralDispatchAuthority,
}) {
  throw const AppLlmPhysicalDispatchPreflightException(
    'unsupported-runtime-capability',
    'this platform cannot attach a formal physical dispatch permit',
  );
}

Future<AppLlmChatResult> dispatchPlatformFormalAdmission(Object admission) =>
    Future<AppLlmChatResult>.value(
      const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unsupportedPlatform,
        detail: 'this platform cannot dispatch a formal provider request',
      ),
    );

void closePlatformFormalAdmission(Object admission) {}

bool isTrustedPlatformAppLlmProviderBoundaryReceipt({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmChatRequest request,
}) => false;

bool verifyPlatformAppLlmProviderBoundaryReceipt({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmProviderBoundaryExpectation expectation,
}) => false;

String? consumeTrustedPlatformProviderOutcomeSealDigest({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmProviderBoundaryExpectation expectation,
}) => null;

class _UnsupportedAppLlmClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  @override
  bool get supportsSinglePhysicalDispatch => false;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: this,
      request: request,
    );
    return const AppLlmChatResult.failure(
      failureKind: AppLlmFailureKind.unsupportedPlatform,
      detail: '当前平台暂不支持真实模型网络请求。',
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    validateAppLlmSinglePhysicalDispatchRequest(request);
    validateAppLlmSinglePhysicalDispatchCapability(
      client: this,
      request: request,
    );
    return Stream<String>.error(
      const AppLlmStreamException(
        failureKind: AppLlmFailureKind.unsupportedPlatform,
        detail: '当前平台暂不支持真实模型网络请求。',
      ),
    );
  }
}
