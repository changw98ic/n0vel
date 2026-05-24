import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/features/story_generation/data/pipeline_definition.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/pipeline_role_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';

/// Golden fixture for pipeline execution tests.
///
/// Each fixture defines stable input metadata and an expected structured
/// output summary. Fixtures are versioned JSON files that can be updated
/// only with an explicit opt-in flag.
class PipelineGoldenFixture {
  const PipelineGoldenFixture({
    required this.caseId,
    required this.description,
    required this.input,
    required this.presetId,
    required this.expectedOutput,
    this.sourcePath,
  });

  final String caseId;
  final String description;
  final GoldenInput input;
  final String presetId;
  final GoldenExpectedOutput expectedOutput;
  final String? sourcePath;

  /// Load a fixture from a JSON file.
  factory PipelineGoldenFixture.fromJson(
    Map<String, Object?> json, {
    String? sourcePath,
  }) {
    return PipelineGoldenFixture(
      caseId: json['caseId'] as String,
      description: json['description'] as String,
      input: GoldenInput.fromJson(json['input'] as Map<String, Object?>),
      presetId: json['presetId'] as String,
      expectedOutput: GoldenExpectedOutput.fromJson(
        json['expectedOutput'] as Map<String, Object?>,
      ),
      sourcePath: sourcePath,
    );
  }

  /// Load a fixture from a file path.
  static Future<PipelineGoldenFixture> fromFile(String path) async {
    final file = File(path);
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, Object?>;
    return PipelineGoldenFixture.fromJson(json, sourcePath: path);
  }
}

/// Input metadata for a golden test case.
class GoldenInput {
  const GoldenInput({
    required this.projectId,
    required this.sceneId,
    required this.sceneIndex,
    required this.totalScenesInChapter,
    required this.sceneTitle,
    required this.sceneSummary,
  });

  final String projectId;
  final String sceneId;
  final int sceneIndex;
  final int totalScenesInChapter;
  final String sceneTitle;
  final String sceneSummary;

  factory GoldenInput.fromJson(Map<String, Object?> json) {
    return GoldenInput(
      projectId: json['projectId'] as String,
      sceneId: json['sceneId'] as String,
      sceneIndex: json['sceneIndex'] as int,
      totalScenesInChapter: json['totalScenesInChapter'] as int,
      sceneTitle: json['sceneTitle'] as String,
      sceneSummary: json['sceneSummary'] as String,
    );
  }

  SceneBriefRef toSceneBriefRef() {
    return SceneBriefRef(
      projectId: projectId,
      sceneId: sceneId,
      sceneIndex: sceneIndex,
      totalScenesInChapter: totalScenesInChapter,
    );
  }
}

/// Expected structured output summary for a golden test case.
class GoldenExpectedOutput {
  const GoldenExpectedOutput({
    required this.success,
    required this.stageCount,
    this.stageOrder,
    this.disabledStages,
    required this.eventSequence,
    this.failureCode,
    this.failedStageId,
    this.finalArtifactType,
    this.failureMode,
    required this.metadata,
  });

  final bool success;
  final int stageCount;
  final List<String>? stageOrder;
  final List<String>? disabledStages;
  final List<GoldenEventSummary> eventSequence;
  final String? failureCode;
  final String? failedStageId;
  final String? finalArtifactType;
  final String? failureMode;
  final Map<String, Object?> metadata;

  factory GoldenExpectedOutput.fromJson(Map<String, Object?> json) {
    return GoldenExpectedOutput(
      success: json['success'] as bool,
      stageCount: json['stageCount'] as int,
      stageOrder: (json['stageOrder'] as List<Object?>?)?.cast<String>(),
      disabledStages: (json['disabledStages'] as List<Object?>?)
          ?.cast<String>(),
      eventSequence: (json['eventSequence'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(GoldenEventSummary.fromJson)
          .toList(),
      failureCode: json['failureCode'] as String?,
      failedStageId: json['failedStageId'] as String?,
      finalArtifactType: json['finalArtifactType'] as String?,
      failureMode: json['failureMode'] as String?,
      metadata: (json['metadata'] as Map<String, Object?>?) ?? const {},
    );
  }
}

/// Summary of a single pipeline event in the golden fixture.
class GoldenEventSummary {
  const GoldenEventSummary({
    required this.stageId,
    required this.eventType,
    required this.artifactType,
    this.failureCode,
  });

  final String stageId;
  final String eventType;
  final String artifactType;
  final String? failureCode;

  factory GoldenEventSummary.fromJson(Map<String, Object?> json) {
    return GoldenEventSummary(
      stageId: json['stageId'] as String,
      eventType: json['eventType'] as String,
      artifactType: json['artifactType'] as String,
      failureCode: json['failureCode'] as String?,
    );
  }
}

/// Deterministic mock pipeline runner for golden tests.
///
/// Produces stable, predictable output based on fixture input without
/// making any real LLM calls or network requests.
class GoldenMockRunner implements PipelineStageRunner {
  GoldenMockRunner({required this.preset, this.simulateFailureAt});

  final PipelinePreset preset;
  final String? simulateFailureAt;

  final _GoldenEventLog _eventLog = _GoldenEventLog();

  @override
  List<PipelineStage<TypedArtifact, TypedArtifact>> get stages {
    return preset.enabledStages.map((spec) {
      return _MockStage(spec: spec);
    }).toList();
  }

  @override
  PipelineEventLog get eventLog => _eventLog;

  @override
  RagRetrievalPolicy get defaultRetrievalPolicy =>
      RagRetrievalPolicy.director();

  @override
  MemoryWritebackGate get writebackGate => const BasicMemoryWritebackGate();

  @override
  int get maxGlobalRetries => 3;

  @override
  Future<PipelineRunResult> run(
    SceneBriefRef brief,
    PipelineContext context,
  ) async {
    var artifact = _MockArtifact(
      type: ArtifactType.retrievalPack,
      content: 'seed:${brief.sceneId}',
    );

    final enabledStages = preset.enabledStages;
    var timestamp = 0;

    for (final stageSpec in enabledStages) {
      final stageId = stageSpec.id.name;
      final outputType = _artifactTypeForStage(stageSpec.id);

      _eventLog.emitTimestamped(
        timestamp++,
        PipelineEvent(
          timestampMs: timestamp,
          stageId: stageId,
          eventType: 'started',
          artifactType: outputType,
          metadata: {'projectId': brief.projectId, 'sceneId': brief.sceneId},
        ),
      );

      if (simulateFailureAt == stageId) {
        _eventLog.emitTimestamped(
          timestamp++,
          PipelineEvent(
            timestampMs: timestamp,
            stageId: stageId,
            eventType: 'failed',
            artifactType: outputType,
            failureCode: FailureCode.recoverable,
            metadata: {
              'projectId': brief.projectId,
              'sceneId': brief.sceneId,
              'failureReason': 'Simulated deterministic failure',
            },
          ),
        );

        return PipelineRunResult(
          success: false,
          events: _eventLog.query(),
          failureCode: FailureCode.recoverable,
          failedStageId: stageId,
        );
      }

      artifact = _MockArtifact(
        type: outputType,
        content: '${artifact.content}|$stageId:${brief.sceneId}',
      );

      _eventLog.emitTimestamped(
        timestamp++,
        PipelineEvent(
          timestampMs: timestamp,
          stageId: stageId,
          eventType: 'completed',
          artifactType: outputType,
          metadata: {'projectId': brief.projectId, 'sceneId': brief.sceneId},
        ),
      );
    }

    return PipelineRunResult(
      success: true,
      events: _eventLog.query(),
      finalArtifact: artifact,
    );
  }

  ArtifactType _artifactTypeForStage(PipelineStageId stageId) {
    return switch (stageId) {
      PipelineStageId.contextEnrichment => ArtifactType.contextAssembly,
      PipelineStageId.scenePlanning => ArtifactType.directorPlan,
      PipelineStageId.roleplay => ArtifactType.roleplaySession,
      PipelineStageId.stageNarration => ArtifactType.stageNarration,
      PipelineStageId.beatResolution => ArtifactType.beatResolution,
      PipelineStageId.editorial => ArtifactType.proseDraft,
      PipelineStageId.review => ArtifactType.reviewResult,
      PipelineStageId.polish => ArtifactType.polishedProse,
      PipelineStageId.finalization => ArtifactType.sceneOutput,
    };
  }
}

class _MockStage extends PipelineStage<TypedArtifact, TypedArtifact> {
  const _MockStage({required this.spec});

  final PipelineStageSpec spec;

  @override
  String get roleId => spec.id.name;

  @override
  ArtifactType get outputType => _artifactTypeForStageId(spec.id);

  @override
  Future<TypedArtifact> execute(TypedArtifact input, Object context) async {
    return input;
  }

  ArtifactType _artifactTypeForStageId(PipelineStageId stageId) {
    return switch (stageId) {
      PipelineStageId.contextEnrichment => ArtifactType.contextAssembly,
      PipelineStageId.scenePlanning => ArtifactType.directorPlan,
      PipelineStageId.roleplay => ArtifactType.roleplaySession,
      PipelineStageId.stageNarration => ArtifactType.stageNarration,
      PipelineStageId.beatResolution => ArtifactType.beatResolution,
      PipelineStageId.editorial => ArtifactType.proseDraft,
      PipelineStageId.review => ArtifactType.reviewResult,
      PipelineStageId.polish => ArtifactType.polishedProse,
      PipelineStageId.finalization => ArtifactType.sceneOutput,
    };
  }
}

class _MockArtifact extends TypedArtifact {
  const _MockArtifact({required this.type, required this.content});

  @override
  final ArtifactType type;

  final String content;

  @override
  int get tokenEstimate => (content.length / 4).ceil();

  @override
  Map<String, Object?> toJson() => {'type': type.name, 'content': content};
}

class _GoldenEventLog extends PipelineEventLog {
  final List<PipelineEvent> _events = [];

  void emitTimestamped(int timestamp, PipelineEvent event) {
    _events.add(event);
  }

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

/// Create a custom preset with some stages disabled.
PipelinePreset createCustomPreset({
  required String id,
  required String name,
  List<PipelineStageId> disabledStages = const [],
}) {
  final baseStages = BuiltInPresets.defaultNineStage.stages;

  return PipelinePreset(
    id: id,
    name: name,
    stages: baseStages
        .map(
          (s) => disabledStages.contains(s.id) ? s.copyWith(enabled: false) : s,
        )
        .toList(),
  );
}
