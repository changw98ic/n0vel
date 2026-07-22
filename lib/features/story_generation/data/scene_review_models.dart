import 'package:novel_writer/domain/storage_utils.dart';

import '../domain/scene_models.dart' show SceneQualityScore;
import 'scene_context_models.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_runtime_models.dart';
import 'polish_canon_evidence.dart';
import 'story_mechanics_evidence.dart';
import 'generation_evidence_receipt.dart';

enum SceneReviewStatus { pass, rewriteProse, replanScene }

enum SceneReviewDecision { pass, rewriteProse, replanScene }

enum SceneReviewPhase {
  preliminary,
  finalCouncil,
  deterministic,
  quality;

  String get wireName => this == finalCouncil ? 'final' : name;
}

/// One immutable audit entry for a council or deterministic quality decision.
///
/// [timestamp] is Unix epoch milliseconds. Both constructors defensively
/// snapshot [failureCodes]; [SceneReviewAttempt.snapshot] is the named
/// production entry point used where that behavior should be explicit.
final class SceneReviewAttempt {
  SceneReviewAttempt({
    required this.round,
    required this.proseAttempt,
    required this.phase,
    required this.decision,
    required this.reason,
    List<String> failureCodes = const [],
    this.timestamp,
    this.proseHash,
    this.repairScheduled = false,
  }) : _failureCodes = immutableList(failureCodes);

  factory SceneReviewAttempt.snapshot({
    required int round,
    required int proseAttempt,
    required SceneReviewPhase phase,
    required SceneReviewDecision decision,
    required String reason,
    List<String> failureCodes = const [],
    int? timestamp,
    String? proseHash,
    bool repairScheduled = false,
  }) {
    return SceneReviewAttempt(
      round: round,
      proseAttempt: proseAttempt,
      phase: phase,
      decision: decision,
      reason: reason,
      failureCodes: failureCodes,
      timestamp: timestamp,
      proseHash: proseHash,
      repairScheduled: repairScheduled,
    );
  }

  final int round;
  final int proseAttempt;
  final SceneReviewPhase phase;
  final SceneReviewDecision decision;
  final String reason;
  final List<String> _failureCodes;
  final int? timestamp;
  final String? proseHash;
  final bool repairScheduled;

  List<String> get failureCodes => List<String>.unmodifiable(_failureCodes);

  Map<String, Object?> toJson() => <String, Object?>{
    'round': round,
    'proseAttempt': proseAttempt,
    'phase': phase.wireName,
    'decision': decision.name,
    'reason': reason,
    'failureCodes': List<String>.unmodifiable(failureCodes),
    'timestamp': timestamp,
    'proseHash': proseHash,
    'repairScheduled': repairScheduled,
  };
}

enum SceneReviewCategory {
  prose,
  scenePlan,
  chapterPlan,
  continuity,
  characterState,
  worldState,
  roleplayFidelity,
  characterConsistency,
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
    this.adjudication,
    this.readerFlow,
    this.lexicon,
    this.roleplayFidelity,
    required this.decision,
    this.refinementGuidance,
  });

  final SceneReviewPassResult judge;
  final SceneReviewPassResult consistency;

  /// Tie-break evidence when the judge and consistency reviewers disagree on
  /// whether the scene must be replanned.
  final SceneReviewPassResult? adjudication;
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
        if (adjudication != null) ...adjudication!.categories,
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
      if (adjudication != null && adjudication!.reason.trim().isNotEmpty)
        'Adjudication: ${adjudication!.reason.trim()}',
      if (readerFlow != null && readerFlow!.reason.trim().isNotEmpty)
        'ReaderFlow: ${readerFlow!.reason.trim()}',
      if (lexicon != null && lexicon!.reason.trim().isNotEmpty)
        'Lexicon: ${lexicon!.reason.trim()}',
      if (roleplayFidelity != null &&
          roleplayFidelity!.reason.trim().isNotEmpty)
        'RoleplayFidelity: ${roleplayFidelity!.reason.trim()}',
    ].join('\n');
  }

  String get editorialFeedback {
    return [
      if (judge.reason.trim().isNotEmpty) 'Judge: ${judge.reason.trim()}',
      if (consistency.reason.trim().isNotEmpty)
        'Consistency: ${consistency.reason.trim()}',
      if (adjudication != null && adjudication!.reason.trim().isNotEmpty)
        'Adjudication: ${adjudication!.reason.trim()}',
      if (readerFlow != null && readerFlow!.reason.trim().isNotEmpty)
        'ReaderFlow: ${readerFlow!.reason.trim()}',
      if (lexicon != null && lexicon!.reason.trim().isNotEmpty)
        'Lexicon: ${lexicon!.reason.trim()}',
      if (roleplayFidelity != null &&
          roleplayFidelity!.status != SceneReviewStatus.pass)
        'RoleplayFidelity: $_roleplayFidelityEditorialGuidance',
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
    if (adjudication != null &&
        adjudication!.status != SceneReviewStatus.pass &&
        adjudication!.reason.trim().isNotEmpty) {
      plotIssues.add(adjudication!.reason.trim());
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
      consistencyFixes.add(_roleplayFidelityEditorialGuidance);
    }
    if (judge.status == SceneReviewStatus.pass &&
        judge.reason.trim().isNotEmpty) {
      preserve.add(judge.reason.trim());
    }
    if (consistency.status == SceneReviewStatus.pass &&
        consistency.reason.trim().isNotEmpty) {
      preserve.add(consistency.reason.trim());
    }
    if (adjudication != null &&
        adjudication!.status == SceneReviewStatus.pass &&
        adjudication!.reason.trim().isNotEmpty) {
      preserve.add(adjudication!.reason.trim());
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
      if (adjudication != null &&
          adjudication!.status != SceneReviewStatus.pass)
        adjudication!.reason.trim(),
      if (readerFlow != null && readerFlow!.status != SceneReviewStatus.pass)
        readerFlow!.reason.trim(),
      if (lexicon != null && lexicon!.status != SceneReviewStatus.pass)
        lexicon!.reason.trim(),
      if (roleplayFidelity != null &&
          roleplayFidelity!.status != SceneReviewStatus.pass)
        _roleplayFidelityEditorialGuidance,
    ].where((s) => s.isNotEmpty).toList(growable: false);
  }

  List<String> extractStrengths() {
    return [
      if (judge.status == SceneReviewStatus.pass) judge.reason.trim(),
      if (consistency.status == SceneReviewStatus.pass)
        consistency.reason.trim(),
      if (adjudication != null &&
          adjudication!.status == SceneReviewStatus.pass)
        adjudication!.reason.trim(),
      if (readerFlow != null && readerFlow!.status == SceneReviewStatus.pass)
        readerFlow!.reason.trim(),
      if (lexicon != null && lexicon!.status == SceneReviewStatus.pass)
        lexicon!.reason.trim(),
      if (roleplayFidelity != null &&
          roleplayFidelity!.status == SceneReviewStatus.pass)
        '正文已通过角色扮演公开事实一致性审查。',
    ].where((s) => s.isNotEmpty).toList(growable: false);
  }

  static const String _roleplayFidelityEditorialGuidance =
      '正文以角色扮演公开事件、已提交事实与最终公开局面为锚点；角色私有内心转化为POV当下判断。';
}

class SceneRuntimeOutput {
  SceneRuntimeOutput({
    required this.brief,
    required List<ResolvedSceneCastMember> resolvedCast,
    required this.director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    List<RuntimeRoleTurn> roleTurns = const [],
    List<ResolvedBeat> resolvedBeats = const [],
    List<BeliefState> updatedBeliefStates = const [],
    List<ContextPresentationState> updatedPresentationStates = const [],
    this.sceneState,
    this.roleplaySession,
    this.editorialDraft,
    required this.prose,
    required this.review,
    required this.proseAttempts,
    required this.softFailureCount,
    List<SceneReviewAttempt> reviewAttempts = const [],
    this.qualityScore,
    this.polishCanonEvidence,
    this.storyMechanicsEvidence,
    this.generationEvidenceReceipt,
    Map<String, Object?>? productionPreQualityEvidence,
  }) : resolvedCast = immutableList(resolvedCast),
       roleOutputs = immutableList(roleOutputs),
       roleTurns = immutableList(roleTurns),
       resolvedBeats = immutableList(resolvedBeats),
       updatedBeliefStates = immutableList(updatedBeliefStates),
       updatedPresentationStates = immutableList(updatedPresentationStates),
       reviewAttempts = immutableList(reviewAttempts),
       productionPreQualityEvidence = productionPreQualityEvidence == null
           ? null
           : immutableMap(productionPreQualityEvidence);

  final SceneBrief brief;
  final List<ResolvedSceneCastMember> resolvedCast;
  final SceneDirectorOutput director;
  final List<DynamicRoleAgentOutput> roleOutputs;
  final List<RuntimeRoleTurn> roleTurns;
  final List<ResolvedBeat> resolvedBeats;
  final List<BeliefState> updatedBeliefStates;
  final List<ContextPresentationState> updatedPresentationStates;
  final SceneState? sceneState;
  final SceneRoleplaySession? roleplaySession;
  final RuntimeEditorialDraft? editorialDraft;
  final SceneProseDraft prose;
  final SceneReviewResult review;
  final int proseAttempts;
  final int softFailureCount;
  final List<SceneReviewAttempt> reviewAttempts;
  final SceneQualityScore? qualityScore;
  final PolishCanonEvidence? polishCanonEvidence;
  final StoryMechanicsEvidence? storyMechanicsEvidence;

  /// Present only after the no-redraw journal has durably verified the exact
  /// intent/outcome/artifact chain.  It is never synthesized from an in-memory
  /// capture or an adaptive production run.
  final GenerationEvidenceReceipt? generationEvidenceReceipt;
  final Map<String, Object?>? productionPreQualityEvidence;

  SceneRuntimeOutput withGenerationEvidenceReceipt(
    GenerationEvidenceReceipt receipt,
  ) => SceneRuntimeOutput(
    brief: brief,
    resolvedCast: resolvedCast,
    director: director,
    roleOutputs: roleOutputs,
    roleTurns: roleTurns,
    resolvedBeats: resolvedBeats,
    updatedBeliefStates: updatedBeliefStates,
    updatedPresentationStates: updatedPresentationStates,
    sceneState: sceneState,
    roleplaySession: roleplaySession,
    editorialDraft: editorialDraft,
    prose: prose,
    review: review,
    proseAttempts: proseAttempts,
    softFailureCount: softFailureCount,
    reviewAttempts: reviewAttempts,
    qualityScore: qualityScore,
    polishCanonEvidence: polishCanonEvidence,
    storyMechanicsEvidence: storyMechanicsEvidence,
    generationEvidenceReceipt: receipt,
    productionPreQualityEvidence: productionPreQualityEvidence,
  );
}
