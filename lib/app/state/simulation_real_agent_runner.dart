import '../llm/app_llm_client.dart';
import '../state/app_settings_store.dart';
import 'simulation_models.dart';
import 'simulation_snapshot_builder.dart';

/// Runs a multi-agent LLM simulation where each agent calls the real AI
/// provider and contributes a message per round.
class SimulationRealAgentRunner {
  const SimulationRealAgentRunner();

  Future<RealAgentSimulationResult> run({
    required AppSettingsStore settingsStore,
    required String sceneContext,
    required List<RealAgentConfig> agents,
    String authorGoal = '',
    int rounds = 2,
  }) async {
    final normalizedContext = sceneContext.trim();
    if (normalizedContext.isEmpty) {
      throw ArgumentError.value(
        sceneContext,
        'sceneContext',
        'must not be empty',
      );
    }
    if (rounds < 1) {
      throw ArgumentError.value(rounds, 'rounds', 'must be greater than zero');
    }

    final extraMessages = <SimulationChatMessage>[];
    final transcript = <SimulationChatMessage>[];
    final priorOutputs = <String>[];

    try {
      for (var round = 1; round <= rounds; round++) {
        final results = await Future.wait(
          agents.map(
            (agent) => _requestAgentWithRetry(
              settingsStore: settingsStore,
              messages: _messagesForRealAgent(
                agent: agent,
                round: round,
                rounds: rounds,
                sceneContext: normalizedContext,
                authorGoal: authorGoal.trim(),
                priorOutputs: priorOutputs,
              ),
            ),
          ),
        );

        for (var i = 0; i < agents.length; i++) {
          final agent = agents[i];
          final result = results[i];
          if (!result.succeeded || result.text == null) {
            final detail =
                result.detail ?? result.failureKind?.name ?? 'empty response';
            extraMessages.add(
              SimulationChatMessage(
                sender: agent.label,
                title: '真实回合 $round · 调用失败',
                body: detail,
                tone: agent.tone,
                alignEnd: agent.alignEnd,
                kind: SimulationMessageKind.verdict,
              ),
            );
            return RealAgentSimulationResult(
              succeeded: false,
              messages: List<SimulationChatMessage>.unmodifiable(extraMessages),
              failureDetail: detail,
            );
          }

          final text = result.text!.trim();
          final message = SimulationChatMessage(
            sender: agent.label,
            title: '真实回合 $round · ${agent.goal}',
            body: text,
            tone: agent.tone,
            alignEnd: agent.alignEnd,
            kind: agent.key == 'director'
                ? SimulationMessageKind.intent
                : SimulationMessageKind.speech,
          );
          transcript.add(message);
          extraMessages.add(message);
          priorOutputs.add('${agent.label}：$text');
        }
      }

      return RealAgentSimulationResult(
        succeeded: true,
        messages: List<SimulationChatMessage>.unmodifiable(transcript),
      );
    } catch (error) {
      extraMessages.add(
        SimulationChatMessage(
          sender: '系统',
          title: '真实多 Agent 调用异常',
          body: error.toString(),
          tone: SimulationChatTone.stateMachine,
          alignEnd: false,
          kind: SimulationMessageKind.verdict,
        ),
      );
      return RealAgentSimulationResult(
        succeeded: false,
        messages: List<SimulationChatMessage>.unmodifiable(extraMessages),
        failureDetail: error.toString(),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Private helpers.
  // -----------------------------------------------------------------------

  Future<AppLlmChatResult> _requestAgentWithRetry({
    required AppSettingsStore settingsStore,
    required List<AppLlmChatMessage> messages,
    int maxRetries = 3,
  }) async {
    var retries = 0;
    while (true) {
      final result = await settingsStore.requestAiCompletion(
        messages: messages,
      );
      if (result.succeeded || retries >= maxRetries) {
        return result;
      }
      final kind = result.failureKind;
      if (kind != AppLlmFailureKind.network &&
          kind != AppLlmFailureKind.timeout &&
          kind != AppLlmFailureKind.server) {
        return result;
      }
      retries += 1;
      await Future<void>.delayed(
        Duration(milliseconds: 500 * (1 << (retries - 1))),
      );
    }
  }

  List<AppLlmChatMessage> _messagesForRealAgent({
    required RealAgentConfig agent,
    required int round,
    required int rounds,
    required String sceneContext,
    required String authorGoal,
    required List<String> priorOutputs,
  }) {
    return [
      AppLlmChatMessage(
        role: 'system',
        content: [
          '你是小说场景模拟中的真实多 Agent 角色：${agent.label}。',
          '你的目标：${agent.goal}。',
          '你的固定 prompt：${agent.prompt}',
          '输出本回合可被正文生成引用的中文内容，保持角色现场判断口吻。',
        ].join('\n'),
      ),
      AppLlmChatMessage(
        role: 'user',
        content: [
          '任务：真实多 Agent 场景模拟',
          '回合：$round/$rounds',
          if (authorGoal.isNotEmpty) '作者目标：$authorGoal',
          '场景上下文：$sceneContext',
          if (priorOutputs.isNotEmpty)
            '此前回合输出：\n${priorOutputs.join('\n')}',
          '请给出 ${agent.label} 本回合的判断、行动/阻力、以及对正文生成的约束。',
        ].join('\n\n'),
      ),
    ];
  }
}
