import '../domain/character_cognition_models.dart';
import '../domain/pipeline_models.dart';
import '../domain/memory_models.dart';
import '../domain/roleplay_models.dart';
import 'story_memory_retriever.dart';

/// A named retrieval tool that produces [ContextCapsule] objects for agents.
class KnowledgeTool {
  const KnowledgeTool({
    required this.name,
    required this.description,
    required this.retrieve,
  });

  final String name;
  final String description;
  final Future<ContextCapsule> Function(Map<String, Object?> parameters)
      retrieve;
}

/// Registry of named retrieval tools available to role agents.
///
/// Agents request tools by name. The registry resolves the request,
/// executes the retrieval, and returns a compressed capsule.
class KnowledgeToolRegistry {
  KnowledgeToolRegistry({List<KnowledgeTool>? tools})
      : _tools = {for (final t in tools ?? const []) t.name: t};

  final Map<String, KnowledgeTool> _tools;

  /// Names of all registered tools.
  List<String> get availableTools => List<String>.unmodifiable(_tools.keys);

  /// Whether a tool with the given name is registered.
  bool hasTool(String name) => _tools.containsKey(name);

  /// Registers a new tool. Overwrites if name already exists.
  void register(KnowledgeTool tool) {
    _tools[tool.name] = tool;
  }

  /// Calls a tool by name with the given parameters.
  ///
  /// Throws [StateError] if the tool is not registered.
  Future<ContextCapsule> call(
    String name,
    Map<String, Object?> parameters,
  ) async {
    final tool = _tools[name];
    if (tool == null) {
      throw StateError('Knowledge tool not found: $name');
    }
    return tool.retrieve(parameters);
  }

  /// Lists tool names and descriptions for prompt injection.
  String toolListSummary() {
    if (_tools.isEmpty) return '';
    return _tools.entries
        .map((e) => '- ${e.key}: ${e.value.description}')
        .join('\n');
  }

  /// Builds a [RolePromptPacket] from a cognition snapshot and its atoms.
  ///
  /// The packet is positive-only (what the character knows/perceives), small
  /// (each field capped at ~200 chars), and deterministic (same input always
  /// produces the same output).
  static RolePromptPacket buildPacket({
    required CharacterCognitionSnapshot snapshot,
    required List<CharacterCognitionAtom> atoms,
  }) {
    // Filter to only this character's atoms, then group by kind.
    final mine = CharacterCognitionAtom.forCharacter(
      atoms,
      snapshot.characterId,
    );
    final grouped = CharacterCognitionAtom.groupByKind(mine);

    final currentUnderstanding = _joinField([
      ...grouped[CognitionKind.perceivedEvent]!,
      ...grouped[CognitionKind.reportedEvent]!,
    ]);

    final currentFeeling = _joinField(grouped[CognitionKind.selfState]!);

    final viewOfOthers = _joinField([
      ...grouped[CognitionKind.acceptedBelief]!,
      ...grouped[CognitionKind.inference]!,
    ]);

    final surfaceBehavior = _joinField(grouped[CognitionKind.presentation]!);

    final unspokenThoughts = _joinField([
      ...grouped[CognitionKind.suspicion]!,
      ...grouped[CognitionKind.uncertainty]!,
    ]);

    final actionIntent = _joinField(grouped[CognitionKind.goal]!);

    final dialogueTendency = _joinField(grouped[CognitionKind.intent]!);

    final sourceAtomIds = List<String>.unmodifiable(
      [for (final atom in mine) atom.id],
    );

    return RolePromptPacket(
      characterId: snapshot.characterId,
      characterName: snapshot.name,
      characterRole: snapshot.role,
      currentUnderstanding: currentUnderstanding,
      currentFeeling: currentFeeling,
      viewOfOthers: viewOfOthers,
      surfaceBehavior: surfaceBehavior,
      unspokenThoughts: unspokenThoughts,
      actionIntent: actionIntent,
      dialogueTendency: dialogueTendency,
      sourceAtomIds: sourceAtomIds,
    );
  }

  /// Joins atom contents and truncates to ~200 chars.
  static String _joinField(List<CharacterCognitionAtom> atoms) {
    if (atoms.isEmpty) return '';
    final joined = atoms.map((a) => a.content).join('；');
    return joined.length > 200 ? '${joined.substring(0, 197)}...' : joined;
  }
}

/// Creates memory-backed knowledge tools from a retriever.
///
/// Returns tools for: plot_memory, persona_memory, foreshadowing,
/// state_ledger, thought_memory.
List<KnowledgeTool> createMemoryTools(StoryMemoryRetriever retriever) {
  return [
    KnowledgeTool(
      name: 'get_plot_memory',
      description: 'Retrieves plot-relevant memory: outline beats, accepted states, and causality thoughts.',
      retrieve: (params) => _retrieveToCapsule(
        retriever: retriever,
        queryType: StoryMemoryQueryType.causality,
        params: params,
        fallbackText: 'outline',
      ),
    ),
    KnowledgeTool(
      name: 'get_persona_memory',
      description: 'Retrieves persona and character insights.',
      retrieve: (params) => _retrieveToCapsule(
        retriever: retriever,
        queryType: StoryMemoryQueryType.persona,
        params: params,
        fallbackText: 'character',
      ),
    ),
    KnowledgeTool(
      name: 'get_foreshadowing_memory',
      description: 'Retrieves foreshadowing hints and unresolved plot threads.',
      retrieve: (params) => _retrieveToCapsule(
        retriever: retriever,
        queryType: StoryMemoryQueryType.foreshadowing,
        params: params,
        fallbackText: 'foreshadow',
      ),
    ),
    KnowledgeTool(
      name: 'get_state_ledger',
      description: 'Retrieves accepted scene states and current world facts.',
      retrieve: (params) => _retrieveToCapsule(
        retriever: retriever,
        queryType: StoryMemoryQueryType.concreteFact,
        params: params,
        fallbackText: 'state',
      ),
    ),
    KnowledgeTool(
      name: 'get_thought_memory',
      description: 'Retrieves high-level thought atoms from previous scenes.',
      retrieve: (params) => _retrieveToCapsule(
        retriever: retriever,
        queryType: StoryMemoryQueryType.sceneContinuity,
        params: params,
        fallbackText: 'thought',
      ),
    ),
  ];
}

Future<ContextCapsule> _retrieveToCapsule({
  required StoryMemoryRetriever retriever,
  required StoryMemoryQueryType queryType,
  required Map<String, Object?> params,
  required String fallbackText,
}) async {
  final projectId = params['projectId']?.toString() ?? '';
  final text = params['query']?.toString() ?? fallbackText;
  final tags = params['tags'] is List
      ? List<String>.from(params['tags'] as List)
      : <String>[];
  final viewerId = params['viewerId']?.toString();

  final query = StoryMemoryQuery(
    projectId: projectId,
    queryType: queryType,
    text: text,
    tags: tags,
    viewerId: viewerId,
  );

  final pack = await retriever.retrieve(query);

  final salientFacts = pack.hits
      .take(5)
      .map((h) => h.chunk.content.length > 100
          ? '${h.chunk.content.substring(0, 97)}...'
          : h.chunk.content)
      .toList();

  final sourceRefIds = <String>[
    for (final hit in pack.hits) ...hit.chunk.rootSourceIds,
  ];

  return ContextCapsule(
    id: '${queryType.name}_${DateTime.now().millisecondsSinceEpoch}',
    sourceTool: 'memory_$queryType',
    summary: pack.summary,
    charBudget: 500,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
    metadata: {
      'salientFacts': salientFacts,
      'uncertainties': [
        if (pack.deferredHitCount > 0)
          '${pack.deferredHitCount} deferred hits',
      ],
      'sourceRefIds': sourceRefIds,
      'visibilityScopes': viewerId != null ? [viewerId] : <String>[],
      'hitCount': pack.hits.length,
      'isThought': pack.hits.any((h) => h.isThought),
    },
  );
}
