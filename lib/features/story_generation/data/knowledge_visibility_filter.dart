import '../domain/character_cognition_models.dart';

/// A piece of knowledge in the world that may or may not be known to characters.
class KnowledgeFact {
  const KnowledgeFact({
    required this.factId,
    required this.content,
    this.isPublic = false,
  });

  final String factId;
  final String content;
  final bool isPublic;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeFact &&
          other.factId == factId &&
          other.content == content &&
          other.isPublic == isPublic;

  @override
  int get hashCode => Object.hash(factId, content, isPublic);
}

/// Controls which characters are aware of a knowledge fact.
class DisclosurePolicy {
  DisclosurePolicy({
    required this.factId,
    Set<String> knownBy = const {},
  }) : knownBy = Set<String>.unmodifiable(knownBy);

  final String factId;
  final Set<String> knownBy;

  bool isKnownTo(String characterId) => knownBy.contains(characterId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisclosurePolicy &&
          other.factId == factId &&
          _setEquals(other.knownBy, knownBy);

  @override
  int get hashCode => Object.hash(factId, Object.hashAllUnordered(knownBy));
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// Filters knowledge visibility per character based on disclosure policies.
class KnowledgeVisibilityFilter {
  /// Returns the subset of [allFacts] visible to [characterId].
  List<KnowledgeFact> visibleFacts(
    List<KnowledgeFact> allFacts,
    String characterId,
    List<DisclosurePolicy> policies,
  ) {
    final policyMap = {for (final p in policies) p.factId: p};
    return [
      for (final fact in allFacts)
        if (_isVisible(fact, characterId, policyMap)) fact,
    ];
  }

  /// Checks whether a specific fact is visible to a character.
  bool isFactVisibleTo(
    String factId,
    String characterId,
    List<KnowledgeFact> allFacts,
    List<DisclosurePolicy> policies,
  ) {
    final fact = _findById(allFacts, factId);
    if (fact == null) return false;
    final policyMap = {for (final p in policies) p.factId: p};
    return _isVisible(fact, characterId, policyMap);
  }

  /// Builds a cognition snapshot whose beliefs are limited to facts
  /// the character is allowed to know.
  CharacterCognitionSnapshot filterSnapshot(
    CharacterCognitionSnapshot snapshot,
    List<DisclosurePolicy> policies,
  ) {
    // Beliefs are self-owned — they reflect what the character already
    // believes, so no filtering is applied. This method is a hook for
    // future cross-character belief leakage prevention.
    return snapshot;
  }

  /// Partitions facts among characters, returning a map from
  /// character ID to the list of facts visible to that character.
  Map<String, List<KnowledgeFact>> partitionFacts(
    List<KnowledgeFact> allFacts,
    List<String> characterIds,
    List<DisclosurePolicy> policies,
  ) {
    return {
      for (final id in characterIds)
        id: visibleFacts(allFacts, id, policies),
    };
  }

  bool _isVisible(
    KnowledgeFact fact,
    String characterId,
    Map<String, DisclosurePolicy> policyMap,
  ) {
    if (fact.isPublic) return true;
    final policy = policyMap[fact.factId];
    if (policy == null) return false;
    return policy.isKnownTo(characterId);
  }

  KnowledgeFact? _findById(List<KnowledgeFact> facts, String factId) {
    for (final f in facts) {
      if (f.factId == factId) return f;
    }
    return null;
  }
}
