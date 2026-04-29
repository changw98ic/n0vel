import '../domain/pipeline_models.dart';

/// Compression strategy selected based on budget pressure.
enum CompressionStrategy {
  /// Keep content as-is when budget is sufficient.
  full,

  /// Truncate at the last sentence boundary within budget.
  sentenceBoundary,

  /// Extract key sentences for tight budgets.
  keySentences,

  /// Aggressive compression for critical budget pressure.
  keywords,
}

/// Compresses raw retrieval results into bounded [ContextCapsule]s
/// that fit within a [PromptBudget].
///
/// Uses dynamic strategy selection based on content/budget ratio:
/// - Full content when budget is sufficient
/// - Sentence-boundary truncation for moderate pressure
/// - Key sentence extraction for tight budgets
/// - Keyword extraction for critical pressure
class ContextCapsuleCompressor {
  ContextCapsuleCompressor({this.defaultCharBudget = 200});

  final int defaultCharBudget;

  /// Selects the optimal compression strategy based on content size vs budget.
  CompressionStrategy selectStrategy(String content, int budget) {
    if (content.length <= budget) return CompressionStrategy.full;
    final ratio = budget / content.length;
    if (ratio > 0.6) return CompressionStrategy.sentenceBoundary;
    if (ratio > 0.25) return CompressionStrategy.keySentences;
    return CompressionStrategy.keywords;
  }

  /// Creates a capsule by dynamically compressing [rawContent] to fit
  /// within both [defaultCharBudget] and the [budget]'s remaining capacity.
  ///
  /// Returns `null` if the budget is exhausted and no space remains.
  /// Optionally pass [strategy] to override automatic strategy selection.
  ContextCapsule? compress({
    required String sourceTool,
    required String rawContent,
    required PromptBudget budget,
    String? id,
    Map<String, Object?> metadata = const {},
    CompressionStrategy? strategy,
  }) {
    if (budget.isExhausted) return null;

    final effectiveBudget =
        budget.remaining < defaultCharBudget ? budget.remaining : defaultCharBudget;
    final effectiveStrategy =
        strategy ?? selectStrategy(rawContent, effectiveBudget);
    final summary = _compress(rawContent, effectiveBudget, effectiveStrategy);

    if (!budget.tryAllocate(summary.length)) return null;

    return ContextCapsule(
      id: id ?? _generateId(sourceTool),
      sourceTool: sourceTool,
      summary: summary,
      charBudget: effectiveBudget,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      metadata: metadata,
    );
  }

  /// Batch-compress multiple raw results with priority-aware budget allocation.
  ///
  /// Results are sorted by priority (higher first) so the most important
  /// items are compressed while the budget still has room. Stops early
  /// if budget is exhausted.
  List<ContextCapsule> compressAll({
    required List<RawRetrievalResult> rawResults,
    required PromptBudget budget,
  }) {
    final sorted = List<RawRetrievalResult>.of(rawResults)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    final capsules = <ContextCapsule>[];
    for (final result in sorted) {
      final capsule = compress(
        sourceTool: result.sourceTool,
        rawContent: result.rawContent,
        budget: budget,
        metadata: result.metadata,
      );
      if (capsule == null) break;
      capsules.add(capsule);
    }
    return List<ContextCapsule>.unmodifiable(capsules);
  }

  /// Applies the selected compression strategy.
  String _compress(String content, int maxChars, CompressionStrategy strategy) {
    if (maxChars <= 0) return '';
    if (content.length <= maxChars) return content;

    return switch (strategy) {
      CompressionStrategy.full => content,
      CompressionStrategy.sentenceBoundary =>
        _truncateAtSentence(content, maxChars),
      CompressionStrategy.keySentences =>
        _extractKeySentences(content, maxChars),
      CompressionStrategy.keywords => _extractKeywords(content, maxChars),
    };
  }

  /// Truncates at the last sentence boundary within budget.
  /// Falls back to ellipsis truncation when no boundary is found.
  String _truncateAtSentence(String content, int maxChars) {
    if (maxChars <= 0) return '';
    if (content.length <= maxChars) return content;

    final substring = content.substring(0, maxChars);
    var lastBoundary = -1;
    for (var i = substring.length - 1; i >= 0; i--) {
      if (_isSentenceEnd(substring[i])) {
        lastBoundary = i;
        break;
      }
    }

    if (lastBoundary > 0) return substring.substring(0, lastBoundary + 1);
    return _truncateWithEllipsis(content, maxChars);
  }

  /// Extracts leading sentences that fit within budget.
  String _extractKeySentences(String content, int maxChars) {
    if (maxChars <= 0) return '';
    if (content.length <= maxChars) return content;

    final parts = _splitSentences(content);
    final buffer = StringBuffer();

    for (final part in parts) {
      final separator = buffer.isEmpty ? 0 : 1;
      if (buffer.length + part.length + separator > maxChars - 3) break;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(part);
    }

    if (buffer.isEmpty) return _truncateWithEllipsis(content, maxChars);
    final result = buffer.toString();
    if (result.length >= content.length) return result;
    if (result.isNotEmpty && _isSentenceEnd(result[result.length - 1])) {
      return result;
    }
    return '$result...';
  }

  /// Aggressive compression: strip punctuation, collapse whitespace.
  String _extractKeywords(String content, int maxChars) {
    if (maxChars <= 0) return '';
    if (content.length <= maxChars) return content;

    final cleaned = content
        .replaceAll(RegExp(r'[，,、；;：:（()）\s]+'), ' ')
        .trim();

    if (cleaned.length <= maxChars) return cleaned;
    return _truncateWithEllipsis(cleaned, maxChars);
  }

  String _truncateWithEllipsis(String content, int maxChars) {
    if (maxChars <= 0) return '';
    if (content.length <= maxChars) return content;
    if (maxChars < 4) return content.substring(0, maxChars);
    return '${content.substring(0, maxChars - 3)}...';
  }

  bool _isSentenceEnd(String char) {
    return char == '。' || char == '！' || char == '？' ||
        char == '.' || char == '!' || char == '?' || char == '\n';
  }

  List<String> _splitSentences(String content) {
    final parts = <String>[];
    var start = 0;
    for (var i = 0; i < content.length; i++) {
      if (_isSentenceEnd(content[i])) {
        final sentence = content.substring(start, i + 1).trim();
        if (sentence.isNotEmpty) parts.add(sentence);
        start = i + 1;
      }
    }
    if (start < content.length) {
      final remaining = content.substring(start).trim();
      if (remaining.isNotEmpty) parts.add(remaining);
    }
    return parts;
  }

  int _nextIdCounter = 0;
  String _generateId(String sourceTool) {
    _nextIdCounter += 1;
    return '${sourceTool}_${DateTime.now().millisecondsSinceEpoch}_$_nextIdCounter';
  }
}

/// A raw retrieval result awaiting compression.
class RawRetrievalResult {
  RawRetrievalResult({
    required this.sourceTool,
    required this.rawContent,
    Map<String, Object?> metadata = const {},
    this.priority = 0,
  }) : metadata = Map<String, Object?>.unmodifiable(metadata);

  final String sourceTool;
  final String rawContent;
  final Map<String, Object?> metadata;

  /// Priority for budget allocation. Higher = compressed first with more budget.
  final int priority;
}
