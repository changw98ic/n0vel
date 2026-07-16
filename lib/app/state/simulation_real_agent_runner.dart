import '../llm/app_llm_client.dart';
import '../llm/app_product_prompt_registry.dart';
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
              agent: agent,
              round: round,
              rounds: rounds,
              sceneContext: normalizedContext,
              authorGoal: authorGoal.trim(),
              priorOutputs: priorOutputs,
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
    required RealAgentConfig agent,
    required int round,
    required int rounds,
    required String sceneContext,
    required String authorGoal,
    required List<String> priorOutputs,
    int maxRetries = 3,
  }) async {
    final promptInvocation = AppProductPromptRegistry.current.invocation(
      stageId: 'simulation',
      callSiteId: 'real-agent-turn',
    );
    final resolvedVariables = <String, Object?>{
      'label': agent.label,
      'goal': agent.goal,
      'agentPrompt': agent.prompt,
      'round': round,
      'rounds': rounds,
      'sceneContext': sceneContext,
      'authorGoal': authorGoal.isEmpty ? '推进当前场景' : authorGoal,
      'priorOutputs': priorOutputs.isEmpty ? '无' : priorOutputs.join('\n'),
    };
    final messages = promptInvocation.render(resolvedVariables).messages;
    final promptEvidence = promptInvocation.evidence(
      messages: messages,
      resolvedVariables: resolvedVariables,
    );
    var retries = 0;
    while (true) {
      // llm-call-site: boundary.simulation.product-request
      final result = await settingsStore.requestAiCompletion(
        messages: messages,
        promptReleaseRef: promptInvocation.promptReleaseRef,
        promptInvocationEvidence: promptEvidence,
        stageId: promptInvocation.stageId,
        callSiteId: promptInvocation.callSiteId,
        variantId: promptInvocation.variantId,
        generationBundleHash: promptInvocation.generationBundleHash,
        traceName: 'simulation_real_agent_turn',
        traceMetadata: <String, Object?>{
          'agentId': agent.key,
          'agentRole': agent.key,
          'agentName': agent.label,
          'round': round,
          'roundCount': rounds,
          'attempt': retries,
          'transientRetryCount': retries,
        },
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
}
