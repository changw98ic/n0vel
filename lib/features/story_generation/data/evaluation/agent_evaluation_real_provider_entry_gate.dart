/// Fail-closed policy for historical real-provider entry points.
///
/// Formal provider execution is owned by
/// `tool/agent_evaluation_release_coordinator.dart`. That coordinator launches
/// the frozen, signed application runtime, verifies the production trust/KMS
/// chain, and validates the complete budget before a provider client is used.
/// Environment variables are user-controlled input and therefore cannot turn
/// a legacy test or tool into a formal runtime.
abstract final class AgentEvaluationRealProviderEntryGate {
  static const coordinatorCommand =
      'dart run tool/agent_evaluation_release_coordinator.dart';

  static const legacyDenialReason =
      'Direct real-provider execution is disabled. Use '
      '$coordinatorCommand with the formally signed runtime, pinned KMS/trust '
      'configuration, and an explicitly authorized complete budget.';

  /// Intentionally ignores every caller-supplied value. No combination of
  /// opt-in, credential, budget, or old "preflighted" environment flags is a
  /// non-forgeable runtime authority.
  static AgentEvaluationRealProviderEntryDecision legacyDecision({
    required String entryPoint,
    Map<String, String> environment = const <String, String>{},
  }) {
    if (entryPoint.trim().isEmpty) {
      throw ArgumentError.value(entryPoint, 'entryPoint');
    }
    return AgentEvaluationRealProviderEntryDecision._(entryPoint: entryPoint);
  }

  /// Adversarial/test seam that proves denial happens before the supplied
  /// provider operation can be evaluated.
  static Future<T> rejectLegacyProviderOperation<T>({
    required AgentEvaluationRealProviderEntryDecision decision,
    required Future<T> Function() providerOperation,
  }) async {
    throw AgentEvaluationLegacyRealProviderEntryException(
      entryPoint: decision.entryPoint,
    );
  }
}

final class AgentEvaluationRealProviderEntryDecision {
  const AgentEvaluationRealProviderEntryDecision._({required this.entryPoint});

  final String entryPoint;

  bool get authorized => false;

  String get denialReason =>
      AgentEvaluationRealProviderEntryGate.legacyDenialReason;
}

final class AgentEvaluationLegacyRealProviderEntryException
    implements Exception {
  const AgentEvaluationLegacyRealProviderEntryException({
    required this.entryPoint,
  });

  final String entryPoint;

  @override
  String toString() =>
      'AgentEvaluationLegacyRealProviderEntryException: $entryPoint: '
      '${AgentEvaluationRealProviderEntryGate.legacyDenialReason}';
}
