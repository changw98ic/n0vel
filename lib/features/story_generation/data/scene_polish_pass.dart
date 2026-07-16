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

class ScenePolishResult {
  final String text;
  final AiClicheReport clicheReport;
  final bool usedLocalFallback;

  const ScenePolishResult({
    required this.text,
    required this.clicheReport,
    this.usedLocalFallback = false,
  });
}

class ScenePolishPass {
  static const Duration _polishTimeout = Duration(seconds: 120);
  static const int _maxPolishAttempts = 2;

  ScenePolishPass({required StoryGenerationSettingsContract settingsStore})
    : _settingsStore = settingsStore;

  final StoryGenerationSettingsContract _settingsStore;
  final AiClicheDetector _clicheDetector = AiClicheDetector();

  Future<ScenePolishResult> polish({
    required SceneBrief brief,
    required SceneEditorialDraft editorialDraft,
    required Iterable<Object> resolvedBeats,
    String? reviewFeedback,
    RefinementGuidance? refinementGuidance,
  }) async {
    final formalEvaluation = FormalEvaluationPolicy.isActive(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    if (brief.metadata['localPolishOnly'] == true) {
      return _localResult(editorialDraft.text);
    }

    final acceptedFacts = _acceptedFactsFrom(resolvedBeats);

    for (var attempt = 0; attempt < _maxPolishAttempts; attempt++) {
      final result = await _requestPolish(
        brief: brief,
        editorialDraft: editorialDraft,
        acceptedFacts: acceptedFacts,
        reviewFeedback: reviewFeedback,
        refinementGuidance: refinementGuidance,
        previousAttempt: attempt > 0,
      );
      if (!result.succeeded || result.text == null) {
        if (formalEvaluation) {
          throw StateError(
            result.detail ?? 'formal language polish provider call failed',
          );
        }
        return _localResult(editorialDraft.text);
      }

      final polished = result.text!.trim();
      if (polished.isEmpty) {
        if (formalEvaluation) {
          throw StateError('formal language polish returned empty prose');
        }
        return _localResult(editorialDraft.text);
      }

      final report = _clicheDetector.detect(polished);
      if (!report.isSevere) {
        return ScenePolishResult(text: polished, clicheReport: report);
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

  Future<AppLlmChatResult> _requestPolish({
    required SceneBrief brief,
    required SceneEditorialDraft editorialDraft,
    required List<String> acceptedFacts,
    String? reviewFeedback,
    RefinementGuidance? refinementGuidance,
    bool previousAttempt = false,
  }) async {
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
      return await requestFormalStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        promptInvocation: promptIdentity,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        initialMaxTokens: storyGenerationEditorialMaxTokens,
        messages: messages,
      ).timeout(_polishTimeout);
    } catch (_) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.timeout,
        detail: 'Language polish timed out.',
      );
    }
  }

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
