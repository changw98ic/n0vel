import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_consistency_models.dart';
import 'knowledge_visibility_filter.dart';
import 'scene_context_models.dart';
import 'scene_pipeline_models.dart' as pipeline;
import 'scene_runtime_models.dart';

/// Proactive character consistency verification for pre- and post-generation.
class CharacterConsistencyVerifier {
  CharacterConsistencyVerifier({required this.settingsStore});

  final AppSettingsStore settingsStore;

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

    final characterProfiles = _buildCharacterProfiles(cast);
    final generatedContent = _collectGeneratedContent(
      director,
      roleOutputs,
      prose,
    );

    final systemPrompt = _buildPostCheckSystemPrompt();
    final userPrompt = _buildPostCheckUserPrompt(
      sceneTitle: brief.sceneTitle,
      characterProfiles: characterProfiles,
      generatedContent: generatedContent,
    );

    try {
      final result = await settingsStore.requestAiCompletion(
        messages: [
          AppLlmChatMessage(role: 'system', content: systemPrompt),
          AppLlmChatMessage(role: 'user', content: userPrompt),
        ],
        maxTokens: 1024,
        traceName: 'character-consistency-check',
      );

      if (result.text == null || result.text!.trim().isEmpty) {
        return const ConsistencyReport(issues: []);
      }

      return _parseCheckResponse(result.text!);
    } on Object {
      return const ConsistencyReport(issues: []);
    }
  }

  String _buildCharacterProfiles(List<ResolvedSceneCastMember> cast) {
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

  String _buildPostCheckSystemPrompt() {
    return '你是一个小说角色一致性校验器。检查生成的场景内容是否符合角色设定。\n'
        '逐条检查以下方面，对每个发现的问题输出一行：\n'
        '格式：[严重度]|[检查项]|[角色ID]|[问题描述]|[修复建议]\n'
        '严重度: info/warning/blocking\n'
        '检查项: dialogueVoice/actionCapability/knowledgeBoundary/emotionalArc/relationshipConsistency\n'
        '如果没有问题，输出: PASS\n'
        '检查重点：\n'
        '1. 对话风格是否符合角色性格\n'
        '2. 动作是否在角色能力范围内\n'
        '3. 角色是否引用了不该知道的信息\n'
        '4. 情感变化是否合理\n'
        '5. 角色间互动是否符合已建立的关系';
  }

  String _buildPostCheckUserPrompt({
    required String sceneTitle,
    required String characterProfiles,
    required String generatedContent,
  }) {
    return '场景: $sceneTitle\n\n'
        '【角色设定】\n$characterProfiles\n\n'
        '【生成内容】\n$generatedContent\n\n'
        '请检查以上生成内容中的角色一致性问题：';
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
