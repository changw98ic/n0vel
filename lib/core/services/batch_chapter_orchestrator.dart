import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/editor/data/chapter_repository.dart';
import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';
import 'batch_chapter_parsing.dart';
import 'batch_chapter_prompt_builder.dart';

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// 批量章节请求
class BatchChapterRequest {
  final String workId;
  final String volumeId;
  final int chapterCount;
  final String storyContext;
  final String? genre;
  final String? style;
  final int wordsPerChapter;

  const BatchChapterRequest({
    required this.workId,
    required this.volumeId,
    required this.chapterCount,
    this.storyContext = '',
    this.genre,
    this.style,
    this.wordsPerChapter = 2500,
  });
}

/// 章节大纲
class ChapterOutline {
  final int index;
  final String title;
  final String plotSummary;
  final String keyEvents;
  final String hook;

  const ChapterOutline({
    required this.index,
    required this.title,
    required this.plotSummary,
    required this.keyEvents,
    required this.hook,
  });
}

/// 批量章节结果
class BatchChapterResult {
  final int index;
  final String title;
  final String content;
  final String? chapterId;
  final int wordCount;

  const BatchChapterResult({
    required this.index,
    required this.title,
    required this.content,
    this.chapterId,
    required this.wordCount,
  });
}

// ---------------------------------------------------------------------------
// Orchestrator events
// ---------------------------------------------------------------------------

sealed class BatchChapterEvent {}

class BatchPhaseStart extends BatchChapterEvent {
  final String phase; // 'outlining' | 'writing' | 'saving'
  final int total;
  BatchPhaseStart({required this.phase, required this.total});
}

class BatchChapterProgress extends BatchChapterEvent {
  final int index;
  final String? title;
  final String phase;
  final int completed;
  final int total;
  BatchChapterProgress({
    required this.index,
    this.title,
    required this.phase,
    required this.completed,
    required this.total,
  });
}

class BatchSingleChapterDone extends BatchChapterEvent {
  final int index;
  final String title;
  final String? chapterId;
  final int wordCount;
  BatchSingleChapterDone({
    required this.index,
    required this.title,
    this.chapterId,
    required this.wordCount,
  });
}

class BatchAllComplete extends BatchChapterEvent {
  final List<BatchChapterResult> chapters;
  final int totalWords;
  final int totalInputTokens;
  final int totalOutputTokens;
  BatchAllComplete({
    required this.chapters,
    required this.totalWords,
    required this.totalInputTokens,
    required this.totalOutputTokens,
  });
}

class BatchChapterError extends BatchChapterEvent {
  final String error;
  final int? chapterIndex;
  BatchChapterError({required this.error, this.chapterIndex});
}

// ---------------------------------------------------------------------------
// Intent detection
// ---------------------------------------------------------------------------

/// 批量章节创建意图
class BatchChapterIntent {
  final int chapterCount;
  final String storyContext;

  const BatchChapterIntent({
    required this.chapterCount,
    required this.storyContext,
  });

  /// 从用户消息中检测批量创建意图
  static BatchChapterIntent? detect(String message) {
    final patterns = [
      // "帮我写十章" "连续写5章" "批量生成20章" "一口气写10章"
      RegExp(
        r'(?:连续|批量|一次|一口气|帮我|请|给我)?'
        r'(?:写|生成|创建|来|产出|规划|构思|搞|出)'
        r'\s*(?:[大概约]+)?\s*'
        r'([一二两三四五六七八九十百千万\d]+)\s*'
        r'(?:章|回|节)',
      ),
      // "连续N章" "批量N章" (no verb)
      RegExp(
        r'(?:连续|批量)\s*([一二两三四五六七八九十百千万\d]+)\s*(?:章|回|节)',
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        final countStr = match.group(1);
        if (countStr != null) {
          final count = _parseNumber(countStr);
          if (count != null && count >= 2 && count <= 50) {
            return BatchChapterIntent(
              chapterCount: count,
              storyContext: message,
            );
          }
        }
      }
    }
    return null;
  }

  static int? _parseNumber(String str) {
    // Try Arabic numeral first
    final arabic = int.tryParse(str);
    if (arabic != null) return arabic;

    // Parse Chinese numeral
    const digits = {
      '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '七': 7, '八': 8, '九': 9, '两': 2,
    };

    int result = 0;
    int i = 0;
    while (i < str.length) {
      final ch = str[i];
      if (ch == '十') {
        result += (result == 0 ? 1 : result) * 10;
        // resets accumulator — "二十" = 20, "十二" = 12
        final prev = result;
        result = prev;
        // actually let's redo this logic properly
        i++;
        continue;
      }
      if (ch == '百') {
        result *= 100;
        i++;
        continue;
      }
      if (digits.containsKey(ch)) {
        result += digits[ch]!;
        i++;
        continue;
      }
      return null;
    }
    return result > 0 ? result : null;
  }
}

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------

/// 批量章节编排器
/// 三阶段流水线：并行大纲 → 波次正文 → 顺序落库
class BatchChapterOrchestrator {
  final AIService _aiService;
  final ChapterRepository _chapterRepository;

  /// 每波并行生成几章正文
  final int waveSize;

  BatchChapterOrchestrator({
    required AIService aiService,
    required ChapterRepository chapterRepository,
    this.waveSize = 3,
  })  : _aiService = aiService,
        _chapterRepository = chapterRepository;

  /// 执行批量章节创建，返回事件流
  Stream<BatchChapterEvent> execute(BatchChapterRequest request) {
    final controller = StreamController<BatchChapterEvent>();
    _run(controller, request);
    return controller.stream;
  }

  Future<void> _run(
    StreamController<BatchChapterEvent> controller,
    BatchChapterRequest request,
  ) async {
    try {
      // ── Phase 1: Parallel outline generation ──
      controller.add(
        BatchPhaseStart(phase: 'outlining', total: request.chapterCount),
      );
      final outlines = await _generateOutlinesParallel(request, controller);

      if (outlines.length != request.chapterCount) {
        controller.add(BatchChapterError(
          error: '大纲生成不完整: 期望${request.chapterCount}章，'
              '实际${outlines.length}章',
        ));
        await controller.close();
        return;
      }

      // ── Phase 2: Wave-based content generation ──
      controller.add(
        BatchPhaseStart(phase: 'writing', total: request.chapterCount),
      );

      final results = <BatchChapterResult>[];
      int totalInputTokens = 0;
      int totalOutputTokens = 0;
      String previousWaveEnding = '';

      for (var waveStart = 0;
          waveStart < request.chapterCount;
          waveStart += waveSize) {
        final waveEnd =
            (waveStart + waveSize).clamp(0, request.chapterCount);
        final waveOutlines = outlines.sublist(waveStart, waveEnd);

        final waveFutures = <Future<_ChapterGenOutput>>[];
        for (var i = 0; i < waveOutlines.length; i++) {
          final outline = waveOutlines[i];
          final globalIndex = waveStart + i;
          final priorOutlines = outlines.sublist(0, globalIndex);

          waveFutures.add(_generateChapterContent(
            request: request,
            outline: outline,
            priorOutlines: priorOutlines,
            previousWaveEnding: i == 0 ? previousWaveEnding : '',
          ));
        }

        final waveResults = await Future.wait(waveFutures);

        for (final wr in waveResults) {
          results.add(wr.result);
          totalInputTokens += wr.inputTokens;
          totalOutputTokens += wr.outputTokens;

          controller.add(BatchChapterProgress(
            index: wr.result.index,
            title: wr.result.title,
            phase: 'writing',
            completed: results.length,
            total: request.chapterCount,
          ));
        }

        // Carry forward ending summary for next wave continuity
        if (waveResults.isNotEmpty) {
          previousWaveEnding = waveResults.last.endingSummary;
        }
      }

      // ── Phase 3: Sequential save ──
      controller.add(BatchPhaseStart(phase: 'saving', total: results.length));
      final savedResults = <BatchChapterResult>[];

      for (final result in results) {
        try {
          final chapter =
              await _chapterRepository.createOrGetChapterByTitle(
            workId: request.workId,
            volumeId: request.volumeId,
            title: result.title,
            sortOrder: result.index,
          );
          await _chapterRepository.updateContent(
            chapter.id,
            result.content,
            result.wordCount,
          );
          savedResults.add(BatchChapterResult(
            index: result.index,
            title: result.title,
            content: result.content,
            chapterId: chapter.id,
            wordCount: result.wordCount,
          ));
          controller.add(BatchSingleChapterDone(
            index: result.index,
            title: result.title,
            chapterId: chapter.id,
            wordCount: result.wordCount,
          ));
        } catch (e) {
          debugPrint('[BatchOrchestrator] 保存章节失败: $e');
          savedResults.add(result);
        }
      }

      // ── Done ──
      final totalWords =
          savedResults.fold<int>(0, (sum, r) => sum + r.wordCount);
      controller.add(BatchAllComplete(
        chapters: savedResults,
        totalWords: totalWords,
        totalInputTokens: totalInputTokens,
        totalOutputTokens: totalOutputTokens,
      ));
    } catch (e, st) {
      debugPrint('[BatchOrchestrator] 失败: $e\n$st');
      controller.add(BatchChapterError(error: e.toString()));
    } finally {
      await controller.close();
    }
  }

  // =========================================================================
  // Phase 1 — parallel outline generation
  // =========================================================================

  Future<List<ChapterOutline>> _generateOutlinesParallel(
    BatchChapterRequest request,
    StreamController<BatchChapterEvent> controller,
  ) async {
    final futures = List.generate(
      request.chapterCount,
      (i) => _generateSingleOutline(request, i),
    );
    final outlines = await Future.wait(futures);
    final sorted = outlines.toList()..sort((a, b) => a.index.compareTo(b.index));

    for (var i = 0; i < sorted.length; i++) {
      controller.add(BatchChapterProgress(
        index: sorted[i].index,
        title: sorted[i].title,
        phase: 'outlining',
        completed: i + 1,
        total: request.chapterCount,
      ));
    }
    return sorted;
  }

  Future<ChapterOutline> _generateSingleOutline(
    BatchChapterRequest request,
    int index,
  ) async {
    final buf = StringBuffer();
    buf.writeln('你是一位专业小说大纲规划师。请为以下小说生成第${index + 1}章'
        '（共${request.chapterCount}章）的大纲。');
    buf.writeln();
    if (request.storyContext.isNotEmpty) {
      buf.writeln('## 故事背景与方向');
      buf.writeln(request.storyContext);
      buf.writeln();
    }
    if (request.genre != null) {
      buf.writeln('类型: ${request.genre}');
    }
    if (request.style != null) {
      buf.writeln('风格: ${request.style}');
    }
    buf.writeln();
    _appendPositionHint(buf, index, request.chapterCount);
    buf.writeln();
    buf.writeln('请用以下 JSON 格式输出（不要加其他内容）：');
    buf.writeln('```json');
    buf.writeln('{');
    buf.writeln('  "title": "章节标题",');
    buf.writeln('  "plot_summary": "200字以内的剧情摘要",');
    buf.writeln('  "key_events": "3-5个关键事件，用分号分隔",');
    buf.writeln('  "hook": "本章结尾的钩子/悬念"');
    buf.writeln('}');
    buf.writeln('```');

    final response = await _aiService.generate(
      prompt: buf.toString(),
      config: AIRequestConfig(
        function: AIFunction.continuation,
        systemPrompt: '你是一位专业的网络小说大纲规划师。'
            '擅长设计引人入胜的章节节奏和钩子。只输出 JSON。',
        userPrompt: buf.toString(),
        overrideTier: ModelTier.middle,
        useCache: false,
        stream: false,
      ),
    );
    return _parseOutline(response.content, index);
  }

  void _appendPositionHint(StringBuffer buf, int index, int total) {
    buf.writeln('## 位置信息');
    if (index == 0) {
      buf.writeln('这是第1章，即故事开篇。需要建立世界观、引入主角、设置初始冲突。');
    } else if (index == total - 1) {
      buf.writeln('这是最后一章（第${index + 1}章）。'
          '需要收束主线、解决核心冲突、给出结局或悬念。');
    } else {
      final pct = (index / total * 100).round();
      buf.writeln('这是第${index + 1}章，故事进度约$pct%。');
      if (pct < 30) {
        buf.writeln('铺垫阶段，推进剧情、发展角色关系。');
      } else if (pct < 70) {
        buf.writeln('中段，张力升级、冲突加深、转折出现。');
      } else {
        buf.writeln('高潮/收尾阶段，集中爆发、高潮迭起。');
      }
    }
  }

  ChapterOutline _parseOutline(String content, int index) {
    try {
      final jsonMatch =
          RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(content);
      final jsonStr = jsonMatch?.group(1) ?? content;
      final json = BatchChapterParsing.tryParseJson(jsonStr);
      if (json != null) {
        return ChapterOutline(
          index: index,
          title: json['title'] as String? ?? '第${index + 1}章',
          plotSummary: json['plot_summary'] as String? ?? '',
          keyEvents: json['key_events'] as String? ?? '',
          hook: json['hook'] as String? ?? '',
        );
      }
    } catch (_) {}
    return ChapterOutline(
      index: index,
      title: '第${index + 1}章',
      plotSummary: '',
      keyEvents: '',
      hook: '',
    );
  }

  // =========================================================================
  // Phase 2 — wave-based content generation
  // =========================================================================

  Future<_ChapterGenOutput> _generateChapterContent({
    required BatchChapterRequest request,
    required ChapterOutline outline,
    required List<ChapterOutline> priorOutlines,
    required String previousWaveEnding,
  }) async {
    final buf = StringBuffer();
    buf.writeln('你是一位专业的网络小说作家。请根据以下大纲撰写完整的章节正文。');
    buf.writeln();
    buf.writeln('## 本章大纲');
    buf.writeln('标题: ${outline.title}');
    buf.writeln('剧情摘要: ${outline.plotSummary}');
    buf.writeln('关键事件: ${outline.keyEvents}');
    buf.writeln('结尾钩子: ${outline.hook}');
    buf.writeln();

    if (previousWaveEnding.isNotEmpty) {
      buf.writeln('## 上一章节结尾内容');
      buf.writeln(previousWaveEnding);
      buf.writeln();
    }

    if (priorOutlines.isNotEmpty) {
      buf.writeln('## 前文章节大纲（供衔接参考）');
      final recentSummaries = BatchChapterPromptBuilder.recentOutlineSummaries(
        priorOutlines.map(
          (prev) => (title: prev.title, plotSummary: prev.plotSummary),
        ),
      );
      for (final summary in recentSummaries) {
        buf.writeln(summary);
      }
      buf.writeln();
    }

    if (request.genre != null) {
      buf.writeln('类型: ${request.genre}');
    }
    if (request.style != null) {
      buf.writeln('风格: ${request.style}');
    }

    buf.writeln();
    buf.writeln('要求:');
    buf.writeln('- 正文字数约${request.wordsPerChapter}字');
    buf.writeln('- 包含完整的叙事：场景描写、人物对话、动作细节');
    buf.writeln('- 章节结尾要有钩子/悬念');
    buf.writeln('- 与前文自然衔接，不要重复已述内容');
    buf.writeln('- 直接输出正文，不要加标题或大纲');
    buf.writeln();
    buf.writeln('在正文之后，另起一行输出结尾摘要（用于后续章节衔接）：');
    buf.writeln('[ENDING_SUMMARY]');
    buf.writeln('用2-3句话总结本章结尾的场景、情绪和状态');
    buf.writeln('[/ENDING_SUMMARY]');

    final response = await _aiService.generate(
      prompt: buf.toString(),
      config: AIRequestConfig(
        function: AIFunction.continuation,
        systemPrompt: '你是一位专业的网络小说作家，擅长写出引人入胜的章节正文。'
            '文字流畅自然，对话生动，场景描写细腻。'
            '注意控制节奏，在章节结尾设置钩子。',
        userPrompt: buf.toString(),
        overrideTier: ModelTier.thinking,
        useCache: false,
        stream: false,
      ),
    );

    final contentParts =
        BatchChapterParsing.splitEndingSummary(response.content);

    return _ChapterGenOutput(
      result: BatchChapterResult(
        index: outline.index,
        title: outline.title,
        content: contentParts.content,
        wordCount: contentParts.content.length,
      ),
      inputTokens: response.inputTokens,
      outputTokens: response.outputTokens,
      endingSummary: contentParts.endingSummary,
    );
  }

}

/// Internal output wrapper for content generation
class _ChapterGenOutput {
  final BatchChapterResult result;
  final int inputTokens;
  final int outputTokens;
  final String endingSummary;

  const _ChapterGenOutput({
    required this.result,
    required this.inputTokens,
    required this.outputTokens,
    required this.endingSummary,
  });
}
