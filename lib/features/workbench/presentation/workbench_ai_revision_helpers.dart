import 'package:flutter/services.dart';

import 'workbench_text_helpers.dart';

class WorkbenchAiSelectionDraft {
  const WorkbenchAiSelectionDraft({
    required this.start,
    required this.end,
    required this.prompt,
  });

  final int start;
  final int end;
  final String prompt;

  int get length => end - start;

  WorkbenchAiSelectionDraft copyWith({String? prompt}) {
    return WorkbenchAiSelectionDraft(
      start: start,
      end: end,
      prompt: prompt ?? this.prompt,
    );
  }
}

class WorkbenchAiReviewBlock {
  const WorkbenchAiReviewBlock({
    required this.blockLabel,
    required this.previousText,
    required this.originalText,
    required this.nextText,
    required this.authorPrompt,
    required this.suggestionText,
    this.selection,
  });

  final String blockLabel;
  final String previousText;
  final String originalText;
  final String nextText;
  final String authorPrompt;
  final String suggestionText;
  final WorkbenchAiSelectionDraft? selection;
}

class WorkbenchAiRevisionHelpers {
  const WorkbenchAiRevisionHelpers._();

  static bool hasOverlappingSelections(
    List<WorkbenchAiSelectionDraft> selections,
  ) {
    if (selections.length < 2) {
      return false;
    }
    final sorted = List<WorkbenchAiSelectionDraft>.from(selections)
      ..sort((left, right) => left.start.compareTo(right.start));
    for (var index = 1; index < sorted.length; index += 1) {
      if (sorted[index].start < sorted[index - 1].end) {
        return true;
      }
    }
    return false;
  }

  static String defaultIntent({required bool continueMode}) {
    return continueMode ? '补上一段自然衔接的正文。' : '调整语气与节奏';
  }

  static String selectionPreview(String text, TextSelection? selection) {
    if (selection == null || !selection.isValid || selection.isCollapsed) {
      return '尚未选择正文片段';
    }
    final excerpt = text.substring(selection.start, selection.end).trim();
    if (excerpt.isEmpty) {
      return '尚未选择正文片段';
    }
    if (excerpt.length <= 36) {
      return excerpt;
    }
    return '${excerpt.substring(0, 36)}...';
  }

  static String contextWindow(
    String text, {
    int? start,
    int? end,
    bool backwards = false,
  }) {
    if (text.isEmpty) {
      return '无可预览上下文';
    }
    if (backwards) {
      final safeEnd = (end ?? 0).clamp(0, text.length).toInt();
      final safeStart = (safeEnd - 24).clamp(0, safeEnd).toInt();
      final snippet = text.substring(safeStart, safeEnd).trim();
      return snippet.isEmpty ? '无上一段预览' : snippet;
    }
    final safeStart = (start ?? text.length).clamp(0, text.length).toInt();
    final safeEnd = (safeStart + 24).clamp(safeStart, text.length).toInt();
    final snippet = text.substring(safeStart, safeEnd).trim();
    return snippet.isEmpty ? '无下一段预览' : snippet;
  }

  static String previewText(String text, int maxLength) {
    final normalized = WorkbenchTextHelpers.collapseWhitespace(text.trim());
    if (normalized.length <= maxLength) {
      return normalized;
    }
    if (maxLength <= 3) {
      return normalized.substring(0, maxLength);
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }

  static String acceptedTextForBlocks(
    String original,
    List<WorkbenchAiReviewBlock> blocks,
    List<bool> included, {
    required bool continueMode,
  }) {
    final keptBlocks = <WorkbenchAiReviewBlock>[
      for (var index = 0; index < blocks.length; index += 1)
        if (included[index]) blocks[index],
    ];
    if (keptBlocks.isEmpty) {
      return original;
    }
    final selectionBlocks = keptBlocks
        .where((block) => block.selection != null)
        .toList();
    if (selectionBlocks.isEmpty) {
      if (continueMode) {
        return [
          original,
          for (final block in keptBlocks) block.suggestionText,
        ].join('\n\n');
      }
      return keptBlocks.last.suggestionText;
    }
    final replacements = List<WorkbenchAiReviewBlock>.from(selectionBlocks)
      ..sort(
        (left, right) =>
            right.selection!.start.compareTo(left.selection!.start),
      );
    var nextText = original;
    for (final block in replacements) {
      final selection = block.selection!;
      nextText = nextText.replaceRange(
        selection.start,
        selection.end,
        continueMode
            ? '${block.originalText}\n\n${block.suggestionText}'
            : block.suggestionText,
      );
    }
    return nextText;
  }
}
