import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'ai_cliche_detector.dart';
import 'scene_pipeline_models.dart'
    show SceneBeat, SceneBeatKind, SceneEditorialDraft;
import 'story_generation_pass_retry.dart';
import 'story_generation_models.dart';
import 'scene_text_utils.dart';

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

  ScenePolishPass({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;
  final AiClicheDetector _clicheDetector = AiClicheDetector();

  Future<ScenePolishResult> polish({
    required SceneBrief brief,
    required SceneEditorialDraft editorialDraft,
    required Iterable<Object> resolvedBeats,
    String? reviewFeedback,
    RefinementGuidance? refinementGuidance,
  }) async {
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
        return _localResult(editorialDraft.text);
      }

      final polished = result.text!.trim();
      if (polished.isEmpty) {
        return _localResult(editorialDraft.text);
      }

      final report = _clicheDetector.detect(polished);
      if (!report.isSevere) {
        return ScenePolishResult(text: polished, clicheReport: report);
      }
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
      return await requestStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        initialMaxTokens: storyGenerationEditorialMaxTokens,
        messages: [
          AppLlmChatMessage(
            role: 'system',
            content: _polishSystemPrompt(
              refinementGuidance: refinementGuidance,
            ),
          ),
          AppLlmChatMessage(
            role: 'user',
            content: [
              '任务：language_polish',
              '场景：${brief.sceneTitle}',
              '目标字数：约${brief.targetLength}汉字',
              _factsGuard(acceptedFacts),
              _characterSpeechAnchors(brief),
              if (refinementGuidance != null)
                '精炼指引：\n${refinementGuidance.toPromptText()}',
              if (reviewFeedback != null && reviewFeedback.trim().isNotEmpty)
                '审查反馈：${reviewFeedback.trim()}',
              if (previousAttempt) '注意：上一轮润色后仍有人工智能写作痕迹，请更加彻底地改写。',
              '以下是需要润色的散文稿：\n\n${editorialDraft.text}',
            ].where((line) => line.isNotEmpty).join('\n\n'),
          ),
        ],
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

  String _polishSystemPrompt({RefinementGuidance? refinementGuidance}) {
    final base =
        '你是一位中文小说语言润色编辑。\n'
        '你的任务是对已有散文稿进行语言层面的润色，方向如下：\n'
        '1. 保持已裁定的情节事实\n'
        '2. 消除以下人工智能写作痕迹：'
        '"不由得""竟然""心中暗想""恍然大悟""眼眶微红""一股莫名的"'
        '"嘴角微微上扬""露出一抹苦笑""淡淡一笑""缓缓开口"等\n'
        '3. 避免连续的短句（3-8字）超过3个，用逗号或连词连接\n'
        '4. 避免同一段落中重复使用同一个形容词\n'
        '5. 对白体现角色个性差异\n'
        '6. 保持段落呼吸感，长短句交替\n'
        '7. 过渡衔接自然\n'
        '输出润色后的散文正文。';
    if (refinementGuidance == null) return base;
    final focus = refinementGuidance.focusInstruction.trim();
    if (focus.isEmpty) return base;
    return '$base\n本次润色聚焦：$focus';
  }
}
