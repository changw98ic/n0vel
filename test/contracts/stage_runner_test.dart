import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';

void main() {
  group('PipelineContext', () {
    test('construction with all fields', () {
      final ctx = PipelineContext(
        eventLog: _FakeEventLog(),
        retrievalPolicy: RagRetrievalPolicy.director(),
        writebackGate: const BasicMemoryWritebackGate(),
        sceneBrief: const SceneBriefRef(
          projectId: 'p1',
          sceneId: 's1',
        ),
        metadata: {'key': 'value'},
      );
      expect(ctx.metadata['key'], 'value');
      expect(ctx.sceneBrief.projectId, 'p1');
    });

    test('withMetadata merges correctly', () {
      final ctx = PipelineContext(
        eventLog: _FakeEventLog(),
        retrievalPolicy: RagRetrievalPolicy.roleplay(),
        writebackGate: const BasicMemoryWritebackGate(),
        sceneBrief: const SceneBriefRef(projectId: 'p1', sceneId: 's1'),
        metadata: {'a': 1},
      );
      final extended = ctx.withMetadata({'b': 2});
      expect(extended.metadata['a'], 1);
      expect(extended.metadata['b'], 2);
      expect(ctx.metadata.containsKey('b'), isFalse);
    });
  });

  group('SceneBriefRef', () {
    test('defaults', () {
      const ref = SceneBriefRef(projectId: 'p', sceneId: 's');
      expect(ref.sceneIndex, 0);
      expect(ref.totalScenesInChapter, 0);
    });
  });

  group('PipelineRunResult', () {
    test('success result', () {
      const result = PipelineRunResult(
        success: true,
        events: [],
      );
      expect(result.success, isTrue);
      expect(result.failureCode, isNull);
      expect(result.finalArtifact, isNull);
    });

    test('failure result', () {
      const result = PipelineRunResult(
        success: false,
        events: [],
        failureCode: FailureCode.qualityFail,
        failedStageId: 'review',
      );
      expect(result.success, isFalse);
      expect(result.failureCode, FailureCode.qualityFail);
      expect(result.failedStageId, 'review');
    });
  });
}

class _FakeEventLog extends PipelineEventLog {
  final _events = <PipelineEvent>[];

  @override
  void emit(PipelineEvent event) => _events.add(event);

  @override
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  }) {
    return _events.where((e) {
      if (stageId != null && e.stageId != stageId) return false;
      if (eventType != null && e.eventType != eventType) return false;
      if (failureCode != null && e.failureCode != failureCode) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> flush() async {}
}
