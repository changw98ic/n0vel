import 'package:freezed_annotation/freezed_annotation.dart';


part 'workflow_service.freezed.dart';

enum NodeStatus {
  pending,
  running,
  completed,
  failed,
  skipped,
  waitingReview,
  approved,
  rejected,
}

enum TaskStatus { pending, running, paused, completed, failed, cancelled }

@freezed
class NodeResult with _$NodeResult {
  const factory NodeResult({
    required String nodeId,
    required NodeStatus status,
    dynamic output,
    String? error,
    int? inputTokens,
    int? outputTokens,
  }) = _NodeResult;
}

class WorkflowContext {
  final Map<String, dynamic> variables;
  final List<NodeResult> completedNodes;
  final String taskId;

  WorkflowContext({
    required this.taskId,
    Map<String, dynamic>? variables,
    List<NodeResult>? completedNodes,
  }) : variables = variables ?? <String, dynamic>{},
       completedNodes = completedNodes ?? <NodeResult>[];

  T? get<T>(String key) => variables[key] as T?;

  void set(String key, dynamic value) => variables[key] = value;

  T? getNodeOutput<T>(String nodeId) {
    final result = completedNodes.cast<NodeResult?>().firstWhere(
      (entry) => entry?.nodeId == nodeId,
      orElse: () => null,
    );
    return result?.output as T?;
  }

  WorkflowContext copy() => WorkflowContext(
    taskId: taskId,
    variables: Map<String, dynamic>.from(variables),
    completedNodes: List<NodeResult>.from(completedNodes),
  );
}

abstract class WorkflowNode {
  String get id;
  String get name;
  int get index;

  Future<NodeResult> execute(WorkflowContext context);

  bool canSkip(WorkflowContext context) => false;
}

class AINode extends WorkflowNode {
  @override
  final String id;
  @override
  final String name;
  @override
  final int index;

  final String promptTemplate;
  final String outputVariable;
  final String modelTier;

  AINode({
    required this.id,
    required this.name,
    required this.index,
    required this.promptTemplate,
    required this.outputVariable,
    this.modelTier = 'middle',
  });

  @override
  Future<NodeResult> execute(WorkflowContext context) async {
    return NodeResult(nodeId: id, status: NodeStatus.pending);
  }
}

class ConditionNode extends WorkflowNode {
  @override
  final String id;
  @override
  final String name;
  @override
  final int index;

  final bool Function(WorkflowContext) condition;
  final int trueBranchIndex;
  final int falseBranchIndex;

  ConditionNode({
    required this.id,
    required this.name,
    required this.index,
    required this.condition,
    required this.trueBranchIndex,
    required this.falseBranchIndex,
  });

  @override
  Future<NodeResult> execute(WorkflowContext context) async {
    final matched = condition(context);
    return NodeResult(
      nodeId: id,
      status: NodeStatus.completed,
      output: matched ? trueBranchIndex : falseBranchIndex,
    );
  }
}

class ParallelNode extends WorkflowNode {
  @override
  final String id;
  @override
  final String name;
  @override
  final int index;

  final List<WorkflowNode> branches;

  ParallelNode({
    required this.id,
    required this.name,
    required this.index,
    required this.branches,
  });

  @override
  Future<NodeResult> execute(WorkflowContext context) async {
    return NodeResult(nodeId: id, status: NodeStatus.pending);
  }
}

class ReviewNode extends WorkflowNode {
  @override
  final String id;
  @override
  final String name;
  @override
  final int index;

  final String reviewVariable;
  final String? approvedVariable;
  final int? retryNodeIndex;

  ReviewNode({
    required this.id,
    required this.name,
    required this.index,
    required this.reviewVariable,
    this.approvedVariable,
    this.retryNodeIndex,
  });

  @override
  Future<NodeResult> execute(WorkflowContext context) async {
    return NodeResult(
      nodeId: id,
      status: NodeStatus.waitingReview,
      output: context.get(reviewVariable),
    );
  }
}

class DataNode extends WorkflowNode {
  @override
  final String id;
  @override
  final String name;
  @override
  final int index;

  final void Function(WorkflowContext) processor;

  DataNode({
    required this.id,
    required this.name,
    required this.index,
    required this.processor,
  });

  @override
  Future<NodeResult> execute(WorkflowContext context) async {
    processor(context);
    return NodeResult(nodeId: id, status: NodeStatus.completed);
  }
}

/// Agent 节点
/// 在工作流中嵌入 ReAct 循环，可自主调用工具完成任务
class AgentNode extends WorkflowNode {
  @override
  final String id;
  @override
  final String name;
  @override
  final int index;

  /// Agent 任务描述（支持变量替换）
  final String taskTemplate;

  /// 输出变量名
  final String outputVariable;

  /// 允许使用的工具列表（null = 全部可用）
  final List<String>? allowedTools;

  /// 最大迭代次数
  final int maxIterations;

  AgentNode({
    required this.id,
    required this.name,
    required this.index,
    required this.taskTemplate,
    required this.outputVariable,
    this.allowedTools,
    this.maxIterations = 10,
  });

  @override
  Future<NodeResult> execute(WorkflowContext context) async {
    // AgentNode 需要 AgentService 注入
    // 这里返回 pending 状态，实际执行由上层服务协调
    return NodeResult(
      nodeId: id,
      status: NodeStatus.pending,
      output: {
        'taskTemplate': taskTemplate,
        'outputVariable': outputVariable,
        'allowedTools': allowedTools,
        'maxIterations': maxIterations,
      },
    );
  }
}

class WorkflowAIExecution {
  final dynamic output;
  final int inputTokens;
  final int outputTokens;

  const WorkflowAIExecution({
    required this.output,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });
}

class WorkflowRunSummary {
  final TaskStatus status;
  final int nextNodeIndex;
  final WorkflowContext context;
  final List<NodeResult> results;

  const WorkflowRunSummary({
    required this.status,
    required this.nextNodeIndex,
    required this.context,
    required this.results,
  });
}

typedef WorkflowAIExecutor =
    Future<WorkflowAIExecution> Function(AINode node, WorkflowContext context);

typedef WorkflowReviewHandler =
    Future<bool?> Function(ReviewNode node, WorkflowContext context);

class WorkflowService {
  final WorkflowAIExecutor? aiExecutor;
  final WorkflowReviewHandler? reviewHandler;

  WorkflowService({this.aiExecutor, this.reviewHandler});

  Future<WorkflowRunSummary> run({
    required List<WorkflowNode> nodes,
    required WorkflowContext context,
    int startIndex = 0,
  }) async {
    final workingContext = context.copy();
    final results = <NodeResult>[];
    var pointer = startIndex;
    final visitedPointers = <int>{};
    final stepBudget = (nodes.length * 10).clamp(10, 500);
    var steps = 0;
    visitedPointers.add(startIndex);

    while (pointer >= 0 && pointer < nodes.length) {
      steps++;
      if (steps > stepBudget) {
        return WorkflowRunSummary(
          status: TaskStatus.failed,
          nextNodeIndex: pointer,
          context: workingContext,
          results: [
            ...results,
            NodeResult(
              nodeId: nodes[pointer].id,
              status: NodeStatus.failed,
              error: 'Workflow exceeded step budget ($stepBudget)',
            ),
          ],
        );
      }

      final node = nodes[pointer];
      final result = await _executeNode(node, workingContext);
      workingContext.completedNodes.add(result);
      results.add(result);

      switch (result.status) {
        case NodeStatus.failed:
          return WorkflowRunSummary(
            status: TaskStatus.failed,
            nextNodeIndex: pointer,
            context: workingContext,
            results: results,
          );
        case NodeStatus.waitingReview:
          return WorkflowRunSummary(
            status: TaskStatus.paused,
            nextNodeIndex: pointer,
            context: workingContext,
            results: results,
          );
        default:
          break;
      }

      if (node is ConditionNode && result.output is int) {
        final newPointer = result.output as int;
        if (newPointer == pointer || visitedPointers.contains(newPointer)) {
          // 检测到循环，避免无限循环
          return WorkflowRunSummary(
            status: TaskStatus.failed,
            nextNodeIndex: pointer,
            context: workingContext,
            results: results,
          );
        }
        visitedPointers.add(pointer);
        pointer = newPointer;
        continue;
      }

      if (node is ReviewNode && result.status == NodeStatus.rejected) {
        final retryIndex = node.retryNodeIndex;
        if (retryIndex == null) {
          return WorkflowRunSummary(
            status: TaskStatus.failed,
            nextNodeIndex: pointer,
            context: workingContext,
            results: results,
          );
        }
        if (retryIndex < 0 || retryIndex >= nodes.length) {
          return WorkflowRunSummary(
            status: TaskStatus.failed,
            nextNodeIndex: pointer,
            context: workingContext,
            results: [
              ...results,
              NodeResult(
                nodeId: node.id,
                status: NodeStatus.failed,
                error: 'Invalid retry node index: $retryIndex',
              ),
            ],
          );
        }
        pointer = retryIndex;
        continue;
      }

      pointer += 1;
    }

    return WorkflowRunSummary(
      status: TaskStatus.completed,
      nextNodeIndex: nodes.isEmpty ? 0 : nodes.length,
      context: workingContext,
      results: results,
    );
  }

  Future<NodeResult> _executeNode(
    WorkflowNode node,
    WorkflowContext context,
  ) async {
    if (node.canSkip(context)) {
      return NodeResult(nodeId: node.id, status: NodeStatus.skipped);
    }

    if (node is AINode) {
      return _executeAINode(node, context);
    }

    if (node is ParallelNode) {
      return _executeParallelNode(node, context);
    }

    if (node is ReviewNode) {
      return _executeReviewNode(node, context);
    }

    return node.execute(context);
  }

  Future<NodeResult> _executeAINode(
    AINode node,
    WorkflowContext context,
  ) async {
    if (aiExecutor == null) {
      return NodeResult(
        nodeId: node.id,
        status: NodeStatus.failed,
        error: 'No AI executor configured',
      );
    }

    try {
      final execution = await aiExecutor!(node, context);
      context.set(node.outputVariable, execution.output);
      return NodeResult(
        nodeId: node.id,
        status: NodeStatus.completed,
        output: execution.output,
        inputTokens: execution.inputTokens,
        outputTokens: execution.outputTokens,
      );
    } catch (error) {
      return NodeResult(
        nodeId: node.id,
        status: NodeStatus.failed,
        error: error.toString(),
      );
    }
  }

  Future<NodeResult> _executeParallelNode(
    ParallelNode node,
    WorkflowContext context,
  ) async {
    final branchContexts = node.branches
        .map((_) => context.copy())
        .toList(growable: false);

    final branchResults = await Future.wait(
      List.generate(
        node.branches.length,
        (index) => _executeNode(node.branches[index], branchContexts[index]),
      ),
    );

    for (var i = 0; i < branchResults.length; i++) {
      final branchResult = branchResults[i];
      final branchContext = branchContexts[i];
      context.completedNodes.addAll(branchContext.completedNodes);
      context.variables.addAll(branchContext.variables);

      if (branchResult.status == NodeStatus.failed) {
        return NodeResult(
          nodeId: node.id,
          status: NodeStatus.failed,
          output: branchResults,
          error:
              'Parallel branch failed: ${branchResult.error ?? branchResult.nodeId}',
        );
      }
    }

    return NodeResult(
      nodeId: node.id,
      status: NodeStatus.completed,
      output: branchResults,
    );
  }

  Future<NodeResult> _executeReviewNode(
    ReviewNode node,
    WorkflowContext context,
  ) async {
    if (reviewHandler == null) {
      return node.execute(context);
    }

    final approved = await reviewHandler!(node, context);
    if (approved == null) {
      return node.execute(context);
    }

    if (node.approvedVariable != null) {
      context.set(node.approvedVariable!, approved);
    }

    return NodeResult(
      nodeId: node.id,
      status: approved ? NodeStatus.approved : NodeStatus.rejected,
      output: approved,
    );
  }
}
