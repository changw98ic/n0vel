import 'package:novel_writer/app/llm/app_llm_client.dart';
import '../domain/contracts/settings_contract.dart';

import 'ai_cliche_detector.dart';
import 'scene_pipeline_models.dart'
    show SceneBeat, SceneBeatKind, SceneEditorialDraft;
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'story_generation_models.dart';
import 'scene_text_utils.dart';
import 'formal_evaluation_policy.dart';
import 'generation_evidence_fingerprints.dart';

class ScenePolishResult {
  final String text;
  final AiClicheReport clicheReport;
  final bool usedLocalFallback;
  final String? sourceLogicalAttemptId;
  final String? sourceCallSiteId;

  const ScenePolishResult({
    required this.text,
    required this.clicheReport,
    this.usedLocalFallback = false,
    this.sourceLogicalAttemptId,
    this.sourceCallSiteId,
  });
}

class ScenePolishPass {
  static const Duration _polishTimeout = Duration(seconds: 120);
  static const int _maxPolishAttempts = 2;

  ScenePolishPass({
    required StoryGenerationSettingsContract settingsStore,
    Duration polishTimeout = _polishTimeout,
  }) : _settingsStore = settingsStore,
       _requestTimeout = polishTimeout;

  final StoryGenerationSettingsContract _settingsStore;
  final Duration _requestTimeout;
  final AiClicheDetector _clicheDetector = AiClicheDetector();

  Future<ScenePolishResult> polish({
    required SceneBrief brief,
    required SceneEditorialDraft editorialDraft,
    required Iterable<Object> resolvedBeats,
    String? reviewFeedback,
    RefinementGuidance? refinementGuidance,
  }) async {
    final noContentRedraw = _noContentRedraw;
    final formalEvaluation = FormalEvaluationPolicy.isActive(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    if (brief.metadata['localPolishOnly'] == true) {
      if (noContentRedraw) {
        throw StoryGenerationEvidencePreflightFailure(
          'no-redraw language polish cannot use a local-only result',
        );
      }
      return _localResult(editorialDraft.text);
    }

    final acceptedFacts = _acceptedFactsFrom(resolvedBeats);

    for (var attempt = 0; attempt < _maxPolishAttempts; attempt++) {
      final requestOutcome = await _requestPolish(
        brief: brief,
        editorialDraft: editorialDraft,
        acceptedFacts: acceptedFacts,
        reviewFeedback: reviewFeedback,
        refinementGuidance: refinementGuidance,
        previousAttempt: attempt > 0,
      );
      final result = requestOutcome.result;
      if (!result.succeeded || result.text == null) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError(
            result.detail ?? 'formal language polish provider call failed',
          );
        }
        return _localResult(editorialDraft.text);
      }

      final returnedText = result.text!;
      final polished = noContentRedraw ? returnedText : returnedText.trim();
      if (polished.trim().isEmpty) {
        if (formalEvaluation || noContentRedraw) {
          throw StateError('formal language polish returned empty prose');
        }
        return _localResult(editorialDraft.text);
      }

      final report = _clicheDetector.detect(polished);
      if (!report.isSevere || noContentRedraw) {
        // In a frozen experiment the first successful completion is the
        // sampled completion. A severe cliche report may reject the sample at
        // a later quality gate, but it must never trigger another provider
        // draw here.
        final source = requestOutcome.sourceEvidence;
        if (noContentRedraw &&
            (source == null ||
                source.logicalAttemptId == null ||
                !source.succeeded ||
                source.callSiteId != 'language-polish' ||
                !_sameArtifactDigest(
                  source.artifactDigest,
                  ArtifactDigest.fromUtf8String(polished),
                ))) {
          throw StoryGenerationEvidenceIntegrityFailure(
            'polish prose is not the exact successful formal provider artifact',
          );
        }
        return ScenePolishResult(
          text: polished,
          clicheReport: report,
          sourceLogicalAttemptId: source?.logicalAttemptId,
          sourceCallSiteId: source?.callSiteId,
        );
      }
    }

    if (formalEvaluation) {
      throw StateError(
        'formal language polish exhausted attempts with severe cliches',
      );
    }
    final fallbackReport = _clicheDetector.detect(editorialDraft.text);
    return ScenePolishResult(
      text: editorialDraft.text.trim(),
      clicheReport: fallbackReport,
      usedLocalFallback: true,
    );
  }

  Future<_PolishRequestOutcome> _requestPolish({
    required SceneBrief brief,
    required SceneEditorialDraft editorialDraft,
    required List<String> acceptedFacts,
    String? reviewFeedback,
    RefinementGuidance? refinementGuidance,
    bool previousAttempt = false,
  }) async {
    final noContentRedraw = _noContentRedraw;
    final evidence = noContentRedraw
        ? StoryGenerationAttemptEvidenceCapture()
        : null;
    try {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'polish',
        callSiteId: 'language-polish',
      );
      final resolvedVariables = <String, Object?>{
        'sceneTitle': brief.sceneTitle,
        'targetLength': brief.targetLength,
        'factsGuard': _factsGuard(acceptedFacts),
        'speechAnchors': _characterSpeechAnchors(brief),
        'refinementGuidance': refinementGuidance?.toPromptText() ?? '',
        'reviewFeedback': reviewFeedback?.trim() ?? '',
        'previousAttempt': previousAttempt ? '上一轮润色后仍有人工智能写作痕迹，请更加彻底地改写。' : '',
        'prose': editorialDraft.text,
      };
      final messages = promptIdentity.render(resolvedVariables).messages;
      final request = requestFormalStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        promptInvocation: promptIdentity,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        initialMaxTokens: storyGenerationEditorialMaxTokens,
        onAttemptEvidence: evidence?.record,
        messages: messages,
      );
      final result = noContentRedraw
          ? await request
          : await request.timeout(_requestTimeout);
      _requireCompleteNoRedrawEvidence(
        noContentRedraw: noContentRedraw,
        evidence: evidence,
        stageLabel: 'language polish',
      );
      final source = evidence != null && evidence.attempts.isNotEmpty
          ? evidence.attempts.last
          : null;
      return _PolishRequestOutcome(result: result, sourceEvidence: source);
    } on StoryGenerationEvidencePreflightFailure {
      rethrow;
    } catch (_) {
      if (noContentRedraw) {
        rethrow;
      }
      return const _PolishRequestOutcome(
        result: AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: 'Language polish timed out.',
        ),
      );
    }
  }

  bool get _noContentRedraw =>
      StoryGenerationRetryScope.current?.allowsContentRedraw == false;

  ScenePolishResult _localResult(String text) {
    final report = _clicheDetector.detect(text);
    return ScenePolishResult(
      text: text.trim(),
      clicheReport: report,
      usedLocalFallback: true,
    );
  }

  List<String> _acceptedFactsFrom(Iterable<Object> resolvedBeats) {
    final facts = <String>[];
    for (final beat in resolvedBeats) {
      if (beat is ResolvedBeat) {
        if (beat.actionAccepted) {
          facts.addAll(
            beat.newPublicFacts.where((fact) => fact.trim().isNotEmpty),
          );
        }
        continue;
      }
      if (beat is SceneBeat && beat.kind == SceneBeatKind.fact) {
        final fact = beat.content.trim();
        if (fact.isNotEmpty) {
          facts.add(fact);
        }
      }
    }
    return List<String>.unmodifiable(facts);
  }

  String _factsGuard(List<String> acceptedFacts) {
    if (acceptedFacts.isEmpty) return '';
    final preview = acceptedFacts.length > 8
        ? '${acceptedFacts.take(8).join('；')}…'
        : acceptedFacts.join('；');
    return '已裁定事实（润色时保持）：$preview';
  }

  String _characterSpeechAnchors(SceneBrief brief) {
    final anchors = characterAnchorsText(brief.characterProfiles);
    return anchors.isEmpty ? '' : '角色语言特征（对白必须符合）：\n$anchors';
  }
}

bool _sameArtifactDigest(ArtifactDigest? left, ArtifactDigest right) =>
    left != null &&
    left.domainTag == right.domainTag &&
    left.byteLength == right.byteLength &&
    left.digest == right.digest;

final class _PolishRequestOutcome {
  const _PolishRequestOutcome({required this.result, this.sourceEvidence});

  final AppLlmChatResult result;
  final StoryGenerationAttemptEvidence? sourceEvidence;
}

void _requireCompleteNoRedrawEvidence({
  required bool noContentRedraw,
  required StoryGenerationAttemptEvidenceCapture? evidence,
  required String stageLabel,
}) {
  if (!noContentRedraw) return;
  if (evidence == null || !evidence.toEnvelope().evidenceComplete) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw $stageLabel produced incomplete attempt evidence',
    );
  }
}
