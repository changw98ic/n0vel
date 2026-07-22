import '../../../../app/llm/app_llm_client_types.dart';
import '../../../../app/llm/app_llm_prompt_release.dart';
import '../../../../app/llm/app_llm_prompt_invocation.dart';
import '../../../../app/llm/app_llm_prompt_version.dart';
import '../../../../domain/prompt_language.dart';

/// Abstraction for LLM settings needed by the story generation pipeline.
///
/// Decouples the story_generation data layer from the concrete
/// [AppSettingsStore], depending only on the narrow surface it actually uses:
/// prompt language preference and the ability to make AI completion requests.
abstract interface class StoryGenerationSettingsContract {
  /// Current prompt language preference (Chinese vs English).
  PromptLanguage get promptLanguage;

  /// Sends a chat completion request to the configured LLM provider.
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  });
}

/// Optional, non-secret snapshot of the model-routing contract used by story
/// generation. Experiment evidence uses this to bind the configured primary
/// route and failover chain without serializing credentials.
///
/// Test doubles are intentionally not forced to implement this interface.
/// A no-redraw experiment, however, fails before provider dispatch when its
/// settings implementation cannot supply a route identity.
abstract interface class StoryGenerationModelRouteIdentityProvider {
  Object? storyGenerationModelRouteIdentity({required String traceName});
}

/// Optional settings boundary used by no-redraw experiments.
///
/// The separate method keeps the normal product contract unchanged while
/// making the stronger transport guarantee explicit and impossible to enable
/// accidentally through trace metadata.
abstract interface class StoryGenerationSinglePhysicalDispatchSettingsContract {
  /// Freezes the credential-bearing route before durable intent is written.
  /// Callers can only observe its credential-free identity and must pass the
  /// same opaque lease to the physical dispatch.
  StoryGenerationSinglePhysicalDispatchRouteLease?
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  });

  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  });
}

abstract interface class StoryGenerationSinglePhysicalDispatchRouteLease {
  Object get credentialFreeIdentity;
}
