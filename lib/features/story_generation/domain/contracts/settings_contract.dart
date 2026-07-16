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
