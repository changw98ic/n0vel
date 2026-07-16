import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/data/role_agent_controller.dart';
import 'package:novel_writer/features/story_generation/data/role_turn_skill.dart';
import 'package:novel_writer/features/story_generation/data/scene_arbiter_skill.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  test(
    'role turn and arbiter retain agent metadata across wrapper retries',
    () async {
      final settings = _CapturingSettingsContract(<AppLlmChatResult>[
        const AppLlmChatResult.success(text: 'malformed role turn'),
        const AppLlmChatResult.success(
          text:
              '意图：稳住现场\n'
              '可见动作：柳溪按住门闩\n'
              '对白：先别开门\n'
              '内心：我必须确认门外是谁。',
        ),
        const AppLlmChatResult.success(
          text:
              '事实：门闩已经锁死\n'
              '状态：柳溪守在门边\n'
              '压力：门外脚步逼近\n'
              '收束：否',
        ),
      ]);
      final roleSkill = BasicRoleTurnSkill(settingsStore: settings);

      final turn = await roleSkill.runTurn(
        context: _visibleContext(),
        round: 4,
      );
      final arbiter = BasicSceneArbiterSkill(settingsStore: settings);
      await arbiter.arbitrate(
        sceneTitle: '仓库门外',
        previousPublicState: '柳溪被困在仓库里',
        round: 4,
        roundTurns: <SceneRoleplayTurn>[turn],
        transcript: <SceneRoleplayTurn>[turn],
      );

      expect(settings.requests, hasLength(3));
      final roleRequests = settings.requests.take(2).toList(growable: false);
      expect(
        roleRequests.map((request) => request.traceName),
        everyElement('scene_roleplay_turn'),
      );
      expect(
        roleRequests.map((request) => request.metadata['agentId']),
        everyElement('character-liuxi'),
      );
      expect(
        roleRequests.map((request) => request.metadata['agentRole']),
        everyElement('调查记者'),
      );
      expect(
        roleRequests.map((request) => request.metadata['round']),
        everyElement(4),
      );
      expect(
        roleRequests.map((request) => request.metadata['attempt']),
        <Object?>[0, 1],
      );
      expect(
        roleRequests.map((request) => request.metadata['outputRetryCount']),
        <Object?>[0, 1],
      );

      final arbiterRequest = settings.requests.last;
      expect(arbiterRequest.traceName, 'scene_roleplay_arbitrate');
      expect(arbiterRequest.metadata['agentId'], 'scene-arbiter');
      expect(arbiterRequest.metadata['agentRole'], 'arbiter');
      expect(arbiterRequest.metadata['round'], 4);
      expect(arbiterRequest.metadata['attempt'], 0);
    },
  );

  test(
    'retrieval role agent traces each real agent round explicitly',
    () async {
      final settings = _CapturingSettingsContract(<AppLlmChatResult>[
        const AppLlmChatResult.success(
          text: 'RETRIEVE:character_profile:targetId=character-yueren',
        ),
        const AppLlmChatResult.success(text: '立场：继续追问\n动作：挡住出口\n禁忌：泄露线人身份'),
      ]);
      final controller = RoleAgentController(settingsStore: settings);

      await controller.runWithRetrieval(
        brief: _brief(),
        member: _member(),
        director: const SceneDirectorOutput(text: '目标：逼出线索'),
        retrievalTool: (_) async => '岳人曾在旧码头出现。',
      );

      expect(settings.requests, hasLength(2));
      expect(
        settings.requests.map((request) => request.traceName),
        everyElement('scene_roleplay_turn'),
      );
      expect(
        settings.requests.map((request) => request.metadata['agentId']),
        everyElement('character-liuxi'),
      );
      expect(
        settings.requests.map((request) => request.metadata['agentRole']),
        everyElement('调查记者'),
      );
      expect(
        settings.requests.map((request) => request.metadata['round']),
        <Object?>[1, 2],
      );
      expect(
        settings.requests.map((request) => request.metadata['retrievalRound']),
        <Object?>[0, 1],
      );
      expect(
        settings.requests.map((request) => request.metadata['attempt']),
        everyElement(0),
      );
    },
  );
}

CharacterVisibleContext _visibleContext() => CharacterVisibleContext(
  characterId: 'character-liuxi',
  characterName: '柳溪',
  role: '调查记者',
  privateBriefing: '确认门外来人的身份。',
  publicSceneState: const PublicSceneState(summary: '柳溪被困在仓库里。'),
);

SceneBrief _brief() => SceneBrief(
  chapterId: 'chapter-01',
  chapterTitle: '第一章',
  sceneId: 'scene-01',
  sceneTitle: '仓库门外',
  sceneSummary: '柳溪在风雨中拦住岳人。',
);

ResolvedSceneCastMember _member() => ResolvedSceneCastMember(
  characterId: 'character-liuxi',
  name: '柳溪',
  role: '调查记者',
  contributions: const <SceneCastContribution>[SceneCastContribution.action],
);

final class _CapturedRequest {
  const _CapturedRequest({
    required this.traceName,
    required this.metadata,
    required this.stageId,
    required this.callSiteId,
  });

  final String? traceName;
  final Map<String, Object?> metadata;
  final String? stageId;
  final String? callSiteId;
}

final class _CapturingSettingsContract
    implements StoryGenerationSettingsContract {
  _CapturingSettingsContract(List<AppLlmChatResult> results)
    : _results = List<AppLlmChatResult>.of(results);

  final List<AppLlmChatResult> _results;
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const <String, Object?>{},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    if (_results.isEmpty) {
      throw StateError('unexpected story-generation dispatch');
    }
    if (promptReleaseRef == null ||
        promptInvocationEvidence == null ||
        !promptInvocationEvidence.matchesMessages(messages)) {
      throw StateError('captured dispatch lacks valid prompt evidence');
    }
    requests.add(
      _CapturedRequest(
        traceName: traceName,
        metadata: Map<String, Object?>.unmodifiable(traceMetadata),
        stageId: stageId,
        callSiteId: callSiteId,
      ),
    );
    return _results.removeAt(0);
  }
}
