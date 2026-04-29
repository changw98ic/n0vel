import '../domain/memory_models.dart';

/// Default confidence threshold for thought acceptance.
const double defaultThoughtConfidenceThreshold = 0.72;

/// Similarity and redundancy guard for chunks and thoughts.
///
/// Uses deterministic token overlap until embeddings are available.
class StoryMemoryDedupe {
  /// Checks whether a candidate thought is redundant against existing ones.
  bool isDuplicate(ThoughtAtom candidate, List<ThoughtAtom> existing) {
    for (final atom in existing) {
      if (atom.thoughtType != candidate.thoughtType) continue;
      final overlap = _tokenOverlap(atom.content, candidate.content);
      if (overlap >= 0.7) return true;
    }
    return false;
  }

  /// Checks whether a thought passes quality gates.
  bool passesQualityGate(ThoughtAtom thought) {
    if (thought.confidence < defaultThoughtConfidenceThreshold) return false;
    if (thought.sourceRefs.isEmpty && thought.rootSourceIds.isEmpty) {
      return false;
    }
    if (thought.content.trim().isEmpty) return false;
    return true;
  }

  /// Normalized token overlap between two strings.
  double _tokenOverlap(String a, String b) {
    final tokensA = _tokenize(a);
    final tokensB = _tokenize(b);
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
    var matches = 0;
    for (final token in tokensA) {
      if (tokensB.contains(token)) matches++;
    }
    return matches / (tokensA.length + tokensB.length - matches);
  }

  Set<String> _tokenize(String text) {
    return {
      for (final word in text.toLowerCase().split(RegExp(r'\s+')))
        if (word.isNotEmpty) word,
    };
  }
}
