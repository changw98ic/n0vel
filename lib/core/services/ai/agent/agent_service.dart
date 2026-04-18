import 'dart:async';

import 'agent_message_formatter.dart';
import 'agent_planning_prompt_builder.dart';
import 'agent_prompt_builder.dart';
import 'agent_response_parser.dart';
import 'agent_tool_executor.dart';
import 'agent_tool_policy.dart';
import '../ai_service.dart';
import '../context/context_manager.dart';
import '../models/model_tier.dart';
import '../tools/tool_definition.dart';
import '../tools/tool_registry.dart';
part 'agent_execution_helpers.dart';

// 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?// Agent Events
// 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
/// Agent 娴滃娆㈠ù浣哥唨缁?sealed class AgentEvent {}

/// Agent 閻㈢喐鍨氭禍鍡樺⒔鐞涘矁顓搁崚鎺炵礄Plan-Execute 闂冭埖顔?1閿?class AgentPlan extends AgentEvent {
  final List<String> steps;
  AgentPlan(this.steps);
}

/// Agent 瀵偓婵澧界悰宀冾吀閸掓帊鑵戦惃鍕厙娑撯偓濮?class AgentPlanStepStart extends AgentEvent {
  final int stepIndex;
  final int totalSteps;
  final String description;
  AgentPlanStepStart({
    required this.stepIndex,
    required this.totalSteps,
    required this.description,
  });
}

/// Agent 鐎瑰本鍨氭禍鍡氼吀閸掓帊鑵戦惃鍕厙娑撯偓濮?class AgentPlanStepComplete extends AgentEvent {
  final int stepIndex;
  final bool success;
  final String summary;
  AgentPlanStepComplete({
    required this.stepIndex,
    required this.success,
    required this.summary,
  });
}

/// Agent 鐎佃顒炴?缂佹挻鐏夋潻娑滎攽娴滃棗寮介幀婵婄槑娴?class AgentReflection extends AgentEvent {
  final String target;
  final bool passed;
  final String evaluation;
  final String? feedback;
  AgentReflection({
    required this.target,
    required this.passed,
    required this.evaluation,
    this.feedback,
  });
}

/// Agent 濮濓絽婀柌宥堢槸閺屾劒绔村銉╊€冮敍鍫濈唨娴滃骸寮介幀婵嗗冀妫ｅ牞绱?class AgentRetry extends AgentEvent {
  final int stepIndex;
  final int retryCount;
  final int maxRetries;
  final String reason;
  AgentRetry({
    required this.stepIndex,
    required this.retryCount,
    required this.maxRetries,
    required this.reason,
  });
}

/// Agent 閹繆鈧啩鑵?class AgentThinking extends AgentEvent {
  final String thought;
  AgentThinking(this.thought);
}

/// Agent 閹笛嗩攽瀹搞儱鍙?class AgentAction extends AgentEvent {
  final String toolName;
  final Map<String, dynamic> input;
  AgentAction(this.toolName, this.input);
}

/// Agent 鐟欏倸鐧傚銉ュ徔缂佹挻鐏?class AgentObservation extends AgentEvent {
  final ToolResult result;
  AgentObservation(this.result);
}

/// Agent 閺堚偓缂佸牆鎼锋惔鏃撶礄濞翠礁绱￠弬鍥ㄦ拱閸ф绱?class AgentResponseChunk extends AgentEvent {
  final String chunk;
  AgentResponseChunk(this.chunk);
}

/// Agent 閺堚偓缂佸牆鎼锋惔鏃撶礄鐎瑰本鍨氶敍?class AgentResponse extends AgentEvent {
  final String content;
  final int iterations;
  final int totalInputTokens;
  final int totalOutputTokens;
  AgentResponse({
    required this.content,
    required this.iterations,
    required this.totalInputTokens,
    required this.totalOutputTokens,
  });
}

/// Agent 闁挎瑨顕?class AgentError extends AgentEvent {
  final String error;
  AgentError(this.error);
}

// 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?// Internal: Step execution result
// 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
class _StepResult {
  final bool success;
  final String summary;
  final String? newWorkId;
  final int inputTokens;
  final int outputTokens;
  final Map<String, String> keyResults;
  final _StepObservation observation;

  _StepResult({
    required this.success,
    required this.summary,
    this.newWorkId,
    required this.inputTokens,
    required this.outputTokens,
    this.keyResults = const {},
    required this.observation,
  });
}

class _ReflectionResult {
  final bool passed;
  final String evaluation;
  final String? feedback;
  final int inputTokens;
  final int outputTokens;

  _ReflectionResult({
    required this.passed,
    required this.evaluation,
    this.feedback,
    required this.inputTokens,
    required this.outputTokens,
  });
}

class _AdditionalPlanResult {
  final List<String> steps;
  final int inputTokens;
  final int outputTokens;

  _AdditionalPlanResult({
    required this.steps,
    required this.inputTokens,
    required this.outputTokens,
  });
}

class _ToolCallProcessingResult {
  final String currentWorkId;
  final Map<String, String> keyResults;

  _ToolCallProcessingResult({
    required this.currentWorkId,
    this.keyResults = const {},
  });
}

/// 缂佹挻鐎崠鏍吀閸掓帗顒炴?class _PlanStep {
  final String description;
  final Set<int> dependsOn;
  final String? suggestedTool;

  _PlanStep({
    required this.description,
    this.dependsOn = const {},
    this.suggestedTool,
  });
}

/// 缂佹挻鐎崠鏍劄妤犮倛顫囩€电噦绱欐稉濠佺瑓閺傚洤甯囩紓鈺冩暏閿?class _StepObservation {
  final int stepIndex;
  final String stepDesc;
  final bool success;
  final String summary;
  final Map<String, String> keyResults; // e.g. {'work_id': 'abc123'}

  _StepObservation({
    required this.stepIndex,
    required this.stepDesc,
    required this.success,
    required this.summary,
    this.keyResults = const {},
  });

  /// 閸樺缂夌悰銊с仛閿涙艾褰ф穱婵堟殌閸忔娊鏁穱鈩冧紖
  String toCompact() {
    final parts = <String>[];
    parts.add('${stepIndex + 1}. $stepDesc: ${success ? "閴? : "閴?}');
    if (keyResults.isNotEmpty) {
      parts.add(keyResults.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }
    return parts.join(' | ');
  }

  String toFull() =>
      '濮濄儵顎?${stepIndex + 1}閵?stepDesc閵? ${success ? "閴?$summary" : "閴?$summary"}';
}

// 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?// Agent Service 閳?Plan-Execute + ReAct 濞ｅ嘲鎮庨弸鑸电€?//
// Phase 1 (Plan):   AI 閸掑棙鐎芥禒璇插 閳?閻㈢喐鍨氬銉╊€冮崚妤勩€?// Phase 2 (Execute): 濮ｅ繑顒為悪顒傜彌 ReAct 鐎涙劕鎯婇悳?(Reason 閳?Act 閳?Observe)
// Phase 3 (Synthesize): 濮瑰洦鈧粯澧嶉張澶嬵劄妤犮倗绮ㄩ弸?閳?閻㈢喐鍨氶張鈧紒鍫濇礀婢?// 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
class AgentService {
  final AIService _aiService;
  final ToolRegistry _toolRegistry;
  final ContextManager _contextManager;
  final AgentPromptBuilder _promptBuilder;
  final AgentPlanningPromptBuilder _planningPromptBuilder;

  /// 閺堚偓婢堆嗗嚡娴狅絾顐奸弫?  static const int defaultMaxIterations = 10;

  /// 濮ｅ繋閲滅拋鈥冲灊濮濄儵顎冮惃鍕付婢?ReAct 鐎涙劘鍑禒锝嗩偧閺?  static const int maxSubIterationsPerStep = 5;

  AgentService({
    required AIService aiService,
    required ToolRegistry toolRegistry,
    required ContextManager contextManager,
  })  : _aiService = aiService,
        _toolRegistry = toolRegistry,
        _contextManager = contextManager,
        _promptBuilder = const AgentPromptBuilder(),
        _planningPromptBuilder = const AgentPlanningPromptBuilder();

  // 閳光偓閳光偓閳光偓 Public API 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓

  /// 缂傛牗甯?AI 鐠嬪啰鏁ら敍宀€绮潻?Agent 瀵邦亞骞?  Future<AIResponse> orchestrate({
    required String task,
    required AIFunction function,
    ModelTier tier = ModelTier.middle,
    String? systemPrompt,
    String? userPrompt,
    bool useCache = false,
    bool stream = false,
    double temperature = 1.0,
    int? maxTokens,
  }) {
    final prompt = userPrompt ?? task;
    return _aiService.generate(
      prompt: prompt,
      config: AIRequestConfig(
        function: function,
        systemPrompt: systemPrompt,
        userPrompt: prompt,
        overrideTier: tier,
        useCache: useCache,
        stream: stream,
        temperature: temperature,
        maxTokens: maxTokens,
      ),
    );
  }

  /// 閹笛嗩攽 Agent 娴犺濮熼敍鍦an-Execute + ReAct閿?  Stream<AgentEvent> run({
    required String task,
    required String workId,
    List<String>? allowedTools,
    int? maxIterations,
    ModelTier tier = ModelTier.middle,
    List<ChatMessage>? conversationHistory,
  }) {
    final controller = StreamController<AgentEvent>();
    final maxIter = maxIterations ?? defaultMaxIterations;

    _executePlanReActLoop(
      controller: controller,
      task: task,
      workId: workId,
      allowedTools: allowedTools,
      maxIterations: maxIter,
      tier: tier,
      conversationHistory: conversationHistory,
    );

    return controller.stream;
  }

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?  // Phase 1 + 2 + 3: Plan-Execute + ReAct main loop
  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
  Future<void> _executePlanReActLoop({
    required StreamController<AgentEvent> controller,
    required String task,
    required String workId,
    required List<String>? allowedTools,
    required int maxIterations,
    required ModelTier tier,
    required List<ChatMessage>? conversationHistory,
  }) async {
    try {
    final tools = AgentToolPolicy.getAvailableTools(
      _toolRegistry,
      allowedTools,
    );
      if (tools.isEmpty) {
        controller.add(AgentError('濞屸剝婀侀崣顖滄暏閻ㄥ嫬浼愰崗?));
        await controller.close();
        return;
      }

      final toolSchemas = tools.map((t) => t.toFunctionSchema()).toList();
      var currentWorkId = workId;

      // 閳光偓閳光偓閳光偓 Phase 1: Plan 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
      controller.add(AgentThinking('濮濓絽婀崚鍡樼€芥禒璇插楠炴儼顫夐崚鎺撳⒔鐞涘本顒炴?..'));

      final plan = await _generatePlan(task, tools, currentWorkId, tier);

      // 缁犫偓閸楁洑鎹㈤崝?閳?闂勫秶楠囨稉铏瑰嚱 ReAct
      if (plan.isEmpty ||
        (plan.length == 1 && AgentToolPolicy.isSimpleTask(plan.first, task))) {
        controller
            .add(AgentThinking('娴犺濮熸潏鍐暆閸楁洩绱濋惄瀛樺复閹笛嗩攽 (缁?ReAct 闂勫秶楠?'));
        await _executeReActFallback(
          controller: controller,
          task: task,
          workId: currentWorkId,
          tools: tools,
          toolSchemas: toolSchemas,
          maxIterations: maxIterations,
          tier: tier,
          conversationHistory: conversationHistory,
        );
        return;
      }

      controller.add(AgentPlan(plan.map((s) => s.description).toList()));

      // 閳光偓閳光偓閳光偓 Phase 2: Execute (parallel-capable + conditional reflection) 閳光偓
      int totalInputTokens = 0;
      int totalOutputTokens = 0;
      final observations = <_StepObservation>[];
      const maxStepRetries = 1;

      // Build dependency levels for parallel execution
      final levels = _buildDependencyLevels(plan);

      for (final level in levels) {
        if (level.length == 1) {
          // Single step 閳?execute directly
          final idx = level.first;
          final step = plan[idx];
          final result = await _executeOneStep(
            controller: controller,
            idx: idx,
            step: step,
            plan: plan,
            task: task,
            currentWorkId: currentWorkId,
            observations: observations,
            tools: tools,
            toolSchemas: toolSchemas,
            tier: tier,
            maxStepRetries: maxStepRetries,
            conversationHistory: idx == 0 ? conversationHistory : null,
          );
          totalInputTokens += result.inputTokens;
          totalOutputTokens += result.outputTokens;
          if (result.newWorkId != null) currentWorkId = result.newWorkId!;
          observations.add(result.observation);
        } else {
          // Multiple independent steps 閳?execute in parallel
          controller.add(AgentThinking(
            '楠炴儼顢戦幍褑顢?${level.length} 娑擃亞瀚粩瀣劄妤? ${level.map((i) => plan[i].description).join(", ")}',
          ));
          final futures = level.map((idx) => _executeOneStep(
            controller: controller,
            idx: idx,
            step: plan[idx],
            plan: plan,
            task: task,
            currentWorkId: currentWorkId,
            observations: observations,
            tools: tools,
            toolSchemas: toolSchemas,
            tier: tier,
            maxStepRetries: 0, // No reflection in parallel mode
            conversationHistory: null,
          )).toList();

          final results = await Future.wait(futures);
          for (final result in results) {
            totalInputTokens += result.inputTokens;
            totalOutputTokens += result.outputTokens;
            if (result.newWorkId != null) currentWorkId = result.newWorkId!;
            observations.add(result.observation);
          }
        }
      }

      // 閳光偓閳光偓閳光偓 Phase 3: Synthesize (with skip optimization) 閳光偓閳光偓閳光偓閳光偓
      // If last step already produced a good final answer, skip synthesis
      final lastObs = observations.last;
      final allSucceeded = observations.every((o) => o.success);
      String finalContent;

      if (allSucceeded && _isLastStepSynthesisCandidate(lastObs, plan.length)) {
        // Skip synthesis: last step's summary is good enough
        controller.add(AgentThinking('閹碘偓閺堝顒炴銈嗗灇閸旂噦绱濋惄瀛樺复娴ｈ法鏁ら張鈧紒鍫㈢波閺?));
        finalContent = lastObs.summary;
      } else {
        controller.add(AgentThinking('濮濓絽婀Ч鍥ㄢ偓鑽ょ波閺嬫粎鏁撻幋鎰付缂佸牆娲栨径?..'));
        final obsText = observations.map((o) => o.toCompact()).join('\n');
        var synthesisResponse = await _synthesize(
          task: task,
          plan: plan.map((s) => s.description).toList(),
          observations: [obsText],
          tier: tier,
        );
        totalInputTokens += synthesisResponse.inputTokens;
        totalOutputTokens += synthesisResponse.outputTokens;

        // 閳光偓閳光偓 Final Reflection (only if not all succeeded) 閳光偓閳光偓
        if (!allSucceeded) {
          final finalReflection = await _reflectOnSynthesis(
            task: task,
            plan: plan.map((s) => s.description).toList(),
            observations: observations.map((o) => o.toFull()).toList(),
            synthesis: synthesisResponse.content,
            tier: tier,
          );
          totalInputTokens += finalReflection.inputTokens;
          totalOutputTokens += finalReflection.outputTokens;

          controller.add(AgentReflection(
            target: '閺堚偓缂佸牏绮ㄩ弸?,
            passed: finalReflection.passed,
            evaluation: finalReflection.evaluation,
            feedback: finalReflection.feedback,
          ));

          if (!finalReflection.passed && finalReflection.feedback != null) {
            controller.add(AgentThinking('閸欏秵鈧繂褰傞悳棰佺瑝鐡掔绱濆锝呮躬鐞涖儱鍘栭幍褑顢?..'));
            final additionalSteps = await _generatePlanFromFeedback(
              originalTask: task,
              originalPlan: plan.map((s) => s.description).toList(),
              observations: observations.map((o) => o.toFull()).toList(),
              feedback: finalReflection.feedback!,
              tools: tools,
              workId: currentWorkId,
              tier: tier,
            );
            totalInputTokens += additionalSteps.inputTokens;
            totalOutputTokens += additionalSteps.outputTokens;

            if (additionalSteps.steps.isNotEmpty) {
              for (var j = 0; j < additionalSteps.steps.length; j++) {
                final extraStep = additionalSteps.steps[j];
                final extraIdx = plan.length + j;
                controller.add(AgentPlanStepStart(
                  stepIndex: extraIdx,
                  totalSteps: plan.length + additionalSteps.steps.length,
                  description: '[鐞涖儱鍘朷 $extraStep',
                ));
                controller.add(AgentThinking(
                  '閹笛嗩攽鐞涖儱鍘栧銉╊€?${j + 1}/${additionalSteps.steps.length}: $extraStep',
                ));
                final extraResult = await _executeStepReAct(
                  controller: controller,
                  stepTask: extraStep,
                  originalTask: task,
                  currentWorkId: currentWorkId,
                  compressedObservations: observations.map((o) => o.toCompact()).join('\n'),
                  tools: tools,
                  toolSchemas: toolSchemas,
                  tier: tier,
                  maxSubIterations: maxSubIterationsPerStep,
                  reflectionFeedback: finalReflection.feedback,
                );
                totalInputTokens += extraResult.inputTokens;
                totalOutputTokens += extraResult.outputTokens;
                if (extraResult.newWorkId != null) currentWorkId = extraResult.newWorkId!;
                observations.add(_StepObservation(
                  stepIndex: extraIdx,
                  stepDesc: extraStep,
                  success: extraResult.success,
                  summary: extraResult.summary,
                  keyResults: extraResult.keyResults,
                ));
                controller.add(AgentPlanStepComplete(
                  stepIndex: extraIdx,
                  success: extraResult.success,
                  summary: extraResult.summary,
                ));
              }
              // Re-synthesize
              synthesisResponse = await _synthesize(
                task: task,
                plan: [...plan.map((s) => s.description), ...additionalSteps.steps],
                observations: [observations.map((o) => o.toCompact()).join('\n')],
                tier: tier,
              );
              totalInputTokens += synthesisResponse.inputTokens;
              totalOutputTokens += synthesisResponse.outputTokens;
            }
          }
        }

        finalContent = synthesisResponse.content;
      }

      controller.add(AgentResponse(
        content: finalContent,
        iterations: observations.length,
        totalInputTokens: totalInputTokens,
        totalOutputTokens: totalOutputTokens,
      ));

      await controller.close();
    } catch (e) {
      controller.add(AgentError('Agent 閹笛嗩攽闁挎瑨顕? $e'));
      await controller.close();
    }
  }

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?  // Phase 1 Helper: Generate plan
  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
  Future<List<_PlanStep>> _generatePlan(
    String task,
    List<ToolDefinition> tools,
    String workId,
    ModelTier tier,
  ) async {
    final toolNames = tools.map((t) => t.name).toSet();

    try {
      final userPrompt = _planningPromptBuilder.buildPlanUserPrompt(
        task: task,
        tools: tools,
        workId: workId,
      );

      final response = await _aiService.generate(
        prompt: userPrompt,
        config: AIRequestConfig(
          function: AIFunction.chat,
          overrideTier: tier,
          systemPrompt: _planningPromptBuilder.buildPlanSystemPrompt(),
          userPrompt: userPrompt,
          useCache: false,
          stream: false,
          temperature: 0.3,
        ),
      );

      final content = response.content.trim();
      final jsonSteps = AgentResponseParser.tryParseJsonPlan(
        content,
        toolNames,
      );
      if (jsonSteps != null && jsonSteps.isNotEmpty) {
        return jsonSteps
            .map(
              (step) => _PlanStep(
                description: step.description,
                dependsOn: step.dependsOn,
                suggestedTool: step.suggestedTool,
              ),
            )
            .toList();
      }

      return AgentResponseParser.parseTextPlan(
        content,
      ).map((step) => _PlanStep(description: step)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<_StepResult> _executeStepReAct({
    required StreamController<AgentEvent> controller,
    required String stepTask,
    required String originalTask,
    required String currentWorkId,
    required String compressedObservations,
    required List<ToolDefinition> tools,
    required List<Map<String, dynamic>> toolSchemas,
    required ModelTier tier,
    required int maxSubIterations,
    String? reflectionFeedback,
    List<ChatMessage>? conversationHistory,
  }) async {
    var effectiveWorkId = currentWorkId;
    final messages = <ChatMessage>[];
    final keyResults = <String, String>{};
    var stepIdx = -1; // Caller sets via observation

    // System prompt for this step
    messages.add(ChatMessage(
      role: 'system',
        content: _promptBuilder.buildStepSystemPrompt(
          tools,
          effectiveWorkId,
          stepTask,
        ),
    ));

    // Add conversation history for first step
    if (conversationHistory != null) {
      for (final msg in conversationHistory) {
        if (msg.role != 'system') messages.add(msg);
      }
    }

    // Step user message with compressed observations
    final stepMsg = StringBuffer();
    stepMsg.writeln('閸樼喍鎹㈤崝? $originalTask');
    stepMsg.writeln('瑜版挸澧犲銉╊€? $stepTask');
    if (compressedObservations.isNotEmpty) {
      stepMsg.writeln('\n瀹告彃鐣幋鎰畱濮濄儵顎?(閹芥顩?:');
      stepMsg.writeln(compressedObservations);
    }
    // Reflection feedback for retry
    if (reflectionFeedback != null && reflectionFeedback.isNotEmpty) {
      stepMsg.writeln('\n閳?閸欏秵鈧繂寮芥＃鍫礄娑撳﹥顐奸幍褑顢戞稉宥堝喕娑斿顦╅敍?');
      stepMsg.writeln(reflectionFeedback);
      stepMsg.writeln('鐠囬攱鐗撮幑顔讳簰娑撳﹤寮芥＃鍫熸暭鏉╂稒澧界悰灞烩偓?);
    }
    messages.add(ChatMessage(role: 'user', content: stepMsg.toString()));

    int inputTokens = 0;
    int outputTokens = 0;
    String stepSummary = '';

    for (var i = 0; i < maxSubIterations; i++) {
      final response = await _runAgentTurn(
        controller: controller,
        messages: messages,
        toolSchemas: toolSchemas,
        tier: tier,
      );
      inputTokens += response.inputTokens;
      outputTokens += response.outputTokens;

      if (response.toolCalls.isNotEmpty) {
        final processed = await _processToolCalls(
          response: response,
          controller: controller,
          messages: messages,
          currentWorkId: effectiveWorkId,
        );
        effectiveWorkId = processed.currentWorkId;
        keyResults.addAll(processed.keyResults);
      } else {
        // No tool call 閳?step complete
        stepSummary = response.content;
        break;
      }

      if (i == maxSubIterations - 1 && stepSummary.isEmpty) {
        stepSummary = '濮濄儵顎冩潏鎯у煂閺堚偓婢堆冪摍鏉╊厺鍞▎鈩冩殶 ($maxSubIterations)';
      }
    }

    return _StepResult(
      success: stepSummary.isNotEmpty,
      summary: stepSummary.isNotEmpty ? stepSummary : '濮濄儵顎冪€瑰本鍨?,
      newWorkId:
          effectiveWorkId != currentWorkId ? effectiveWorkId : null,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      keyResults: keyResults,
      observation: _StepObservation(
        stepIndex: stepIdx,
        stepDesc: stepTask,
        success: stepSummary.isNotEmpty,
        summary: stepSummary.isNotEmpty ? stepSummary : '濮濄儵顎冪€瑰本鍨?,
        keyResults: Map.from(keyResults),
      ),
    );
  }

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?  // Phase 3 Helper: Synthesize final response
  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
  Future<AIResponse> _synthesize({
    required String task,
    required List<String> plan,
    required List<String> observations,
    required ModelTier tier,
  }) async {
    final userPrompt = _planningPromptBuilder.buildSynthesisUserPrompt(
      task: task,
      plan: plan,
      observations: observations,
    );

    return _aiService.generate(
      prompt: userPrompt,
      config: AIRequestConfig(
        function: AIFunction.chat,
        overrideTier: tier,
        systemPrompt: _planningPromptBuilder.buildSynthesisSystemPrompt(),
        userPrompt: userPrompt,
        useCache: false,
        stream: false,
        temperature: 0.3,
      ),
    );
  }

  // Reflection Helpers
  Future<_ReflectionResult> _reflectOnStep({
    required String stepTask,
    required String stepResult,
    required bool stepSuccess,
    required ModelTier tier,
  }) async {
    final userPrompt = _planningPromptBuilder.buildStepReflectionUserPrompt(
      stepTask: stepTask,
      stepResult: stepResult,
      stepSuccess: stepSuccess,
    );

    return _doReflect(target: 'step', userPrompt: userPrompt, tier: tier);
  }

  Future<_ReflectionResult> _reflectOnSynthesis({
    required String task,
    required List<String> plan,
    required List<String> observations,
    required String synthesis,
    required ModelTier tier,
  }) async {
    final userPrompt =
        _planningPromptBuilder.buildSynthesisReflectionUserPrompt(
      task: task,
      plan: plan,
      observations: observations,
      synthesis: synthesis,
    );

    return _doReflect(
      target: 'synthesis',
      userPrompt: userPrompt,
      tier: tier,
    );
  }

  Future<_ReflectionResult> _doReflect({
    required String target,
    required String userPrompt,
    required ModelTier tier,
  }) async {
    try {
      final response = await _aiService.generate(
        prompt: userPrompt,
        config: AIRequestConfig(
          function: AIFunction.chat,
          overrideTier: tier,
          systemPrompt: _planningPromptBuilder.reflectSystemPrompt,
          userPrompt: userPrompt,
          useCache: false,
          stream: false,
          temperature: 0.1,
        ),
      );

      final content = response.content.trim();
      final parsed = AgentResponseParser.parseReflection(content);

      return _ReflectionResult(
        passed: parsed.passed,
        evaluation: parsed.evaluation ?? content,
        feedback: parsed.feedback,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
      );
    } catch (_) {
      return _ReflectionResult(
        passed: true,
        evaluation: 'Reflection skipped because the reviewer call failed.',
        feedback: null,
        inputTokens: 0,
        outputTokens: 0,
      );
    }
  }

  /// Generate additional steps from final reflection feedback/// Generate additional steps from final reflection feedback
  Future<_AdditionalPlanResult> _generatePlanFromFeedback({
    required String originalTask,
    required List<String> originalPlan,
    required List<String> observations,
    required String feedback,
    required List<ToolDefinition> tools,
    required String workId,
    required ModelTier tier,
  }) async {
    try {
      final userPrompt = _planningPromptBuilder.buildAdditionalPlanUserPrompt(
        originalTask: originalTask,
        originalPlan: originalPlan,
        observations: observations,
        feedback: feedback,
        tools: tools,
        workId: workId,
      );

      final response = await _aiService.generate(
        prompt: userPrompt,
        config: AIRequestConfig(
          function: AIFunction.chat,
          overrideTier: tier,
          systemPrompt: _planningPromptBuilder.buildAdditionalPlanSystemPrompt(),
          userPrompt: userPrompt,
          useCache: false,
          stream: false,
          temperature: 0.3,
        ),
      );

      final content = response.content.trim();
      if (content.toUpperCase() == 'NONE') {
        return _AdditionalPlanResult(
          steps: [],
          inputTokens: response.inputTokens,
          outputTokens: response.outputTokens,
        );
      }

      final steps = AgentResponseParser.parseTextPlan(content);

      return _AdditionalPlanResult(
        steps: steps,
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
      );
    } catch (_) {
      return _AdditionalPlanResult(steps: [], inputTokens: 0, outputTokens: 0);
    }
  }

  // Fallback: Pure ReAct (for simple tasks)
  Future<void> _executeReActFallback({
    required StreamController<AgentEvent> controller,
    required String task,
    required String workId,
    required List<ToolDefinition> tools,
    required List<Map<String, dynamic>> toolSchemas,
    required int maxIterations,
    required ModelTier tier,
    List<ChatMessage>? conversationHistory,
  }) async {
    var currentWorkId = workId;
    final messages = <ChatMessage>[];

    messages.add(ChatMessage(
      role: 'system',
        content: _promptBuilder.buildSystemPrompt(tools, currentWorkId),
    ));

    if (conversationHistory != null) {
      for (final msg in conversationHistory) {
        if (msg.role != 'system') messages.add(msg);
      }
    }

    messages.add(ChatMessage(role: 'user', content: task));

    int totalInputTokens = 0;
    int totalOutputTokens = 0;

    for (var i = 0; i < maxIterations; i++) {
      final response = await _runAgentTurn(
        controller: controller,
        messages: messages,
        toolSchemas: toolSchemas,
        tier: tier,
      );
      totalInputTokens += response.inputTokens;
      totalOutputTokens += response.outputTokens;

      if (response.toolCalls.isNotEmpty) {
        final processed = await _processToolCalls(
          response: response,
          controller: controller,
          messages: messages,
          currentWorkId: currentWorkId,
        );
        currentWorkId = processed.currentWorkId;
      } else {
        controller.add(AgentResponse(
          content: response.content,
          iterations: i + 1,
          totalInputTokens: totalInputTokens,
          totalOutputTokens: totalOutputTokens,
        ));
        await controller.close();
        return;
      }
    }

    controller.add(
        AgentError('鏉堟儳鍩岄張鈧径褑鍑禒锝嗩偧閺?($maxIterations)閿涘奔鎹㈤崝鈥冲讲閼宠姤婀€瑰本鍨?));
    await controller.close();
  }

  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?  // AI call + System prompts
  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
  /// 鐠嬪啰鏁?AI閿涘牅濞囬悽銊ュ斧閻?tool calling閿?  Future<AIResponse> _callAI(
    List<ChatMessage> messages,
    List<Map<String, dynamic>> toolSchemas,
    ModelTier tier,
  ) async {
    final bundle = AgentMessageFormatter.bundle(messages);

    final response = await _aiService.generateWithTools(
      prompt: bundle.userMessage,
      config: AIRequestConfig(
        function: AIFunction.chat,
        systemPrompt: bundle.systemMessage,
        userPrompt: bundle.userMessage,
        useCache: false,
        stream: false,
        temperature: 0.1,
      ),
      tools: toolSchemas,
    );

    if (response.toolCalls.isNotEmpty ||
        toolSchemas.isEmpty ||
        !bundle.isSingleUserMessage) {
      return response;
    }

    final retryResponse = await _aiService.generateWithTools(
      prompt: bundle.userMessage,
      config: AIRequestConfig(
        function: AIFunction.chat,
        systemPrompt:
            '${bundle.systemMessage}\nWhen the request can be handled by an available tool, you must return a tool call instead of prose. Do not ask follow-up questions if the required arguments are already present.',
        userPrompt: bundle.userMessage,
        useCache: false,
        stream: false,
        temperature: 0.1,
      ),
      tools: toolSchemas,
    );

    return retryResponse.toolCalls.isNotEmpty ? retryResponse : response;
  }

  Future<AIResponse> _runAgentTurn({
    required StreamController<AgentEvent> controller,
    required List<ChatMessage> messages,
    required List<Map<String, dynamic>> toolSchemas,
    required ModelTier tier,
  }) async {
    if (messages.length > 4 && _contextManager.needsCompact(messages, '')) {
      final compacted = await _contextManager.compact(
        messages: messages,
        modelName: '',
      );
      messages
        ..clear()
        ..addAll(compacted.recent);
    }

    final response = await _callAI(messages, toolSchemas, tier);
    messages.add(ChatMessage(role: 'assistant', content: response.content));

    if (response.thinking != null && response.thinking!.trim().isNotEmpty) {
      controller.add(AgentThinking(response.thinking!.trim()));
    }

    return response;
  }


  Future<_ToolCallProcessingResult> _processToolCalls({
    required AIResponse response,
    required StreamController<AgentEvent> controller,
    required List<ChatMessage> messages,
    required String currentWorkId,
  }) async {
    var effectiveWorkId = currentWorkId;
    final keyResults = <String, String>{};

    if (response.content.trim().isNotEmpty) {
      controller.add(AgentThinking(response.content.trim()));
    }

    for (final toolCall in response.toolCalls) {
      controller.add(AgentAction(toolCall.name, toolCall.arguments));
      controller.add(AgentThinking('执行工具: ${toolCall.name}'));

      final execution = await AgentToolExecutor.execute(
        toolRegistry: _toolRegistry,
        toolCall: toolCall,
        currentWorkId: effectiveWorkId,
      );
      controller.add(AgentObservation(execution.result));
      effectiveWorkId = execution.currentWorkId;
      keyResults.addAll(execution.keyResults);

      messages.add(ChatMessage(
        role: 'tool',
        content: execution.toolMessage,
        toolCallId: toolCall.id,
      ));
    }

    return _ToolCallProcessingResult(
      currentWorkId: effectiveWorkId,
      keyResults: keyResults,
    );
  }

  /// 閺嬪嫬缂?step 閹笛嗩攽閻?system prompt
  // Helpers
  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
  /// 閼惧嘲褰囬崣顖滄暏瀹搞儱鍙块崚妤勩€?  
  // Optimization Helpers
  // 閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡?
  /// 閺嬪嫬缂撴笟婵婄鐏炲倻楠囬敍鍫熷珖閹垫垶甯撴惔蹇ョ礆閿涘矁绻戦崶?List<List<stepIndex>>
  /// 閸氬奔绔寸仦鍌滈獓閻ㄥ嫭顒炴銈呭讲楠炴儼顢戦幍褑顢?  List<List<int>> _buildDependencyLevels(List<_PlanStep> plan) =>
      _buildDependencyLevelsHelper(plan);

Future<_StepResult> _executeOneStep({
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
  }) =>
      _executeOneStepHelper(
        controller: controller,
        idx: idx,
        step: step,
        plan: plan,
        task: task,
        currentWorkId: currentWorkId,
        observations: observations,
        tools: tools,
        toolSchemas: toolSchemas,
        tier: tier,
        maxStepRetries: maxStepRetries,
        conversationHistory: conversationHistory,
      );

static bool _needsReflection(_StepResult result) =>
      _needsStepReflection(result);

static bool _isLastStepSynthesisCandidate(_StepObservation lastObs, int planLength) =>
      _isLastStepSynthesisCandidateHelper(lastObs, planLength);
}
