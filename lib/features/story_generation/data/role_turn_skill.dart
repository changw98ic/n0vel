import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_visible_context_models.dart';
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';

abstract interface class RoleTurnSkill {
  String get skillId;
  String get version;

  Future<SceneRoleplayTurn> runTurn({
    required CharacterVisibleContext context,
    required int round,
  });
}

class BasicRoleTurnSkill implements RoleTurnSkill {
  BasicRoleTurnSkill({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  @override
  String get skillId => 'basic_role_turn';

  @override
  String get version => '1.0.0';

  @override
  Future<SceneRoleplayTurn> runTurn({
    required CharacterVisibleContext context,
    required int round,
  }) async {
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        const AppLlmChatMessage(
          role: 'system',
          content:
              'You generate one character response inside a Chinese novel scene. '
              'Use only the character visible context provided in the user '
              'message. Output exactly 5 short lines and nothing else:\n'
              '意图：...\n'
              '可见动作：...\n'
              '对白：...\n'
              '内心：...\n'
              '禁忌：...',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：scene_roleplay_turn',
            'skill：$skillId@$version',
            '回合：$round',
            context.toPromptText(),
            '输出：只写${context.characterName}此刻的反应；严格五行。',
          ].join('\n'),
        ),
      ],
    );
    if (!result.succeeded) {
      throw StateError(
        result.detail ?? 'Role turn skill failed for ${context.characterId}.',
      );
    }
    return _parseTurn(raw: result.text!.trim(), round: round, context: context);
  }

  SceneRoleplayTurn _parseTurn({
    required String raw,
    required int round,
    required CharacterVisibleContext context,
  }) {
    final values = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      final colon = trimmed.indexOf('：');
      if (colon <= 0) continue;
      values[trimmed.substring(0, colon)] = trimmed.substring(colon + 1).trim();
    }
    return SceneRoleplayTurn(
      round: round,
      characterId: context.characterId,
      name: context.characterName,
      intent: values['意图'] ?? '',
      visibleAction: values['可见动作'] ?? '',
      dialogue: values['对白'] ?? '',
      innerState: values['内心'] ?? '',
      taboo: values['禁忌'] ?? '',
      rawText: raw,
      skillId: skillId,
      skillVersion: version,
    );
  }
}
