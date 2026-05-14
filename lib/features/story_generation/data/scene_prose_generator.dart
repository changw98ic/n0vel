import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'scene_runtime_models.dart' show SceneTaskCard;
import 'story_generation_pass_retry.dart';
import 'story_prompt_templates.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class SceneProseGenerator implements SceneProseService {
  SceneProseGenerator({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  @override
  Future<SceneProseDraft> generate({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required int attempt,
    String? reviewFeedback,
  }) async {
    final l = StoryPromptTemplates.locale;
    final isFirstScene = brief.sceneIndex == 0;
    final isLastScene = brief.totalScenesInChapter > 0 &&
        brief.sceneIndex == brief.totalScenesInChapter - 1;

    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      initialMaxTokens: storyGenerationEditorialMaxTokens,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content: l.sysSceneProse,
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：scene_prose_generation',
            '章节：${brief.chapterTitle}',
            '场景：${brief.sceneTitle}',
            '目标字数：约${brief.targetLength}汉字',
            '当前尝试：$attempt',
            '本章场景位置：第${brief.sceneIndex + 1}个场景（共${brief.totalScenesInChapter}个）',
            if (isFirstScene) '⚠️ 这是本章首个场景，前50字必须包含悬念信号。',
            if (isLastScene) '⚠️ 这是本章最后场景，结尾必须留下未决冲突或悬念钩子。',
            if (director.taskCard != null)
              '任务卡：${_taskCardSummary(director.taskCard!)}',
            '导演计划：${_compact(director.text, maxChars: 300)}',
            if (roleOutputs.isNotEmpty)
              '角色输出：\n${_roleOutputSummary(roleOutputs)}',
            if (reviewFeedback != null && reviewFeedback.trim().isNotEmpty)
              '复写反馈：${reviewFeedback.trim()}',
          ].join('\n\n'),
        ),
      ],
    );
    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene prose generation failed.');
    }
    return SceneProseDraft(text: result.text!.trim(), attempt: attempt);
  }

  String _taskCardSummary(SceneTaskCard taskCard) {
    return taskCard.toPromptText();
  }

  String _roleOutputSummary(List<DynamicRoleAgentOutput> roleOutputs) {
    if (roleOutputs.isEmpty) {
      return '无';
    }
    return roleOutputs
        .map((output) => '[${output.name}]：${output.text}')
        .join('\n');
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
