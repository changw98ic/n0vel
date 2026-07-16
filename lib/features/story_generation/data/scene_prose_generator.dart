import '../domain/contracts/settings_contract.dart';

import 'scene_runtime_models.dart' show SceneTaskCard;
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';
import 'formal_evaluation_policy.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class SceneProseGenerator implements SceneProseService {
  SceneProseGenerator({required StoryGenerationSettingsContract settingsStore})
    : _settingsStore = settingsStore;

  final StoryGenerationSettingsContract _settingsStore;

  @override
  Future<SceneProseDraft> generate({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required int attempt,
    String? reviewFeedback,
  }) async {
    FormalEvaluationPolicy.rejectLocalFallbackRequest(
      brief.metadata,
      formalExecution: brief.formalExecution,
    );
    final isFirstScene = brief.sceneIndex == 0;
    final isLastScene =
        brief.totalScenesInChapter > 0 &&
        brief.sceneIndex == brief.totalScenesInChapter - 1;

    final promptIdentity = StoryPromptRegistry.production.invocation(
      stageId: 'prose',
      callSiteId: 'scene-prose',
    );
    final resolvedVariables = <String, Object?>{
      'chapterTitle': brief.chapterTitle,
      'sceneTitle': brief.sceneTitle,
      'targetLength': brief.targetLength,
      'attempt': attempt,
      'sceneNumber': brief.sceneIndex + 1,
      'totalScenes': brief.totalScenesInChapter,
      'openingBoundary': isFirstScene ? '⚠️ 这是本章首个场景，前50字必须包含悬念信号。' : '',
      'closingBoundary': isLastScene ? '⚠️ 这是本章最后场景，结尾必须留下未决冲突或悬念钩子。' : '',
      'taskCard': director.taskCard == null
          ? ''
          : _taskCardSummary(director.taskCard!),
      'director': _compact(director.text, maxChars: 300),
      'roleOutputs': roleOutputs.isEmpty ? '' : _roleOutputSummary(roleOutputs),
      'reviewFeedback':
          reviewFeedback != null && reviewFeedback.trim().isNotEmpty
          ? reviewFeedback.trim()
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
      throw StateError(result.detail ?? 'Scene prose generation failed.');
    }
    final text = result.text!.trim();
    if (text.isEmpty &&
        FormalEvaluationPolicy.isActive(
          brief.metadata,
          formalExecution: brief.formalExecution,
        )) {
      throw StateError('formal scene prose generation returned empty text');
    }
    return SceneProseDraft(text: text, attempt: attempt);
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
