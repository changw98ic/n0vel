import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'story_generation_pass_retry.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class SceneQualityScorer implements SceneQualityScorerService {
  SceneQualityScorer({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async {
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content:
              'You are a quality scorer for Chinese novel scenes. '
              'Use this 6-line scorecard:\n'
              '文笔：<0-100>\n'
              '连贯：<0-100>\n'
              '角色：<0-100>\n'
              '完整：<0-100>\n'
              '综合：<0-100>\n'
              '总结：一句话评价',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：scene_quality_scoring',
            '场：${_compact(brief.sceneTitle, maxChars: 40)}',
            '摘要：${_compact(brief.sceneSummary, maxChars: 80)}',
            '导演：${_compact(director.text, maxChars: 120)}',
            '正文：${prose.text}',
            '评审：${_compact(review.editorialFeedback, maxChars: 120)}',
          ].join('\n'),
        ),
      ],
      traceName: 'scene_quality_scoring',
      traceMetadata: {
        'chapterId': brief.chapterId,
        'sceneId': brief.sceneId,
        'sceneTitle': brief.sceneTitle,
      },
    );
    if (!result.succeeded) {
      throw StateError(result.detail ?? 'Scene quality scoring failed.');
    }

    return parseScore(result.text!.trim());
  }

  /// Parses a quality score from raw LLM output text.
  static SceneQualityScore parseScore(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    double prose = 0;
    double coherence = 0;
    double character = 0;
    double completeness = 0;
    double overall = 0;
    String summary = '';

    for (final line in lines) {
      if (line.startsWith('文笔：')) {
        prose = _extractScore(line);
      } else if (line.startsWith('连贯：')) {
        coherence = _extractScore(line);
      } else if (line.startsWith('角色：')) {
        character = _extractScore(line);
      } else if (line.startsWith('完整：')) {
        completeness = _extractScore(line);
      } else if (line.startsWith('综合：')) {
        overall = _extractScore(line);
      } else if (line.startsWith('总结：')) {
        summary = line.substring(3).trim();
      }
    }

    if (overall == 0) {
      overall = (prose + coherence + character + completeness) / 4;
    }

    return SceneQualityScore(
      overall: overall.clamp(0, 100),
      prose: prose.clamp(0, 100),
      coherence: coherence.clamp(0, 100),
      character: character.clamp(0, 100),
      completeness: completeness.clamp(0, 100),
      summary: summary,
    );
  }

  static double _extractScore(String line) {
    final colonIndex = line.indexOf('：');
    if (colonIndex < 0) return 0;
    final raw = line.substring(colonIndex + 1).trim();
    return double.tryParse(raw)?.clamp(0.0, 100.0) ?? 0.0;
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
