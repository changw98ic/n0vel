import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/workflow_service.dart';
import 'package:writing_assistant/features/workflow/data/workflow_execution_service.dart';

void main() {
  group('buildWorkflowNodes', () {
    test('uses single-chapter review template when chapterContent is present', () {
      final nodes = buildWorkflowNodes(
        taskType: 'review',
        workId: 'work-1',
        config: <String, dynamic>{
          'chapterContent': 'chapter body',
          'chapterContents': <String, String>{'Chapter 1': 'chapter body'},
        },
      );

      expect(nodes, isNotEmpty);
      expect(nodes.first, isA<AINode>());
      expect(nodes.last, isA<ReviewNode>());
      expect(nodes.last.id, 'human_review');
    });

    test('uses batch review template when multiple chapter contents are present', () {
      final nodes = buildWorkflowNodes(
        taskType: 'review',
        workId: 'work-1',
        config: <String, dynamic>{
          'chapterContents': <String, String>{
            'Chapter 1': 'body 1',
            'Chapter 2': 'body 2',
          },
        },
      );

      expect(nodes, hasLength(2));
      expect(nodes.first, isA<ParallelNode>());
      expect(nodes.last, isA<AINode>());
      expect(nodes.first.id, 'parallel_batch_review');
      expect(nodes.last.id, 'batch_summary');
    });

    test('falls back to generic review flow when no chapter content is available', () {
      final nodes = buildWorkflowNodes(
        taskType: 'review',
        workId: 'work-1',
        config: const <String, dynamic>{},
      );

      expect(nodes.map((node) => node.id), <String>[
        'prepare',
        'analyze',
        'finalize',
      ]);
    });

    test('uses continuation template for generate task when generation config is present', () {
      final nodes = buildWorkflowNodes(
        taskType: 'generate',
        workId: 'work-1',
        config: const <String, dynamic>{
          'previousContent': 'previous',
          'continuationRequest': 'continue this',
        },
      );

      expect(nodes.first.id, 'continuation');
      expect(nodes.last, isA<ReviewNode>());
      expect(nodes.last.id, 'human_confirm');
    });

    test('uses extraction template for extract task when text content is present', () {
      final nodes = buildWorkflowNodes(
        taskType: 'extract',
        workId: 'work-1',
        config: const <String, dynamic>{
          'textContent': 'source text',
        },
      );

      expect(nodes.first, isA<ParallelNode>());
      expect(nodes.last, isA<ReviewNode>());
      expect(nodes.last.id, 'extraction_confirm');
    });
  });
}
