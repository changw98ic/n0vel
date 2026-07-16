import 'dart:convert';

import '../domain/contracts/settings_contract.dart';

import '../domain/memory_models.dart';
import 'scene_review_models.dart';
import 'story_prompt_registry.dart';
import 'evaluation/agent_evaluation_trace_context.dart';

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

    try {
      final promptIdentity = StoryPromptRegistry.production.invocation(
        stageId: 'chapter-summary',
        callSiteId: 'chapter-summarizer',
      );
      final resolvedVariables = <String, Object?>{
        'chapterTitle': chapterTitle,
        'previousSummaryBlock': _previousSummaryBlock(previousSummary),
        'sceneTexts': sceneTexts,
      };
      final messages = promptIdentity.render(resolvedVariables).messages;
      // llm-call-site: boundary.story.chapter-summary
      final result = await settingsStore.requestAiCompletion(
        messages: messages,
        maxTokens: 2048,
        traceName: 'chapter-summarizer',
        traceMetadata:
            AgentEvaluationTraceContext.current?.toTraceMetadata() ??
            const <String, Object?>{},
        promptReleaseRef: promptIdentity.promptReleaseRef,
        promptInvocationEvidence: promptIdentity.evidence(
          messages,
          resolvedVariables: resolvedVariables,
        ),
        stageId: promptIdentity.callSite.stageId,
        callSiteId: promptIdentity.callSite.callSiteId,
        variantId: promptIdentity.callSite.variantId,
        generationBundleHash: promptIdentity.generationBundleHash,
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

  String _previousSummaryBlock(ChapterSummary? previousSummary) {
    if (previousSummary == null) return '';
    final buffer = StringBuffer();
    buffer.writeln('剧情: ${previousSummary.plotProgress}');
    if (previousSummary.unresolvedThreads.isNotEmpty) {
      buffer.writeln('未解悬念: ${previousSummary.unresolvedThreads.join("; ")}');
    }
    if (previousSummary.foreshadowingStatus.isNotEmpty) {
      buffer.writeln('伏笔状态: ${previousSummary.foreshadowingStatus}');
    }
    return buffer.toString().trimRight();
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
        final match = RegExp(
          r'```(?:json)?\s*([\s\S]*?)```',
        ).firstMatch(jsonStr);
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
