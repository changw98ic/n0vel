import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';

void main() {
  group('PipelineEventLogImpl', () {
    late PipelineEventLogImpl log;

    setUp(() {
      log = PipelineEventLogImpl();
    });

    tearDown(() async {
      await log.dispose();
    });

    test('emit and query events', () {
      log.emit(const PipelineEvent(
        timestampMs: 100,
        stageId: 'director',
        eventType: 'started',
      ));
      log.emit(const PipelineEvent(
        timestampMs: 200,
        stageId: 'review',
        eventType: 'failed',
        failureCode: FailureCode.qualityFail,
      ));
      log.emit(const PipelineEvent(
        timestampMs: 300,
        stageId: 'review',
        eventType: 'completed',
      ));

      expect(log.query(stageId: 'review'), hasLength(2));
      expect(log.query(eventType: 'started'), hasLength(1));
      expect(log.query(failureCode: FailureCode.qualityFail), hasLength(1));
      expect(log.query(), hasLength(3));
    });

    test('ring buffer evicts oldest when full', () {
      log = PipelineEventLogImpl(ringBufferSize: 3);
      for (var i = 0; i < 5; i++) {
        log.emit(PipelineEvent(
          timestampMs: i,
          stageId: 'stage$i',
          eventType: 'tick',
        ));
      }
      expect(log.query(), hasLength(3));
      expect(log.query().first.stageId, 'stage2');
    });

    test('query with no matches returns empty', () {
      log.emit(const PipelineEvent(
        timestampMs: 1,
        stageId: 'a',
        eventType: 'b',
      ));
      expect(log.query(stageId: 'nonexistent'), isEmpty);
    });

    group('JSONL persistence', () {
      late Directory tempDir;
      late String jsonlPath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('pipeline_log_test_');
        jsonlPath = '${tempDir.path}/pipeline.jsonl';
      });

      tearDown(() async {
        await log.dispose();
        await tempDir.delete(recursive: true);
      });

      test('writes events to JSONL file', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        log.emit(const PipelineEvent(
          timestampMs: 42,
          stageId: 'director',
          eventType: 'started',
          artifactType: ArtifactType.directorPlan,
        ));
        await log.flush();

        final content = await File(jsonlPath).readAsString();
        expect(content, contains('"stageId":"director"'));
        expect(content, contains('"artifactType":"directorPlan"'));
      });

      test('flush is idempotent', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.flush();
        await log.flush();
      });
    });
  });
}
