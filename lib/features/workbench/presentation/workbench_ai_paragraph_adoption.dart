import 'workbench_ai_revision_helpers.dart';

/// AI candidate adoption at paragraph/block level.
///
/// Provides models and helpers for reviewing and adopting AI-generated text
/// at paragraph granularity rather than whole-document level.
///

/// A single adoptable unit representing a paragraph or block comparison.
class AiAdoptableUnit {
  const AiAdoptableUnit({
    required this.id,
    required this.originalText,
    required this.candidateText,
    this.previousText,
    this.nextText,
    this.isAccepted = true,
    this.blockLabel,
    this.selection,
  });

  final String id;
  final String originalText;
  final String candidateText;
  final String? previousText;
  final String? nextText;
  final bool isAccepted;
  final String? blockLabel;
  final WorkbenchAiSelectionDraft? selection;

  AiAdoptableUnit copyWith({
    String? id,
    String? originalText,
    String? candidateText,
    String? previousText,
    String? nextText,
    bool? isAccepted,
    String? blockLabel,
    WorkbenchAiSelectionDraft? selection,
  }) {
    return AiAdoptableUnit(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      candidateText: candidateText ?? this.candidateText,
      previousText: previousText ?? this.previousText,
      nextText: nextText ?? this.nextText,
      isAccepted: isAccepted ?? this.isAccepted,
      blockLabel: blockLabel ?? this.blockLabel,
      selection: selection ?? this.selection,
    );
  }

  /// Returns the text that should be used based on acceptance state.
  String get effectiveText => isAccepted ? candidateText : originalText;
}

/// Helper for building adoptable units and computing accepted text.
class AiParagraphAdoptionHelpers {
  const AiParagraphAdoptionHelpers._();

  /// Splits text into paragraphs safely.
  /// Returns empty list if text is empty or only whitespace.
  static List<String> splitIntoParagraphs(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return [];

    // Split by double newlines or single newlines followed by non-whitespace
    final parts = normalized.split(RegExp(r'\n\s*\n|\n(?=[^\s])'));
    return parts.where((p) => p.trim().isNotEmpty).map((p) => p.trim()).toList();
  }

  /// Builds adoptable units from existing review blocks.
  /// For selection-based review blocks, keeps block-level granularity.
  /// For fallback rewrite/continue blocks, attempts paragraph-level splitting.
  static List<AiAdoptableUnit> buildAdoptableUnits({
    required List<WorkbenchAiReviewBlock> blocks,
    required bool continueMode,
  }) {
    if (blocks.isEmpty) return [];

    // Selection-based blocks: preserve existing block structure and selection offsets
    final hasSelections = blocks.any((b) => b.selection != null);
    if (hasSelections) {
      return blocks
          .asMap()
          .map((idx, block) => MapEntry(
                idx,
                AiAdoptableUnit(
                  id: 'block-$idx',
                  originalText: block.originalText,
                  candidateText: block.suggestionText,
                  previousText: block.previousText.isNotEmpty ? block.previousText : null,
                  nextText: block.nextText.isNotEmpty ? block.nextText : null,
                  blockLabel: block.blockLabel,
                  selection: block.selection,
                ),
              ))
          .values
          .toList();
    }

    // Fallback single block: attempt paragraph-level splitting
    if (blocks.length == 1) {
      final block = blocks.single;
      final originalParagraphs = splitIntoParagraphs(block.originalText);
      final candidateParagraphs = splitIntoParagraphs(block.suggestionText);

      // If we can't align paragraphs safely, fall back to single block
      if (originalParagraphs.isEmpty || candidateParagraphs.isEmpty) {
        return [
          AiAdoptableUnit(
            id: 'block-0',
            originalText: block.originalText,
            candidateText: block.suggestionText,
            previousText: block.previousText.isNotEmpty ? block.previousText : null,
            nextText: block.nextText.isNotEmpty ? block.nextText : null,
            blockLabel: block.blockLabel,
          ),
        ];
      }

      // For continue mode, candidate typically appends paragraphs
      if (continueMode) {
        return [
          // Keep original paragraphs as-is (all accepted means no change)
          for (var i = 0; i < originalParagraphs.length; i++)
            AiAdoptableUnit(
              id: 'original-$i',
              originalText: originalParagraphs[i],
              candidateText: originalParagraphs[i],
              isAccepted: true,
            ),
          // New paragraphs from candidate
          for (var i = 0; i < candidateParagraphs.length; i++)
            AiAdoptableUnit(
              id: 'candidate-$i',
              originalText: '',
              candidateText: candidateParagraphs[i],
              previousText: i == 0
                  ? (originalParagraphs.isNotEmpty ? originalParagraphs.last : null)
                  : candidateParagraphs[i - 1],
              isAccepted: true,
            ),
        ];
      }

      // For rewrite mode: try to align paragraphs by count
      final originalCount = originalParagraphs.length;
      final candidateCount = candidateParagraphs.length;

      // If counts match exactly, align 1:1
      if (originalCount == candidateCount) {
        return List.generate(
          originalCount,
          (i) => AiAdoptableUnit(
            id: 'paragraph-$i',
            originalText: originalParagraphs[i],
            candidateText: candidateParagraphs[i],
            previousText: i > 0 ? originalParagraphs[i - 1] : block.previousText,
            nextText: i < originalCount - 1 ? originalParagraphs[i + 1] : block.nextText,
            isAccepted: true,
          ),
        );
      }

      // If counts differ significantly, fall back to single safe block
      // to avoid destructive misalignment
      if ((originalCount - candidateCount).abs() > originalCount ~/ 2) {
        return [
          AiAdoptableUnit(
            id: 'block-0',
            originalText: block.originalText,
            candidateText: block.suggestionText,
            previousText: block.previousText.isNotEmpty ? block.previousText : null,
            nextText: block.nextText.isNotEmpty ? block.nextText : null,
            blockLabel: block.blockLabel,
          ),
        ];
      }

      // Partial alignment: align what we can, preserve rest
      final minCount = originalCount < candidateCount ? originalCount : candidateCount;
      final units = <AiAdoptableUnit>[];

      for (var i = 0; i < minCount; i++) {
        units.add(AiAdoptableUnit(
          id: 'paragraph-$i',
          originalText: originalParagraphs[i],
          candidateText: candidateParagraphs[i],
          previousText: i > 0 ? originalParagraphs[i - 1] : block.previousText,
          nextText: i < minCount - 1 ? originalParagraphs[i + 1] : null,
          isAccepted: true,
        ));
      }

      // Preserve unaligned original paragraphs
      for (var i = minCount; i < originalCount; i++) {
        units.add(AiAdoptableUnit(
          id: 'original-extra-$i',
          originalText: originalParagraphs[i],
          candidateText: originalParagraphs[i],
          isAccepted: true,
        ));
      }

      // Preserve unaligned candidate paragraphs
      for (var i = minCount; i < candidateCount; i++) {
        units.add(AiAdoptableUnit(
          id: 'candidate-extra-$i',
          originalText: '',
          candidateText: candidateParagraphs[i],
          isAccepted: true,
        ));
      }

      return units;
    }

    // Multiple blocks without selections: treat each as a unit
    return blocks
        .asMap()
        .map((idx, block) => MapEntry(
              idx,
              AiAdoptableUnit(
                id: 'block-$idx',
                originalText: block.originalText,
                candidateText: block.suggestionText,
                previousText: block.previousText.isNotEmpty ? block.previousText : null,
                nextText: block.nextText.isNotEmpty ? block.nextText : null,
                blockLabel: block.blockLabel,
              ),
            ))
        .values
        .toList();
  }

  /// Computes the final accepted text from a list of adoptable units.
  /// For selection-based units, applies replacements to original.
  /// For paragraph units, joins accepted text with appropriate separators.
  static String acceptedTextForUnits({
    required String original,
    required List<AiAdoptableUnit> units,
    required bool continueMode,
  }) {
    if (units.isEmpty) return original;

    // Check if any unit has selection information
    final hasSelectionBlocks = units.any((u) => u.selection != null);

    if (hasSelectionBlocks) {
      // Selection-based: apply replacements to original at specific offsets
      // Sort accepted selection units by start offset descending to apply from end to start
      final acceptedSelectionUnits = units
          .where((u) => u.isAccepted && u.selection != null)
          .toList()
        ..sort((a, b) => b.selection!.start.compareTo(a.selection!.start));

      if (acceptedSelectionUnits.isEmpty) return original;

      // For continue mode with selections: append after original
      if (continueMode) {
        final acceptedParts = <String>[];
        for (final unit in acceptedSelectionUnits) {
          if (unit.candidateText.isNotEmpty) {
            acceptedParts.add(unit.candidateText);
          }
        }
        if (acceptedParts.isEmpty) return original;
        return [original, ...acceptedParts].join('\n\n');
      }

      // For rewrite mode with selections: apply each replacement from highest to lowest offset
      var result = original;
      for (final unit in acceptedSelectionUnits) {
        final sel = unit.selection!;
        final replacement = unit.candidateText;

        // Replace exactly the selected range [sel.start, sel.end)
        // Do NOT expand to consume adjacent spaces
        result = result.replaceRange(sel.start, sel.end, replacement);
      }
      return result;
    }

    // Paragraph-based: build text from all units (accepted and non-accepted)
    // Filter out units that have empty candidate text AND are not accepted
    // These represent placeholder units that should be excluded
    final acceptedTexts = units
        .where((u) => !(u.candidateText.isEmpty && !u.isAccepted))
        .map((u) => u.effectiveText)
        .where((text) => text.isNotEmpty)
        .toList();

    if (acceptedTexts.isEmpty) return original;

    if (continueMode) {
      // For continue mode: if all are from original, return original
      final allOriginal = units.every((u) =>
          u.isAccepted && (u.candidateText == u.originalText || u.candidateText.isEmpty));
      if (allOriginal) return original;

      // Otherwise, join all accepted non-empty texts
      return acceptedTexts.join('\n\n');
    }

    // For rewrite mode: join all accepted texts
    return acceptedTexts.join('\n\n');
  }

  /// Counts how many units have candidate text accepted.
  static int countAcceptedCandidates(List<AiAdoptableUnit> units) {
    return units.where((u) => u.isAccepted && u.candidateText != u.originalText).length;
  }

  /// Counts how many units keep original text.
  static int countKeptOriginals(List<AiAdoptableUnit> units) {
    return units.where((u) => !u.isAccepted || u.candidateText == u.originalText).length;
  }
}
