/// Memory tier classification — controls retention, indexing, and access.
enum MemoryTier {
  /// Authoritative world facts — never pruned, always indexed.
  canon,

  /// Character-level knowledge — long-lived, soul-validated.
  character,

  /// Scene-scoped observations — medium retention.
  scene,

  /// Unvetted generation output — shortest retention, may be pruned.
  draft,

  /// Meta-information about the generation process itself.
  meta,
}

/// Policy governing how a memory tier is stored and retrieved.
class MemoryPolicy {
  const MemoryPolicy({
    required this.tier,
    this.retentionScenes = 0,
    this.indexForRetrieval = true,
    this.allowedConsumers = const [],
    this.maxAgeScenes = 0,
    this.requireSoulValidation = false,
  });

  final MemoryTier tier;

  /// How many scenes this tier's records persist (0 = infinite).
  final int retentionScenes;

  /// Whether records in this tier are indexed for RAG retrieval.
  final bool indexForRetrieval;

  /// Which pipeline roles may consume records in this tier.
  final List<String> allowedConsumers;

  /// Maximum age in scenes before automatic pruning (0 = no pruning).
  final int maxAgeScenes;

  /// Whether writes to this tier require SoulContract validation.
  final bool requireSoulValidation;

  /// Ordered tiers from most to least authoritative.
  static const tierOrder = [
    MemoryTier.canon,
    MemoryTier.character,
    MemoryTier.scene,
    MemoryTier.draft,
    MemoryTier.meta,
  ];

  /// Whether [tier] is at least as authoritative as [minimum].
  static bool meetsMinimum(MemoryTier tier, MemoryTier minimum) {
    return tierOrder.indexOf(tier) <= tierOrder.indexOf(minimum);
  }

  /// Default policies for each tier.
  static const canonPolicy = MemoryPolicy(
    tier: MemoryTier.canon,
    retentionScenes: 0,
    indexForRetrieval: true,
    requireSoulValidation: true,
  );

  static const characterPolicy = MemoryPolicy(
    tier: MemoryTier.character,
    retentionScenes: 0,
    indexForRetrieval: true,
    requireSoulValidation: true,
  );

  static const scenePolicy = MemoryPolicy(
    tier: MemoryTier.scene,
    retentionScenes: 50,
    indexForRetrieval: true,
  );

  static const draftPolicy = MemoryPolicy(
    tier: MemoryTier.draft,
    retentionScenes: 10,
    indexForRetrieval: false,
  );

  static const metaPolicy = MemoryPolicy(
    tier: MemoryTier.meta,
    retentionScenes: 5,
    indexForRetrieval: false,
  );
}
