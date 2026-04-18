import 'dart:convert';

import '../../../core/services/ai/models/model_tier.dart';
import '../../../core/services/workflow_service.dart';
import '../../../core/services/workflow_templates.dart';
import 'workflow_repository.dart';

List<WorkflowNode> buildWorkflowNodes({
  required String taskType,
  required String workId,
  required Map<String, dynamic> config,
}) {
  switch (taskType) {
    case 'review':
      final chapterContents = _readStringMap(config['chapterContents']);
      if (chapterContents.length > 1) {
        return WorkflowTemplates.batchReview(
          chapterContents: chapterContents,
          workId: workId,
        );
      }
      final chapterContent = config['chapterContent'] as String?;
      if (chapterContent != null && chapterContent.trim().isNotEmpty) {
        return WorkflowTemplates.reviewPipeline(
          chapterContent: chapterContent,
          workId: workId,
        );
      }
      return <WorkflowNode>[
        DataNode(
          id: 'prepare',
          name: 'Prepare Task',
          index: 0,
          processor: (context) {
            context.set('prepared', true);
          },
        ),
        AINode(
          id: 'analyze',
          name: 'Analyze Content',
          index: 1,
          promptTemplate: 'Analyze workflow task {taskId}',
          outputVariable: 'analysisResult',
          function: AIFunction.review,
        ),
        DataNode(
          id: 'finalize',
          name: 'Finalize Result',
          index: 2,
          processor: (context) {
            context.set('finalResult', <String, dynamic>{
              'taskId': context.get<String>('taskId'),
              'taskType': context.get<String>('taskType'),
              'analysis': context.get<dynamic>('analysisResult'),
              'chapterIds':
                  (context.get<Map<String, dynamic>>('config')?['chapterIds']
                      as List<dynamic>?) ??
                  const <dynamic>[],
            });
          },
        ),
      ];
    case 'generate':
      final previousContent = config['previousContent'] as String?;
      final continuationRequest = config['continuationRequest'] as String?;
      if (_isBlank(previousContent) || _isBlank(continuationRequest)) {
        return _buildClarificationOnlyFlow(
          id: 'collect_generate_inputs',
          name: '补充续写信息',
          prompt: '继续执行章节续写前，需要先补充关键信息。',
          questions: <String>[
            '请提供前文内容或至少概述当前章节前的关键情节。',
            '请说明这次续写希望发生什么，重点事件或推进方向是什么。',
          ],
          requiredFields: <String>[
            'previousContent',
            'continuationRequest',
          ],
        );
      }
      if (previousContent != null &&
          previousContent.trim().isNotEmpty &&
          continuationRequest != null &&
          continuationRequest.trim().isNotEmpty) {
        return WorkflowTemplates.continuationWithReview(
          previousContent: previousContent,
          continuationRequest: continuationRequest,
          writingStyle: config['writingStyle'] as String? ?? '',
          targetWords: (config['targetWords'] as num?)?.toInt() ?? 2000,
        );
      }
      break;
    case 'dialogue':
      final sceneDescription = config['sceneDescription'] as String?;
      if (_isBlank(sceneDescription)) {
        return _buildClarificationOnlyFlow(
          id: 'collect_dialogue_inputs',
          name: '补充对话场景',
          prompt: '生成对话前，需要先补充场景描述。',
          questions: <String>[
            '这段对话发生在什么场景？请描述时间、地点、人物和核心冲突。',
          ],
          requiredFields: <String>['sceneDescription'],
        );
      }
      if (sceneDescription != null && sceneDescription.trim().isNotEmpty) {
        return WorkflowTemplates.dialogueGeneration(
          sceneDescription: sceneDescription,
          workId: workId,
          characterProfiles: config['characterProfiles'] as String? ?? '',
          contextContent: config['contextContent'] as String? ?? '',
        );
      }
      break;
    case 'plot':
      final chapterContent = config['chapterContent'] as String?;
      final promptText = config['promptText'] as String? ?? '';
      if (_isBlank(chapterContent)) {
        return _buildClarificationOnlyFlow(
          id: 'collect_plot_inputs',
          name: '补充剧情上下文',
          prompt: '生成剧情灵感前，需要先提供当前章节或场景内容。',
          questions: <String>[
            '请提供当前章节内容，或至少描述当前剧情发展到哪里。',
          ],
          requiredFields: <String>['chapterContent'],
        );
      }
      return <WorkflowNode>[
        AINode(
          id: 'plot_inspiration',
          name: '剧情灵感生成',
          index: 0,
          promptTemplate: '你是一位小说剧情策划编辑。请基于以下章节内容，提供 3 到 5 个可执行的剧情方向建议。\n\n'
              '要求：\n'
              '- 每个方向都要说明核心冲突或推进点\n'
              '- 尽量避免空泛建议，直接给出可写的事件或转折\n'
              '- 保持与当前章节气质一致\n\n'
              '${promptText.trim().isNotEmpty ? "额外要求：\n$promptText\n\n" : ""}'
              '当前章节内容：\n$chapterContent',
          outputVariable: 'plotSuggestions',
          modelTier: 'middle',
          function: AIFunction.chat,
        ),
      ];
    case 'custom_prompt':
      final promptText = config['promptText'] as String?;
      final chapterContext = config['chapterContent'] as String? ?? '';
      if (_isBlank(promptText)) {
        return _buildClarificationOnlyFlow(
          id: 'collect_custom_prompt_inputs',
          name: '补充自定义指令',
          prompt: '执行自定义指令前，需要先填写 prompt。',
          questions: <String>[
            '请填写你希望 AI 执行的自定义指令。',
          ],
          requiredFields: <String>['promptText'],
        );
      }
      return <WorkflowNode>[
        AINode(
          id: 'custom_prompt_execute',
          name: '执行自定义指令',
          index: 0,
          promptTemplate: '你是一位专业的小说写作助手。请执行以下自定义指令，并结合当前章节内容给出结果。\n\n'
              '自定义指令：\n$promptText\n\n'
              '${chapterContext.trim().isNotEmpty ? "当前章节内容：\n$chapterContext\n" : ""}',
          outputVariable: 'customPromptResult',
          modelTier: 'middle',
          function: AIFunction.chat,
        ),
      ];
    case 'character_simulation':
      final chapterContent = config['chapterContent'] as String?;
      if (_isBlank(chapterContent)) {
        return _buildClarificationOnlyFlow(
          id: 'collect_character_simulation_inputs',
          name: '补充角色模拟上下文',
          prompt: '模拟角色反应前，需要先提供章节上下文。',
          questions: <String>[
            '请提供当前章节内容，或至少描述角色所处情境和刚刚发生的事件。',
          ],
          requiredFields: <String>['chapterContent'],
        );
      }
      return <WorkflowNode>[
        AINode(
          id: 'character_simulation',
          name: '角色模拟',
          index: 0,
          promptTemplate: '请根据以下章节内容，模拟主要角色在当前情境下最可能的反应、心理活动和下一步行为。\n\n'
              '要求：\n'
              '- 优先保持角色设定一致\n'
              '- 说明角色为什么会这样反应\n'
              '- 给出可直接用于写作的具体建议或片段\n\n'
              '当前章节内容：\n$chapterContent',
          outputVariable: 'characterSimulationResult',
          modelTier: 'thinking',
          function: AIFunction.characterSimulation,
        ),
      ];
    case 'extract':
      final textContent = config['textContent'] as String?;
      if (_isBlank(textContent)) {
        return _buildClarificationOnlyFlow(
          id: 'collect_extract_inputs',
          name: '补充提取源文本',
          prompt: '执行设定提取前，需要先提供源文本。',
          questions: <String>[
            '请提供需要提取设定的正文、片段或章节内容。',
          ],
          requiredFields: <String>['textContent'],
        );
      }
      if (textContent != null && textContent.trim().isNotEmpty) {
        return WorkflowTemplates.extractionPipeline(
          textContent: textContent,
          workId: workId,
        );
      }
      break;
    default:
      break;
    }

  return <WorkflowNode>[
    DataNode(
      id: 'prepare',
      name: 'Prepare Task',
      index: 0,
      processor: (context) => context.set('prepared', true),
    ),
    AINode(
      id: 'execute',
      name: 'Execute Task',
      index: 1,
      promptTemplate: 'Execute workflow task {taskId}',
      outputVariable: 'executionResult',
      function: _defaultFunctionForTaskType(taskType),
    ),
    DataNode(
      id: 'finalize',
      name: 'Finalize Result',
      index: 2,
      processor: (context) {
        context.set('finalResult', <String, dynamic>{
          'taskId': context.get<String>('taskId'),
          'taskType': context.get<String>('taskType'),
          'output': context.get<dynamic>('executionResult'),
        });
      },
    ),
  ];
}

class WorkflowExecutionService {
  final WorkflowRepository _repository;
  final WorkflowService _workflowService;

  WorkflowExecutionService({
    required WorkflowRepository repository,
    required WorkflowService workflowService,
  }) : _repository = repository,
       _workflowService = workflowService;

  Future<void> executeTask(String taskId) async {
    final task = await _repository.getRawTaskById(taskId);
    if (task == null) {
      throw StateError('Task not found: $taskId');
    }

    final config = Map<String, dynamic>.from(
      await _repository.getTaskConfig(taskId) ?? <String, dynamic>{},
    );
    final context = WorkflowContext(
      taskId: taskId,
      variables: <String, dynamic>{
        'taskId': taskId,
        'workId': task.workId,
        'taskType': task.type,
        'taskName': task.name,
        'config': config,
      },
    );
    await _restoreContextFromCheckpoint(taskId, context);

    final nodes = buildWorkflowNodes(
      taskType: task.type,
      workId: task.workId,
      config: config,
    );
    if (nodes.isEmpty) {
      throw StateError(
        'No workflow nodes configured for task type ${task.type}',
      );
    }

    await _repository.updateTaskExecution(
      taskId: taskId,
      status: 'running',
      progress: task.progress,
      currentNodeIndex: task.currentNodeIndex,
    );

    final summary = await _workflowService.run(
      nodes: nodes,
      context: context,
      startIndex: task.currentNodeIndex,
    );

    var totalInputTokens = 0;
    var totalOutputTokens = 0;

    for (final result in summary.results) {
      final node = nodes.firstWhere((entry) => entry.id == result.nodeId);
      totalInputTokens += result.inputTokens ?? 0;
      totalOutputTokens += result.outputTokens ?? 0;

      await _repository.recordNodeRun(
        taskId: taskId,
        nodeName: node.name,
        nodeIndex: node.index,
        status: result.status.name,
        inputSnapshot: jsonEncode(_safeEncode(summary.context.variables)),
        outputSnapshot: result.output == null
            ? null
            : jsonEncode(_safeEncode(result.output)),
        error: result.error,
        inputTokens: result.inputTokens ?? 0,
        outputTokens: result.outputTokens ?? 0,
      );
    }

    final finalResult = _buildFinalResult(task.type, summary.context);
    final finalStatus = switch (summary.status) {
      TaskStatus.completed => 'completed',
      TaskStatus.failed => 'failed',
      TaskStatus.paused => 'paused',
      TaskStatus.waitingReview => 'waitingReview',
      TaskStatus.waitingUserInput => 'waitingUserInput',
      TaskStatus.running => 'running',
      TaskStatus.pending => 'pending',
      TaskStatus.cancelled => 'cancelled',
    };

    await _repository.updateTaskExecution(
      taskId: taskId,
      status: finalStatus,
      progress: summary.status == TaskStatus.completed
          ? 1.0
          : _calculateProgress(nodes.length, summary.results.length),
      currentNodeIndex: summary.nextNodeIndex,
      result: jsonEncode(finalResult),
      errorMessage: summary.status == TaskStatus.failed
          ? summary.results.last.error
          : null,
      inputTokens: task.inputTokens + totalInputTokens,
      outputTokens: task.outputTokens + totalOutputTokens,
    );

    await _repository.createManualCheckpoint(
      taskId: taskId,
      nodeIndex: summary.nextNodeIndex,
      state: <String, dynamic>{
        'taskStatus': finalStatus,
        'context': _serializeContext(summary.context),
        'results': summary.results
            .map(
              (result) => <String, dynamic>{
                'nodeId': result.nodeId,
                'status': result.status.name,
                'output': _safeEncode(result.output),
                'error': result.error,
                'inputTokens': result.inputTokens ?? 0,
                'outputTokens': result.outputTokens ?? 0,
              },
            )
            .toList(),
      },
    );
  }

  Future<void> _restoreContextFromCheckpoint(
    String taskId,
    WorkflowContext context,
  ) async {
    final checkpoint = await _repository.getLatestCheckpoint(taskId);
    final rawState = checkpoint?.fullState;
    if (rawState == null || rawState.trim().isEmpty) {
      return;
    }

    try {
      final state = jsonDecode(rawState) as Map<String, dynamic>;
      final serializedContext = state['context'] as Map<String, dynamic>?;
      if (serializedContext == null) {
        return;
      }

      final variables =
          serializedContext['variables'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      context.variables.addAll(variables);

      final completedNodes =
          serializedContext['completedNodes'] as List<dynamic>? ?? const [];
      context.completedNodes
        ..clear()
        ..addAll(
          completedNodes
              .whereType<Map<String, dynamic>>()
              .map(
                (entry) => NodeResult(
                  nodeId: entry['nodeId'] as String? ?? '',
                  status: NodeStatus.values.firstWhere(
                    (status) => status.name == entry['status'],
                    orElse: () => NodeStatus.pending,
                  ),
                  output: entry['output'],
                  error: entry['error'] as String?,
                  inputTokens: (entry['inputTokens'] as num?)?.toInt(),
                  outputTokens: (entry['outputTokens'] as num?)?.toInt(),
                ),
              ),
        );
    } catch (_) {
      return;
    }
  }

  Map<String, dynamic> _serializeContext(WorkflowContext context) {
    return <String, dynamic>{
      'variables': _safeEncode(context.variables),
      'completedNodes': context.completedNodes
          .map(
            (result) => <String, dynamic>{
              'nodeId': result.nodeId,
              'status': result.status.name,
              'output': _safeEncode(result.output),
              'error': result.error,
              'inputTokens': result.inputTokens ?? 0,
              'outputTokens': result.outputTokens ?? 0,
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> _buildFinalResult(
    String taskType,
    WorkflowContext context,
  ) {
    final finalResult = context.get<Map<String, dynamic>>('finalResult');
    if (finalResult != null) {
      return finalResult;
    }
    return <String, dynamic>{
      'taskId': context.taskId,
      'taskType': taskType,
      'variables': _safeEncode(context.variables),
    };
  }

  double _calculateProgress(int totalNodes, int completedNodes) {
    if (totalNodes == 0) {
      return 0;
    }
    final value = completedNodes / totalNodes;
    return value.clamp(0.0, 1.0);
  }

  dynamic _safeEncode(dynamic value) {
    try {
      jsonEncode(value);
      return value;
    } catch (_) {
      return value.toString();
    }
  }
}

Map<String, String> _readStringMap(Object? raw) {
  if (raw is! Map) {
    return const <String, String>{};
  }
  return raw.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}

List<WorkflowNode> _buildClarificationOnlyFlow({
  required String id,
  required String name,
  required String prompt,
  required List<String> questions,
  required List<String> requiredFields,
}) {
  return <WorkflowNode>[
    ClarificationNode(
      id: id,
      name: name,
      index: 0,
      prompt: prompt,
      questions: questions,
      requiredFields: requiredFields,
      outputVariable: 'clarification_$id',
    ),
  ];
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

AIFunction _defaultFunctionForTaskType(String taskType) {
  switch (taskType) {
    case 'review':
      return AIFunction.review;
    case 'generate':
      return AIFunction.continuation;
    case 'dialogue':
      return AIFunction.dialogue;
    case 'plot':
      return AIFunction.chat;
    case 'custom_prompt':
      return AIFunction.chat;
    case 'character_simulation':
      return AIFunction.characterSimulation;
    case 'extract':
      return AIFunction.entityExtraction;
    default:
      return AIFunction.chat;
  }
}
