import 'memory_policy.dart';

/// How retrieval results are ranked.
enum RankingStrategy {
  /// Rank by semantic (vector) similarity only.
  semantic,

  /// Rank by keyword (FTS5) match only.
  keyword,

  /// Blend semantic and keyword scores using configurable weights.
  hybrid,
}

/// Per-role policy governing what memory tiers and how much data a pipeline
/// stage may retrieve from the RAG system.
class RagRetrievalPolicy {
  const RagRetrievalPolicy({
    required this.roleId,
    this.allowedTiers = const [
      MemoryTier.canon,
      MemoryTier.character,
      MemoryTier.scene,
    ],
    this.maxTokens = 2000,
    this.rankingStrategy = RankingStrategy.hybrid,
    this.mustIncludeCanon = false,
    this.excludeDraftTier = true,
    this.semanticWeight = 0.6,
    this.keywordWeight = 0.4,
  });

  final String roleId;

  /// Which memory tiers this role is allowed to access.
  final List<MemoryTier> allowedTiers;

  /// Maximum tokens to retrieve.
  final int maxTokens;

  /// How to rank retrieval results.
  final RankingStrategy rankingStrategy;

  /// Whether canon-tier results must be included if available.
  final bool mustIncludeCanon;

  /// Whether to exclude draft-tier results even if in allowedTiers.
  final bool excludeDraftTier;

  /// Weight for semantic (vector) scores in hybrid ranking.
  final double semanticWeight;

  /// Weight for keyword (FTS5) scores in hybrid ranking.
  final double keywordWeight;

  /// Validate that weights sum to approximately 1.0.
  bool get weightsValid => (semanticWeight + keywordWeight - 1.0).abs() < 0.01;

  /// Factory: director planning role.
  factory RagRetrievalPolicy.director() => const RagRetrievalPolicy(
    roleId: 'director',
    allowedTiers: [MemoryTier.canon, MemoryTier.character, MemoryTier.scene],
    maxTokens: 3000,
    mustIncludeCanon: true,
    excludeDraftTier: true,
  );

  /// Factory: roleplay execution role.
  factory RagRetrievalPolicy.roleplay() => const RagRetrievalPolicy(
    roleId: 'roleplay',
    allowedTiers: [MemoryTier.canon, MemoryTier.character, MemoryTier.scene],
    maxTokens: 2000,
    mustIncludeCanon: false,
    excludeDraftTier: true,
  );

  /// Factory: review pass role.
  factory RagRetrievalPolicy.review() => const RagRetrievalPolicy(
    roleId: 'review',
    allowedTiers: [MemoryTier.canon],
    maxTokens: 1000,
    mustIncludeCanon: true,
    excludeDraftTier: true,
    semanticWeight: 0.3,
    keywordWeight: 0.7,
  );
}
