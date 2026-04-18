part of 'agent_service.dart';

extension _AgentExecutionHelpers on AgentService {
  List<List<int>> _buildDependencyLevelsHelper(List<_PlanStep> plan) {
    if (plan.isEmpty) return [];
    if (plan.length == 1) return [[0]];

    final levels = <List<int>>[];
    final completed = <int>{};

    while (completed.length < plan.length) {
      final ready = <int>[];
      for (var i = 0; i < plan.length; i++) {
        if (completed.contains(i)) continue;
        if (plan[i]
            .dependsOn
            .every((d) => completed.contains(d) || d >= plan.length)) {
          ready.add(i);
        }
      }

      if (ready.isEmpty) {
        for (var i = 0; i < plan.length; i++) {
          if (!completed.contains(i)) ready.add(i);
        }
      }

      levels.add(ready);
      completed.addAll(ready);
    }
    return levels;
  }

  Future<_StepResult> _executeOneStepHelper({
    required StreamController<AgentEvent> controller,
    required int idx,
    required _PlanStep step,
    required List<_PlanStep> plan,
    required String task,
    required String currentWorkId,
    required List<_StepObservation> observations,
    required List<ToolDefinition> tools,
    required List<Map<String, dynamic>> toolSchemas,
    required ModelTier tier,
    required int maxStepRetries,
    List<ChatMessage>? conversationHistory,
  }) async {
    controller.add(AgentPlanStepStart(
      stepIndex: idx,
      totalSteps: plan.length,
      description: step.description,
    ));
    controller.add(
      AgentThinking('闁圭瑳鍡╂斀婵縿鍎甸?${idx + 1}/${plan.length}: ${step.description}'),
    );

    var stepResult = await _executeStepReAct(
      controller: controller,
      stepTask: step.description,
      originalTask: task,
      currentWorkId: currentWorkId,
      compressedObservations: _compactObservations(observations),
      tools: tools,
      toolSchemas: toolSchemas,
      tier: tier,
      maxSubIterations: maxSubIterationsPerStep,
      conversationHistory: conversationHistory,
    );
    stepResult = _rebuildStepResult(
      source: stepResult,
      stepIndex: idx,
      stepDescription: step.description,
    );

    if (maxStepRetries > 0 && _needsStepReflection(stepResult)) {
      stepResult = await _retryStepWithReflectionHelper(
        controller: controller,
        idx: idx,
        step: step,
        task: task,
        currentWorkId: currentWorkId,
        observations: observations,
        tools: tools,
        toolSchemas: toolSchemas,
        tier: tier,
        maxStepRetries: maxStepRetries,
        initialResult: stepResult,
      );
    }

    controller.add(AgentPlanStepComplete(
      stepIndex: idx,
      success: stepResult.success,
      summary: stepResult.summary,
    ));

    return stepResult;
  }

  Future<_StepResult> _retryStepWithReflectionHelper({
    required StreamController<AgentEvent> controller,
    required int idx,
    required _PlanStep step,
    required String task,
    required String currentWorkId,
    required List<_StepObservation> observations,
    required List<ToolDefinition> tools,
    required List<Map<String, dynamic>> toolSchemas,
    required ModelTier tier,
    required int maxStepRetries,
    required _StepResult initialResult,
  }) async {
    var stepResult = initialResult;
    var retryCount = 0;

    while (retryCount < maxStepRetries) {
      final reflection = await _reflectOnStep(
        stepTask: step.description,
        stepResult: stepResult.summary,
        stepSuccess: stepResult.success,
        tier: tier,
      );
      stepResult = _rebuildStepResult(
        source: stepResult,
        stepIndex: idx,
        stepDescription: step.description,
        inputTokens: stepResult.inputTokens + reflection.inputTokens,
        outputTokens: stepResult.outputTokens + reflection.outputTokens,
      );

      controller.add(AgentReflection(
        target: '婵縿鍎甸?${idx + 1}: ${step.description}',
        passed: reflection.passed,
        evaluation: reflection.evaluation,
        feedback: reflection.feedback,
      ));

      if (reflection.passed) break;

      retryCount++;
      controller.add(AgentRetry(
        stepIndex: idx,
        retryCount: retryCount,
        maxRetries: maxStepRetries,
        reason: reflection.feedback ?? reflection.evaluation,
      ));
      controller.add(
        AgentThinking(
          '闁告瑥绉甸埀顒佺箓瑜板倿鎮虫０浣虹憹閻℃帞顒茬槐婵嬫煂瀹ュ牏妲告慨婵勫劦椤?${idx + 1}闁挎稑鐗忛?$retryCount 婵炲棴绻濋崳鍝ユ嫚閺囶亞绀?',
        ),
      );

      final retryResult = await _executeStepReAct(
        controller: controller,
        stepTask: step.description,
        originalTask: task,
        currentWorkId: currentWorkId,
        compressedObservations: _compactObservations(observations),
        tools: tools,
        toolSchemas: toolSchemas,
        tier: tier,
        maxSubIterations: maxSubIterationsPerStep,
        reflectionFeedback: reflection.feedback ?? reflection.evaluation,
      );

      stepResult = _rebuildStepResult(
        source: retryResult,
        stepIndex: idx,
        stepDescription: step.description,
        newWorkId: retryResult.newWorkId ?? stepResult.newWorkId,
        inputTokens: stepResult.inputTokens + retryResult.inputTokens,
        outputTokens: stepResult.outputTokens + retryResult.outputTokens,
        keyResults: retryResult.keyResults,
      );
    }

    return stepResult;
  }
}

String _compactObservations(List<_StepObservation> observations) =>
    observations.map((o) => o.toCompact()).join('\n');

_StepResult _rebuildStepResult({
  required _StepResult source,
  required int stepIndex,
  required String stepDescription,
  String? newWorkId,
  int? inputTokens,
  int? outputTokens,
  Map<String, String>? keyResults,
}) {
  final effectiveKeyResults = keyResults ?? source.keyResults;
  return _StepResult(
    success: source.success,
    summary: source.summary,
    newWorkId: newWorkId ?? source.newWorkId,
    inputTokens: inputTokens ?? source.inputTokens,
    outputTokens: outputTokens ?? source.outputTokens,
    keyResults: effectiveKeyResults,
    observation: _StepObservation(
      stepIndex: stepIndex,
      stepDesc: stepDescription,
      success: source.success,
      summary: source.summary,
      keyResults: effectiveKeyResults,
    ),
  );
}

bool _needsStepReflection(_StepResult result) {
  if (!result.success) return true;
  if (result.summary.trim().length < 20) return true;
  if (result.summary.contains('闂佹寧鐟ㄩ?)) return true;
  if (result.summary.contains('闁哄牜浜滈悾顒勫箣?)) return true;
  return false;
}

bool _isLastStepSynthesisCandidateHelper(
  _StepObservation lastObs,
  int planLength,
) {
  if (!lastObs.success) return false;
  if (lastObs.summary.length < 50) return false;
  if (planLength <= 2) return false;
  return true;
}
