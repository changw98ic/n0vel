import 'dart:collection';
import 'dart:math';

import 'app_llm_canonical_hash.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';

final class AppLlmCacheEvaluationScope {
  const AppLlmCacheEvaluationScope({
    required this.executionId,
    required this.trialSlotId,
    required this.attemptNo,
    required this.runId,
    required this.generationBundleHash,
    required this.modelRouteHash,
    required this.decodingConfigHash,
    required this.outputSchemaHash,
    required this.promptReleaseHash,
  });

  final String executionId;
  final String trialSlotId;
  final int attemptNo;
  final String runId;
  final String generationBundleHash;
  final String modelRouteHash;
  final String decodingConfigHash;
  final String outputSchemaHash;
  final String promptReleaseHash;
}

final class AppLlmCacheReceipt {
  AppLlmCacheReceipt._(this.value, this.receiptHash);

  factory AppLlmCacheReceipt.fromJson(Map<String, Object?> encoded) {
    const keys = <String>{
      'schemaVersion',
      'requestHash',
      'responseHash',
      'disposition',
      'sourceExecutionId',
      'sourceTrialSlotId',
      'sourceAttemptNo',
      'sourceRunId',
      'currentExecutionId',
      'currentTrialSlotId',
      'currentAttemptNo',
      'currentRunId',
      'createdAtMs',
      'expiresAtMs',
      'cacheReleaseHash',
      'receiptHash',
    };
    if (encoded.keys.toSet().length != keys.length ||
        !encoded.keys.toSet().containsAll(keys) ||
        encoded['schemaVersion'] != 'app-llm-cache-receipt-v1' ||
        !<String>{'hit', 'miss'}.contains(encoded['disposition']) ||
        encoded['currentExecutionId'] is! String ||
        encoded['currentTrialSlotId'] is! String ||
        encoded['currentAttemptNo'] is! int ||
        encoded['currentRunId'] is! String ||
        encoded['createdAtMs'] is! int ||
        encoded['expiresAtMs'] is! int ||
        encoded['receiptHash'] is! String) {
      throw const FormatException('cache receipt shape is invalid');
    }
    final value = Map<String, Object?>.of(encoded)..remove('receiptHash');
    final expected = AppLlmCanonicalHash.domainHash(
      'app-llm-cache-receipt-v1',
      value,
    );
    final sourceIsPresent =
        value['sourceExecutionId'] is String &&
        value['sourceTrialSlotId'] is String &&
        value['sourceAttemptNo'] is int &&
        value['sourceRunId'] is String;
    final sameTrialBoundary =
        sourceIsPresent &&
        value['sourceExecutionId'] == value['currentExecutionId'] &&
        value['sourceTrialSlotId'] == value['currentTrialSlotId'] &&
        value['sourceRunId'] == value['currentRunId'];
    final exactMissSource =
        value['disposition'] != 'miss' ||
        (sameTrialBoundary &&
            value['sourceAttemptNo'] == value['currentAttemptNo']);
    if (encoded['receiptHash'] != expected ||
        value['cacheReleaseHash'] != AppLlmResponseCache.releaseHash ||
        (value['expiresAtMs']! as int) <= (value['createdAtMs']! as int) ||
        !sameTrialBoundary ||
        !exactMissSource) {
      throw const FormatException('cache receipt identity is invalid');
    }
    return AppLlmCacheReceipt._(
      Map<String, Object?>.unmodifiable(value),
      expected,
    );
  }

  final Map<String, Object?> value;
  final String receiptHash;

  bool get hit => value['disposition'] == 'hit';
  String get currentTrialSlotId => value['currentTrialSlotId']! as String;
  String? get sourceTrialSlotId => value['sourceTrialSlotId'] as String?;

  Map<String, Object?> toJson() => <String, Object?>{
    ...value,
    'receiptHash': receiptHash,
  };
}

class _CacheEntry {
  _CacheEntry({
    required this.result,
    required this.createdAtMs,
    required this.responseHash,
    required this.sourceScope,
  });

  final AppLlmChatResult result;
  final int createdAtMs;
  final String responseHash;
  final AppLlmCacheEvaluationScope? sourceScope;
}

/// A caching decorator for [AppLlmClient] that returns cached successful
/// responses for identical requests within a configurable TTL.
///
/// Ordinary requests are partitioned by a process-random credential token.
/// Formal evaluation requests instead require an exact non-secret experiment
/// identity and can only reuse a result inside the same trial slot and run.
/// Only successful responses are cached. Entries are evicted in FIFO order
/// once [maxEntries] is exceeded.
class AppLlmResponseCache implements AppLlmClient {
  AppLlmResponseCache({
    required AppLlmClient delegate,
    this.defaultTtlMs = 300000,
    this.maxEntries = 64,
  }) : _delegate = delegate;

  final AppLlmClient _delegate;
  final int defaultTtlMs;
  final int maxEntries;

  static final String releaseHash = AppLlmCanonicalHash.domainHash(
    'app-llm-response-cache-release-v3',
    const <String, Object?>{
      'formalKey':
          'execution-slot-run-stage-generation-bundle-model-route-decoding-schema-prompt-parser-input',
      'ordinaryCredentialPartition': 'process-random-non-persisted',
      'scope': 'same-trial-run-only',
      'receipt': 'same-trial-source-current-miss-exact',
    },
  );

  final LinkedHashMap<String, _CacheEntry> _entries =
      LinkedHashMap<String, _CacheEntry>();
  final List<AppLlmCacheReceipt> _receipts = <AppLlmCacheReceipt>[];
  final Map<String, String> _credentialPartitions = <String, String>{};
  final Random _secureRandom = Random.secure();
  AppLlmCacheEvaluationScope? _scope;

  int _hits = 0;
  int _misses = 0;

  /// Total cache hits since creation or last [clearAll].
  int get hits => _hits;

  /// Total cache misses since creation or last [clearAll].
  int get misses => _misses;

  /// Number of cached entries.
  int get size => _entries.length;

  void beginEvaluationScope(AppLlmCacheEvaluationScope scope) {
    if (_scope != null || scope.attemptNo <= 0) {
      throw StateError('cache evaluation scope is already active or invalid');
    }
    _scope = scope;
  }

  List<AppLlmCacheReceipt> finishEvaluationScope() {
    if (_scope == null) {
      throw StateError('cache evaluation scope is not active');
    }
    _scope = null;
    final result = List<AppLlmCacheReceipt>.unmodifiable(_receipts);
    _receipts.clear();
    return result;
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final scope = _scope;
    final key = _requestFingerprint(request, scope);
    final now = DateTime.now().millisecondsSinceEpoch;

    final cached = _entries[key];
    if (cached != null) {
      if (now < cached.createdAtMs + defaultTtlMs) {
        _hits++;
        _recordReceipt(
          requestHash: key,
          responseHash: cached.responseHash,
          disposition: 'hit',
          source: cached.sourceScope,
          current: scope,
          createdAtMs: cached.createdAtMs,
          expiresAtMs: cached.createdAtMs + defaultTtlMs,
        );
        return cached.result;
      }
      _entries.remove(key);
    }

    _misses++;
    // llm-call-site: boundary.cache.miss
    final result = await _delegate.chat(request);

    if (result.succeeded) {
      final responseHash = _responseHash(result);
      _entries[key] = _CacheEntry(
        result: result,
        createdAtMs: now,
        responseHash: responseHash,
        sourceScope: scope,
      );
      _recordReceipt(
        requestHash: key,
        responseHash: responseHash,
        disposition: 'miss',
        source: scope,
        current: scope,
        createdAtMs: now,
        expiresAtMs: now + defaultTtlMs,
      );
      _evictIfNeeded();
    }

    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    _misses++;
    // llm-call-site: boundary.cache.stream-miss
    return _delegate.chatStream(request);
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Clears all cache entries and resets hit/miss counters.
  void clearAll() {
    _entries.clear();
    _hits = 0;
    _misses = 0;
    _receipts.clear();
    _credentialPartitions.clear();
  }

  String _requestFingerprint(
    AppLlmChatRequest request,
    AppLlmCacheEvaluationScope? scope,
  ) {
    final messages = <Object?>[
      for (final message in request.messages)
        <String, Object?>{'role': message.role, 'content': message.content},
    ];
    if (scope == null) {
      final credentialPartition = _credentialPartitions.putIfAbsent(
        request.apiKey,
        _newCredentialPartition,
      );
      return AppLlmCanonicalHash.domainHash(
        'app-llm-response-cache-ordinary-request-v3',
        <String, Object?>{
          'baseUrl': request.baseUrl,
          'credentialPartition': credentialPartition,
          'model': request.model,
          'provider': request.provider.name,
          'maxTokens': request.effectiveMaxTokens,
          'messages': messages,
        },
      );
    }

    final identity = request.formalCacheIdentity;
    if (identity == null ||
        identity.stageId.trim().isEmpty ||
        identity.parserRelease.trim().isEmpty ||
        identity.generationBundleHash.trim().isEmpty ||
        identity.generationBundleHash != scope.generationBundleHash ||
        scope.executionId.trim().isEmpty ||
        scope.trialSlotId.trim().isEmpty ||
        scope.runId.trim().isEmpty ||
        scope.modelRouteHash.trim().isEmpty ||
        scope.decodingConfigHash.trim().isEmpty ||
        scope.outputSchemaHash.trim().isEmpty ||
        scope.promptReleaseHash.trim().isEmpty) {
      throw StateError(
        'formal evaluation cache request is missing exact frozen identity',
      );
    }
    final inputHash = AppLlmCanonicalHash.domainHash(
      'app-llm-formal-cache-input-v1',
      <String, Object?>{
        'provider': request.provider.name,
        'maxTokens': request.effectiveMaxTokens,
        'messages': messages,
      },
    );
    return AppLlmCanonicalHash.domainHash(
      'app-llm-response-cache-formal-request-v3',
      <String, Object?>{
        'executionId': scope.executionId,
        'trialSlotId': scope.trialSlotId,
        'runId': scope.runId,
        'stage': identity.stageId,
        'generationBundleHash': identity.generationBundleHash,
        'modelRoute': scope.modelRouteHash,
        'decodingConfigHash': scope.decodingConfigHash,
        'outputSchemaHash': scope.outputSchemaHash,
        'promptReleaseHash': scope.promptReleaseHash,
        'parserRelease': identity.parserRelease,
        'inputHash': inputHash,
      },
    );
  }

  String _newCredentialPartition() {
    final bytes = List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  void _recordReceipt({
    required String requestHash,
    required String responseHash,
    required String disposition,
    required AppLlmCacheEvaluationScope? source,
    required AppLlmCacheEvaluationScope? current,
    required int createdAtMs,
    required int expiresAtMs,
  }) {
    if (current == null) return;
    final value = <String, Object?>{
      'schemaVersion': 'app-llm-cache-receipt-v1',
      'requestHash': requestHash,
      'responseHash': responseHash,
      'disposition': disposition,
      'sourceExecutionId': source?.executionId,
      'sourceTrialSlotId': source?.trialSlotId,
      'sourceAttemptNo': source?.attemptNo,
      'sourceRunId': source?.runId,
      'currentExecutionId': current.executionId,
      'currentTrialSlotId': current.trialSlotId,
      'currentAttemptNo': current.attemptNo,
      'currentRunId': current.runId,
      'createdAtMs': createdAtMs,
      'expiresAtMs': expiresAtMs,
      'cacheReleaseHash': releaseHash,
    };
    _receipts.add(
      AppLlmCacheReceipt._(
        Map<String, Object?>.unmodifiable(value),
        AppLlmCanonicalHash.domainHash('app-llm-cache-receipt-v1', value),
      ),
    );
  }

  String _responseHash(AppLlmChatResult result) =>
      AppLlmCanonicalHash.domainHash(
        'app-llm-cache-response-v1',
        <String, Object?>{
          'text': result.text,
          'promptTokens': result.promptTokens,
          'completionTokens': result.completionTokens,
          'totalTokens': result.totalTokens,
          'succeeded': result.succeeded,
        },
      );
}
