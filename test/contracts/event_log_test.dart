import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FailureCode', () {
    test('has all expected values', () {
      expect(FailureCode.values, hasLength(8));
      expect(FailureCode.values, containsAll([
        FailureCode.recoverable,
        FailureCode.qualityFail,
        FailureCode.canonViolation,
        FailureCode.soulViolation,
        FailureCode.memoryCorrupted,
        FailureCode.budgetExceeded,
        FailureCode.blocked,
        FailureCode.fatal,
      ]));
    });

    test('name property is stable', () {
      for (final code in FailureCode.values) {
        expect(FailureCode.values.byName(code.name), equals(code));
      }
    });
  });

  group('PipelineEvent', () {
    test('round-trip serialization with all fields', () {
      const event = PipelineEvent(
        timestampMs: 1700000000000,
        stageId: 'review',
        eventType: 'stage_complete',
        artifactType: ArtifactType.proseDraft,
        failureCode: FailureCode.qualityFail,
        metadata: {'score': 0.4, 'threshold': 0.6},
        durationMs: 1500,
      );

      final json = event.toJson();
      final restored = PipelineEvent.fromJson(json);

      expect(restored.timestampMs, 1700000000000);
      expect(restored.stageId, 'review');
      expect(restored.eventType, 'stage_complete');
      expect(restored.artifactType, ArtifactType.proseDraft);
      expect(restored.failureCode, FailureCode.qualityFail);
      expect(restored.metadata['score'], 0.4);
      expect(restored.durationMs, 1500);
    });

    test('round-trip with minimal fields', () {
      const event = PipelineEvent(
        timestampMs: 1000,
        stageId: 'director',
        eventType: 'started',
      );

      final restored = PipelineEvent.fromJson(event.toJson());
      expect(restored.artifactType, isNull);
      expect(restored.failureCode, isNull);
      expect(restored.durationMs, isNull);
      expect(restored.metadata, isEmpty);
    });

    test('handles null/missing JSON gracefully', () {
      final restored = PipelineEvent.fromJson({});
      expect(restored.timestampMs, 0);
      expect(restored.stageId, '');
      expect(restored.eventType, '');
      expect(restored.artifactType, isNull);
      expect(restored.failureCode, isNull);
    });
  });
}
