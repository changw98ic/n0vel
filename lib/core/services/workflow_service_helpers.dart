import 'workflow_service.dart';

int workflowStepBudgetForNodes(List<WorkflowNode> nodes) {
  return (nodes.length * 10).clamp(10, 500);
}

bool workflowWouldLoop({
  required int currentPointer,
  required int newPointer,
  required Set<int> visitedPointers,
}) {
  return newPointer == currentPointer || visitedPointers.contains(newPointer);
}

WorkflowRunSummary workflowFailedSummary({
  required int nextNodeIndex,
  required WorkflowContext context,
  required List<NodeResult> results,
  WorkflowNode? failedNode,
  String? error,
}) {
  return WorkflowRunSummary(
    status: TaskStatus.failed,
    nextNodeIndex: nextNodeIndex,
    context: context,
    results: failedNode == null
        ? results
        : [
            ...results,
            NodeResult(
              nodeId: failedNode.id,
              status: NodeStatus.failed,
              error: error,
            ),
          ],
  );
}

WorkflowRunSummary workflowPausedSummary({
  required TaskStatus status,
  required int nextNodeIndex,
  required WorkflowContext context,
  required List<NodeResult> results,
}) {
  return WorkflowRunSummary(
    status: status,
    nextNodeIndex: nextNodeIndex,
    context: context,
    results: results,
  );
}

WorkflowRunSummary workflowCompletedSummary({
  required List<WorkflowNode> nodes,
  required WorkflowContext context,
  required List<NodeResult> results,
}) {
  return WorkflowRunSummary(
    status: TaskStatus.completed,
    nextNodeIndex: nodes.isEmpty ? 0 : nodes.length,
    context: context,
    results: results,
  );
}

NodeResult workflowNodeFailedResult(
  WorkflowNode node, {
  required String error,
  dynamic output,
}) {
  return NodeResult(
    nodeId: node.id,
    status: NodeStatus.failed,
    error: error,
    output: output,
  );
}

NodeResult workflowAiSuccessResult(
  AINode node,
  WorkflowAIExecution execution,
) {
  return NodeResult(
    nodeId: node.id,
    status: NodeStatus.completed,
    output: execution.output,
    inputTokens: execution.inputTokens,
    outputTokens: execution.outputTokens,
  );
}

NodeResult workflowReviewDecisionResult(
  ReviewNode node, {
  required bool approved,
}) {
  return NodeResult(
    nodeId: node.id,
    status: approved ? NodeStatus.approved : NodeStatus.rejected,
    output: approved,
  );
}

void mergeWorkflowBranchContext(
  WorkflowContext target,
  WorkflowContext branchContext,
) {
  target.completedNodes.addAll(branchContext.completedNodes);
  target.variables.addAll(branchContext.variables);
}
