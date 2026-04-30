import 'package:novel_writer/app/state/app_settings_store.dart';

import 'scene_pipeline_models.dart' show SceneTaskCard;
import 'scene_roleplay_runtime.dart';
import 'scene_roleplay_session_models.dart';
import 'character_memory_delta_models.dart';
import 'character_memory_store.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class DynamicRoleAgentRunner implements DynamicRoleAgentService {
  DynamicRoleAgentRunner({
    required AppSettingsStore settingsStore,
    CharacterMemoryStore? characterMemoryStore,
  }) : _settingsStore = settingsStore,
       _characterMemoryStore = characterMemoryStore;

  final AppSettingsStore _settingsStore;
  final CharacterMemoryStore? _characterMemoryStore;
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

    final memoryDeltasByCharacter = await _loadVisibleMemories(
      brief: brief,
      cast: cast,
    );
    final result = await SceneRoleplayRuntime(settingsStore: _settingsStore)
        .runSession(
          brief: brief,
          cast: cast,
          director: director,
          taskCard: taskCard,
          ragContext: ragContext,
          memoryDeltasByCharacter: memoryDeltasByCharacter,
          onStatus: onStatus,
        );
    _lastRoleplaySession = result.session;
    return result.outputs;
  }

  Future<Map<String, List<CharacterMemoryDelta>>> _loadVisibleMemories({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) async {
    final store = _characterMemoryStore;
    if (store == null) {
      return const <String, List<CharacterMemoryDelta>>{};
    }
    final projectId = brief.projectId ?? brief.chapterId;
    final entries = await Future.wait([
      for (final member in cast)
        store.loadCharacterMemories(
          projectId: projectId,
          characterId: member.characterId,
        ),
    ]);
    return {
      for (var index = 0; index < cast.length; index += 1)
        cast[index].characterId: entries[index],
    };
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
