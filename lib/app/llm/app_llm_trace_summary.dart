enum AppLlmTraceTimingEvidence { none, exact, inferred, mixed }

/// Auditable aggregate of central LLM request trace entries.
///
/// Concurrency is observed from half-open request-pool slot intervals
/// `[start, end)`. Physical dispatches are counted only when their endpoint,
/// gateway-retry, and fallback metadata is present; retries hidden inside
/// legacy logical entries are never inferred. Exact slot timestamps take
/// precedence over legacy timestamp/latency reconstruction. Malformed evidence
/// is reported but never converted into an interval.
final class AppLlmTraceSummary {
  const AppLlmTraceSummary._({
    required this.configuredSceneConcurrency,
    required this.configuredRequestConcurrency,
    required this.observedMaxConcurrency,
    required this.timingEvidence,
    required this.exactTimingCalls,
    required this.inferredTimingCalls,
    required this.malformedTimingCalls,
    required this.untimedCalls,
    required this.totalCalls,
    required this.succeededCalls,
    required this.failedCalls,
    required this.unknownOutcomeCalls,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.succeededTokens,
    required this.failedTokens,
    required this.unknownOutcomeTokens,
    required this.retryCalls,
    required this.retryMetadataCalls,
    required this.physicalDispatchCalls,
    required this.gatewayRetryCalls,
    required this.fallbackCalls,
    required this.replanDecisions,
    required this.reviewDecisionMetadataCalls,
    required this.stageTaggedCalls,
    required this.agentTaggedCalls,
    required this.stageCounts,
    required this.agentCounts,
    required this.traceNameCounts,
    required this.stageTokenTotals,
    required this.traceNameTokenTotals,
  });

  factory AppLlmTraceSummary.fromJsonEntries(
    Iterable<Map<String, Object?>> entries, {
    required int configuredSceneConcurrency,
    required int configuredRequestConcurrency,
  }) {
    if (configuredSceneConcurrency <= 0) {
      throw ArgumentError.value(
        configuredSceneConcurrency,
        'configuredSceneConcurrency',
        'must be positive',
      );
    }
    if (configuredRequestConcurrency <= 0) {
      throw ArgumentError.value(
        configuredRequestConcurrency,
        'configuredRequestConcurrency',
        'must be positive',
      );
    }
    final intervals = <_TraceInterval>[];
    final stageCounts = <String, int>{};
    final agentCounts = <String, int>{};
    final traceNameCounts = <String, int>{};
    final stageTokenTotals = <String, int>{};
    final traceNameTokenTotals = <String, int>{};

    var exactTimingCalls = 0;
    var inferredTimingCalls = 0;
    var malformedTimingCalls = 0;
    var untimedCalls = 0;
    var totalCalls = 0;
    var succeededCalls = 0;
    var failedCalls = 0;
    var unknownOutcomeCalls = 0;
    var promptTokens = 0;
    var completionTokens = 0;
    var totalTokens = 0;
    var succeededTokens = 0;
    var failedTokens = 0;
    var unknownOutcomeTokens = 0;
    var retryCalls = 0;
    var retryMetadataCalls = 0;
    var physicalDispatchCalls = 0;
    var gatewayRetryCalls = 0;
    var fallbackCalls = 0;
    var replanDecisions = 0;
    var reviewDecisionMetadataCalls = 0;
    var stageTaggedCalls = 0;
    var agentTaggedCalls = 0;

    for (final entry in entries) {
      totalCalls++;

      final prompt = _nonNegativeInt(entry['promptTokens']) ?? 0;
      final completion = _nonNegativeInt(entry['completionTokens']) ?? 0;
      final callTokens =
          _nonNegativeInt(entry['totalTokens']) ?? prompt + completion;
      promptTokens += prompt;
      completionTokens += completion;
      totalTokens += callTokens;

      switch (entry['succeeded']) {
        case true:
          succeededCalls++;
          succeededTokens += callTokens;
        case false:
          failedCalls++;
          failedTokens += callTokens;
        default:
          unknownOutcomeCalls++;
          unknownOutcomeTokens += callTokens;
      }

      final metadata = entry['metadata'];
      final stageId =
          _nonEmptyString(entry['stageId']) ??
          (metadata is Map ? _nonEmptyString(metadata['stageId']) : null);
      if (stageId != null) {
        stageTaggedCalls++;
        _increment(stageCounts, stageId, 1);
        if (callTokens > 0) {
          _increment(stageTokenTotals, stageId, callTokens);
        }
      }
      final agentId =
          _nonEmptyString(entry['agentId']) ??
          (metadata is Map ? _nonEmptyString(metadata['agentId']) : null);
      if (agentId != null) {
        agentTaggedCalls++;
        _increment(agentCounts, agentId, 1);
      }
      final traceName = _nonEmptyString(entry['traceName']);
      if (traceName != null) {
        _increment(traceNameCounts, traceName, 1);
        if (callTokens > 0) {
          _increment(traceNameTokenTotals, traceName, callTokens);
        }
      }

      if (metadata is Map) {
        if (_hasRetryMetadata(metadata)) retryMetadataCalls++;
        if (_metadataMarksRetry(metadata)) retryCalls++;
        if (_metadataMarksPhysicalDispatch(metadata)) {
          physicalDispatchCalls++;
          if (_metadataMarksGatewayRetry(metadata)) gatewayRetryCalls++;
          if (_metadataMarksFallback(metadata)) fallbackCalls++;
        }
        final reviewDecision = metadata['reviewDecision'];
        if (reviewDecision is String && reviewDecision.trim().isNotEmpty) {
          reviewDecisionMetadataCalls++;
          if (reviewDecision == 'replanScene') replanDecisions++;
        }
      }

      final timing = _timingFrom(entry);
      switch (timing.kind) {
        case _TimingKind.exact:
          exactTimingCalls++;
          intervals.add(timing.interval!);
        case _TimingKind.inferred:
          inferredTimingCalls++;
          intervals.add(timing.interval!);
        case _TimingKind.malformed:
          malformedTimingCalls++;
        case _TimingKind.untimed:
          untimedCalls++;
      }
    }

    final timingEvidence = switch ((exactTimingCalls, inferredTimingCalls)) {
      (> 0, > 0) => AppLlmTraceTimingEvidence.mixed,
      (> 0, _) => AppLlmTraceTimingEvidence.exact,
      (_, > 0) => AppLlmTraceTimingEvidence.inferred,
      _ => AppLlmTraceTimingEvidence.none,
    };

    return AppLlmTraceSummary._(
      configuredSceneConcurrency: configuredSceneConcurrency,
      configuredRequestConcurrency: configuredRequestConcurrency,
      observedMaxConcurrency: _observedMaxConcurrency(intervals),
      timingEvidence: timingEvidence,
      exactTimingCalls: exactTimingCalls,
      inferredTimingCalls: inferredTimingCalls,
      malformedTimingCalls: malformedTimingCalls,
      untimedCalls: untimedCalls,
      totalCalls: totalCalls,
      succeededCalls: succeededCalls,
      failedCalls: failedCalls,
      unknownOutcomeCalls: unknownOutcomeCalls,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      succeededTokens: succeededTokens,
      failedTokens: failedTokens,
      unknownOutcomeTokens: unknownOutcomeTokens,
      retryCalls: retryCalls,
      retryMetadataCalls: retryMetadataCalls,
      physicalDispatchCalls: physicalDispatchCalls,
      gatewayRetryCalls: gatewayRetryCalls,
      fallbackCalls: fallbackCalls,
      replanDecisions: replanDecisions,
      reviewDecisionMetadataCalls: reviewDecisionMetadataCalls,
      stageTaggedCalls: stageTaggedCalls,
      agentTaggedCalls: agentTaggedCalls,
      stageCounts: _sortedImmutable(stageCounts),
      agentCounts: _sortedImmutable(agentCounts),
      traceNameCounts: _sortedImmutable(traceNameCounts),
      stageTokenTotals: _sortedImmutable(stageTokenTotals),
      traceNameTokenTotals: _sortedImmutable(traceNameTokenTotals),
    );
  }

  final int configuredSceneConcurrency;
  final int configuredRequestConcurrency;

  /// Maximum overlap among represented request-pool slot intervals.
  ///
  /// This is not a count of provider-level physical dispatches.
  final int observedMaxConcurrency;
  final AppLlmTraceTimingEvidence timingEvidence;
  final int exactTimingCalls;
  final int inferredTimingCalls;
  final int malformedTimingCalls;
  final int untimedCalls;
  final int totalCalls;
  final int succeededCalls;
  final int failedCalls;
  final int unknownOutcomeCalls;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int succeededTokens;
  final int failedTokens;
  final int unknownOutcomeTokens;
  final int retryCalls;
  final int retryMetadataCalls;

  /// Entries carrying a complete physical endpoint-dispatch identity.
  final int physicalDispatchCalls;

  /// Physical dispatches whose zero-based gateway retry index is greater than
  /// zero.
  final int gatewayRetryCalls;

  /// Physical dispatches sent to a non-primary failover endpoint.
  final int fallbackCalls;
  final int replanDecisions;
  final int reviewDecisionMetadataCalls;
  final int stageTaggedCalls;
  final int agentTaggedCalls;
  final Map<String, int> stageCounts;
  final Map<String, int> agentCounts;
  final Map<String, int> traceNameCounts;
  final Map<String, int> stageTokenTotals;
  final Map<String, int> traceNameTokenTotals;

  int get timedCalls => exactTimingCalls + inferredTimingCalls;

  bool get observedConcurrencyIsInferred => inferredTimingCalls > 0;

  bool get timingCoverageComplete => totalCalls > 0 && timedCalls == totalCalls;

  bool get observedConcurrencyIsExact =>
      totalCalls > 0 && exactTimingCalls == totalCalls;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 'app-llm-trace-summary-v1',
    'configuredSceneConcurrency': configuredSceneConcurrency,
    'configuredRequestConcurrency': configuredRequestConcurrency,
    'observedMaxConcurrency': observedMaxConcurrency,
    'timingEvidence': timingEvidence.name,
    'observedConcurrencyIsInferred': observedConcurrencyIsInferred,
    'observedConcurrencyIsComplete': timingCoverageComplete,
    'timingCoverageComplete': timingCoverageComplete,
    'observedConcurrencyIsExact': observedConcurrencyIsExact,
    'exactTimingCalls': exactTimingCalls,
    'inferredTimingCalls': inferredTimingCalls,
    'malformedTimingCalls': malformedTimingCalls,
    'untimedCalls': untimedCalls,
    'timedCalls': timedCalls,
    'totalCalls': totalCalls,
    'succeededCalls': succeededCalls,
    'failedCalls': failedCalls,
    'unknownOutcomeCalls': unknownOutcomeCalls,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
    'succeededTokens': succeededTokens,
    'failedTokens': failedTokens,
    'unknownOutcomeTokens': unknownOutcomeTokens,
    'retryCalls': retryCalls,
    'retryMetadataCalls': retryMetadataCalls,
    'physicalDispatchCalls': physicalDispatchCalls,
    'gatewayRetryCalls': gatewayRetryCalls,
    'fallbackCalls': fallbackCalls,
    'replanDecisions': replanDecisions,
    'reviewDecisionMetadataCalls': reviewDecisionMetadataCalls,
    'stageTaggedCalls': stageTaggedCalls,
    'stageUntaggedCalls': totalCalls - stageTaggedCalls,
    'agentTaggedCalls': agentTaggedCalls,
    'agentUntaggedCalls': totalCalls - agentTaggedCalls,
    'stageCounts': stageCounts,
    'agentCounts': agentCounts,
    'traceNameCounts': traceNameCounts,
    'stageTokenTotals': stageTokenTotals,
    'traceNameTokenTotals': traceNameTokenTotals,
  };
}

enum _TimingKind { exact, inferred, malformed, untimed }

final class _TimingResult {
  const _TimingResult(this.kind, [this.interval]);

  final _TimingKind kind;
  final _TraceInterval? interval;
}

final class _TraceInterval {
  const _TraceInterval(this.startMs, this.endMs);

  final int startMs;
  final int endMs;
}

final class _TimingEvent {
  const _TimingEvent(this.atMs, this.delta);

  final int atMs;
  final int delta;
}

_TimingResult _timingFrom(Map<String, Object?> entry) {
  final hasExactEvidence =
      entry.containsKey('startedAtMs') || entry.containsKey('completedAtMs');
  if (hasExactEvidence) {
    final start = _intValue(entry['startedAtMs']);
    final end = _intValue(entry['completedAtMs']);
    if (_isValidInterval(start, end)) {
      return _TimingResult(_TimingKind.exact, _TraceInterval(start!, end!));
    }
    return const _TimingResult(_TimingKind.malformed);
  }

  final hasLegacyEvidence =
      entry.containsKey('timestampMs') || entry.containsKey('latencyMs');
  if (!hasLegacyEvidence) return const _TimingResult(_TimingKind.untimed);

  final end = _intValue(entry['timestampMs']);
  final latency = _intValue(entry['latencyMs']);
  if (end == null || latency == null || latency <= 0) {
    return const _TimingResult(_TimingKind.malformed);
  }
  final start = end - latency;
  if (!_isValidInterval(start, end)) {
    return const _TimingResult(_TimingKind.malformed);
  }
  return _TimingResult(_TimingKind.inferred, _TraceInterval(start, end));
}

bool _isValidInterval(int? start, int? end) =>
    start != null && end != null && start >= 0 && end > start;

int _observedMaxConcurrency(List<_TraceInterval> intervals) {
  final events =
      <_TimingEvent>[
        for (final interval in intervals) ...<_TimingEvent>[
          _TimingEvent(interval.startMs, 1),
          _TimingEvent(interval.endMs, -1),
        ],
      ]..sort((left, right) {
        final byTime = left.atMs.compareTo(right.atMs);
        if (byTime != 0) return byTime;
        // Half-open intervals: an end at T is processed before a start at T.
        return left.delta.compareTo(right.delta);
      });

  var active = 0;
  var maximum = 0;
  for (final event in events) {
    active += event.delta;
    if (active > maximum) maximum = active;
  }
  return maximum;
}

int? _intValue(Object? value) => value is int ? value : null;

int? _nonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _metadataMarksRetry(Map<Object?, Object?> metadata) {
  final legacyRetryAttempt = metadata['retryAttempt'];
  if (legacyRetryAttempt is int && legacyRetryAttempt > 1) return true;
  final zeroBasedAttempt = metadata['attempt'];
  if (zeroBasedAttempt is int && zeroBasedAttempt > 0) return true;
  if (_metadataMarksGatewayRetry(metadata)) return true;
  final transientRetryCount = metadata['transientRetryCount'];
  if (transientRetryCount is int && transientRetryCount > 0) return true;
  final outputRetryCount = metadata['outputRetryCount'];
  return outputRetryCount is int && outputRetryCount > 0;
}

bool _hasRetryMetadata(Map<Object?, Object?> metadata) =>
    metadata.containsKey('retryAttempt') ||
    metadata.containsKey('attempt') ||
    metadata.containsKey('gatewayRetryIndex') ||
    metadata.containsKey('transientRetryCount') ||
    metadata.containsKey('outputRetryCount');

bool _metadataMarksPhysicalDispatch(Map<Object?, Object?> metadata) {
  final endpointId = metadata['endpointId'];
  final endpointIndex = metadata['endpointIndex'];
  final gatewayRetryIndex = metadata['gatewayRetryIndex'];
  final wasFallback = metadata['wasFallback'];
  return endpointId is String &&
      endpointId.trim().isNotEmpty &&
      endpointIndex is int &&
      endpointIndex >= 0 &&
      gatewayRetryIndex is int &&
      gatewayRetryIndex >= 0 &&
      wasFallback is bool;
}

bool _metadataMarksGatewayRetry(Map<Object?, Object?> metadata) {
  final gatewayRetryIndex = metadata['gatewayRetryIndex'];
  return gatewayRetryIndex is int && gatewayRetryIndex > 0;
}

bool _metadataMarksFallback(Map<Object?, Object?> metadata) {
  final endpointIndex = metadata['endpointIndex'];
  return metadata['wasFallback'] == true &&
      endpointIndex is int &&
      endpointIndex > 0;
}

void _increment(Map<String, int> totals, String key, int amount) {
  totals.update(key, (value) => value + amount, ifAbsent: () => amount);
}

Map<String, int> _sortedImmutable(Map<String, int> source) {
  final keys = source.keys.toList(growable: false)..sort();
  return Map<String, int>.unmodifiable(<String, int>{
    for (final key in keys) key: source[key]!,
  });
}
