import '../domain/memory_models.dart';

/// Compresses context using structured chapter summaries instead of
/// raw text truncation. Produces a compact, information-dense context
/// string that preserves plot, character, and world-state continuity.
class SummaryBasedCompressor {
  const SummaryBasedCompressor();

  /// Builds a compressed context string from [ChapterSummary] fields.
  ///
  /// Returns null if the summary lacks structured (LLM-generated) data,
  /// signalling the caller to fall back to truncation-based compression.
  String? compress({
    required ChapterSummary summary,
    required int budget,
  }) {
    if (!summary.isLlmGenerated) return null;

    final buffer = StringBuffer();
    buffer.writeln('[章节: ${summary.chapterTitle}]');

    if (summary.plotProgress.isNotEmpty) {
      buffer.writeln('[剧情] ${summary.plotProgress}');
    }
    if (summary.emotionalArcs.isNotEmpty) {
      buffer.writeln('[情感弧线] ${summary.emotionalArcs}');
    }
    if (summary.worldStateChanges.isNotEmpty) {
      buffer.writeln('[世界观变化] ${summary.worldStateChanges}');
    }
    if (summary.foreshadowingStatus.isNotEmpty) {
      buffer.writeln('[伏笔状态] ${summary.foreshadowingStatus}');
    }
    if (summary.keyRevelations.isNotEmpty) {
      buffer.writeln('[关键揭示] ${summary.keyRevelations}');
    }
    for (final change in summary.characterStateChanges) {
      buffer.writeln('[角色] $change');
    }
    for (final thread in summary.unresolvedThreads) {
      buffer.writeln('[悬念] $thread');
    }

    final result = buffer.toString().trim();

    // If compressed text exceeds budget, truncate from the end
    if (result.length > budget) {
      return '${result.substring(0, budget - 3)}...';
    }

    return result.isEmpty ? null : result;
  }

  /// Builds a multi-chapter compressed context from a list of summaries.
  ///
  /// Each summary is compressed independently. Older summaries get less
  /// budget proportionally (recent chapters are more important).
  String compressMultiple({
    required List<ChapterSummary> summaries,
    required int totalBudget,
  }) {
    if (summaries.isEmpty) return '';

    // Allocate more budget to recent chapters
    final weights = _recencyWeights(summaries.length);
    final parts = <String>[];

    for (var i = 0; i < summaries.length; i++) {
      final budget = (totalBudget * weights[i]).floor();
      if (budget < 50) continue; // Skip if budget too small

      final compressed = compress(summary: summaries[i], budget: budget);
      if (compressed != null) {
        parts.add(compressed);
      }
    }

    final result = parts.join('\n\n');
    if (result.length > totalBudget) {
      return result.substring(result.length - totalBudget);
    }
    return result;
  }

  /// Generates exponentially decaying weights for recency prioritization.
  /// Most recent (last) chapter gets the highest weight.
  List<double> _recencyWeights(int count) {
    if (count == 0) return const [];
    if (count == 1) return const [1.0];

    final weights = <double>[];
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      // Older chapters get exponentially less weight
      final w = 1.0 + (i * 0.5); // index 0=oldest, count-1=newest
      weights.add(w);
      total += w;
    }

    // Normalize
    return [for (final w in weights) w / total];
  }
}
