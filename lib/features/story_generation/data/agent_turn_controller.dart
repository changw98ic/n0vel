import 'context_capsule_compressor.dart';
import '../domain/pipeline_models.dart';
import '../domain/memory_models.dart';
import 'story_memory_retriever.dart';

/// Describes the outcome of a single agent turn with retrieval context.
class AgentTurnResult {
  const AgentTurnResult({
    required this.text,
    required this.capsules,
    required this.retrievalRounds,
    this.evidencePacks = const [],
  });

  final String text;
  final List<ContextCapsule> capsules;
  final int retrievalRounds;

  /// Evidence-backed retrieval packs from memory tools.
  final List<StoryRetrievalPack> evidencePacks;
}

/// General-purpose agent turn controller with retrieval loop support.
///
/// Manages controller-driven retrieval cycles where an agent can request
/// additional context via tool intents. Each retrieval result is compressed
/// into a [ContextCapsule] and re-injected into subsequent turns.
///
/// Supports both legacy retrieval and memory tool requests that produce
/// evidence-backed capsules with source traces.
class AgentTurnController {
  AgentTurnController({
    ContextCapsuleCompressor? capsuleCompressor,
    this.maxRetrievalRounds = 2,
    this.capsuleCharBudget = 500,
    this.memoryRetriever,
  }) : _compressor = capsuleCompressor ?? ContextCapsuleCompressor();

  final ContextCapsuleCompressor _compressor;
  final int maxRetrievalRounds;
  final int capsuleCharBudget;

  /// Optional memory retriever for evidence-backed capsule generation.
  final StoryMemoryRetriever? memoryRetriever;

  /// Runs the agent turn loop.
  ///
  /// [agentFn] produces agent output given current capsules.
  /// [intentExtractor] extracts a retrieval intent from agent text, or null.
  /// [retrievalFn] executes retrieval for a given intent and returns raw content.
  Future<AgentTurnResult> run({
    required Future<String> Function(List<ContextCapsule> capsules) agentFn,
    required RetrievalIntent? Function(String text) intentExtractor,
    required Future<String> Function(RetrievalIntent intent) retrievalFn,
  }) async {
    final capsules = <ContextCapsule>[];
    final evidencePacks = <StoryRetrievalPack>[];
    var rounds = 0;

    while (true) {
      final text = await agentFn(capsules);

      final intent = intentExtractor(text);
      if (intent != null &&
          intent.isToolAllowed &&
          rounds < maxRetrievalRounds) {
        // Try memory retrieval first if it's a memory tool
        if (memoryRetriever != null && _isMemoryTool(intent.toolName)) {
          final pack = await _retrieveFromMemory(intent);
          if (pack != null) {
            evidencePacks.add(pack);
            final budget = PromptBudget(maxChars: capsuleCharBudget);
            final capsule = _compressor.compress(
              sourceTool: intent.toolName,
              rawContent: pack.summary,
              budget: budget,
            );
            if (capsule != null) {
              capsules.add(capsule);
            }
            rounds++;
            continue;
          }
        }

        final rawContent = await retrievalFn(intent);
        final budget = PromptBudget(maxChars: capsuleCharBudget);
        final capsule = _compressor.compress(
          sourceTool: intent.toolName,
          rawContent: rawContent,
          budget: budget,
        );
        if (capsule != null) {
          capsules.add(capsule);
        }
        rounds++;
        continue;
      }

      return AgentTurnResult(
        text: text,
        capsules: capsules,
        retrievalRounds: rounds,
        evidencePacks: evidencePacks,
      );
    }
  }

  bool _isMemoryTool(String toolName) {
    return toolName.startsWith('get_') && toolName.endsWith('_memory') ||
        toolName == 'get_state_ledger';
  }

  Future<StoryRetrievalPack?> _retrieveFromMemory(
    RetrievalIntent intent,
  ) async {
    if (memoryRetriever == null) return null;

    final queryType = _toolNameToQueryType(intent.toolName);
    final query = StoryMemoryQuery(
      projectId: intent.characterId,
      queryType: queryType,
      text: intent.reasoning.isNotEmpty ? intent.reasoning : intent.toolName,
      tags: [],
      viewerId: intent.characterId,
    );

    return memoryRetriever!.retrieve(query);
  }

  StoryMemoryQueryType _toolNameToQueryType(String toolName) {
    return switch (toolName) {
      'get_plot_memory' => StoryMemoryQueryType.causality,
      'get_persona_memory' => StoryMemoryQueryType.persona,
      'get_foreshadowing_memory' => StoryMemoryQueryType.foreshadowing,
      'get_state_ledger' => StoryMemoryQueryType.concreteFact,
      'get_thought_memory' => StoryMemoryQueryType.sceneContinuity,
      _ => StoryMemoryQueryType.concreteFact,
    };
  }
}
