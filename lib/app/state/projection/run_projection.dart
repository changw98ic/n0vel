import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/app_providers.dart';
import '../story_generation_run_store.dart';

final runProjectionProvider =
    NotifierProvider<RunProjectionNotifier, RunProjection>(
      RunProjectionNotifier.new,
    );

class RunProjectionNotifier extends Notifier<RunProjection> {
  @override
  RunProjection build() {
    final runStore = ref.read(storyGenerationRunStoreProvider);
    void listener() => state = RunProjection.fromStore(runStore);
    runStore.addListener(listener);
    ref.onDispose(() => runStore.removeListener(listener));
    return RunProjection.fromStore(runStore);
  }
}

class RunProjection {
  const RunProjection({
    required this.sceneScopeId,
    required this.sceneId,
    required this.sceneLabel,
    required this.status,
    required this.phase,
    required this.headline,
    required this.summary,
    required this.stageSummary,
    required this.errorDetail,
    required this.stages,
    required this.messageCount,
    required this.participantCount,
    required this.candidateCount,
    required this.hasCandidate,
    required this.hasRun,
    required this.isRunning,
    required this.shouldPromptForRecovery,
    required this.canRetry,
    required this.canDiscard,
  });

  factory RunProjection.fromStore(StoryGenerationRunStore store) {
    return RunProjection.fromSnapshot(
      sceneScopeId: store.activeSceneScopeId,
      snapshot: store.snapshot,
    );
  }

  factory RunProjection.fromSnapshot({
    required String sceneScopeId,
    required StoryGenerationRunSnapshot snapshot,
  }) {
    final candidateCount = snapshot.messages.where(_isCandidateMessage).length;
    final hasCandidate =
        candidateCount > 0 ||
        (snapshot.hasRun &&
            _candidatePhases.contains(snapshot.phase) &&
            snapshot.status == StoryGenerationRunStatus.completed);
    return RunProjection(
      sceneScopeId: sceneScopeId,
      sceneId: snapshot.sceneId,
      sceneLabel: snapshot.sceneLabel,
      status: snapshot.status,
      phase: snapshot.phase,
      headline: snapshot.headline,
      summary: snapshot.summary,
      stageSummary: snapshot.stageSummary,
      errorDetail: snapshot.errorDetail,
      stages: [
        for (final stage in snapshot.stageTimeline)
          RunStageProjection.fromSnapshot(stage),
      ],
      messageCount: snapshot.messages.length,
      participantCount: snapshot.participants.length,
      candidateCount: candidateCount,
      hasCandidate: hasCandidate,
      hasRun: snapshot.hasRun,
      isRunning: snapshot.status == StoryGenerationRunStatus.running,
      shouldPromptForRecovery:
          snapshot.hasRun &&
          snapshot.status == StoryGenerationRunStatus.running,
      canRetry:
          snapshot.hasRun &&
          (snapshot.status == StoryGenerationRunStatus.running ||
              snapshot.status == StoryGenerationRunStatus.failed),
      canDiscard:
          snapshot.hasRun && snapshot.status != StoryGenerationRunStatus.idle,
    );
  }

  final String sceneScopeId;
  final String sceneId;
  final String sceneLabel;
  final StoryGenerationRunStatus status;
  final StoryGenerationRunPhase phase;
  final String headline;
  final String summary;
  final String stageSummary;
  final String errorDetail;
  final List<RunStageProjection> stages;
  final int messageCount;
  final int participantCount;
  final int candidateCount;
  final bool hasCandidate;
  final bool hasRun;
  final bool isRunning;
  final bool shouldPromptForRecovery;
  final bool canRetry;
  final bool canDiscard;

  RunStageProjection? get activeStage {
    for (final stage in stages) {
      if (stage.status == StoryGenerationRunStageStatus.running ||
          stage.status == StoryGenerationRunStageStatus.failed) {
        return stage;
      }
    }
    return null;
  }

  String get failureSummary {
    final trimmedError = errorDetail.trim();
    if (trimmedError.isNotEmpty) {
      return trimmedError;
    }
    final failedStage = activeStage;
    final failedSummary = failedStage?.summary?.trim();
    if (failedSummary != null && failedSummary.isNotEmpty) {
      return failedSummary;
    }
    return status == StoryGenerationRunStatus.failed ? stageSummary : '';
  }

  @override
  bool operator ==(Object other) {
    return other is RunProjection &&
        other.sceneScopeId == sceneScopeId &&
        other.sceneId == sceneId &&
        other.sceneLabel == sceneLabel &&
        other.status == status &&
        other.phase == phase &&
        other.headline == headline &&
        other.summary == summary &&
        other.stageSummary == stageSummary &&
        other.errorDetail == errorDetail &&
        listEquals(other.stages, stages) &&
        other.messageCount == messageCount &&
        other.participantCount == participantCount &&
        other.candidateCount == candidateCount &&
        other.hasCandidate == hasCandidate &&
        other.hasRun == hasRun &&
        other.isRunning == isRunning &&
        other.shouldPromptForRecovery == shouldPromptForRecovery &&
        other.canRetry == canRetry &&
        other.canDiscard == canDiscard;
  }

  @override
  int get hashCode => Object.hash(
    sceneScopeId,
    sceneId,
    sceneLabel,
    status,
    phase,
    headline,
    summary,
    stageSummary,
    errorDetail,
    Object.hashAll(stages),
    messageCount,
    participantCount,
    candidateCount,
    hasCandidate,
    hasRun,
    isRunning,
    shouldPromptForRecovery,
    canRetry,
    canDiscard,
  );

  static const _candidatePhases = {
    StoryGenerationRunPhase.candidate,
    StoryGenerationRunPhase.feedback,
    StoryGenerationRunPhase.check,
    StoryGenerationRunPhase.commit,
  };

  static bool _isCandidateMessage(StoryGenerationRunMessage message) {
    return message.kind == StoryGenerationRunMessageKind.editorial ||
        message.kind == StoryGenerationRunMessageKind.review;
  }
}

class RunStageProjection {
  const RunStageProjection({
    required this.stageId,
    required this.label,
    required this.status,
    required this.attempt,
    this.failureCode,
    this.summary,
  });

  factory RunStageProjection.fromSnapshot(
    StoryGenerationRunStageSnapshot snapshot,
  ) {
    return RunStageProjection(
      stageId: snapshot.stageId.name,
      label: snapshot.label,
      status: snapshot.status,
      attempt: snapshot.attempt,
      failureCode: snapshot.failureCode,
      summary: snapshot.summary,
    );
  }

  final String stageId;
  final String label;
  final StoryGenerationRunStageStatus status;
  final int attempt;
  final String? failureCode;
  final String? summary;

  @override
  bool operator ==(Object other) {
    return other is RunStageProjection &&
        other.stageId == stageId &&
        other.label == label &&
        other.status == status &&
        other.attempt == attempt &&
        other.failureCode == failureCode &&
        other.summary == summary;
  }

  @override
  int get hashCode =>
      Object.hash(stageId, label, status, attempt, failureCode, summary);
}
