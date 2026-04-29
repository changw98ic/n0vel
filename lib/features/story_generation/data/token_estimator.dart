/// Centralized token-cost estimator for the story generation pipeline.
///
/// Uses a character-based heuristic (~4 characters per token) which provides
/// a reasonable approximation across English and CJK text without requiring
/// a tiktoken-compatible tokenizer.
///
/// All estimators in the pipeline should delegate to this class so the
/// formula lives in exactly one place.
class TokenEstimator {
  const TokenEstimator();

  /// Characters per estimated token.
  static const int charsPerToken = 4;

  /// Estimate token count for a single string.
  ///
  /// Returns 0 for empty strings, 1 for 1–4 chars, then `ceil(length / 4)`.
  int estimate(String text) {
    if (text.isEmpty) return 0;
    return (text.length / charsPerToken).ceil();
  }

  /// Sum of token estimates across multiple strings.
  int estimateList(List<String> texts) {
    var total = 0;
    for (final text in texts) {
      total += estimate(text);
    }
    return total;
  }

  /// Estimate tokens for a list of strings joined by [separator].
  ///
  /// This accounts for the separator characters that would appear between
  /// items when the list is concatenated (e.g., newline-joined prompt parts).
  int estimateJoined(List<String> texts, {String separator = '\n'}) {
    if (texts.isEmpty) return 0;
    if (texts.length == 1) return estimate(texts.first);
    final joinedLength = texts.fold<int>(
      0,
      (sum, t) => sum + t.length,
    ) +
        separator.length * (texts.length - 1);
    if (joinedLength == 0) return 0;
    return (joinedLength / charsPerToken).ceil();
  }

  /// Whether [text] fits within [budget] tokens.
  bool fitsBudget(String text, int budget) => estimate(text) <= budget;

  /// Total token cost across a list of already-costed items.
  ///
  /// Useful for summing the `tokenCostEstimate` of memory chunks.
  int totalCost(List<int> tokenCosts) {
    var total = 0;
    for (final cost in tokenCosts) {
      total += cost;
    }
    return total;
  }

  /// Remaining tokens after spending [used] from [budget].
  int remaining(int budget, int used) => budget - used;
}
