/// Canonical names for side effects observed outside the trial sandbox.
///
/// Production release scenarios may use only these names inside the
/// `production` namespace. Custom, non-production namespaces remain available
/// to purpose-built evaluators whose executors report their own counts.
abstract final class AgentEvaluationProductionSideEffectKeys {
  static const String contractVersion = 'eval-production-side-effect-keys-v1';
  static const String commitReceipt = 'production.commit_receipt';
  static const String outbox = 'production.outbox';
  static const String authoritativeWrite = 'production.authoritative_write';

  static const List<String> supportedList = <String>[
    commitReceipt,
    outbox,
    authoritativeWrite,
  ];

  static const Set<String> supported = <String>{
    commitReceipt,
    outbox,
    authoritativeWrite,
  };

  static bool isProductionNamespace(String key) =>
      key.startsWith('production.') || key.startsWith('production-');

  /// Rejects unknown or legacy names only when they claim the production
  /// namespace. This closes the comparator's absent-key-as-zero escape hatch
  /// without preventing custom executor-owned side-effect counters.
  static void validateStrict(Iterable<String> keys) {
    for (final key in keys) {
      if (isProductionNamespace(key) && !supported.contains(key)) {
        throw FormatException('unsupported production side-effect key: $key');
      }
    }
  }
}
