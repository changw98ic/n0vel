import 'dart:convert';

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
      if (sceneDescription != null && sceneDescription.trim().isNotEmpty) {
        return WorkflowTemplates.dialogueGeneration(
          sceneDescription: sceneDescription,
          workId: workId,
          characterProfiles: config['characterProfiles'] as String? ?? '',
          contextContent: config['contextContent'] as String? ?? '',
        );
      }
      break;
    case 'extract':
      final textContent = config['textContent'] as String?;
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
