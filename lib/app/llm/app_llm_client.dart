export 'app_llm_circuit_breaker.dart';
export 'app_llm_client_contract.dart';
export 'app_llm_client_gateway.dart';
export 'app_llm_client_types.dart';
export 'app_llm_call_trace.dart';
export 'app_llm_failover_chain.dart';
export 'app_llm_logging_middleware.dart';
export 'app_llm_output_schema.dart';
export 'app_llm_prompt_version.dart';
export 'app_llm_provider_adapters.dart';
export 'app_llm_provider_outcome_seal.dart';
export 'app_llm_response_cache.dart';
export 'app_llm_response_decoding.dart';
export 'app_llm_token_usage.dart';
export 'app_llm_trace_record.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';

import 'app_llm_canonical_hash.dart';
import 'app_llm_client_stub.dart'
    if (dart.library.io) 'app_llm_client_io.dart'
    as platform;
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';
import 'app_llm_client_gateway.dart';
import 'app_llm_logging_middleware.dart';
import 'app_llm_provider_outcome_seal.dart';
import 'app_llm_response_cache.dart';

AppLlmClient createDefaultAppLlmClient() => platform.createAppLlmClient();

AppLlmClient createCachedAppLlmClient() =>
    AppLlmResponseCache(delegate: platform.createAppLlmClient());

AppLlmClient createResilientAppLlmClient({AppLlmClient? delegate}) =>
    AppLlmClientGateway(delegate: delegate ?? createCachedAppLlmClient());

AppLlmClient createLoggedAppLlmClient({AppEventLog? eventLog}) =>
    AppLlmLoggingMiddleware(
      delegate: createResilientAppLlmClient(),
      eventLog: eventLog,
    );

/// Runtime-only admission that owns one direct platform formal dispatch.
///
/// The frozen request and its transport permit never enter the injected
/// [AppLlmClient] decorator graph. That graph remains available for adaptive
/// product traffic, but cannot retain a raw delegate and schedule a delayed
/// formal-to-adaptive downgrade after this admission returns.
@pragma('vm:isolate-unsendable')
final class AppLlmFormalDispatchAdmission {
  AppLlmFormalDispatchAdmission._({required Object platformAdmission})
    : _platformAdmission = platformAdmission;

  final Object _platformAdmission;
  bool _dispatchClaimed = false;
  bool _closed = false;

  /// Consumes this admission and sends the exact frozen request through the
  /// private platform transport. Reuse and dispatch-after-close fail closed.
  Future<AppLlmChatResult> dispatch() {
    if (_dispatchClaimed || _closed) {
      return Future<AppLlmChatResult>.value(
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'formal platform dispatch admission is closed or consumed',
        ),
      );
    }
    // Burn before invoking platform code so a synchronous throw cannot make
    // this capability reusable.
    _dispatchClaimed = true;
    return platform.dispatchPlatformFormalAdmission(_platformAdmission);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    platform.closePlatformFormalAdmission(_platformAdmission);
  }
}

/// Asks the platform transport to consume independent journal and central
/// authorities and create a private, one-shot direct dispatch admission.
AppLlmFormalDispatchAdmission admitAppLlmFormalDispatch({
  required AppLlmChatRequest request,
  required Object committedIntentAuthority,
  required Map<String, Object?> formalDispatchIntent,
  required Object formalDispatchRouteIdentity,
  required Object centralDispatchAuthority,
}) {
  final platformAdmission = platform.attachPlatformFormalDispatchPermit(
    request: request,
    committedIntentAuthority: committedIntentAuthority,
    formalDispatchIntent: formalDispatchIntent,
    formalDispatchRouteIdentity: formalDispatchRouteIdentity,
    centralDispatchAuthority: centralDispatchAuthority,
  );
  return AppLlmFormalDispatchAdmission._(platformAdmission: platformAdmission);
}

/// Whether this runtime has the private transport needed for a formal direct
/// dispatch. This deliberately does not inspect an injected decorator graph.
bool appLlmPlatformSupportsFormalDispatch() =>
    platform.supportsPlatformFormalDispatch();

/// An opaque, one-shot in-memory proof that the platform IO client observed
/// exactly the formal provider dispatch described by [expectation].
///
/// Its constructor is deliberately private and it never has a JSON form.
/// Public receipt-shaped maps and `...Verified` booleans therefore cannot be
/// promoted into formal provenance after a process restart.
@pragma('vm:isolate-unsendable')
final class AppLlmFormalDispatchWitness {
  AppLlmFormalDispatchWitness._({
    required String dispatchEvidenceNonce,
    required String providerBoundaryReceiptDigest,
    required String providerOutcomeSealDigest,
  }) : _dispatchEvidenceNonce = dispatchEvidenceNonce,
       _providerBoundaryReceiptDigest = providerBoundaryReceiptDigest,
       _providerOutcomeSealDigest = providerOutcomeSealDigest;

  final String _dispatchEvidenceNonce;
  final String _providerBoundaryReceiptDigest;
  final String _providerOutcomeSealDigest;
  bool _consumed = false;

  /// Consumes this witness for one durable attempt record. Reuse, a different
  /// logical id, or a receipt-map substitution fails closed.
  bool consumeForStoryGenerationAttempt({
    required String logicalAttemptId,
    required Map<String, Object?> providerBoundaryReceipt,
    required Map<String, Object?> providerOutcomeSeal,
  }) {
    if (_consumed) return false;
    // Any presentation burns the witness, including a mismatch. This prevents
    // callers from using it as an oracle and retrying with altered evidence.
    _consumed = true;
    if (logicalAttemptId != _dispatchEvidenceNonce) return false;
    final observedReceipt = AppLlmCanonicalHash.domainHash(
      'story-generation-provider-boundary-receipt-v1',
      providerBoundaryReceipt,
    );
    final observedOutcome = appLlmProviderOutcomeSealDigest(
      providerOutcomeSeal,
    );
    return observedReceipt == _providerBoundaryReceiptDigest &&
        observedOutcome == _providerOutcomeSealDigest;
  }
}

/// Issues a non-serializable provenance witness only after the platform's
/// private IO receipt implementation has verified every formal request field.
/// An arbitrary implementation of the public receipt interface cannot pass
/// [verifyAppLlmProviderBoundaryReceipt].
AppLlmFormalDispatchWitness? issueAppLlmFormalDispatchWitness({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmProviderBoundaryExpectation expectation,
}) {
  final providerOutcomeSealDigest = platform
      .consumeTrustedPlatformProviderOutcomeSealDigest(
        receipt: receipt,
        expectation: expectation,
      );
  if (providerOutcomeSealDigest == null) return null;
  return AppLlmFormalDispatchWitness._(
    dispatchEvidenceNonce: expectation.dispatchEvidenceNonce,
    providerBoundaryReceiptDigest: AppLlmCanonicalHash.domainHash(
      'story-generation-provider-boundary-receipt-v1',
      receipt.toCredentialFreeJson(),
    ),
    providerOutcomeSealDigest: providerOutcomeSealDigest,
  );
}

/// Returns true only for a receipt created by this platform's concrete IO
/// transport for this exact request object.
///
/// Receipt fields are useful for diagnostics but are not an authority: an
/// arbitrary decorator or fake can implement the public interface and copy
/// those fields. Formal no-redraw evidence must pass this opaque platform
/// check before treating a receipt as proof of a physical transport attempt.
bool isTrustedAppLlmProviderBoundaryReceipt({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmChatRequest request,
}) => platform.isTrustedPlatformAppLlmProviderBoundaryReceipt(
  receipt: receipt,
  request: request,
);

/// Verifies an opaque IO receipt against every secret-free semantic field of
/// the formal request. This rejects both public-interface lookalikes and a
/// genuine receipt replayed from another request.
bool verifyAppLlmProviderBoundaryReceipt({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmProviderBoundaryExpectation expectation,
}) => platform.verifyPlatformAppLlmProviderBoundaryReceipt(
  receipt: receipt,
  expectation: expectation,
);
