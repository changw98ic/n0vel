import 'dart:async';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'scene_pipeline_models.dart';
import 'story_generation_pass_retry.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class SceneDirectorOrchestrator implements SceneDirectorService {
  static const Duration _requestTimeout = Duration(seconds: 60);

  SceneDirectorOrchestrator({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    final localPlanText = _buildLocalPlan(brief: brief, cast: cast);
    final localPlan = _buildStructuredPlan(
      text: localPlanText,
      brief: brief,
      cast: cast,
    );

    if (brief.metadata['localDirectorOnly'] == true) {
      return SceneDirectorOutput(text: localPlanText, plan: localPlan);
    }

    try {
      final result = await requestStoryGenerationPassWithRetry(
        settingsStore: _settingsStore,
        messages: [
          const AppLlmChatMessage(role: 'system', content: _systemPrompt),
          AppLlmChatMessage(
            role: 'user',
            content: _buildUserPrompt(
              brief: brief,
              cast: cast,
              localPlanText: localPlanText,
              ragContext: ragContext,
            ),
          ),
        ],
      ).timeout(_requestTimeout);

      if (!result.succeeded || result.text == null) {
        return SceneDirectorOutput(text: localPlanText, plan: localPlan);
      }
      final parsed = SceneDirectorPlan.tryParse(result.text!.trim());
      if (parsed == null) {
        return SceneDirectorOutput(text: localPlanText, plan: localPlan);
      }
      final polishedText = parsed.toText();
      return SceneDirectorOutput(
        text: polishedText,
        plan: _buildStructuredPlan(
          text: polishedText,
          brief: brief,
          cast: cast,
        ),
      );
    } on TimeoutException {
      return SceneDirectorOutput(text: localPlanText, plan: localPlan);
    } catch (_) {
      return SceneDirectorOutput(text: localPlanText, plan: localPlan);
    }
  }

  String _buildUserPrompt({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required String localPlanText,
    String? ragContext,
  }) {
    final castSummary = cast.isEmpty
        ? '出场角色：无'
        : '出场角色：${cast.map((m) => '${m.name}(${m.role})').join('、')}';
    final revisionPrompt = _revisionRequestPrompt(brief);
    return [
      '任务：scene_director_polish',
      '格式：目标/冲突/推进/约束',
      '章：${_compact('${brief.chapterTitle} ${brief.chapterId}', maxChars: 40)}',
      '场：${_compact('${brief.sceneTitle} ${brief.sceneId}', maxChars: 40)}',
      '目标节拍：${_compact(brief.targetBeat, maxChars: 80)}',
      '场景概要：${_compact(brief.sceneSummary, maxChars: 80)}',
      castSummary,
      if (revisionPrompt.isNotEmpty) '作者修订请求：\n$revisionPrompt',
      if (ragContext != null && ragContext.isNotEmpty) ragContext,
      '本地计划：',
      localPlanText,
    ].join('\n');
  }

  static const _systemPrompt =
      'You are a scene plan polisher for a Chinese novel.\n'
      'Polish the existing plan only; do not invent a new scene.\n'
      'Return exactly 4 non-empty Chinese lines and nothing else:\n'
      '目标：...\n'
      '冲突：...\n'
      '推进：...\n'
      '约束：...';

  String _buildLocalPlan({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final target = _compact(
      brief.targetBeat.trim().isNotEmpty
          ? brief.targetBeat
          : brief.sceneSummary,
      maxChars: 48,
    );
    final conflict = cast.isEmpty
        ? '冲突：围绕场景目标推进'
        : '冲突：${cast.map((member) => member.name).join('与')}在目标上相互施压';
    final progression = brief.targetBeat.trim().isNotEmpty
        ? '推进：${_compact(brief.targetBeat, maxChars: 48)}'
        : '推进：${_compact(brief.sceneSummary, maxChars: 48)}';
    final baseConstraints = brief.worldNodeIds.isEmpty
        ? '遵守当前世界观和角色设定'
        : '遵守${brief.worldNodeIds.join('/')}相关规则';
    final roleConstraints = cast.isEmpty
        ? ''
        : '；出场：${cast.map((member) => '${member.name}(${member.role})').join('、')}';
    final revisionConstraints = _revisionRequestConstraint(brief);
    final constraintText = [
      roleConstraints.isEmpty
          ? _compact(baseConstraints, maxChars: 48)
          : '$baseConstraints$roleConstraints',
      if (revisionConstraints.isNotEmpty) revisionConstraints,
    ].join('；');
    final constraints = '约束：$constraintText';
    return ['目标：$target', conflict, progression, constraints].join('\n');
  }

  String _revisionRequestPrompt(SceneBrief brief) {
    final notes = _revisionRequestNotes(brief);
    if (notes.isEmpty) {
      return '';
    }
    return [
      for (var i = 0; i < notes.length; i++)
        '${i + 1}. ${_compact(notes[i], maxChars: 120)}',
    ].join('\n');
  }

  String _revisionRequestConstraint(SceneBrief brief) {
    final notes = _revisionRequestNotes(brief);
    if (notes.isEmpty) {
      return '';
    }
    return '落实作者修订：${_compact(notes.join('；'), maxChars: 80)}';
  }

  List<String> _revisionRequestNotes(SceneBrief brief) {
    final raw = brief.metadata['authorRevisionRequests'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  SceneDirectorPlan? _buildStructuredPlan({
    required String text,
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final parsed =
        SceneDirectorPlan.tryParse(text) ??
        SceneDirectorPlan.tryParse(_buildLocalPlan(brief: brief, cast: cast));
    if (parsed == null) {
      return null;
    }
    return SceneDirectorPlan(
      target: parsed.target,
      conflict: parsed.conflict,
      progression: parsed.progression,
      constraints: parsed.constraints,
      tone: _inferTone(brief),
      pacing: _inferPacing(brief),
      characterNotes: _buildCharacterNotes(brief: brief, cast: cast),
    );
  }

  List<DirectorCharacterNote> _buildCharacterNotes({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
  }) {
    final target = _compact(
      brief.targetBeat.trim().isNotEmpty
          ? brief.targetBeat
          : brief.sceneSummary,
      maxChars: 48,
    );
    return [
      for (final member in cast)
        DirectorCharacterNote(
          characterId: member.characterId,
          name: member.name,
          motivation: '$target (${member.role})',
          emotionalArc: '${_inferTone(brief)}中随压力推进',
          keyAction: member.contributions.isEmpty
              ? '围绕场景目标行动'
              : '承担${member.contributions.map((c) => c.name).join('/')}功能',
        ),
    ];
  }

  String _inferTone(SceneBrief brief) {
    final text =
        '${brief.sceneTitle} ${brief.sceneSummary} ${brief.targetBeat}';
    if (text.contains('宁静') ||
        text.contains('闲聊') ||
        text.contains('回忆') ||
        text.contains('平静')) {
      return '平和';
    }
    if (text.contains('逼问') ||
        text.contains('拦住') ||
        text.contains('对峙') ||
        text.contains('冲突') ||
        text.contains('施压')) {
      return '紧张';
    }
    return '克制';
  }

  ScenePacing _inferPacing(SceneBrief brief) {
    if (brief.targetLength <= 250) {
      return ScenePacing.fast;
    }
    if (brief.targetLength >= 1000) {
      return ScenePacing.slow;
    }
    return ScenePacing.medium;
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
