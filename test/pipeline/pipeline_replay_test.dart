// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/pipeline_role_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';

void main() {
  group('Pipeline replay fixtures', () {
    late List<Map<String, Object?>> fixtures;

    setUp(() {
      final file = File(
        'test/fixtures/golden_prompts/scene_prompt_projection_fixtures.json',
      );
      final raw = file.readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      fixtures = (decoded['fixtures'] as List<Object?>)
          .cast<Map<String, Object?>>();
    });

    test('replays recorded scene fixtures through ordered stages', () async {
      final runner = _ReplayPipelineRunner(
        stages: [
          const _ReplayStage(
            roleId: 'context_enrichment',
            outputType: ArtifactType.contextAssembly,
          ),
          const _ReplayStage(
            roleId: 'scene_planning',
            outputType: ArtifactType.directorPlan,
          ),
          const _ReplayStage(
            roleId: 'roleplay',
            outputType: ArtifactType.roleplaySession,
          ),
          const _ReplayStage(
            roleId: 'finalization',
            outputType: ArtifactType.sceneOutput,
          ),
        ],
      );

      for (final fixture in fixtures) {
        final sceneId = fixture['sceneId']! as String;
        final context = _contextFor(runner, fixture);
        final result = await runner.run(context.sceneBrief, context);

        expect(result.success, isTrue);
        expect(result.failureCode, isNull);
        expect(result.finalArtifact, isA<_ReplayArtifact>());

        final finalArtifact = result.finalArtifact! as _ReplayArtifact;
        expect(finalArtifact.type, ArtifactType.sceneOutput);
        expect(finalArtifact.content, contains(sceneId));

        final stageEvents = result.events
            .where((event) => event.metadata['sceneId'] == sceneId)
            .toList();
        expect(
          stageEvents.map((event) => '${event.stageId}:${event.eventType}'),
          [
            'context_enrichment:started',
            'context_enrichment:completed',
            'scene_planning:started',
            'scene_planning:completed',
            'roleplay:started',
            'roleplay:completed',
            'finalization:started',
            'finalization:completed',
          ],
        );
      }
    });

    test('returns recoverable failure result when a stage throws', () async {
      final runner = _ReplayPipelineRunner(
        stages: [
          const _ReplayStage(
            roleId: 'context_enrichment',
            outputType: ArtifactType.contextAssembly,
          ),
          const _ReplayStage(
            roleId: 'scene_planning',
            outputType: ArtifactType.directorPlan,
            shouldThrow: true,
          ),
          const _ReplayStage(
            roleId: 'finalization',
            outputType: ArtifactType.sceneOutput,
          ),
        ],
      );
      final fixture = fixtures.first;
      final context = _contextFor(runner, fixture);

      final result = await runner.run(context.sceneBrief, context);

      expect(result.success, isFalse);
      expect(result.failureCode, FailureCode.recoverable);
      expect(result.failedStageId, 'scene_planning');
      expect(result.finalArtifact, isNull);
      expect(
        result.events.where(
          (event) =>
              event.stageId == 'scene_planning' &&
              event.eventType == 'failed' &&
              event.failureCode == FailureCode.recoverable,
        ),
        hasLength(1),
      );
    });
  });
}

PipelineContext _contextFor(
  _ReplayPipelineRunner runner,
  Map<String, Object?> fixture,
) {
  return PipelineContext(
    eventLog: runner.eventLog,
    retrievalPolicy: runner.defaultRetrievalPolicy,
    writebackGate: runner.writebackGate,
    sceneBrief: SceneBriefRef(
      projectId: fixture['projectId']! as String,
      sceneId: fixture['sceneId']! as String,
    ),
    metadata: fixture,
  );
}

class _ReplayPipelineRunner extends PipelineStageRunner {
  _ReplayPipelineRunner({required List<_ReplayStage> stages})
    : _stages = stages;

  final List<_ReplayStage> _stages;
  final _InMemoryEventLog _eventLog = _InMemoryEventLog();

  @override
  List<PipelineStage<TypedArtifact, TypedArtifact>> get stages => _stages;

  @override
  PipelineEventLog get eventLog => _eventLog;

  @override
  RagRetrievalPolicy get defaultRetrievalPolicy =>
      RagRetrievalPolicy.director();

  @override
  MemoryWritebackGate get writebackGate => const BasicMemoryWritebackGate();

  @override
  Future<PipelineRunResult> run(
    SceneBriefRef brief,
    PipelineContext context,
  ) async {
    TypedArtifact artifact = _ReplayArtifact(
      type: ArtifactType.retrievalPack,
      content: 'seed:${brief.sceneId}',
    );

    for (final stage in _stages) {
      _emit(brief, stage.roleId, 'started', stage.outputType);
      try {
        artifact = await stage.execute(artifact, context);
      } catch (_) {
        _emit(
          brief,
          stage.roleId,
          'failed',
          stage.outputType,
          failureCode: FailureCode.recoverable,
        );
        return PipelineRunResult(
          success: false,
          events: _eventLog.query(),
          failureCode: FailureCode.recoverable,
          failedStageId: stage.roleId,
        );
      }
      _emit(brief, stage.roleId, 'completed', stage.outputType);
    }

    return PipelineRunResult(
      success: true,
      events: _eventLog.query(),
      finalArtifact: artifact,
    );
  }

  void _emit(
    SceneBriefRef brief,
    String stageId,
    String eventType,
    ArtifactType artifactType, {
    FailureCode? failureCode,
  }) {
    _eventLog.emit(
      PipelineEvent(
        timestampMs: _eventLog.query().length,
        stageId: stageId,
        eventType: eventType,
        artifactType: artifactType,
        failureCode: failureCode,
        metadata: {'projectId': brief.projectId, 'sceneId': brief.sceneId},
      ),
    );
  }
}

class _ReplayStage extends PipelineStage<TypedArtifact, TypedArtifact> {
  const _ReplayStage({
    required this.roleId,
    required this.outputType,
    this.shouldThrow = false,
  });

  @override
  final String roleId;

  @override
  final ArtifactType outputType;

  final bool shouldThrow;

  @override
  Future<TypedArtifact> execute(TypedArtifact input, Object context) async {
    if (shouldThrow) {
      throw StateError('replay failure: $roleId');
    }
    final pipelineContext = context as PipelineContext;
    final previous = input as _ReplayArtifact;
    return _ReplayArtifact(
      type: outputType,
      content:
          '${previous.content}|$roleId:${pipelineContext.sceneBrief.sceneId}',
    );
  }
}

class _ReplayArtifact extends TypedArtifact {
  const _ReplayArtifact({required this.type, required this.content});

  @override
  final ArtifactType type;

  final String content;

  @override
  int get tokenEstimate => (content.length / 4).ceil();

  @override
  Map<String, Object?> toJson() => {'type': type.name, 'content': content};
}

class _InMemoryEventLog extends PipelineEventLog {
  final List<PipelineEvent> _events = [];

  @override
  void emit(PipelineEvent event) => _events.add(event);

  @override
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  }) {
    return _events.where((event) {
      if (stageId != null && event.stageId != stageId) {
        return false;
      }
      if (eventType != null && event.eventType != eventType) {
        return false;
      }
      if (failureCode != null && event.failureCode != failureCode) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<void> flush() async {}
}
