import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../../core/database/database.dart';
import '../domain/workflow_models.dart';

class WorkflowRepository {
  final AppDatabase _db;

  WorkflowRepository(this._db);

  Future<List<WorkflowTaskSummary>> getTasksByWorkId(String workId) async {
    final rows =
        await (_db.select(_db.aiTasks)
              ..where((table) => table.workId.equals(workId))
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    return rows.map(_mapTask).toList();
  }

  Future<WorkflowTaskSummary?> getTaskById(String taskId) async {
    final row = await (_db.select(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).getSingleOrNull();
    return row == null ? null : _mapTask(row);
  }

  Future<AITask?> getRawTaskById(String taskId) {
    return (_db.select(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).getSingleOrNull();
  }

  Future<Map<String, dynamic>?> getTaskConfig(String taskId) async {
    final task = await getRawTaskById(taskId);
    if (task?.config == null || task!.config!.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(task.config!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateTaskConfig(
    String taskId,
    Map<String, dynamic> config,
  ) async {
    await (_db.update(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).write(
      AiTasksCompanion(
        config: Value(jsonEncode(config)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<WorkflowNodeRunRecord>> getNodeRuns(String taskId) async {
    final rows =
        await (_db.select(_db.workflowNodeRuns)
              ..where((table) => table.taskId.equals(taskId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.nodeIndex),
                (table) => OrderingTerm.asc(table.attempt),
              ]))
            .get();

    return rows.map(_mapNodeRun).toList();
  }

  Future<List<WorkflowCheckpointRecord>> getCheckpoints(String taskId) async {
    final rows =
        await (_db.select(_db.workflowCheckpoints)
              ..where((table) => table.taskId.equals(taskId))
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
            .get();

    return rows.map(_mapCheckpoint).toList();
  }

  Future<WorkflowCheckpointRecord?> getLatestCheckpoint(String taskId) async {
    final row =
        await (_db.select(_db.workflowCheckpoints)
              ..where((table) => table.taskId.equals(taskId))
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
              ..limit(1))
            .getSingleOrNull();

    return row == null ? null : _mapCheckpoint(row);
  }

  Future<void> resumeTask(String taskId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).write(
      AiTasksCompanion(
        status: const Value('running'),
        errorMessage: const Value.absent(),
        startedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> pauseTask(String taskId) async {
    await (_db.update(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).write(
      AiTasksCompanion(
        status: const Value('paused'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> cancelTask(String taskId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).write(
      AiTasksCompanion(
        status: const Value('cancelled'),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> retryTask(String taskId) async {
    final task = await getTaskById(taskId);
    if (task == null) {
      return;
    }

    final nodeRuns = await getNodeRuns(taskId);
    final failedNode = nodeRuns
        .where((run) => run.status == WorkflowRunStatus.failed)
        .toList();
    final restartIndex = failedNode.isEmpty
        ? task.currentNodeIndex
        : failedNode.last.nodeIndex;

    final now = DateTime.now();
    await (_db.update(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).write(
      AiTasksCompanion(
        status: const Value('pending'),
        progress: const Value(0),
        currentNodeIndex: Value(restartIndex),
        errorMessage: const Value(null),
        completedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );

    await createManualCheckpoint(
      taskId: taskId,
      nodeIndex: restartIndex,
      state: {
        'action': 'retry',
        'previousStatus': task.status.name,
        'restartNodeIndex': restartIndex,
      },
    );
  }

  Future<void> createManualCheckpoint({
    required String taskId,
    required int nodeIndex,
    Map<String, dynamic>? state,
  }) async {
    final now = DateTime.now();
    await _db
        .into(_db.workflowCheckpoints)
        .insert(
          WorkflowCheckpointsCompanion.insert(
            id: _newId(),
            taskId: taskId,
            checkpointType: 'manual',
            nodeIndex: nodeIndex,
            fullState: Value(state == null ? null : jsonEncode(state)),
            createdAt: now,
          ),
        );
  }

  Future<void> recordNodeRun({
    required String taskId,
    required String nodeName,
    required int nodeIndex,
    required String status,
    String branchId = 'main',
    String? inputSnapshot,
    String? outputSnapshot,
    String? error,
    int inputTokens = 0,
    int outputTokens = 0,
  }) async {
    final existingRuns =
        await (_db.select(_db.workflowNodeRuns)..where(
              (table) =>
                  table.taskId.equals(taskId) &
                  table.nodeIndex.equals(nodeIndex) &
                  table.branchId.equals(branchId),
            ))
            .get();

    final attempt = existingRuns.length;
    final now = DateTime.now();

    await _db
        .into(_db.workflowNodeRuns)
        .insert(
          WorkflowNodeRunsCompanion.insert(
            id: _newId(),
            taskId: taskId,
            nodeName: nodeName,
            nodeIndex: nodeIndex,
            branchId: Value(branchId),
            status: status,
            attempt: Value(attempt),
            inputSnapshot: Value(inputSnapshot == null ? null : inputSnapshot),
            outputSnapshot: Value(
              outputSnapshot == null ? null : outputSnapshot,
            ),
            error: Value(error == null ? null : error),
            inputTokens: Value(inputTokens),
            outputTokens: Value(outputTokens),
            startedAt: Value(now),
            finishedAt: Value(
              status == 'running' || status == 'pending' ? null : now,
            ),
            createdAt: now,
          ),
        );
  }

  Future<void> updateTaskExecution({
    required String taskId,
    required String status,
    required double progress,
    required int currentNodeIndex,
    String? result,
    String? errorMessage,
    int? inputTokens,
    int? outputTokens,
  }) async {
    final now = DateTime.now();
    final companion = AiTasksCompanion(
      status: Value(status),
      progress: Value(progress),
      currentNodeIndex: Value(currentNodeIndex),
      updatedAt: Value(now),
      result: result != null ? Value(result) : const Value.absent(),
      errorMessage: errorMessage != null
          ? Value(errorMessage)
          : const Value.absent(),
      inputTokens: inputTokens != null
          ? Value(inputTokens)
          : const Value.absent(),
      outputTokens: outputTokens != null
          ? Value(outputTokens)
          : const Value.absent(),
      startedAt: status == 'running' ? Value(now) : const Value.absent(),
      completedAt:
          (status == 'completed' || status == 'failed' || status == 'cancelled')
          ? Value(now)
          : const Value.absent(),
    );

    await (_db.update(
      _db.aiTasks,
    )..where((table) => table.id.equals(taskId))).write(companion);
  }

  WorkflowTaskSummary _mapTask(AITask row) {
    return WorkflowTaskSummary(
      id: row.id,
      workId: row.workId,
      name: row.name,
      type: row.type,
      status: WorkflowTaskStatus.fromName(row.status),
      progress: row.progress,
      currentNodeIndex: row.currentNodeIndex,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      errorMessage: row.errorMessage,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  WorkflowNodeRunRecord _mapNodeRun(WorkflowNodeRun row) {
    return WorkflowNodeRunRecord(
      id: row.id,
      taskId: row.taskId,
      nodeName: row.nodeName,
      nodeIndex: row.nodeIndex,
      branchId: row.branchId,
      status: WorkflowRunStatus.fromStoredValue(row.status),
      attempt: row.attempt,
      inputSnapshot: row.inputSnapshot,
      outputSnapshot: row.outputSnapshot,
      error: row.error,
      aiRequestId: row.aiRequestId,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      startedAt: row.startedAt,
      finishedAt: row.finishedAt,
      createdAt: row.createdAt,
    );
  }

  WorkflowCheckpointRecord _mapCheckpoint(WorkflowCheckpoint row) {
    return WorkflowCheckpointRecord(
      id: row.id,
      taskId: row.taskId,
      checkpointType: row.checkpointType,
      nodeIndex: row.nodeIndex,
      fullState: row.fullState,
      createdAt: row.createdAt,
    );
  }

  String _newId() => const Uuid().v4();
}
