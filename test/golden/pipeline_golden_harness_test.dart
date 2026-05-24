import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';

import 'pipeline_golden_harness.dart';

/// Environment variable to enable golden fixture updates.
///
/// When set to '1' or 'true', tests will update fixture files instead of
/// comparing against them. Use with caution.
const _updateGoldensKey = 'UPDATE_GOLDENS';

bool get _shouldUpdateGoldens {
  final value = Platform.environment[_updateGoldensKey];
  return value == '1' || value?.toLowerCase() == 'true';
}

void main() {
  group('Pipeline golden harness', () {
    group('success-nine-stage fixture', () {
      late PipelineGoldenFixture fixture;

      setUp(() async {
        fixture = await PipelineGoldenFixture.fromFile(
          'test/fixtures/pipeline_goldens/success_nine_stage.json',
        );
      });

      test('loads fixture with correct metadata', () {
        expect(fixture.caseId, 'success-nine-stage');
        expect(fixture.input.projectId, 'proj-test-novel');
        expect(fixture.input.sceneId, 'scene-001');
        expect(fixture.presetId, 'default-nine-stage');
      });

      test('runs nine-stage pipeline and matches golden snapshot', () async {
        final runner = GoldenMockRunner(
          preset: BuiltInPresets.defaultNineStage,
        );

        final context = PipelineContext(
          eventLog: runner.eventLog,
          retrievalPolicy: runner.defaultRetrievalPolicy,
          writebackGate: runner.writebackGate,
          sceneBrief: fixture.input.toSceneBriefRef(),
        );

        final result = await runner.run(
          fixture.input.toSceneBriefRef(),
          context,
        );

        if (_shouldUpdateGoldens) {
          await _updateFixture(fixture, result);
          fail(
            'Updated golden file at ${fixture.caseId} — re-run without UPDATE_GOLDENS',
          );
        }

        _assertGoldenMatch(fixture, result);
      });

      test('generates deterministic event sequence', () async {
        final runner1 = GoldenMockRunner(
          preset: BuiltInPresets.defaultNineStage,
        );

        final context1 = PipelineContext(
          eventLog: runner1.eventLog,
          retrievalPolicy: runner1.defaultRetrievalPolicy,
          writebackGate: runner1.writebackGate,
          sceneBrief: fixture.input.toSceneBriefRef(),
        );

        final result1 = await runner1.run(
          fixture.input.toSceneBriefRef(),
          context1,
        );

        final runner2 = GoldenMockRunner(
          preset: BuiltInPresets.defaultNineStage,
        );

        final context2 = PipelineContext(
          eventLog: runner2.eventLog,
          retrievalPolicy: runner2.defaultRetrievalPolicy,
          writebackGate: runner2.writebackGate,
          sceneBrief: fixture.input.toSceneBriefRef(),
        );

        final result2 = await runner2.run(
          fixture.input.toSceneBriefRef(),
          context2,
        );

        expect(result1.events.length, result2.events.length);
        for (var i = 0; i < result1.events.length; i++) {
          _expectEventEqual(result1.events[i], result2.events[i]);
        }
      });
    });

    group('recoverable-failure fixture', () {
      late PipelineGoldenFixture fixture;

      setUp(() async {
        fixture = await PipelineGoldenFixture.fromFile(
          'test/fixtures/pipeline_goldens/recoverable_failure.json',
        );
      });

      test('loads fixture with failure metadata', () {
        expect(fixture.caseId, 'recoverable-failure');
        expect(fixture.expectedOutput.success, isFalse);
        expect(fixture.expectedOutput.failureCode, 'recoverable');
        expect(fixture.expectedOutput.failedStageId, 'roleplay');
      });

      test('simulates recoverable failure at roleplay stage', () async {
        final runner = GoldenMockRunner(
          preset: BuiltInPresets.defaultNineStage,
          simulateFailureAt: 'roleplay',
        );

        final context = PipelineContext(
          eventLog: runner.eventLog,
          retrievalPolicy: runner.defaultRetrievalPolicy,
          writebackGate: runner.writebackGate,
          sceneBrief: fixture.input.toSceneBriefRef(),
        );

        final result = await runner.run(
          fixture.input.toSceneBriefRef(),
          context,
        );

        if (_shouldUpdateGoldens) {
          await _updateFixture(fixture, result);
          fail(
            'Updated golden file at ${fixture.caseId} — re-run without UPDATE_GOLDENS',
          );
        }

        _assertGoldenMatch(fixture, result);
      });

      test('failure is recoverable (not fatal)', () {
        expect(fixture.expectedOutput.failureCode, 'recoverable');
        expect(
          fixture.expectedOutput.failureMode,
          'stage-failure-before-retry',
        );
      });
    });

    group('disabled-review-stage fixture', () {
      late PipelineGoldenFixture fixture;
      late PipelinePreset customPreset;

      setUp(() async {
        fixture = await PipelineGoldenFixture.fromFile(
          'test/fixtures/pipeline_goldens/disabled_review_stage.json',
        );

        customPreset = createCustomPreset(
          id: 'custom-no-review',
          name: 'Custom preset without review stage',
          disabledStages: [PipelineStageId.review],
        );
      });

      test('loads fixture with custom topology', () {
        expect(fixture.caseId, 'disabled-review-stage');
        expect(fixture.presetId, 'custom-no-review');
        expect(fixture.expectedOutput.disabledStages, contains('review'));
        expect(fixture.expectedOutput.stageCount, 8);
      });

      test('runs eight-stage pipeline without review', () async {
        final runner = GoldenMockRunner(preset: customPreset);

        final context = PipelineContext(
          eventLog: runner.eventLog,
          retrievalPolicy: runner.defaultRetrievalPolicy,
          writebackGate: runner.writebackGate,
          sceneBrief: fixture.input.toSceneBriefRef(),
        );

        final result = await runner.run(
          fixture.input.toSceneBriefRef(),
          context,
        );

        if (_shouldUpdateGoldens) {
          await _updateFixture(fixture, result);
          fail(
            'Updated golden file at ${fixture.caseId} — re-run without UPDATE_GOLDENS',
          );
        }

        _assertGoldenMatch(fixture, result);
      });

      test('review stage is absent from event sequence', () async {
        final runner = GoldenMockRunner(preset: customPreset);

        final context = PipelineContext(
          eventLog: runner.eventLog,
          retrievalPolicy: runner.defaultRetrievalPolicy,
          writebackGate: runner.writebackGate,
          sceneBrief: fixture.input.toSceneBriefRef(),
        );

        final result = await runner.run(
          fixture.input.toSceneBriefRef(),
          context,
        );

        final reviewEvents = result.events.where((e) => e.stageId == 'review');

        expect(reviewEvents, isEmpty);
        expect(result.events.length, 16); // 8 stages * 2 events each
      });
    });

    group('createCustomPreset helper', () {
      test('creates preset with specified stages disabled', () {
        final preset = createCustomPreset(
          id: 'test-custom',
          name: 'Test Custom',
          disabledStages: [PipelineStageId.review, PipelineStageId.polish],
        );

        expect(preset.stages, hasLength(9));
        expect(preset.enabledStages, hasLength(7));

        final reviewStage = preset.stages.firstWhere(
          (s) => s.id == PipelineStageId.review,
        );
        final polishStage = preset.stages.firstWhere(
          (s) => s.id == PipelineStageId.polish,
        );

        expect(reviewStage.enabled, isFalse);
        expect(polishStage.enabled, isFalse);
      });

      test('does not modify original BuiltInPresets', () {
        final _ = createCustomPreset(
          id: 'test-custom',
          name: 'Test Custom',
          disabledStages: [PipelineStageId.review],
        );

        expect(
          BuiltInPresets.defaultNineStage.stages.every((s) => s.enabled),
          isTrue,
        );
      });
    });

    group('fixture file integrity', () {
      test('all fixture files are valid JSON', () async {
        final fixtureDir = Directory('test/fixtures/pipeline_goldens');
        final files = fixtureDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList();

        for (final file in files) {
          final raw = await file.readAsString();
          expect(
            () => jsonDecode(raw),
            returnsNormally,
            reason: '${file.path} should be valid JSON',
          );
        }
      });

      test('all fixture files have required fields', () async {
        final fixtureFiles = [
          'test/fixtures/pipeline_goldens/success_nine_stage.json',
          'test/fixtures/pipeline_goldens/recoverable_failure.json',
          'test/fixtures/pipeline_goldens/disabled_review_stage.json',
        ];

        for (final path in fixtureFiles) {
          final fixture = await PipelineGoldenFixture.fromFile(path);

          expect(fixture.caseId, isNotEmpty);
          expect(fixture.description, isNotEmpty);
          expect(fixture.input.projectId, isNotEmpty);
          expect(fixture.input.sceneId, isNotEmpty);
          expect(fixture.presetId, isNotEmpty);
          expect(fixture.expectedOutput.success, isA<bool>());
          expect(fixture.expectedOutput.stageCount, greaterThan(0));
          expect(fixture.expectedOutput.eventSequence, isNotEmpty);
        }
      });
    });
  });
}

void _assertGoldenMatch(
  PipelineGoldenFixture fixture,
  PipelineRunResult result,
) {
  // Check success status
  expect(
    result.success,
    fixture.expectedOutput.success,
    reason: 'Success status mismatch for fixture ${fixture.caseId}',
  );

  // Check stage count
  final actualStageCount = result.events
      .where((e) => e.eventType == 'started')
      .length;
  expect(
    actualStageCount,
    fixture.expectedOutput.stageCount,
    reason: 'Stage count mismatch for fixture ${fixture.caseId}',
  );

  // Check stage order if specified
  if (fixture.expectedOutput.stageOrder != null) {
    final actualStageOrder = result.events
        .where((e) => e.eventType == 'started')
        .map((e) => e.stageId)
        .toSet()
        .toList();
    expect(
      actualStageOrder,
      fixture.expectedOutput.stageOrder,
      reason: 'Stage order mismatch for fixture ${fixture.caseId}',
    );
  }

  // Check disabled stages if specified
  if (fixture.expectedOutput.disabledStages != null) {
    final allStageIds = result.events.map((e) => e.stageId).toSet();
    for (final disabledStage in fixture.expectedOutput.disabledStages!) {
      expect(
        allStageIds.contains(disabledStage),
        isFalse,
        reason:
            'Disabled stage $disabledStage found in events for fixture ${fixture.caseId}',
      );
    }
  }

  // Check final artifact type if specified
  if (fixture.expectedOutput.finalArtifactType != null) {
    expect(
      result.finalArtifact?.type.name,
      fixture.expectedOutput.finalArtifactType,
      reason: 'Final artifact type mismatch for fixture ${fixture.caseId}',
    );
  }

  // Check failure metadata if applicable
  if (fixture.expectedOutput.failureCode != null) {
    expect(
      result.failureCode?.name,
      fixture.expectedOutput.failureCode,
      reason: 'Failure code mismatch for fixture ${fixture.caseId}',
    );
  }

  if (fixture.expectedOutput.failedStageId != null) {
    expect(
      result.failedStageId,
      fixture.expectedOutput.failedStageId,
      reason: 'Failed stage ID mismatch for fixture ${fixture.caseId}',
    );
  }

  // Check deterministic metadata
  final actualMetadata = _generateDeterministicMetadata(result);
  final expectedMetadata = fixture.expectedOutput.metadata;
  expect(
    actualMetadata['eventCount'],
    expectedMetadata['eventCount'],
    reason: 'Event count in metadata mismatch for fixture ${fixture.caseId}',
  );
  expect(
    actualMetadata['stageCount'],
    expectedMetadata['stageCount'],
    reason: 'Stage count in metadata mismatch for fixture ${fixture.caseId}',
  );
  if (fixture.expectedOutput.finalArtifactType != null) {
    expect(
      actualMetadata['finalArtifactType'],
      expectedMetadata['finalArtifactType'],
      reason:
          'Final artifact type in metadata mismatch for fixture ${fixture.caseId}',
    );
  }

  // Check event sequence matches
  final actualEvents = result.events
      .map(
        (e) => GoldenEventSummary(
          stageId: e.stageId,
          eventType: e.eventType,
          artifactType: e.artifactType?.name ?? '',
          failureCode: e.failureCode?.name,
        ),
      )
      .toList();

  expect(
    actualEvents.length,
    fixture.expectedOutput.eventSequence.length,
    reason: 'Event count mismatch for fixture ${fixture.caseId}',
  );

  for (var i = 0; i < fixture.expectedOutput.eventSequence.length; i++) {
    final expected = fixture.expectedOutput.eventSequence[i];
    final actual = actualEvents[i];

    expect(
      actual.stageId,
      expected.stageId,
      reason: 'Event $i stageId mismatch',
    );
    expect(
      actual.eventType,
      expected.eventType,
      reason: 'Event $i eventType mismatch',
    );
    expect(
      actual.artifactType,
      expected.artifactType,
      reason: 'Event $i artifactType mismatch',
    );
    expect(
      actual.failureCode,
      expected.failureCode,
      reason: 'Event $i failureCode mismatch',
    );
  }
}

void _expectEventEqual(PipelineEvent a, PipelineEvent b) {
  expect(a.stageId, b.stageId);
  expect(a.eventType, b.eventType);
  expect(a.artifactType, b.artifactType);
  expect(a.failureCode, b.failureCode);
}

Future<void> _updateFixture(
  PipelineGoldenFixture fixture,
  PipelineRunResult result,
) async {
  final stageCount = result.events
      .where((e) => e.eventType == 'started')
      .length;
  final stageOrder = result.events
      .where((e) => e.eventType == 'started')
      .map((e) => e.stageId)
      .toSet()
      .toList();

  final updated = {
    'caseId': fixture.caseId,
    'description': fixture.description,
    'input': {
      'projectId': fixture.input.projectId,
      'sceneId': fixture.input.sceneId,
      'sceneIndex': fixture.input.sceneIndex,
      'totalScenesInChapter': fixture.input.totalScenesInChapter,
      'sceneTitle': fixture.input.sceneTitle,
      'sceneSummary': fixture.input.sceneSummary,
    },
    'presetId': fixture.presetId,
    'expectedOutput': {
      'success': result.success,
      'stageCount': stageCount,
      'stageOrder': stageOrder,
      if (fixture.expectedOutput.disabledStages != null)
        'disabledStages': fixture.expectedOutput.disabledStages,
      'eventSequence': result.events
          .map(
            (e) => {
              'stageId': e.stageId,
              'eventType': e.eventType,
              'artifactType': e.artifactType?.name,
              if (e.failureCode != null) 'failureCode': e.failureCode!.name,
            },
          )
          .toList(),
      'failureCode': result.failureCode?.name,
      'failedStageId': result.failedStageId,
      'finalArtifactType': result.finalArtifact?.type.name,
      if (fixture.expectedOutput.failureMode != null)
        'failureMode': fixture.expectedOutput.failureMode,
      'metadata': _generateDeterministicMetadata(result),
    },
  };

  // Use sourcePath if available, otherwise fall back to generated path
  final path =
      fixture.sourcePath ??
      'test/fixtures/pipeline_goldens/${fixture.caseId}.json';
  final file = File(path);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(updated));
}

Map<String, Object?> _generateDeterministicMetadata(PipelineRunResult result) {
  final stageCount = result.events
      .where((e) => e.eventType == 'started')
      .length;
  return {
    'eventCount': result.events.length,
    'stageCount': stageCount,
    if (result.finalArtifact != null)
      'finalArtifactType': result.finalArtifact!.type.name,
  };
}
