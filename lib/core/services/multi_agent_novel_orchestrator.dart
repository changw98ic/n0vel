import 'ai/agent/agent_service.dart';
import 'ai/models/model_tier.dart';
import 'writer_guidance_loader.dart';

class ParallelAgentTask {
  final String id;
  final String prompt;
  final String? systemPrompt;
  final AIFunction function;
  final ModelTier tier;

  const ParallelAgentTask({
    required this.id,
    required this.prompt,
    this.systemPrompt,
    this.function = AIFunction.continuation,
    this.tier = ModelTier.middle,
  });
}

class ParallelAgentResult {
  final String id;
  final String content;

  const ParallelAgentResult({required this.id, required this.content});
}

class MultiAgentNovelOrchestrator {
  final AgentService _agentService;
  final WriterGuidanceLoader _guidanceLoader;

  MultiAgentNovelOrchestrator({
    required AgentService agentService,
    WriterGuidanceLoader? guidanceLoader,
  }) : _agentService = agentService,
       _guidanceLoader = guidanceLoader ?? WriterGuidanceLoader();

  /// 并行执行多个独立任务
  Future<List<ParallelAgentResult>> runParallel(
    List<ParallelAgentTask> tasks, {
    String? teamId,
  }) async {
    final teamGuidance = teamId == null
        ? ''
        : await _guidanceLoader.loadTeamGuidance(teamId);
    final futures = tasks.map((task) async {
      final response = await _agentService.orchestrate(
        task: task.prompt,
        function: task.function,
        tier: task.tier,
        systemPrompt: _mergeSystemPrompt(task.systemPrompt, teamGuidance),
      );
      return ParallelAgentResult(id: task.id, content: response.content);
    });

    return Future.wait(futures);
  }

  /// 顺序管道：前一个任务的输出作为后一个任务的输入
  /// 每个任务的 prompt 可用 {previous_output} 占位符引用前序结果
  Future<List<ParallelAgentResult>> runSequential(
    List<ParallelAgentTask> tasks, {
    String? teamId,
  }) async {
    final teamGuidance = teamId == null
        ? ''
        : await _guidanceLoader.loadTeamGuidance(teamId);
    final results = <ParallelAgentResult>[];
    String? previousOutput;

    for (final task in tasks) {
      var prompt = task.prompt;
      if (previousOutput != null) {
        prompt = prompt.replaceAll('{previous_output}', previousOutput);
      }

      final response = await _agentService.orchestrate(
        task: prompt,
        function: task.function,
        tier: task.tier,
        systemPrompt: _mergeSystemPrompt(task.systemPrompt, teamGuidance),
      );

      final result = ParallelAgentResult(id: task.id, content: response.content);
      results.add(result);
      previousOutput = response.content;
    }

    return results;
  }

  /// Map-Reduce：并行执行多个子任务，再用一个聚合任务合并结果
  Future<ParallelAgentResult> runMapReduce({
    required List<ParallelAgentTask> mapTasks,
    required String aggregationPrompt,
    AIFunction aggregationFunction = AIFunction.chat,
    ModelTier aggregationTier = ModelTier.middle,
    String? teamId,
  }) async {
    // Map: 并行执行
    final mapResults = await runParallel(mapTasks, teamId: teamId);

    // Reduce: 聚合
    final reducedInput = StringBuffer();
    for (final result in mapResults) {
      reducedInput.writeln('### ${result.id}');
      reducedInput.writeln(result.content);
      reducedInput.writeln();
    }

    final teamGuidance = teamId == null
        ? ''
        : await _guidanceLoader.loadTeamGuidance(teamId);
    final finalPrompt = aggregationPrompt.replaceAll(
      '{map_results}',
      reducedInput.toString().trim(),
    );

    final response = await _agentService.orchestrate(
      task: finalPrompt,
      function: aggregationFunction,
      tier: aggregationTier,
      systemPrompt: _mergeSystemPrompt(null, teamGuidance),
    );

    return ParallelAgentResult(id: 'aggregated', content: response.content);
  }

  String? _mergeSystemPrompt(String? base, String extra) {
    final trimmedExtra = extra.trim();
    if (trimmedExtra.isEmpty) {
      return base;
    }
    final trimmedBase = base?.trim();
    if (trimmedBase == null || trimmedBase.isEmpty) {
      return trimmedExtra;
    }
    return '$trimmedBase\n\n$trimmedExtra';
  }
}
