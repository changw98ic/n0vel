import '../domain/contracts/settings_contract.dart';

import 'prompt_string_utils.dart';
import 'scene_cast_roleplay_policy.dart';
import 'scene_runtime_models.dart' show SceneBrief;
import 'scene_stage_narrator.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'scene_pipeline_models.dart';
import 'scene_roleplay_session_models.dart';
import 'story_prompt_templates.dart';
import 'formal_evaluation_policy.dart';

/// Generates prose only from resolved [SceneBeat]s and allowed narration state.
///
/// Unlike [SceneProseGenerator] which operates on raw role-summary text,
/// the editorial generator stitches beats into coherent prose, preserving
/// factual boundaries established by the resolver.
class SceneEditorialGenerator {
  SceneEditorialGenerator({
    required StoryGenerationSettingsContract settingsStore,
  }) : _settingsStore = settingsStore;

  final StoryGenerationSettingsContract _settingsStore;

  /// Build scene-position and hook warning lines for the editorial user prompt.
  static String buildUserPrompt({
    required SceneBrief brief,
    required int attempt,
  }) {
    final isFirstScene = brief.sceneIndex == 0;
    final isLastScene =
        brief.totalScenesInChapter > 0 &&
        brief.sceneIndex == brief.totalScenesInChapter - 1;
    final dialogueBudget = (brief.targetLength * 0.35).ceil();

    return [
      '本章场景位置：第${brief.sceneIndex + 1}个场景（共${brief.totalScenesInChapter}个）',
      if (isFirstScene)
        '⚠️ 这是本章首个场景。开头硬约束：第一句禁止环境白描。最终输出前必须逐项自检：前100字同时出现动作动词(冲/跑/抓/摔/撞/翻/喊/拍/推/拉/砸/踢)和悬念词(突然/竟然/意外/发现/秘密/失踪)，或以「」对白/疑问句开头；前20字内出现句号形成短句冲击。不得只满足“有动作”一项。首场还必须在前两段明确“异常或风险 → 主角此刻要什么 → 谁/什么阻碍 → 行动后风险或线索如何变化”的因果链。参考："「谁动过它？」柳溪拍上终端，突然发现时间戳不对。"',
      if (isLastScene)
        '⚠️ 这是本章最后场景。最终输出前必须逐项自检：最后150字除问号/感叹/破折号/省略号外，还必须包含未完成动作(还没/来不及/正要/就要/差一点/眼看)或悬念词(真相/秘密/危险/背后/发现/到底/究竟)；不得只用标点伪造钩子。',
      if (brief.sceneSummary.isNotEmpty)
        '【场景道具约束】场景概要：${brief.sceneSummary.length > 60 ? '${brief.sceneSummary.substring(0, 57)}...' : brief.sceneSummary}。所有角色互动的物品必须在场景中合理存在。禁止引入与场景矛盾的现代便利设施。',
      '【最终交稿机械自检】先在脑中列出至少8个「」对白回合，再展开正文；每回合不少于18个汉字，并让至少4轮对白改变事实、选择、关系或压力。按本场目标长度预留不少于$dialogueBudget个中文对白字；对白必须占全文至少35%（25%以下会被直接拒稿）。删除多余心理解释和环境白描，每两段至少一段含对白。未满足时先改稿，不能提交。',
    ].join('\n');
  }

  /// Generate an editorial draft from resolved beats.
  ///
  /// [reviewFeedback] from a previous attempt is included for rewrite passes.
  /// [previousProse] is the full text of the previous attempt so the model can
  /// see what it wrote and make targeted improvements.
  Future<SceneEditorialDraft> generate({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
    required List<LightContextCapsule> capsules,
    required int attempt,
    SceneRoleplaySession? roleplaySession,
    String? reviewFeedback,
    String? previousProse,
  }) async {
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      taskCard.metadata,
      formalExecution: taskCard.brief.formalExecution,
    );
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      taskCard.brief.metadata,
      formalExecution: taskCard.brief.formalExecution,
    );
    if (taskCard.metadata['localEditorialOnly'] == true ||
        taskCard.brief.metadata['localEditorialOnly'] == true) {
      return _localDraft(
        taskCard: taskCard,
        resolvedBeats: resolvedBeats,
        attempt: attempt,
        roleplaySession: roleplaySession,
      );
    }

    final l = StoryPromptTemplates.locale;
    final hardLimit = taskCard.brief.targetLength < 1
        ? 800
        : taskCard.brief.targetLength * 2;
    final roleplayDraft = roleplaySession?.toRoleplayDraftPromptText(
      maxChars: hardLimit * 2,
    );
    final noninteractiveCastBoundary = noninteractiveCastBoundaryText(
      taskCard.brief,
    );
    final dialogueRepairDirective = _dialogueRepairDirective(reviewFeedback);
    final rejectedEvidenceDirective = buildRejectedEvidenceDirective(
      reviewFeedback,
    );
    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'editorial',
      callSiteId: 'scene-editorial-generator',
    );
    final stageCapsules = _stageCapsules(capsules);
    final retrievalCapsules = _retrievalCapsules(capsules);
    final hasRoleplay = roleplaySession != null && !roleplaySession.isEmpty;
    final resolvedVariables = <String, Object?>{
      'sceneTitle': PromptStringUtils.compact(
        taskCard.brief.sceneTitle,
        maxChars: 40,
      ),
      'targetLength': taskCard.brief.targetLength,
      'hardLimit': hardLimit,
      'briefInstructions': buildUserPrompt(
        brief: taskCard.brief,
        attempt: attempt,
      ),
      'sceneSummary': PromptStringUtils.compact(
        taskCard.brief.sceneSummary,
        maxChars: 120,
      ),
      'noninteractiveBoundary': noninteractiveCastBoundary,
      'roleplayDraftBlock': roleplayDraft != null && roleplayDraft.isNotEmpty
          ? '角色扮演正文草稿：\n$roleplayDraft\n润色边界：以角色扮演正文草稿为正文底稿，保留角色动作、对白、顺序和已裁定事实；补顺段落衔接、语气和节奏。'
          : '',
      'resolvedBeats': _formatBeats(resolvedBeats),
      'stageContext': stageCapsules.isEmpty
          ? ''
          : '场景旁白/舞台信息（权威场景源）：${PromptStringUtils.mapJoin(stageCapsules, (c) => c.summary, separator: l.listSeparator)}',
      'retrievalContext': retrievalCapsules.isEmpty
          ? ''
          : '${l.contextLabel}${l.colon}${PromptStringUtils.mapJoin(retrievalCapsules, (c) => c.summary, separator: l.listSeparator)}',
      'roleplayProcess': hasRoleplay
          ? '角色扮演公开过程：${roleplaySession.toCommittedPromptText(maxChars: 2200)}'
          : '',
      'roleplayGuidance': hasRoleplay
          ? '正文依据：围绕角色扮演过程中的可见事件、正文片段与已提交事实润色；角色内心用于POV当下判断。'
          : '',
      'attempt': attempt,
      'dialogueDirective': dialogueRepairDirective ?? '',
      'rejectedEvidenceDirective': rejectedEvidenceDirective ?? '',
      'reviewFeedback': reviewFeedback == null
          ? ''
          : '${l.editorialFeedbackLabel}${l.colon}${reviewFeedback.trim()}',
      'previousProseBlock':
          previousProse != null && previousProse.trim().isNotEmpty
          ? '上一版正文（请在此版基础上针对性修改）：\n${previousProse.trim()}'
          : '',
    };
    final messages = promptIdentity.render(resolvedVariables).messages;
    final result = await requestFormalStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      promptInvocation: promptIdentity,
      promptInvocationEvidence: promptIdentity.evidence(
        messages,
        resolvedVariables: resolvedVariables,
      ),
      initialMaxTokens: storyGenerationEditorialMaxTokens,
      messages: messages,
    );

    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene editorial generation failed.');
    }

    final text = result.text!.trim();
    if (text.isEmpty &&
        FormalEvaluationPolicy.isActive(
          taskCard.brief.metadata,
          formalExecution: taskCard.brief.formalExecution,
        )) {
      throw StateError('formal scene editorial generation returned empty text');
    }
    return SceneEditorialDraft(
      text: text,
      beatCount: resolvedBeats.length,
      attempt: attempt,
    );
  }

  String? _dialogueRepairDirective(String? reviewFeedback) {
    if (reviewFeedback == null || !reviewFeedback.contains('对话占比')) {
      return null;
    }
    final match = RegExp(r'还需增加约(\d+)个中文对白字').firstMatch(reviewFeedback);
    final needed = match == null ? '至少120' : '至少${match.group(1)}';
    return '【本轮唯一机械修复】上一版对白不足。保留已通过的事实和动作，但把连续叙述改写为角色之间有因果回应的「」对白；'
        '本轮净增加$needed个中文对白字，并把总对白占比推到35%以上。'
        '不要解释计数、不要输出提纲或自检过程，只输出修复后的正文。';
  }

  static String? buildRejectedEvidenceDirective(String? reviewFeedback) {
    if (reviewFeedback == null || reviewFeedback.trim().isEmpty) return null;
    final rejected = <String>{
      for (final match in RegExp(
        r'[“「]([^”」]{2,24})[”」]',
      ).allMatches(reviewFeedback))
        if (match.group(1)?.trim().isNotEmpty ?? false) match.group(1)!.trim(),
    };
    if (rejected.isEmpty) return null;
    return '【已证伪元素不得复用】评审已确认以下元素或状态会导致事实/物理一致性失败：'
        '${rejected.join('、')}。本轮必须删除、替换或解释其因果，不能原样保留；'
        '先修复这些证据冲突，再润色其余文本。';
  }

  String _formatBeats(List<SceneBeat> beats) {
    final l = StoryPromptTemplates.locale;
    if (beats.isEmpty) return '${l.sceneBeatsLabel}${l.colon}${l.noneLabel}';
    String kindLabel(SceneBeatKind k) => switch (k) {
      SceneBeatKind.fact => l.beatFact,
      SceneBeatKind.dialogue => l.beatDialogue,
      SceneBeatKind.action => l.beatAction,
      SceneBeatKind.internal => l.beatInternal,
      SceneBeatKind.narration => l.beatNarration,
    };
    final buf = StringBuffer('${l.sceneBeatsLabel}${l.colon}');
    for (final b in beats) {
      buf
        ..writeln()
        ..write('[${kindLabel(b.kind)}]@${b.sourceCharacterId} ${b.content}');
    }
    return buf.toString();
  }

  List<LightContextCapsule> _stageCapsules(List<LightContextCapsule> capsules) {
    return [
      for (final capsule in capsules)
        if (capsule.intent.toolName == SceneStageNarrator.capsuleToolName)
          capsule,
    ];
  }

  List<LightContextCapsule> _retrievalCapsules(
    List<LightContextCapsule> capsules,
  ) {
    return [
      for (final capsule in capsules)
        if (capsule.intent.toolName != SceneStageNarrator.capsuleToolName)
          capsule,
    ];
  }

  SceneEditorialDraft _localDraft({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
    required int attempt,
    SceneRoleplaySession? roleplaySession,
  }) {
    final roleplayDraft = roleplaySession?.roleplayDraft.trim();
    if (roleplayDraft != null && roleplayDraft.isNotEmpty) {
      return SceneEditorialDraft(
        text: roleplayDraft,
        beatCount: resolvedBeats.length,
        attempt: attempt,
      );
    }
    final parts = <String>[];
    final summary = taskCard.brief.sceneSummary.trim();
    if (summary.isNotEmpty) {
      parts.add(summary);
    }
    for (final beat in resolvedBeats) {
      final content = beat.content.trim();
      if (content.isEmpty || parts.contains(content)) {
        continue;
      }
      final characterName = _characterName(taskCard, beat.sourceCharacterId);
      parts.add(switch (beat.kind) {
        SceneBeatKind.dialogue =>
          characterName.isEmpty ? '“$content”' : '$characterName说：“$content”',
        SceneBeatKind.action =>
          characterName.isEmpty ? content : '$characterName$content',
        SceneBeatKind.internal =>
          characterName.isEmpty ? content : '$characterName心中确认：$content',
        SceneBeatKind.fact || SceneBeatKind.narration => content,
      });
    }
    final text = parts.isEmpty
        ? taskCard.brief.targetBeat.trim()
        : parts.join('。');
    return SceneEditorialDraft(
      text: text.trim(),
      beatCount: resolvedBeats.length,
      attempt: attempt,
    );
  }

  String _characterName(SceneTaskCard taskCard, String characterId) {
    for (final member in taskCard.cast) {
      if (member.characterId == characterId) {
        return member.name;
      }
    }
    return '';
  }
}
