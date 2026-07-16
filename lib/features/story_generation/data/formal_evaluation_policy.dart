import 'dart:async';

import 'evaluation/agent_evaluation_trace_context.dart';

final Object _formalExecutionZoneKey = Object();

/// Runtime-owned policy marker for a formal release evaluation.
///
/// The marker is written after outline/fixture metadata is merged. The active
/// evaluation trace is the authoritative signal and cannot be supplied by a
/// fixture. The marker keeps the policy available to typed stage inputs whose
/// work may cross an asynchronous boundary.
abstract final class FormalEvaluationPolicy {
  static const String metadataKey = '_formalEvaluationPolicy';
  static const String metadataValue = 'fail-closed-no-local-fallback-v2';

  static const Set<String> localFallbackFlags = <String>{
    'localDirectorOnly',
    'localStructuredRoleplayOnly',
    'localEditorialOnly',
    'localReviewOnly',
    'localPolishOnly',
  };

  static bool isActive(
    Map<String, Object?> metadata, {
    bool formalExecution = false,
  }) =>
      AgentEvaluationTraceContext.current != null ||
      Zone.current[_formalExecutionZoneKey] == true ||
      formalExecution ||
      metadata[metadataKey] == metadataValue;

  static R runWithFormalExecution<R>({
    required bool formalExecution,
    required R Function() body,
  }) {
    if (!formalExecution || Zone.current[_formalExecutionZoneKey] == true) {
      return body();
    }
    return runZoned<R>(
      body,
      zoneValues: <Object, Object?>{_formalExecutionZoneKey: true},
    );
  }

  static Map<String, Object?> runtimeMetadata() => <String, Object?>{
    metadataKey: metadataValue,
    for (final flag in localFallbackFlags) flag: false,
  };

  static void rejectLocalFallbackRequest(
    Map<String, Object?> metadata, {
    bool formalExecution = false,
  }) {
    if (!isActive(metadata, formalExecution: formalExecution)) return;
    final requested = metadata.keys
        .where(_isLocalOnlyFlag)
        .where((flag) => metadata[flag] == true)
        .toList(growable: false);
    if (requested.isNotEmpty) {
      throw StateError(
        'formal evaluation rejects local fallback flags: '
        '${requested.join(',')}',
      );
    }
  }

  static bool _isLocalOnlyFlag(String key) =>
      key.startsWith('local') && key.endsWith('Only');
}
