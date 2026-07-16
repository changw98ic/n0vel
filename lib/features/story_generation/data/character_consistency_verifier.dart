import '../domain/contracts/settings_contract.dart';

import 'character_consistency_models.dart';
import 'knowledge_visibility_filter.dart';
import 'scene_context_models.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_runtime_models.dart';
import 'soul_contract_validator.dart';
import 'story_prompt_registry.dart';
import 'evaluation/agent_evaluation_trace_context.dart';

/// Proactive character consistency verification for pre- and post-generation.
class CharacterConsistencyVerifier {
  CharacterConsistencyVerifier({
    required this.settingsStore,
    SoulContractValidator? soulValidator,
  }) : _soulValidator = soulValidator;

  final StoryGenerationSettingsContract settingsStore;
  final SoulContractValidator? _soulValidator;

  /// Pre-generation check: validates character context against their profiles.
  ///
  /// Examines the scene brief, cast, and retrieval pack to detect potential
  /// inconsistencies before generation begins. Issues are returned as warnings
  /// or blocking items that can be injected into the director's constraints.
  Future<ConsistencyReport> preGenerationCheck({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required List<KnowledgeFact> allFacts,
    required List<DisclosurePolicy> policies,
  }) async {
    final issues = <ConsistencyIssue>[];

    // Check knowledge boundary: verify each character only "knows" facts
    // they should know based on disclosure policies.
    final filter = KnowledgeVisibilityFilter();
    for (final member in cast) {
      final visibleFacts = filter.visibleFacts(
        allFacts,
        member.characterId,
        policies,
      );
      // Check if brief references facts that the character shouldn't know
      final briefText = '${brief.sceneTitle} ${brief.sceneSummary}'
          .toLowerCase();

      for (final fact in allFacts) {
        if (fact.isPublic) continue;
        if (visibleFacts.any((vf) => vf.factId == fact.factId)) continue;

        // Fact is NOT visible to this character — check if brief implies
        // they know it (simple keyword check)
        final keywords = fact.content
            .split(RegExp(r'[，。、；\s,.;]+'))
            .where((w) => w.length >= 2);
        var matchCount = 0;
        for (final kw in keywords) {
          if (briefText.contains(kw.toLowerCase())) matchCount++;
        }
        if (matchCount >= 2 && keywords.length >= 3) {
          issues.add(
            ConsistencyIssue(
              aspect: ConsistencyAspect.knowledgeBoundary,
              severity: ConsistencySeverity.warning,
              characterId: member.characterId,
              description:
                  '场景描述可能暗示 ${member.name} 知道他不了解的信息: "${fact.content.substring(0, fact.content.length > 40 ? 40 : fact.content.length)}"',
              suggestion: '确保该角色不会直接引用或暗示此信息',
            ),
          );
        }
      }
    }

    issues.addAll(
      _soulIssuesForText(
        text: '${brief.sceneTitle}\n${brief.sceneSummary}',
        cast: cast,
        phase: 'pre-generation scene brief',
      ),
    );

    return ConsistencyReport(issues: issues);
  }

  /// Post-generation check: verifies generated content against character profiles.
  ///
  /// Uses an LLM to check dialogue voice, action capability, knowledge boundaries,
  /// and emotional arcs against the established character profiles.
  Future<ConsistencyReport> postGenerationCheck({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    required List<ResolvedSceneCastMember> cast,
  }) async {
    if (cast.isEmpty) return const ConsistencyReport(issues: []);

    final profileSummaries = _buildProfileSummaries(cast);
    final generatedContent = _collectGeneratedContent(
      director,
      roleOutputs,
      prose,
    );
    final soulIssues = _soulIssuesForText(
      text: generatedContent,
      cast: cast,
      phase: 'post-generation content',
    );

    try {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'review',
        callSiteId: 'character-consistency',
      );
      final resolvedVariables = <String, Object?>{
        'sceneTitle': brief.sceneTitle,
        'characterProfiles': profileSummaries,
        'generatedContent': generatedContent,
      };
      final messages = promptIdentity.render(resolvedVariables).messages;
      // llm-call-site: boundary.story.character-consistency
      final result = await settingsStore.requestAiCompletion(
        messages: messages,
        maxTokens: 1024,
        traceName: 'character-consistency-check',
        traceMetadata:
            AgentEvaluationTraceContext.current?.toTraceMetadata() ??
            const <String, Object?>{},
        promptReleaseRef: promptIdentity.promptReleaseRef,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        stageId: promptIdentity.callSite.stageId,
        callSiteId: promptIdentity.callSite.callSiteId,
        variantId: promptIdentity.callSite.variantId,
        generationBundleHash: promptIdentity.generationBundleHash,
      );

      if (result.text == null || result.text!.trim().isEmpty) {
        return ConsistencyReport(issues: soulIssues);
      }

      final llmReport = _parseCheckResponse(result.text!);
      return ConsistencyReport(issues: [...llmReport.issues, ...soulIssues]);
    } on Object {
      return ConsistencyReport(issues: soulIssues);
    }
  }

  List<ConsistencyIssue> _soulIssuesForText({
    required String text,
    required List<ResolvedSceneCastMember> cast,
    required String phase,
  }) {
    final validator = _soulValidator;
    if (validator == null || text.trim().isEmpty) return const [];

    final violations = validator.validate(text, context: {'phase': phase});
    if (violations.isEmpty) return const [];

    final characterIds = cast.isEmpty
        ? const ['scene']
        : [for (final member in cast) member.characterId];
    return [
      for (final characterId in characterIds)
        for (final violation in violations)
          ConsistencyIssue(
            aspect: ConsistencyAspect.actionCapability,
            severity: ConsistencySeverity.blocking,
            characterId: characterId,
            description:
                'Soul contract violation during $phase: ${violation.description}',
            suggestion: 'Revise the action so it respects ${violation.rule}.',
          ),
    ];
  }

  String _buildProfileSummaries(List<ResolvedSceneCastMember> cast) {
    final parts = <String>[];
    for (final member in cast) {
      parts.add('- ${member.name}(${member.characterId}): role=${member.role}');
    }
    return parts.join('\n');
  }

  String _collectGeneratedContent(
    SceneDirectorOutput director,
    List<DynamicRoleAgentOutput> roleOutputs,
    SceneProseDraft prose,
  ) {
    final parts = <String>[];
    if (director.text.isNotEmpty) {
      parts.add('【导演策划】\n${_truncate(director.text, 500)}');
    }
    for (final output in roleOutputs) {
      final turn = pipeline.RolePlayTurnOutput.fromDynamicAgentOutput(output);
      parts.add(
        '【${output.name} 立场=${turn.stance} 动作=${turn.action}】\n'
        '${turn.proseFragment}',
      );
    }
    if (prose.text.isNotEmpty) {
      parts.add('【正文】\n${_truncate(prose.text, 800)}');
    }
    return parts.join('\n\n');
  }

  ConsistencyReport _parseCheckResponse(String response) {
    final text = response.trim();
    if (text == 'PASS' || text.isEmpty) {
      return const ConsistencyReport(issues: []);
    }

    final issues = <ConsistencyIssue>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == 'PASS') continue;

      final parts = trimmed.split('|');
      if (parts.length < 4) continue;

      issues.add(
        ConsistencyIssue(
          severity: _parseSeverity(parts[0].trim()),
          aspect: _parseAspect(parts[1].trim()),
          characterId: parts[2].trim(),
          description: parts[3].trim(),
          suggestion: parts.length >= 5 ? parts[4].trim() : null,
        ),
      );
    }

    return ConsistencyReport(issues: issues);
  }

  ConsistencySeverity _parseSeverity(String raw) {
    return switch (raw) {
      'blocking' => ConsistencySeverity.blocking,
      'warning' => ConsistencySeverity.warning,
      _ => ConsistencySeverity.info,
    };
  }

  ConsistencyAspect _parseAspect(String raw) {
    return switch (raw) {
      'dialogueVoice' => ConsistencyAspect.dialogueVoice,
      'actionCapability' => ConsistencyAspect.actionCapability,
      'knowledgeBoundary' => ConsistencyAspect.knowledgeBoundary,
      'emotionalArc' => ConsistencyAspect.emotionalArc,
      'relationshipConsistency' => ConsistencyAspect.relationshipConsistency,
      _ => ConsistencyAspect.dialogueVoice,
    };
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 3)}...';
  }
}
