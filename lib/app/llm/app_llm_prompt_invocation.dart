import 'app_llm_canonical_hash.dart';
import 'app_llm_client_types.dart';
import 'app_llm_prompt_release.dart';
import 'app_llm_prompt_renderer.dart';

/// Evidence that an actual rendered request came from one immutable release.
///
/// The evidence owns immutable snapshots of messages and resolved variables.
/// Its digests are always computed locally; callers cannot supply digest text.
final class PromptInvocationEvidence {
  factory PromptInvocationEvidence({
    required PromptRelease release,
    required PromptReleaseRef promptReleaseRef,
    required Iterable<AppLlmChatMessage> messages,
    required Object? resolvedVariables,
    AppLlmPromptRendererRegistry rendererRegistry =
        AppLlmPromptRendererRegistry.builtIn,
  }) {
    if (!release.hasValidContentHash) {
      throw StateError('PromptRelease content hash is invalid');
    }
    if (promptReleaseRef != release.ref) {
      throw StateError(
        'PromptReleaseRef does not identify the supplied release',
      );
    }
    final actualMessages = List<AppLlmChatMessage>.unmodifiable(
      messages.map(
        (message) =>
            AppLlmChatMessage(role: message.role, content: message.content),
      ),
    );
    if (actualMessages.isEmpty) {
      throw ArgumentError.value(messages, 'messages', 'must not be empty');
    }
    final replay = rendererRegistry.render(
      release: release,
      resolvedVariables: resolvedVariables,
    );
    if (!_sameMessages(replay.messages, actualMessages)) {
      throw StateError(
        'actual dispatch messages differ from schema-valid renderer replay',
      );
    }
    final variables = replay.resolvedVariables;
    return PromptInvocationEvidence._(
      release: release,
      promptReleaseRef: promptReleaseRef,
      messages: actualMessages,
      resolvedVariables: variables,
      renderedMessagesDigest: _messagesDigest(actualMessages),
      resolvedVariablesDigest: AppLlmCanonicalHash.domainHash(
        'resolved-variables-v1',
        variables,
      ),
      rendererContractHash: replay.rendererContractHash,
    );
  }

  const PromptInvocationEvidence._({
    required this.release,
    required this.promptReleaseRef,
    required this.messages,
    required this.resolvedVariables,
    required this.renderedMessagesDigest,
    required this.resolvedVariablesDigest,
    required this.rendererContractHash,
  });

  final PromptRelease release;
  final PromptReleaseRef promptReleaseRef;
  final List<AppLlmChatMessage> messages;
  final Object? resolvedVariables;
  final String renderedMessagesDigest;
  final String resolvedVariablesDigest;
  final String rendererContractHash;

  bool matchesMessages(Iterable<AppLlmChatMessage> actualMessages) =>
      renderedMessagesDigest == _messagesDigest(actualMessages);

  Map<String, Object?> toTraceMetadata() => <String, Object?>{
    'renderedMessagesDigest': renderedMessagesDigest,
    'resolvedVariablesDigest': resolvedVariablesDigest,
    'rendererContractHash': rendererContractHash,
  };
}

bool _sameMessages(
  List<AppLlmChatMessage> expected,
  List<AppLlmChatMessage> actual,
) {
  if (expected.length != actual.length) return false;
  for (var index = 0; index < expected.length; index += 1) {
    if (expected[index].role != actual[index].role ||
        expected[index].content != actual[index].content) {
      return false;
    }
  }
  return true;
}

String _messagesDigest(Iterable<AppLlmChatMessage> messages) =>
    AppLlmCanonicalHash.domainHash('rendered-messages-v1', [
      for (final message in messages) message.toJson(),
    ]);
