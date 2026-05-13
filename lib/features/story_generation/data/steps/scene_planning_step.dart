import '../character_consistency_verifier.dart';
import '../narrative_arc_prompt_builder.dart';
import '../narrative_arc_models.dart';
import '../scene_context_models.dart' show KnowledgeVisibility;
import '../scene_task_card_builder.dart';
import '../scene_runtime_models.dart' show SceneBrief;
import '../knowledge_visibility_filter.dart';
import '../../domain/story_pipeline_interfaces.dart'
    show
        SceneCastResolverService,
        SceneDirectorService;
import '../step_io.dart';

/// Step 2: Resolves cast, runs consistency checks, composes director context,
/// runs the scene director, and builds the task card.
///
/// Extracted from [ChapterGenerationOrchestrator] lines 271-304 plus helper
/// methods 688-709, 1040-1062.
class ScenePlanningStep {
  ScenePlanningStep({
    required SceneCastResolverService castResolver,
    CharacterConsistencyVerifier? consistencyVerifier,
    required SceneDirectorService directorOrchestrator,
    required NarrativeArcPromptBuilder arcPromptBuilder,
  })  : _castResolver = castResolver,
        _consistencyVerifier = consistencyVerifier,
        _directorOrchestrator = directorOrchestrator,
        _arcPromptBuilder = arcPromptBuilder,
        _taskCardBuilder = const SceneTaskCardBuilder();

  final SceneCastResolverService _castResolver;
  final CharacterConsistencyVerifier? _consistencyVerifier;
  final SceneDirectorService _directorOrchestrator;
  final NarrativeArcPromptBuilder _arcPromptBuilder;
  final SceneTaskCardBuilder _taskCardBuilder;

  /// Executes scene planning for a scene brief.
  ///
  /// - Resolves cast via [SceneCastResolverService].
  /// - Runs pre-generation consistency check if verifier is available.
  /// - Composes director context (memory + RAG + consistency + narrative arc).
  /// - Runs the scene director.
  /// - Builds the task card via [SceneTaskCardBuilder].
  Future<ScenePlanningOutput> execute(ScenePlanningInput input) async {
    final brief = input.brief;

    final resolvedCast = _castResolver.resolve(brief);

    // Pre-generation consistency check: inject warnings into director context
    String? consistencyConstraints;
    if (_consistencyVerifier != null) {
      final preCheck = await _consistencyVerifier.preGenerationCheck(
        brief: brief,
        cast: resolvedCast,
        allFacts: _extractKnowledgeFacts(brief),
        policies: _extractDisclosurePolicies(brief),
      );
      if (preCheck.hasWarnings || preCheck.hasBlockingIssues) {
        consistencyConstraints = preCheck.toPromptText();
      }
    }

    final directorContext = _composeDirectorContext(
      memoryContext: input.directorMemory.toPromptText(),
      ragContext: input.ragContext?.formattedContext,
      consistencyConstraints: consistencyConstraints,
      narrativeArc: input.narrativeArc,
    );

    final director = await _directorOrchestrator.run(
      brief: brief,
      cast: resolvedCast,
      ragContext: directorContext,
    );

    final taskCard = _taskCardBuilder.build(
      brief: brief,
      cast: resolvedCast,
      director: director,
    );

    return ScenePlanningOutput(
      resolvedCast: resolvedCast,
      consistencyConstraints: consistencyConstraints,
      director: director,
      taskCard: taskCard,
    );
  }

  /// Combines memory context, RAG context, consistency constraints, and
  /// narrative arc context into a single director context string.
  ///
  /// Returns null when no context parts are available.
  String? _composeDirectorContext({
    String? memoryContext,
    String? ragContext,
    String? consistencyConstraints,
    NarrativeArcState? narrativeArc,
  }) {
    final parts = <String>[];
    if (memoryContext != null && memoryContext.isNotEmpty) {
      parts.add(memoryContext);
    }
    if (ragContext != null && ragContext.isNotEmpty) {
      parts.add(ragContext);
    }
    if (consistencyConstraints != null && consistencyConstraints.isNotEmpty) {
      parts.add(consistencyConstraints);
    }
    final arcContext = _arcPromptBuilder.buildArcContext(narrativeArc ?? NarrativeArcState());
    if (arcContext != null) {
      parts.add(arcContext);
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  /// Extracts [KnowledgeFact] list from brief knowledge atoms.
  List<KnowledgeFact> _extractKnowledgeFacts(SceneBrief brief) {
    return [
      for (final atom in brief.knowledgeAtoms)
        KnowledgeFact(
          factId: atom.id,
          content: atom.content,
          isPublic: atom.visibility == KnowledgeVisibility.publicObservable,
        ),
    ];
  }

  /// Extracts [DisclosurePolicy] list from brief knowledge atoms.
  ///
  /// Only non-public atoms with a non-empty [ownerScope] produce policies.
  List<DisclosurePolicy> _extractDisclosurePolicies(SceneBrief brief) {
    final policies = <DisclosurePolicy>[];
    for (final atom in brief.knowledgeAtoms) {
      if (atom.visibility != KnowledgeVisibility.publicObservable &&
          atom.ownerScope.isNotEmpty) {
        policies.add(
          DisclosurePolicy(factId: atom.id, knownBy: {atom.ownerScope}),
        );
      }
    }
    return policies;
  }
}
