import 'dart:convert';

import '../domain/workflow_models.dart';
import 'workflow_execution_service.dart';
import 'workflow_repository.dart';

class WorkflowTaskRunner {
  final WorkflowRepository _workflowRepository;
  final WorkflowExecutionService _workflowExecutionService;

  WorkflowTaskRunner({
    required WorkflowRepository workflowRepository,
    required WorkflowExecutionService workflowExecutionService,
  }) : _workflowRepository = workflowRepository,
       _workflowExecutionService = workflowExecutionService;

  Future<WorkflowTaskSummary?> getStatus(String taskId) {
    return _workflowRepository.getTaskById(taskId);
  }

  Future<List<WorkflowTaskSummary>> getTasksByWorkId(String workId) {
    return _workflowRepository.getTasksByWorkId(workId);
  }

  Future<String> startTask({
    required String workId,
    required String name,
    required String type,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) async {
    final taskId = await _workflowRepository.createTask(
      workId: workId,
      name: name,
      type: type,
      config: config,
    );
    await _workflowExecutionService.executeTask(taskId);
    return taskId;
  }

  Future<WorkflowClarificationRequest?> getPendingClarification(
    String taskId,
  ) {
    return _workflowRepository.getPendingClarification(taskId);
  }

  Future<void> submitClarificationAnswers({
    required String taskId,
    required String nodeId,
    required Map<String, dynamic> answers,
    bool resume = true,
  }) async {
    await _workflowRepository.submitClarificationAnswers(
      taskId: taskId,
      nodeId: nodeId,
      answers: answers,
      resume: resume,
    );

    if (resume) {
      await _workflowExecutionService.executeTask(taskId);
    }
  }

  Future<void> submitReviewDecision({
    required String taskId,
    required bool approved,
    bool resume = true,
  }) async {
    await _workflowRepository.submitReviewDecision(
      taskId: taskId,
      approved: approved,
      resume: resume,
    );

    if (resume) {
      await _workflowExecutionService.executeTask(taskId);
    }
  }

  Future<Map<String, dynamic>?> getDecodedResult(String taskId) async {
    final task = await _workflowRepository.getRawTaskById(taskId);
    final raw = task?.result;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return null;
    }
  }

  Future<String> getDisplayText(String taskId) async {
    final task = await _workflowRepository.getRawTaskById(taskId);
    final result = await getDecodedResult(taskId);
    if (task == null || result == null) {
      return '';
    }

    final variablesValue = result['variables'];
    final variables = variablesValue is Map
        ? Map<String, dynamic>.from(variablesValue)
        : <String, dynamic>{};

    switch (task.type) {
      case 'generate':
        return _firstNonBlank(<dynamic>[
          variables['revision_suggestions'],
          variables['continuation_draft'],
          result['output'],
        ]);
      case 'dialogue':
        return _firstNonBlank(<dynamic>[
          variables['dialogue_final'],
          variables['dialogue_draft'],
          result['output'],
        ]);
      case 'plot':
        return _firstNonBlank(<dynamic>[
          variables['plotSuggestions'],
          result['output'],
        ]);
      case 'custom_prompt':
        return _firstNonBlank(<dynamic>[
          variables['customPromptResult'],
          result['output'],
        ]);
      case 'character_simulation':
        return _firstNonBlank(<dynamic>[
          variables['characterSimulationResult'],
          result['output'],
        ]);
      case 'extract':
        return _firstNonBlank(<dynamic>[
          variables['extraction_summary'],
          variables['relationships'],
          result['output'],
        ]);
      case 'review':
        return _firstNonBlank(<dynamic>[
          variables['review_summary'],
          result['analysis'],
          result['output'],
        ]);
      default:
        return _firstNonBlank(<dynamic>[
          result['output'],
          result['analysis'],
        ]);
    }
  }
}

String _firstNonBlank(List<dynamic> candidates) {
  for (final candidate in candidates) {
    final text = candidate?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}
