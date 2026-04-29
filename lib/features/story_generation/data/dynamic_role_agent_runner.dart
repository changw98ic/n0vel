import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'scene_pipeline_models.dart' show SceneTaskCard;
import 'scene_roleplay_runtime.dart';
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class DynamicRoleAgentRunner implements DynamicRoleAgentService {
  DynamicRoleAgentRunner({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;
  SceneRoleplaySession? _lastRoleplaySession;

  SceneRoleplaySession? get lastRoleplaySession => _lastRoleplaySession;

  @override
  Future<List<DynamicRoleAgentOutput>> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
    SceneTaskCard? taskCard,
    String? ragContext,
    void Function(String message)? onStatus,
  }) async {
    if (brief.metadata['localStructuredRoleplayOnly'] == true) {
      _lastRoleplaySession = null;
      return [
        for (final member in cast)
          _localMemberOutput(
            brief: brief,
            director: director,
            member: member,
            taskCard: taskCard,
            onStatus: onStatus,
          ),
      ];
    }

    if (brief.metadata['legacyRoleIntentOnly'] != true) {
      final result = await SceneRoleplayRuntime(settingsStore: _settingsStore)
          .runSession(
            brief: brief,
            cast: cast,
            director: director,
            taskCard: taskCard,
            ragContext: ragContext,
            onStatus: onStatus,
          );
      _lastRoleplaySession = result.session;
      return result.outputs;
    }

    final outputs = await Future.wait([
      for (final member in cast)
        _runMember(
          brief: brief,
          director: director,
          member: member,
          taskCard: taskCard,
          ragContext: ragContext,
          onStatus: onStatus,
        ),
    ]);
    _lastRoleplaySession = null;
    return List<DynamicRoleAgentOutput>.unmodifiable(outputs);
  }

  DynamicRoleAgentOutput _localMemberOutput({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
    SceneTaskCard? taskCard,
    void Function(String message)? onStatus,
  }) {
    onStatus?.call(
      '场景 ${brief.chapterId}/${brief.sceneId} · role ${member.name}',
    );
    final note = director.plan?.noteFor(member.characterId);
    final target = _compact(
      brief.targetBeat.trim().isNotEmpty
          ? brief.targetBeat
          : brief.sceneSummary,
      maxChars: 72,
    );
    final stance = _firstNonEmpty([
      note?.motivation,
      _beliefStance(taskCard: taskCard, member: member),
      '$target（${member.role}）',
    ]);
    final action = _firstNonEmpty([
      note?.keyAction,
      _participationAction(member),
      '推动：$target',
    ]);
    final taboo = _localTaboo(brief: brief, member: member);
    return DynamicRoleAgentOutput(
      characterId: member.characterId,
      name: member.name,
      text: ['立场：$stance', '动作：$action', '禁忌：$taboo'].join('\n'),
    );
  }

  Future<DynamicRoleAgentOutput> _runMember({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
    SceneTaskCard? taskCard,
    String? ragContext,
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call(
      '场景 ${brief.chapterId}/${brief.sceneId} · role ${member.name}',
    );
    final retrievalEnabled = _hasRetrievableContext(taskCard);
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content: _systemPrompt(retrievalEnabled: retrievalEnabled),
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：dynamic_role',
            '格式：立场/动作/禁忌',
            '角色：${member.name}(${member.role})',
            '参与：${member.contributions.map(_contributionLabel).join('/')}',
            '梗概：${_compact(brief.sceneSummary, maxChars: 100)}',
            '导演：${_compact(director.text, maxChars: 120)}',
            ..._directorNoteLines(director: director, member: member),
            ..._cognitionLines(taskCard: taskCard, member: member),
            if (ragContext != null && ragContext.isNotEmpty) ragContext,
          ].join('\n'),
        ),
      ],
    );
    if (!result.succeeded) {
      throw StateError(
        result.detail ?? 'Dynamic role pass failed for ${member.characterId}.',
      );
    }
    return DynamicRoleAgentOutput(
      characterId: member.characterId,
      name: member.name,
      text: result.text!.trim(),
    );
  }

  String _systemPrompt({required bool retrievalEnabled}) {
    final base =
        'You are a dynamic role agent for a Chinese novel scene. '
        'Output exactly 3 short lines and nothing else:\n'
        '立场：...\n'
        '动作：...\n'
        '禁忌：...\n'
        'Keep every line concrete and brief. No prose.';
    if (!retrievalEnabled) {
      return base;
    }
    return 'You are a dynamic role agent for a Chinese novel scene. '
        'Output the three required short lines first:\n'
        '立场：...\n'
        '动作：...\n'
        '禁忌：...\n'
        'When role cognition needs more context, append optional retrieval lines:\n'
        '检索：tool_name|query|purpose\n'
        'Available tools: character_profile, relationship, world_setting, past_event.\n'
        'Keep every line concrete and brief. No prose.';
  }

  bool _hasRetrievableContext(SceneTaskCard? taskCard) {
    if (taskCard == null) {
      return false;
    }
    return taskCard.beliefs.isNotEmpty ||
        taskCard.relationships.isNotEmpty ||
        taskCard.socialPositions.isNotEmpty ||
        taskCard.knowledge.isNotEmpty;
  }

  List<String> _directorNoteLines({
    required SceneDirectorOutput director,
    required ResolvedSceneCastMember member,
  }) {
    final plan = director.plan;
    if (plan == null) {
      return const [];
    }
    final note = plan.noteFor(member.characterId);
    return [
      if (note != null && note.motivation.trim().isNotEmpty)
        '角色动机：${note.motivation.trim()}',
      if (note != null && note.emotionalArc.trim().isNotEmpty)
        '情绪弧线：${note.emotionalArc.trim()}',
      if (note != null && note.keyAction.trim().isNotEmpty)
        '关键动作：${note.keyAction.trim()}',
      if (plan.tone.trim().isNotEmpty) '场景基调：${plan.tone.trim()}',
    ];
  }

  List<String> _cognitionLines({
    required SceneTaskCard? taskCard,
    required ResolvedSceneCastMember member,
  }) {
    if (taskCard == null) {
      return const [];
    }
    final beliefs = taskCard.beliefsFor(member.characterId);
    final relationships = taskCard.relationshipsFor(member.characterId);
    final socialPosition = taskCard.socialPositionFor(member.characterId);
    return [
      if (beliefs.isNotEmpty)
        '信念：${beliefs.map((belief) {
          final target = _memberName(taskCard, belief.targetId);
          return '$target/${belief.aspect}=${belief.value}';
        }).join('；')}',
      if (relationships.isNotEmpty)
        '关系：${relationships.map((relationship) {
          final a = _memberName(taskCard, relationship.characterA);
          final b = _memberName(taskCard, relationship.characterB);
          return '$a↔$b：${relationship.label}（张力${relationship.tension}/信任${relationship.trust}）';
        }).join('；')}',
      if (socialPosition != null)
        '社会地位：${socialPosition.role}/${socialPosition.formalRank}/影响力${socialPosition.actualInfluence}',
    ];
  }

  String _memberName(SceneTaskCard taskCard, String characterId) {
    for (final member in taskCard.cast) {
      if (member.characterId == characterId) {
        return member.name;
      }
    }
    return characterId;
  }

  String _contributionLabel(SceneCastContribution contribution) {
    return switch (contribution) {
      SceneCastContribution.action => '行动',
      SceneCastContribution.dialogue => '对白',
      SceneCastContribution.interaction => '互动',
    };
  }

  String _beliefStance({
    required SceneTaskCard? taskCard,
    required ResolvedSceneCastMember member,
  }) {
    if (taskCard == null) {
      return '';
    }
    final beliefs = taskCard.beliefsFor(member.characterId);
    if (beliefs.isEmpty) {
      return '';
    }
    final belief = beliefs.first;
    return '${_memberName(taskCard, belief.targetId)}${belief.aspect}：${belief.value}';
  }

  String _participationAction(ResolvedSceneCastMember member) {
    if (member.contributions.isEmpty) {
      return '';
    }
    return '承担${member.contributions.map(_contributionLabel).join('/')}功能';
  }

  String _localTaboo({
    required SceneBrief brief,
    required ResolvedSceneCastMember member,
  }) {
    final target = _compact(
      brief.targetBeat.trim().isNotEmpty
          ? brief.targetBeat
          : brief.sceneSummary,
      maxChars: 48,
    );
    if (target.isNotEmpty) {
      return '脱离$target';
    }
    return '脱离${member.role}的当前认知';
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
