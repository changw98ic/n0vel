import 'dart:convert';

import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import '../domain/contracts/settings_contract.dart';

import '../domain/memory_models.dart';
import 'scene_review_models.dart';

/// Uses an LLM to produce structured chapter summaries for cross-chapter
/// coherence. Falls back to the existing structural approach on failure.
class ChapterSummarizer {
  ChapterSummarizer({required this.settingsStore});

  final StoryGenerationSettingsContract settingsStore;

  /// Generates a structured [ChapterSummary] from the scene outputs of a
  /// completed chapter.
  ///
  /// If [previousSummary] is provided, the LLM receives it as context for
  /// incremental summarization. On any LLM failure, returns null so the
  /// caller can fall back to the structural approach.
  Future<ChapterSummary?> summarizeChapter({
    required String chapterId,
    required String chapterTitle,
    required List<SceneRuntimeOutput> outputs,
    ChapterSummary? previousSummary,
    int? nowMs,
  }) async {
    if (outputs.isEmpty) return null;

    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final sceneTexts = _collectSceneTexts(outputs);

    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(
      chapterTitle: chapterTitle,
      sceneTexts: sceneTexts,
      previousSummary: previousSummary,
    );

    try {
      final result = await settingsStore.requestAiCompletion(
        messages: [
          AppLlmChatMessage(role: 'system', content: systemPrompt),
          AppLlmChatMessage(role: 'user', content: userPrompt),
        ],
        maxTokens: 2048,
        traceName: 'chapter-summarizer',
      );

      if (result.text == null || result.text!.trim().isEmpty) return null;

      return _parseSummaryResponse(
        result.text!,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        sceneCount: outputs.length,
        createdAtMs: ts,
      );
    } on Object {
      return null;
    }
  }

  String _buildSystemPrompt() {
    return '你是一个小说章节摘要生成器。根据给定的场景输出，生成结构化的 JSON 摘要。\n'
        '必须严格按以下 JSON 格式输出，不要添加任何其他文字：\n'
        '{\n'
        '  "plotProgression": "本章剧情进展的核心描述",\n'
        '  "characterStateChanges": ["角色A: 情感/状态变化", "角色B: ..."],\n'
        '  "unresolvedThreads": ["未解决的悬念1", "未解决的悬念2"],\n'
        '  "worldStateChanges": "世界观/设定的变化",\n'
        '  "foreshadowingStatus": "已埋伏笔的状态（已回收/仍待解）",\n'
        '  "emotionalArcs": "主要角色的情感弧线变化",\n'
        '  "keyRevelations": "本章揭示的关键信息"\n'
        '}\n'
        '要求：\n'
        '- plotProgression 必须简洁但完整，涵盖本章核心事件\n'
        '- characterStateChanges 每条以"角色名: 变化描述"格式\n'
        '- 如果上一章摘要提供了增量上下文，要确保连续性\n'
        '- 各字段不要为空，即使内容为"无变化"也要明确说明';
  }

  String _buildUserPrompt({
    required String chapterTitle,
    required String sceneTexts,
    required ChapterSummary? previousSummary,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('章节标题: $chapterTitle');
    buffer.writeln();

    if (previousSummary != null) {
      buffer.writeln('【上一章摘要】');
      buffer.writeln('剧情: ${previousSummary.plotProgress}');
      if (previousSummary.unresolvedThreads.isNotEmpty) {
        buffer.writeln('未解悬念: ${previousSummary.unresolvedThreads.join("; ")}');
      }
      if (previousSummary.foreshadowingStatus.isNotEmpty) {
        buffer.writeln('伏笔状态: ${previousSummary.foreshadowingStatus}');
      }
      buffer.writeln();
    }

    buffer.writeln('【本章场景输出】');
    buffer.writeln(sceneTexts);
    buffer.writeln();
    buffer.writeln('请生成上述章节的结构化摘要 JSON：');

    return buffer.toString();
  }

  String _collectSceneTexts(List<SceneRuntimeOutput> outputs) {
    final parts = <String>[];
    for (var i = 0; i < outputs.length; i++) {
      final output = outputs[i];
      final sceneTitle = output.brief.sceneTitle;
      final directorText = output.director.text;
      final prose = output.prose.text;

      final sceneBuf = StringBuffer('--- 场景 ${i + 1}: $sceneTitle ---');
      if (directorText.isNotEmpty) {
        sceneBuf.writeln();
        sceneBuf.write('导演策划: ${_truncate(directorText, 300)}');
      }
      if (prose.isNotEmpty) {
        sceneBuf.writeln();
        sceneBuf.write('正文片段: ${_truncate(prose, 500)}');
      }
      parts.add(sceneBuf.toString());
    }
    return parts.join('\n\n');
  }

  ChapterSummary? _parseSummaryResponse(
    String response, {
    required String chapterId,
    required String chapterTitle,
    required int sceneCount,
    required int createdAtMs,
  }) {
    try {
      // Extract JSON from response — handle markdown code blocks
      var jsonStr = response.trim();
      if (jsonStr.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (match != null) jsonStr = match.group(1)?.trim() ?? jsonStr;
      }

      final json = jsonDecode(jsonStr) as Map<String, Object?>;

      return ChapterSummary(
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        sceneCount: sceneCount,
        plotProgress: _asString(json['plotProgression']) ?? '',
        characterStateChanges: _asStringList(json['characterStateChanges']),
        unresolvedThreads: _asStringList(json['unresolvedThreads']),
        createdAtMs: createdAtMs,
        worldStateChanges: _asString(json['worldStateChanges']) ?? '',
        foreshadowingStatus: _asString(json['foreshadowingStatus']) ?? '',
        emotionalArcs: _asString(json['emotionalArcs']) ?? '',
        keyRevelations: _asString(json['keyRevelations']) ?? '',
        summarySource: SummarySource.llm,
      );
    } on Object {
      return null;
    }
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 3)}...';
  }

  String? _asString(Object? raw) {
    if (raw is String) return raw;
    return null;
  }

  List<String> _asStringList(Object? raw) {
    if (raw is List) {
      return [for (final item in raw) item?.toString() ?? ''];
    }
    return const [];
  }
}
