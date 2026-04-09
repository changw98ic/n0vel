import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/workflow_service.dart';

void main() {
  group('WorkflowService review loop', () {
    test('rejected review reruns from retry node and can later approve', () async {
      var aiCalls = 0;
      var reviewCalls = 0;

      final service = WorkflowService(
        aiExecutor: (node, context) async {
          aiCalls++;
          return WorkflowAIExecution(
            output: 'draft-$aiCalls',
            inputTokens: 10,
            outputTokens: 20,
          );
        },
        reviewHandler: (node, context) async {
          reviewCalls++;
          return reviewCalls > 1;
        },
      );

      final nodes = <WorkflowNode>[
        AINode(
          id: 'draft',
          name: 'Draft',
          index: 0,
          promptTemplate: 'Write draft',
          outputVariable: 'draftOutput',
        ),
        ReviewNode(
          id: 'review',
          name: 'Review',
          index: 1,
          reviewVariable: 'draftOutput',
          approvedVariable: 'approved',
          retryNodeIndex: 0,
        ),
      ];

      final summary = await service.run(
        nodes: nodes,
        context: WorkflowContext(taskId: 'task-1'),
      );

      expect(summary.status, TaskStatus.completed);
      expect(aiCalls, 2);
      expect(reviewCalls, 2);
      expect(summary.results.map((result) => result.status), <NodeStatus>[
        NodeStatus.completed,
        NodeStatus.rejected,
        NodeStatus.completed,
        NodeStatus.approved,
      ]);
      expect(summary.context.get<String>('draftOutput'), 'draft-2');
      expect(summary.context.get<bool>('approved'), isTrue);
    });
  });
}
