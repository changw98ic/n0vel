enum WorkflowTaskStatus {
  pending('Pending'),
  running('Running'),
  paused('Paused'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled');

  const WorkflowTaskStatus(this.label);

  final String label;

  static WorkflowTaskStatus fromName(String value) {
    return WorkflowTaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WorkflowTaskStatus.pending,
    );
  }
}

enum WorkflowRunStatus {
  pending('Pending'),
  running('Running'),
  completed('Completed'),
  failed('Failed'),
  skipped('Skipped'),
  waitingReview('Waiting Review'),
  approved('Approved'),
  rejected('Rejected');

  const WorkflowRunStatus(this.label);

  final String label;

  static WorkflowRunStatus fromStoredValue(String value) {
    final normalized = value.replaceAll('_', '');
    return WorkflowRunStatus.values.firstWhere(
      (status) => status.name.toLowerCase() == normalized.toLowerCase(),
      orElse: () => WorkflowRunStatus.pending,
    );
  }
}

class WorkflowTaskSummary {
  final String id;
  final String workId;
  final String name;
  final String type;
  final WorkflowTaskStatus status;
  final double progress;
  final int currentNodeIndex;
  final int inputTokens;
  final int outputTokens;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkflowTaskSummary({
    required this.id,
    required this.workId,
    required this.name,
    required this.type,
    required this.status,
    required this.progress,
    required this.currentNodeIndex,
    required this.inputTokens,
    required this.outputTokens,
    required this.errorMessage,
    required this.startedAt,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });
}

class WorkflowNodeRunRecord {
  final String id;
  final String taskId;
  final String nodeName;
  final int nodeIndex;
  final String branchId;
  final WorkflowRunStatus status;
  final int attempt;
  final String? inputSnapshot;
  final String? outputSnapshot;
  final String? error;
  final String? aiRequestId;
  final int inputTokens;
  final int outputTokens;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime createdAt;

  const WorkflowNodeRunRecord({
    required this.id,
    required this.taskId,
    required this.nodeName,
    required this.nodeIndex,
    required this.branchId,
    required this.status,
    required this.attempt,
    required this.inputSnapshot,
    required this.outputSnapshot,
    required this.error,
    required this.aiRequestId,
    required this.inputTokens,
    required this.outputTokens,
    required this.startedAt,
    required this.finishedAt,
    required this.createdAt,
  });
}

class WorkflowCheckpointRecord {
  final String id;
  final String taskId;
  final String checkpointType;
  final int nodeIndex;
  final String? fullState;
  final DateTime createdAt;

  const WorkflowCheckpointRecord({
    required this.id,
    required this.taskId,
    required this.checkpointType,
    required this.nodeIndex,
    required this.fullState,
    required this.createdAt,
  });
}
