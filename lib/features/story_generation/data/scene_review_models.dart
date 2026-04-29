import 'package:novel_writer/app/state/app_storage_clone.dart';

import '../domain/scene_models.dart' show SceneQualityScore;
import 'scene_context_models.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_runtime_models.dart';

enum SceneReviewStatus { pass, rewriteProse, replanScene }

enum SceneReviewDecision { pass, rewriteProse, replanScene }

enum SceneReviewCategory {
  prose,
  scenePlan,
  chapterPlan,
  continuity,
  characterState,
  worldState,
  roleplayFidelity,
}

class SceneReviewPassResult {
  const SceneReviewPassResult({
    required this.status,
    required this.reason,
    required this.rawText,
    this.categories = const [],
  });

  final SceneReviewStatus status;
  final String reason;
  final String rawText;
  final List<SceneReviewCategory> categories;
}

class RefinementGuidance {
  RefinementGuidance({
    List<String> plotIssues = const [],
    List<String> consistencyFixes = const [],
    List<String> styleTargets = const [],
    List<String> preserve = const [],
    this.focusInstruction = '',
  }) : plotIssues = immutableList(plotIssues),
       consistencyFixes = immutableList(consistencyFixes),
       styleTargets = immutableList(styleTargets),
       preserve = immutableList(preserve);

  final List<String> plotIssues;
  final List<String> consistencyFixes;
  final List<String> styleTargets;
  final List<String> preserve;
  final String focusInstruction;

  String toPromptText() {
    final parts = <String>[];
    if (plotIssues.isNotEmpty) {
      parts.add('情节问题：${plotIssues.join('；')}');
    }
    if (consistencyFixes.isNotEmpty) {
      parts.add('一致性修正：${consistencyFixes.join('；')}');
    }
    if (styleTargets.isNotEmpty) {
      parts.add('风格目标：${styleTargets.join('；')}');
    }
    if (preserve.isNotEmpty) {
      parts.add('保留亮点：${preserve.join('；')}');
    }
    if (focusInstruction.isNotEmpty) {
      parts.add('聚焦：$focusInstruction');
    }
    return parts.join('\n');
  }
}

class SceneReviewResult {
  const SceneReviewResult({
    required this.judge,
    required this.consistency,
    this.readerFlow,
    this.lexicon,
    this.roleplayFidelity,
    required this.decision,
    this.refinementGuidance,
  });

  final SceneReviewPassResult judge;
  final SceneReviewPassResult consistency;
  final SceneReviewPassResult? readerFlow;
  final SceneReviewPassResult? lexicon;
  final SceneReviewPassResult? roleplayFidelity;
  final SceneReviewDecision decision;
  final RefinementGuidance? refinementGuidance;

  List<SceneReviewCategory> get categories {
    final seen = <SceneReviewCategory>{};
    return [
      for (final category in [
        ...judge.categories,
        ...consistency.categories,
        if (readerFlow != null) ...readerFlow!.categories,
        if (lexicon != null) ...lexicon!.categories,
        if (roleplayFidelity != null) ...roleplayFidelity!.categories,
      ])
        if (seen.add(category)) category,
    ];
  }

  String get feedback {
    return [
      if (judge.reason.trim().isNotEmpty) 'Judge: ${judge.reason.trim()}',
      if (consistency.reason.trim().isNotEmpty)
        'Consistency: ${consistency.reason.trim()}',
      if (readerFlow != null && readerFlow!.reason.trim().isNotEmpty)
        'ReaderFlow: ${readerFlow!.reason.trim()}',
      if (lexicon != null && lexicon!.reason.trim().isNotEmpty)
        'Lexicon: ${lexicon!.reason.trim()}',
      if (roleplayFidelity != null &&
          roleplayFidelity!.reason.trim().isNotEmpty)
        'RoleplayFidelity: ${roleplayFidelity!.reason.trim()}',
    ].join('\n');
  }

  RefinementGuidance synthesizeGuidance() {
    final plotIssues = <String>[];
    final consistencyFixes = <String>[];
    final styleTargets = <String>[];
    final preserve = <String>[];

    if (judge.status != SceneReviewStatus.pass &&
        judge.reason.trim().isNotEmpty) {
      plotIssues.add(judge.reason.trim());
    }
    if (consistency.status != SceneReviewStatus.pass &&
        consistency.reason.trim().isNotEmpty) {
      consistencyFixes.add(consistency.reason.trim());
    }
    if (readerFlow != null &&
        readerFlow!.status != SceneReviewStatus.pass &&
        readerFlow!.reason.trim().isNotEmpty) {
      styleTargets.add(readerFlow!.reason.trim());
    }
    if (lexicon != null &&
        lexicon!.status != SceneReviewStatus.pass &&
        lexicon!.reason.trim().isNotEmpty) {
      styleTargets.add(lexicon!.reason.trim());
    }
    if (roleplayFidelity != null &&
        roleplayFidelity!.status != SceneReviewStatus.pass &&
        roleplayFidelity!.reason.trim().isNotEmpty) {
      consistencyFixes.add(roleplayFidelity!.reason.trim());
    }
    if (judge.status == SceneReviewStatus.pass &&
        judge.reason.trim().isNotEmpty) {
      preserve.add(judge.reason.trim());
    }
    if (readerFlow != null &&
        readerFlow!.status == SceneReviewStatus.pass &&
        readerFlow!.reason.trim().isNotEmpty) {
      preserve.add(readerFlow!.reason.trim());
    }

    final critical = <String>[...plotIssues, ...consistencyFixes];
    final focusInstruction = critical.isNotEmpty
        ? critical.first.length > 80
              ? '${critical.first.substring(0, 77)}...'
              : critical.first
        : styleTargets.isNotEmpty
        ? styleTargets.first
        : '';

    return RefinementGuidance(
      plotIssues: plotIssues,
      consistencyFixes: consistencyFixes,
      styleTargets: styleTargets,
      preserve: preserve,
      focusInstruction: focusInstruction,
    );
  }

  List<String> extractIssues() {
    return [
      if (judge.status != SceneReviewStatus.pass) judge.reason.trim(),
      if (consistency.status != SceneReviewStatus.pass)
        consistency.reason.trim(),
      if (readerFlow != null && readerFlow!.status != SceneReviewStatus.pass)
        readerFlow!.reason.trim(),
      if (lexicon != null && lexicon!.status != SceneReviewStatus.pass)
        lexicon!.reason.trim(),
      if (roleplayFidelity != null &&
          roleplayFidelity!.status != SceneReviewStatus.pass)
        roleplayFidelity!.reason.trim(),
    ].where((s) => s.isNotEmpty).toList(growable: false);
  }

  List<String> extractStrengths() {
    return [
      if (judge.status == SceneReviewStatus.pass) judge.reason.trim(),
      if (consistency.status == SceneReviewStatus.pass)
        consistency.reason.trim(),
      if (readerFlow != null && readerFlow!.status == SceneReviewStatus.pass)
        readerFlow!.reason.trim(),
      if (lexicon != null && lexicon!.status == SceneReviewStatus.pass)
        lexicon!.reason.trim(),
      if (roleplayFidelity != null &&
          roleplayFidelity!.status == SceneReviewStatus.pass)
        roleplayFidelity!.reason.trim(),
    ].where((s) => s.isNotEmpty).toList(growable: false);
  }
}

class SceneRuntimeOutput {
  SceneRuntimeOutput({
    required this.brief,
    required List<ResolvedSceneCastMember> resolvedCast,
    required this.director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    List<RolePlayTurnOutput> roleTurns = const [],
    List<ResolvedBeat> resolvedBeats = const [],
    List<BeliefState> updatedBeliefStates = const [],
    List<PresentationState> updatedPresentationStates = const [],
    this.sceneState,
    this.roleplaySession,
    this.editorialDraft,
    required this.prose,
    required this.review,
    required this.proseAttempts,
    required this.softFailureCount,
    this.qualityScore,
  }) : resolvedCast = immutableList(resolvedCast),
       roleOutputs = immutableList(roleOutputs),
       roleTurns = immutableList(roleTurns),
       resolvedBeats = immutableList(resolvedBeats),
       updatedBeliefStates = immutableList(updatedBeliefStates),
       updatedPresentationStates = immutableList(updatedPresentationStates);

  final SceneBrief brief;
  final List<ResolvedSceneCastMember> resolvedCast;
  final SceneDirectorOutput director;
  final List<DynamicRoleAgentOutput> roleOutputs;
  final List<RolePlayTurnOutput> roleTurns;
  final List<ResolvedBeat> resolvedBeats;
  final List<BeliefState> updatedBeliefStates;
  final List<PresentationState> updatedPresentationStates;
  final SceneState? sceneState;
  final SceneRoleplaySession? roleplaySession;
  final SceneEditorialDraft? editorialDraft;
  final SceneProseDraft prose;
  final SceneReviewResult review;
  final int proseAttempts;
  final int softFailureCount;
  final SceneQualityScore? qualityScore;
}
