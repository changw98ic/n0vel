import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../app/llm/app_llm_call_trace.dart';
import '../../../../app/llm/app_llm_client_contract.dart';
import '../../../../app/llm/app_llm_client_types.dart';
import '../../../../app/llm/app_llm_prompt_release.dart';
import '../../../../app/llm/app_llm_prompt_version.dart';
import '../../../../app/llm/app_llm_response_cache.dart';
import '../../../../app/state/story_generation_run_store.dart';
import '../story_prompt_registry.dart';
import '../../domain/evaluation/outcome_evaluation.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_metered_client.dart';
import 'agent_evaluation_production_authority.dart';
import 'agent_evaluation_production_authorities.dart';
import 'agent_evaluation_production_evidence.dart';
import 'agent_evaluation_cache_receipt_store.dart';
import 'agent_evaluation_runner.dart';
import 'agent_evaluation_typed_evidence.dart';

abstract final class AgentEvaluationProductionExecutorPolicy {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'eval-production-executor-release-v10',
    <String, Object?>{
      'entry':
          'story-generation-run-store-v2-sandbox-hydrated-authoritative-plus-fenced-short-handles-v2',
      'candidate':
          'release-v2-only-proof-plus-canonical-generation-receipt-rehydration-v1',
      'commit': 'author-accept-receipt-v1',
      'meter': 'attempt-scoped-exact-usage-v1',
      'trace': 'attempt-scoped-formal-trace-v1',
      'collector': 'runner-db-authority-receipt-v4-fixture-scene-bound',
      'route': 'canonical-provider-url-model-timeout-v1',
      'decoding': 'single-flight-non-streaming-call-site-policy-v1',
      'runtimeReuse': 'episode-isolation-trial-v1',
      'localFallback':
          'trace-plus-one-way-scene-brief-formal-latch-all-local-star-only-fail-closed-v3',
      'durableSandboxCheckpoint':
          'db-bound-candidate-provider-complete-prepared-evidence-plus-idempotent-author-accept-forward-recovery-v6',
      'sealVerifier':
          'pure-lib-pre-ui-signed-self-app-or-bound-aot-cache-release-fail-closed-v4',
      'sealTableProjection': <String>[
        'story_generation_runs',
        'story_generation_candidate_proofs',
        'story_generation_commit_receipts',
        'eval_production_prepared_results',
        'eval_production_executor_results',
        'version_entries',
      ],
      'sealLifecycleClaim': 'runtime-disposed-ack-is-not-snapshot-v1',
      'releaseHarnessBusyTimeoutOverride': 'none',
      'judgeReplay': 'canonical-candidate-json-persisted-v1',
    },
  );
}

enum AgentEvaluationProductionCheckpointBoundary {
  providerResponsesCompletedBeforePreparedCommit,
  preparedEvidencePersisted,
  authorAcceptanceCommitted,
  finalResultPersisted,
}

typedef AgentEvaluationProductionCheckpointObserver =
    Future<void> Function(AgentEvaluationProductionCheckpointBoundary boundary);

final class AgentEvaluationProductionRouteRelease {
  AgentEvaluationProductionRouteRelease({
    required this.model,
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.timeout,
    String? providerConfigHashWithoutSecrets,
    required this.providerApiRevision,
    required this.sdkAdapterReleaseHash,
  }) : providerConfigHashWithoutSecrets = AgentEvaluationHashes.domainHash(
         'eval-provider-config-without-secrets-v1',
         <String, Object?>{
           'model': model.trim(),
           'provider': provider.name,
           'baseUrl': canonicalAgentEvaluationBaseUrl(baseUrl),
           'timeout': timeout.toJson(),
         },
       ),
       modelRouteHash = AgentEvaluationHashes.domainHash(
         'eval-production-model-route-release-v1',
         <String, Object?>{
           'model': model.trim(),
           'provider': provider.name,
           'baseUrl': canonicalAgentEvaluationBaseUrl(baseUrl),
           'timeout': timeout.toJson(),
           'providerApiRevision': providerApiRevision.trim(),
           'sdkAdapterReleaseHash': sdkAdapterReleaseHash,
         },
       ) {
    for (final value in <String>[sdkAdapterReleaseHash, modelRouteHash]) {
      AgentEvaluationHashes.requireDigest(value, 'productionRouteDigest');
    }
    if (providerConfigHashWithoutSecrets != null &&
        providerConfigHashWithoutSecrets !=
            this.providerConfigHashWithoutSecrets) {
      throw ArgumentError(
        'declared provider config hash contradicts the actual frozen route',
      );
    }
    if (providerApiRevision.trim().isEmpty) {
      throw ArgumentError('providerApiRevision must not be empty');
    }
  }

  final String model;
  final AppLlmProvider provider;
  final String baseUrl;
  final String apiKey;
  final AppLlmTimeoutConfig timeout;
  final String providerConfigHashWithoutSecrets;
  final String providerApiRevision;
  final String sdkAdapterReleaseHash;
  final String modelRouteHash;

  static String providerContractHashForRoutes(
    Iterable<AgentEvaluationProductionRouteRelease> routes,
  ) {
    final frozen = routes.toList(growable: false);
    if (frozen.isEmpty) {
      throw ArgumentError('provider route set must not be empty');
    }
    if (frozen.length == 1) {
      return frozen.single.providerConfigHashWithoutSecrets;
    }
    final routeHashes = frozen.map((route) => route.modelRouteHash).toList()
      ..sort();
    if (routeHashes.toSet().length != routeHashes.length) {
      throw ArgumentError('provider route set must be unique');
    }
    return AgentEvaluationHashes.domainHash(
      'eval-provider-route-set-contract-v1',
      routeHashes,
    );
  }

  static bool routeMatchesManifestContract(
    AgentEvaluationProductionRouteRelease route,
    ExperimentManifest manifest,
  ) {
    if (!manifest.modelRouteHashes.contains(route.modelRouteHash)) {
      return false;
    }
    final expected = manifest.modelRouteHashes.length == 1
        ? route.providerConfigHashWithoutSecrets
        : AgentEvaluationHashes.domainHash(
            'eval-provider-route-set-contract-v1',
            (manifest.modelRouteHashes.toList()..sort()),
          );
    return manifest.providerConfigHashWithoutSecrets == expected;
  }
}

/// Frozen decoding mechanics that the production runtime can actually enforce.
/// Per-call token limits remain code-reviewed call-site policy, while release
/// evaluation fixes concurrency and disables streaming.
final class AgentEvaluationProductionDecodingRelease {
  factory AgentEvaluationProductionDecodingRelease.standard() {
    const maxConcurrentRequests = 1;
    const streamingAllowed = false;
    const tokenLimitPolicy = 'production-call-site-max-tokens-v1';
    return AgentEvaluationProductionDecodingRelease._(
      maxConcurrentRequests: maxConcurrentRequests,
      streamingAllowed: streamingAllowed,
      tokenLimitPolicy: tokenLimitPolicy,
      decodingConfigHash: AgentEvaluationHashes.domainHash(
        'eval-production-decoding-release-v1',
        const <String, Object?>{
          'maxConcurrentRequests': maxConcurrentRequests,
          'streamingAllowed': streamingAllowed,
          'tokenLimitPolicy': tokenLimitPolicy,
        },
      ),
    );
  }

  const AgentEvaluationProductionDecodingRelease._({
    required this.maxConcurrentRequests,
    required this.streamingAllowed,
    required this.tokenLimitPolicy,
    required this.decodingConfigHash,
  });

  final int maxConcurrentRequests;
  final bool streamingAllowed;
  final String tokenLimitPolicy;
  final String decodingConfigHash;
}

abstract interface class AgentEvaluationProductionQualityAuthority {
  String get evaluationBundleHash;

  Future<AgentEvaluationQualityEvaluation> evaluate({
    required AgentEvaluationTrialContext context,
    required String prose,
    required AgentEvaluationMeterSnapshot meterSnapshot,
  });
}

final class AgentEvaluationQualityEvaluation {
  AgentEvaluationQualityEvaluation({
    required this.evidence,
    required this.judgeCandidateJson,
    required Iterable<AgentEvaluationProviderCallEvidence> externalCalls,
  }) : externalCalls = List<AgentEvaluationProviderCallEvidence>.unmodifiable(
         externalCalls,
       );

  final AgentEvaluationQualityEvidence evidence;
  final String judgeCandidateJson;
  final List<AgentEvaluationProviderCallEvidence> externalCalls;
}

final class AgentEvaluationQualityException
    extends AgentEvaluationProductionEvidenceException {
  AgentEvaluationQualityException(
    super.message, {
    required Iterable<AgentEvaluationProviderCallEvidence> externalCalls,
    this.judgeInjectionSafetyReceipt,
  }) : externalCalls = List<AgentEvaluationProviderCallEvidence>.unmodifiable(
         externalCalls,
       );

  final List<AgentEvaluationProviderCallEvidence> externalCalls;
  final AgentEvaluationJudgeInjectionSafetyReceipt? judgeInjectionSafetyReceipt;
}

/// Release executors require a quality authority that can prove its judge,
/// safety verifier, and price table are members of the frozen manifest
/// authorities before any SUT provider request is dispatched.
abstract interface class AgentEvaluationProductionAuthorityMembership {
  void validateMembership({
    required AgentEvaluationTrialContext context,
    required String safetyVerifierReleaseHash,
    required String priceTableReleaseHash,
  });
}

/// A runtime owns the normal production stores for one isolated trial. Episode
/// steps reuse it; independent slots receive a fresh instance.
abstract interface class AgentEvaluationProductionRuntime {
  String get isolationTrialId;
  String get generationBundleHash;
  String get modelRouteHash;
  String get decodingConfigHash;
  String get databasePath;
  StoryPromptRegistry get promptRegistry;
  StoryGenerationRunStore get runStore;
  AgentEvaluationMeteredAppLlmClient get meter;
  AgentEvaluationAttemptTraceSink get traceSink;

  Future<void> prepare(AgentEvaluationTrialContext context);
  Future<void> dispose();
}

abstract interface class AgentEvaluationProductionRuntimeFactory {
  Future<AgentEvaluationProductionRuntime> open({
    required AgentEvaluationTrialContext context,
    required StoryPromptRegistry promptRegistry,
    required AgentEvaluationProductionRouteRelease route,
    required AgentEvaluationProductionDecodingRelease decoding,
    required AppLlmClient providerClient,
  });
}

/// Owns the complete, non-selectable trace interval for one formal attempt.
final class AgentEvaluationAttemptTraceSink
    implements AppLlmRequiredCallTraceSink {
  AgentEvaluationTrialContext? _context;
  List<AppLlmCallTraceEntry>? _entries;

  bool get isActive => _context != null;

  void beginAttempt(AgentEvaluationTrialContext context) {
    if (_context != null) {
      throw StateError('another formal trace attempt is already active');
    }
    _context = context;
    _entries = <AppLlmCallTraceEntry>[];
  }

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    final context = _context;
    final entries = _entries;
    if (context == null || entries == null) {
      throw StateError('LLM trace was emitted outside a formal attempt');
    }
    final metadata = entry.metadata;
    if (metadata['experimentId'] != context.manifest.experimentId ||
        metadata['executionId'] != context.lease.executionId ||
        metadata['runId'] != context.runId ||
        metadata['trialSlotId'] != context.lease.trialSlotId ||
        metadata['attemptNo'] != context.attemptNo ||
        metadata['cellId'] != context.lease.cellId ||
        metadata['leaseEpoch'] != context.lease.epoch ||
        metadata['leaseOwner'] != context.lease.owner ||
        metadata['isolationTrialId'] != context.isolationTrialId ||
        metadata['evaluationBundleHash'] !=
            'sha256:${context.manifest.evaluationBundleHash}') {
      throw StateError('LLM trace contradicts the active formal attempt');
    }
    entries.add(entry);
  }

  List<AppLlmCallTraceEntry> finishAttempt() {
    final entries = _entries;
    if (_context == null || entries == null || entries.isEmpty) {
      abortAttempt();
      throw StateError('formal trace attempt is incomplete');
    }
    final frozen = List<AppLlmCallTraceEntry>.unmodifiable(entries);
    _context = null;
    _entries = null;
    return frozen;
  }

  void abortAttempt() {
    _context = null;
    _entries = null;
  }
}

/// The only release-capable trial executor. It invokes the same run-store
/// entry and author-accept transaction used by the normal workbench.
final class AgentEvaluationProductionTrialExecutor {
  AgentEvaluationProductionTrialExecutor({
    required this.providerClient,
    required this.runtimeFactory,
    required this.routeByModelHash,
    required this.decodingByHash,
    required this.promptRegistryByBundleHash,
    required this.authorities,
    this.collector = const AgentEvaluationProductionEvidenceCollector(),
    this.checkpointObserver,
  });

  final AppLlmClient providerClient;
  final AgentEvaluationProductionRuntimeFactory runtimeFactory;
  final Map<String, AgentEvaluationProductionRouteRelease> routeByModelHash;
  final Map<String, AgentEvaluationProductionDecodingRelease> decodingByHash;
  final Map<String, StoryPromptRegistry> promptRegistryByBundleHash;
  final AgentEvaluationReleaseAuthoritySet authorities;
  AgentEvaluationProductionQualityAuthority get qualityAuthority =>
      authorities.quality;
  AgentEvaluationProductionSafetyVerifier get safetyVerifier =>
      authorities.safety;
  AgentEvaluationFrozenPriceTable get priceTable => authorities.priceTable;
  final AgentEvaluationProductionEvidenceCollector collector;
  final AgentEvaluationProductionCheckpointObserver? checkpointObserver;
  final Map<String, AgentEvaluationProductionRuntime> _runtimes = {};

  Future<AgentEvaluationTrialExecutionResult> execute(
    AgentEvaluationTrialContext context,
  ) async {
    final route = routeByModelHash[context.cell.modelRouteHash];
    final promptRegistry =
        promptRegistryByBundleHash[context.cell.generationBundleHash];
    final decoding = decodingByHash[context.cell.decodingConfigHash];
    final databasePath = context.sandboxDatabasePath;
    if (route == null ||
        promptRegistry == null ||
        decoding == null ||
        databasePath == null ||
        databasePath.trim().isEmpty) {
      throw const AgentEvaluationProductionEvidenceException(
        'frozen production route, prompt arm, and sandbox path are required',
      );
    }
    if (route.modelRouteHash != context.cell.modelRouteHash ||
        !AgentEvaluationProductionRouteRelease.routeMatchesManifestContract(
          route,
          context.manifest,
        ) ||
        route.providerApiRevision != context.manifest.providerApiRevision ||
        route.sdkAdapterReleaseHash != context.manifest.sdkAdapterReleaseHash ||
        _rawBundleHash(promptRegistry.generationBundle.bundleHash) !=
            context.cell.generationBundleHash ||
        decoding.decodingConfigHash != context.cell.decodingConfigHash ||
        qualityAuthority.evaluationBundleHash !=
            context.manifest.evaluationBundleHash ||
        priceTable.releaseHash != context.manifest.priceTableHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'production runtime does not match the frozen manifest cell',
      );
    }
    authorities.validateFor(context);
    final recovered = _recoverCommittedResult(context);
    if (recovered != null) {
      if (context.durableSandbox) {
        await _acknowledgeRecoveredDurableSealBoundary(context);
      }
      return recovered;
    }
    final runtimeKey = context.scenario.isolationMode == 'episode'
        ? '${context.isolationTrialId}:$databasePath'
        : '${context.isolationTrialId}:${context.runId}';
    final runtime = await _runtime(
      runtimeKey: runtimeKey,
      context: context,
      promptRegistry: promptRegistry,
      route: route,
      decoding: decoding,
    );
    _validateRuntime(runtime, context, databasePath);
    final cache = providerClient is AppLlmResponseCache
        ? providerClient as AppLlmResponseCache
        : null;
    var cacheScopeActive = false;
    AgentEvaluationMeterSnapshot? meterSnapshot;
    List<AppLlmCallTraceEntry>? traces;
    AgentEvaluationTrialExecutionResult? completedResult;
    var providerPhaseComplete = false;
    var providerResponsesComplete = false;
    List<AgentEvaluationProviderCallEvidence> completedExternalCalls =
        const <AgentEvaluationProviderCallEvidence>[];
    try {
      await runtime.prepare(context);
      final prepared = _recoverPreparedEvidence(context);
      if (prepared != null) {
        providerPhaseComplete = true;
        final result = await _finishPreparedEvidence(
          context: context,
          runtime: runtime,
          prepared: prepared,
        );
        completedResult = result;
        return result;
      }
      if (_existingProductionRunStatus(context) != null) {
        throw AgentEvaluationIndeterminateProviderCompletionException(
          'existing production run has no verified prepared checkpoint; '
          'provider replay is prohibited',
          usage: _conservativeIndeterminateUsage(
            context: context,
            route: route,
            priceTable: priceTable,
          ),
        );
      }
      if (cache != null) {
        cache.beginEvaluationScope(
          AppLlmCacheEvaluationScope(
            executionId: context.lease.executionId,
            trialSlotId: context.lease.trialSlotId,
            attemptNo: context.attemptNo,
            runId: context.runId,
            generationBundleHash: 'sha256:${context.cell.generationBundleHash}',
            modelRouteHash: context.cell.modelRouteHash,
            decodingConfigHash: context.cell.decodingConfigHash,
            outputSchemaHash: AgentEvaluationHashes.domainHash(
              'eval-cache-output-schema-set-v1',
              <Object?>[
                for (final registration in promptRegistry.registrations)
                  registration.release.outputSchemaSnapshot,
              ]..sort(),
            ),
            promptReleaseHash: AgentEvaluationHashes.domainHash(
              'eval-cache-prompt-release-set-v1',
              <Object?>[
                for (final registration in promptRegistry.registrations)
                  registration.release.contentHash,
              ]..sort(),
            ),
          ),
        );
        cacheScopeActive = true;
      }
      runtime.meter.beginAttempt(
        trialSlotId: context.lease.trialSlotId,
        attemptNo: context.attemptNo,
      );
      runtime.traceSink.beginAttempt(context);
      await promptRegistry.runAsync(() async {
        await runtime.runStore.ready;
        await runtime.runStore.runCurrentScene(
          rulesOverride: _scenarioCommand(context),
        );
      });
      final snapshot = runtime.runStore.snapshot;
      if (snapshot.runId != context.runId ||
          !snapshot.hasDurableCandidateProof ||
          snapshot.candidateProse.trim().isEmpty) {
        final failureDetail = snapshot.errorDetail.trim();
        throw AgentEvaluationProductionEvidenceException(
          'normal production pipeline did not produce the authoritative '
          'candidate: ${failureDetail.isEmpty ? snapshot.status.name : failureDetail}',
        );
      }
      traces = runtime.traceSink.finishAttempt();
      meterSnapshot = runtime.meter.finishAttempt();
      if (cacheScopeActive) {
        final store = AgentEvaluationCacheReceiptStore(db: context.database);
        for (final receipt in cache!.finishEvaluationScope()) {
          store.append(receipt);
        }
        cacheScopeActive = false;
      }
      final qualityEvaluation = await qualityAuthority.evaluate(
        context: context,
        prose: snapshot.candidateProse,
        meterSnapshot: meterSnapshot,
      );
      completedExternalCalls = qualityEvaluation.externalCalls;
      providerResponsesComplete = true;
      await checkpointObserver?.call(
        AgentEvaluationProductionCheckpointBoundary
            .providerResponsesCompletedBeforePreparedCommit,
      );
      final preparedEvidence = _persistPreparedEvidence(
        context: context,
        traces: traces,
        meterSnapshot: meterSnapshot,
        qualityEvaluation: qualityEvaluation,
      );
      await _persistDurableRecoveryCheckpoint(
        context: context,
        stage: AgentEvaluationDurableRecoveryStage.prepared,
        candidateHash: preparedEvidence.candidateHash,
      );
      providerPhaseComplete = true;
      await checkpointObserver?.call(
        AgentEvaluationProductionCheckpointBoundary.preparedEvidencePersisted,
      );
      final commit = await runtime.runStore.acceptCurrentCandidate(
        acceptIdempotencyKey: 'evaluation-accept:${context.runId}',
        scheduleOutboxDrain: false,
      );
      final committedReceipts = context.database.select(
        '''SELECT receipt_id FROM story_generation_commit_receipts
           WHERE receipt_id = ? AND run_id = ?''',
        <Object?>[commit.receipt.receiptId, context.runId],
      );
      if (committedReceipts.length != 1) {
        throw const AgentEvaluationProductionEvidenceException(
          'author acceptance escaped the active trial sandbox',
        );
      }
      await _persistDurableRecoveryCheckpoint(
        context: context,
        stage: AgentEvaluationDurableRecoveryStage.accepted,
        candidateHash: preparedEvidence.candidateHash,
      );
      await _drainAcceptedReceipt(
        context: context,
        runtime: runtime,
        receiptId: commit.receipt.receiptId,
      );
      await _persistDurableRecoveryCheckpoint(
        context: context,
        stage: AgentEvaluationDurableRecoveryStage.outboxCompleted,
        candidateHash: preparedEvidence.candidateHash,
      );
      await checkpointObserver?.call(
        AgentEvaluationProductionCheckpointBoundary.authorAcceptanceCommitted,
      );
      final result = _collectPreparedEvidence(context, preparedEvidence);
      _persistRecoveryResult(context, result);
      await _persistDurableRecoveryCheckpoint(
        context: context,
        stage: AgentEvaluationDurableRecoveryStage.finalPersisted,
        candidateHash: preparedEvidence.candidateHash,
      );
      await checkpointObserver?.call(
        AgentEvaluationProductionCheckpointBoundary.finalResultPersisted,
      );
      final persistedBoundary = context.database.select(
        '''SELECT
             (SELECT COUNT(*) FROM main.story_generation_commit_receipts) AS receipts,
             (SELECT COUNT(*) FROM main.story_generation_candidate_proofs) AS proofs,
             (SELECT COUNT(*) FROM main.eval_production_prepared_results) AS prepared,
             (SELECT COUNT(*) FROM main.eval_production_executor_results) AS results''',
      ).single;
      if ((persistedBoundary['receipts'] as int) < 1 ||
          (persistedBoundary['proofs'] as int) < 1 ||
          (persistedBoundary['prepared'] as int) < 1 ||
          (persistedBoundary['results'] as int) < 1) {
        throw const AgentEvaluationProductionEvidenceException(
          'production evidence disappeared before runtime disposal',
        );
      }
      final tempEvidenceTables = context.database.select(
        '''SELECT name FROM sqlite_temp_master
           WHERE type = 'table' AND name IN (
             'story_generation_commit_receipts',
             'story_generation_candidate_proofs',
             'eval_production_prepared_results',
             'eval_production_executor_results',
             'version_entries'
           )''',
      );
      if (tempEvidenceTables.isNotEmpty) {
        throw AgentEvaluationProductionEvidenceException(
          'production evidence used TEMP shadow tables: '
          '${tempEvidenceTables.map((row) => row['name']).join(',')}',
        );
      }
      final databases = context.database.select('PRAGMA database_list');
      final mainDatabases = databases.where((row) => row['name'] == 'main');
      final attachedDatabases = databases.where(
        (row) => row['name'] != 'main' && row['name'] != 'temp',
      );
      if (mainDatabases.length != 1 || attachedDatabases.isNotEmpty) {
        throw const AgentEvaluationProductionEvidenceException(
          'production evidence connection attached another database',
        );
      }
      completedResult = result;
      return result;
    } catch (error, stackTrace) {
      if (cacheScopeActive) {
        final store = AgentEvaluationCacheReceiptStore(db: context.database);
        for (final receipt in cache!.finishEvaluationScope()) {
          store.append(receipt);
        }
        cacheScopeActive = false;
      }
      AgentEvaluationAttemptUsage? failedUsage;
      AgentEvaluationMeterSnapshot? failedSnapshot = meterSnapshot;
      if (runtime.meter.isActive) {
        try {
          failedSnapshot = runtime.meter.finishAttempt();
        } on Object {
          // An unmetered or partially metered provider failure cannot become
          // release evidence; the original failure remains authoritative.
        }
      }
      if (!providerPhaseComplete && failedSnapshot != null) {
        failedUsage = _frozenUsage(
          context: context,
          meterSnapshot: failedSnapshot,
          priceTable: priceTable,
          externalCalls: error is AgentEvaluationQualityException
              ? error.externalCalls
              : completedExternalCalls,
        );
      }
      if (runtime.traceSink.isActive) runtime.traceSink.abortAttempt();
      if (runtime.meter.isActive) runtime.meter.abortAttempt();
      if (failedUsage != null) {
        final providerResponseObserved =
            providerResponsesComplete ||
            error is AgentEvaluationQualityException ||
            (failedSnapshot?.calls.any((call) => call.succeeded) ?? false);
        if (providerResponseObserved) {
          throw AgentEvaluationIndeterminateProviderCompletionException(
            'provider responses completed before durable prepared evidence; '
            'provider replay is prohibited',
            usage: failedUsage,
            judgeInjectionSafetyReceipt:
                error is AgentEvaluationQualityException
                ? error.judgeInjectionSafetyReceipt
                : null,
          );
        }
        throw AgentEvaluationTransportException(
          'production provider returned a failed metered attempt',
          usage: failedUsage,
          judgeInjectionSafetyReceipt: error is AgentEvaluationQualityException
              ? error.judgeInjectionSafetyReceipt
              : null,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (context.scenario.isolationMode != 'episode' ||
          context.durableSandbox) {
        _runtimes.remove(runtimeKey);
        await runtime.dispose();
      }
      if (completedResult != null && context.durableSandbox) {
        await _stageDurableSeal(context);
      }
    }
  }

  Future<void> _stageDurableSeal(AgentEvaluationTrialContext context) async {
    final acknowledgeRuntimeDisposed =
        context.acknowledgeDurableSandboxRuntimeDisposed;
    if (acknowledgeRuntimeDisposed == null) {
      throw const AgentEvaluationProductionEvidenceException(
        'durable production executor has no Runner-owned seal boundary',
      );
    }
    final acknowledgedPath = await acknowledgeRuntimeDisposed(context.database);
    final expectedPath = context.sandboxDatabasePath;
    final ownerCount = context.sandboxConnectionOwnerCount?.call();
    final databases = context.database.select('PRAGMA database_list');
    final main = databases.where((row) => row['name'] == 'main').toList();
    final attached = databases.where(
      (row) => row['name'] != 'main' && row['name'] != 'temp',
    );
    if (expectedPath == null ||
        !context.database.autocommit ||
        main.length != 1 ||
        attached.isNotEmpty ||
        File(main.single['file'] as String).resolveSymbolicLinksSync() !=
            File(expectedPath).resolveSymbolicLinksSync() ||
        File(acknowledgedPath).resolveSymbolicLinksSync() !=
            File(expectedPath).resolveSymbolicLinksSync() ||
        ownerCount != 1) {
      throw const AgentEvaluationProductionEvidenceException(
        'durable runtime did not release every sandbox connection owner',
      );
    }
  }

  Future<void> _acknowledgeRecoveredDurableSealBoundary(
    AgentEvaluationTrialContext context,
  ) async {
    final databasePath = context.sandboxDatabasePath;
    if (databasePath == null ||
        _runtimes.values.any(
          (runtime) => runtime.databasePath == databasePath,
        )) {
      throw const AgentEvaluationProductionEvidenceException(
        'recovered durable result still has an active production runtime',
      );
    }
    await _stageDurableSeal(context);
  }

  Future<AgentEvaluationProductionRuntime> _runtime({
    required String runtimeKey,
    required AgentEvaluationTrialContext context,
    required StoryPromptRegistry promptRegistry,
    required AgentEvaluationProductionRouteRelease route,
    required AgentEvaluationProductionDecodingRelease decoding,
  }) async {
    final existing = _runtimes[runtimeKey];
    if (existing != null) return existing;
    final created = await runtimeFactory.open(
      context: context,
      promptRegistry: promptRegistry,
      route: route,
      decoding: decoding,
      providerClient: providerClient,
    );
    _runtimes[runtimeKey] = created;
    return created;
  }

  void _validateRuntime(
    AgentEvaluationProductionRuntime runtime,
    AgentEvaluationTrialContext context,
    String databasePath,
  ) {
    if (runtime.isolationTrialId != context.isolationTrialId ||
        runtime.generationBundleHash != context.cell.generationBundleHash ||
        runtime.modelRouteHash != context.cell.modelRouteHash ||
        runtime.decodingConfigHash != context.cell.decodingConfigHash ||
        runtime.databasePath != databasePath ||
        _rawBundleHash(runtime.promptRegistry.generationBundle.bundleHash) !=
            context.cell.generationBundleHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'production runtime isolation identity collision',
      );
    }
  }

  Future<void> dispose() async {
    final runtimes = _runtimes.values.toSet().toList(growable: false);
    _runtimes.clear();
    for (final runtime in runtimes) {
      await runtime.dispose();
    }
  }

  AgentEvaluationTrialExecutionResult? _recoverCommittedResult(
    AgentEvaluationTrialContext context,
  ) {
    final rows = context.database.select(
      '''SELECT result_json, result_hash, executor_release_hash
         FROM eval_production_executor_results WHERE run_id = ?''',
      <Object?>[context.runId],
    );
    if (rows.isEmpty) return null;
    final runs = context.database.select(
      'SELECT status FROM story_generation_runs WHERE run_id = ?',
      <Object?>[context.runId],
    );
    if (rows.length != 1 ||
        runs.length != 1 ||
        runs.single['status'] != 'committed' ||
        rows.single['executor_release_hash'] !=
            AgentEvaluationProductionExecutorPolicy.releaseHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'production executor recovery result contradicts the committed run',
      );
    }
    final encoded = rows.single['result_json'];
    if (encoded is! String) {
      throw const AgentEvaluationProductionEvidenceException(
        'production executor recovery result is malformed',
      );
    }
    final decoded = _jsonObject(encoded);
    final expectedHash = AgentEvaluationHashes.domainHash(
      'eval-production-executor-result-v1',
      decoded,
    );
    if (rows.single['result_hash'] != expectedHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'production executor recovery result hash is invalid',
      );
    }
    final result = _resultFromJson(decoded);
    AgentEvaluationProductionDatabaseAuthority.verify(
      context: context,
      result: result,
    );
    return result;
  }

  String? _existingProductionRunStatus(AgentEvaluationTrialContext context) {
    final rows = context.database.select(
      'SELECT status FROM story_generation_runs WHERE run_id = ?',
      <Object?>[context.runId],
    );
    if (rows.isEmpty) return null;
    if (rows.length != 1 || rows.single['status'] is! String) {
      throw const AgentEvaluationProductionEvidenceException(
        'production run identity is ambiguous',
      );
    }
    return rows.single['status'] as String;
  }

  _PreparedProductionEvidence _persistPreparedEvidence({
    required AgentEvaluationTrialContext context,
    required List<AppLlmCallTraceEntry> traces,
    required AgentEvaluationMeterSnapshot meterSnapshot,
    required AgentEvaluationQualityEvaluation qualityEvaluation,
  }) {
    final candidates = context.database.select(
      '''SELECT run.status, run.current_candidate_revision,
           proof.candidate_hash, payload.final_prose
         FROM story_generation_runs run
         JOIN story_generation_candidate_proofs proof
           ON proof.run_id = run.run_id
          AND proof.candidate_revision = run.current_candidate_revision
         JOIN story_generation_candidate_payloads payload
           ON payload.run_id = proof.run_id
          AND payload.candidate_revision = proof.candidate_revision
         WHERE run.run_id = ?''',
      <Object?>[context.runId],
    );
    if (candidates.length != 1 ||
        candidates.single['status'] != 'candidateReady') {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared evidence does not bind the active candidate attempt',
      );
    }
    final candidateHash = _rawDigestValue(
      candidates.single['candidate_hash'],
      'candidateHash',
    );
    final candidateRevision = candidates.single['current_candidate_revision'];
    if (candidateRevision is! int || candidateRevision < 0) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared candidate revision is malformed',
      );
    }
    final prose = candidates.single['final_prose'];
    if (prose is! String) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared candidate prose is malformed',
      );
    }
    _requireReplayableJudgeCandidateJson(
      qualityEvaluation.judgeCandidateJson,
      prose,
    );
    final prepared = _PreparedProductionEvidence(
      executionId: context.lease.executionId,
      trialSlotId: context.lease.trialSlotId,
      attemptNo: context.attemptNo,
      runId: context.runId,
      originalLeaseEpoch: context.lease.epoch,
      originalLeaseOwner: context.lease.owner,
      cellId: context.lease.cellId,
      manifestHash: context.manifest.manifestHash,
      generationBundleHash: context.cell.generationBundleHash,
      modelRouteHash: context.cell.modelRouteHash,
      decodingConfigHash: context.cell.decodingConfigHash,
      candidateRevision: candidateRevision,
      candidateHash: candidateHash,
      traces: traces,
      meterSnapshot: meterSnapshot,
      qualityEvidence: qualityEvaluation.evidence,
      judgeCandidateJson: qualityEvaluation.judgeCandidateJson,
      externalProviderCalls: qualityEvaluation.externalCalls,
    );
    final value = prepared.toJson();
    final encoded = AgentEvaluationHashes.canonicalJson(value);
    final preparedHash = AgentEvaluationHashes.domainHash(
      'eval-production-prepared-evidence-v1',
      value,
    );
    final existing = context.database.select(
      '''SELECT prepared_hash, executor_release_hash
         FROM eval_production_prepared_results WHERE run_id = ?''',
      <Object?>[context.runId],
    );
    if (existing.isNotEmpty) {
      if (existing.length == 1 &&
          existing.single['prepared_hash'] == preparedHash &&
          existing.single['executor_release_hash'] ==
              AgentEvaluationProductionExecutorPolicy.releaseHash) {
        return prepared;
      }
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production evidence already differs',
      );
    }
    if (!context.database.autocommit) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared evidence cannot join an unrelated open transaction',
      );
    }
    context.database.execute('BEGIN IMMEDIATE');
    try {
      context.database.execute(
        '''INSERT INTO eval_production_prepared_results (
             run_id, execution_id, trial_slot_id, attempt_no,
             original_lease_epoch, original_lease_owner, cell_id,
             manifest_hash, candidate_revision, candidate_hash,
             prepared_json, prepared_hash,
             executor_release_hash, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          context.runId,
          context.lease.executionId,
          context.lease.trialSlotId,
          context.attemptNo,
          context.lease.epoch,
          context.lease.owner,
          context.lease.cellId,
          context.manifest.manifestHash,
          candidateRevision,
          candidateHash,
          encoded,
          preparedHash,
          AgentEvaluationProductionExecutorPolicy.releaseHash,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      context.database.execute('COMMIT');
    } on Object {
      context.database.execute('ROLLBACK');
      rethrow;
    }
    if (!context.database.autocommit) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared evidence was not durably committed',
      );
    }
    return prepared;
  }

  _PreparedProductionEvidence? _recoverPreparedEvidence(
    AgentEvaluationTrialContext context,
  ) {
    final rows = context.database.select(
      '''SELECT execution_id, trial_slot_id, attempt_no,
           original_lease_epoch, original_lease_owner, cell_id, manifest_hash,
           candidate_revision, candidate_hash, prepared_json, prepared_hash,
           executor_release_hash
         FROM eval_production_prepared_results WHERE run_id = ?''',
      <Object?>[context.runId],
    );
    if (rows.isEmpty) return null;
    if (rows.length != 1 ||
        rows.single['execution_id'] != context.lease.executionId ||
        rows.single['trial_slot_id'] != context.lease.trialSlotId ||
        rows.single['attempt_no'] != context.attemptNo ||
        rows.single['manifest_hash'] != context.manifest.manifestHash ||
        rows.single['executor_release_hash'] !=
            AgentEvaluationProductionExecutorPolicy.releaseHash ||
        rows.single['prepared_json'] is! String) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production checkpoint contradicts the recovery attempt',
      );
    }
    final decoded = _jsonObject(rows.single['prepared_json'] as String);
    final expectedHash = AgentEvaluationHashes.domainHash(
      'eval-production-prepared-evidence-v1',
      decoded,
    );
    if (rows.single['prepared_hash'] != expectedHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production checkpoint hash is invalid',
      );
    }
    final prepared = _PreparedProductionEvidence.fromJson(decoded);
    final candidates = context.database.select(
      '''SELECT run.status, run.current_candidate_revision,
           proof.candidate_hash, payload.final_prose
         FROM story_generation_runs run
         JOIN story_generation_candidate_proofs proof
           ON proof.run_id = run.run_id
          AND proof.candidate_revision = run.current_candidate_revision
         JOIN story_generation_candidate_payloads payload
           ON payload.run_id = proof.run_id
          AND payload.candidate_revision = proof.candidate_revision
         WHERE run.run_id = ?''',
      <Object?>[context.runId],
    );
    if (!prepared.matches(context) ||
        rows.single['original_lease_epoch'] != prepared.originalLeaseEpoch ||
        rows.single['original_lease_owner'] != prepared.originalLeaseOwner ||
        rows.single['cell_id'] != prepared.cellId ||
        rows.single['candidate_revision'] != prepared.candidateRevision ||
        candidates.length != 1 ||
        !const <String>{
          'candidateReady',
          'committed',
        }.contains(candidates.single['status']) ||
        _rawDigestValue(candidates.single['candidate_hash'], 'candidateHash') !=
            prepared.candidateHash ||
        candidates.single['current_candidate_revision'] !=
            prepared.candidateRevision ||
        rows.single['candidate_hash'] != prepared.candidateHash ||
        candidates.single['final_prose'] is! String) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production checkpoint no longer matches its candidate',
      );
    }
    _requireReplayableJudgeCandidateJson(
      prepared.judgeCandidateJson,
      candidates.single['final_prose'] as String,
    );
    return prepared;
  }

  Future<AgentEvaluationTrialExecutionResult> _finishPreparedEvidence({
    required AgentEvaluationTrialContext context,
    required AgentEvaluationProductionRuntime runtime,
    required _PreparedProductionEvidence prepared,
  }) async {
    final status = _existingProductionRunStatus(context);
    if (status != 'candidateReady' && status != 'committed') {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production run is not at a recoverable commit boundary',
      );
    }
    final commit = await runtime.runStore.acceptCurrentCandidate(
      acceptIdempotencyKey: 'evaluation-accept:${context.runId}',
      scheduleOutboxDrain: false,
    );
    final committedReceipts = context.database.select(
      '''SELECT receipt_id FROM story_generation_commit_receipts
         WHERE receipt_id = ? AND run_id = ?''',
      <Object?>[commit.receipt.receiptId, context.runId],
    );
    if (committedReceipts.length != 1) {
      throw const AgentEvaluationProductionEvidenceException(
        'recovered author acceptance escaped the active trial sandbox',
      );
    }
    await _persistDurableRecoveryCheckpoint(
      context: context,
      stage: AgentEvaluationDurableRecoveryStage.accepted,
      candidateHash: prepared.candidateHash,
    );
    await _drainAcceptedReceipt(
      context: context,
      runtime: runtime,
      receiptId: commit.receipt.receiptId,
    );
    await _persistDurableRecoveryCheckpoint(
      context: context,
      stage: AgentEvaluationDurableRecoveryStage.outboxCompleted,
      candidateHash: prepared.candidateHash,
    );
    await checkpointObserver?.call(
      AgentEvaluationProductionCheckpointBoundary.authorAcceptanceCommitted,
    );
    final result = _collectPreparedEvidence(context, prepared);
    _persistRecoveryResult(context, result);
    await _persistDurableRecoveryCheckpoint(
      context: context,
      stage: AgentEvaluationDurableRecoveryStage.finalPersisted,
      candidateHash: prepared.candidateHash,
    );
    await checkpointObserver?.call(
      AgentEvaluationProductionCheckpointBoundary.finalResultPersisted,
    );
    return result;
  }

  Future<void> _persistDurableRecoveryCheckpoint({
    required AgentEvaluationTrialContext context,
    required AgentEvaluationDurableRecoveryStage stage,
    required String candidateHash,
  }) async {
    final persist = context.persistDurableSandboxRecoveryCheckpoint;
    if (persist == null) return;
    await persist(stage: stage, candidateHash: candidateHash);
  }

  Future<void> _drainAcceptedReceipt({
    required AgentEvaluationTrialContext context,
    required AgentEvaluationProductionRuntime runtime,
    required String receiptId,
  }) => runtime.runStore.drainReceiptOutboxUntilCompleted(
    receiptId: receiptId,
    deadlineAtMs: context.deadlineAtMs ?? context.lease.expiresAtMs,
    leaseOwner:
        'agent-evaluation:${context.lease.trialSlotId}:'
        '${context.attemptNo}:${context.lease.epoch}',
  );

  AgentEvaluationTrialExecutionResult _collectPreparedEvidence(
    AgentEvaluationTrialContext context,
    _PreparedProductionEvidence prepared,
  ) => collector.collect(
    context: context,
    storyRunId: context.runId,
    traces: prepared.traces,
    meterSnapshot: prepared.meterSnapshot,
    priceTable: priceTable,
    qualityEvidence: prepared.qualityEvidence,
    judgeCandidateJson: prepared.judgeCandidateJson,
    externalProviderCalls: prepared.externalProviderCalls,
    safetyVerifier: safetyVerifier,
    executorReleaseHash: AgentEvaluationProductionExecutorPolicy.releaseHash,
  );

  void _persistRecoveryResult(
    AgentEvaluationTrialContext context,
    AgentEvaluationTrialExecutionResult result,
  ) {
    final value = _resultToJson(result);
    final encoded = AgentEvaluationHashes.canonicalJson(value);
    final resultHash = AgentEvaluationHashes.domainHash(
      'eval-production-executor-result-v1',
      value,
    );
    final existing = context.database.select(
      '''SELECT result_hash, executor_release_hash
         FROM eval_production_executor_results WHERE run_id = ?''',
      <Object?>[context.runId],
    );
    if (existing.isNotEmpty) {
      if (existing.length == 1 &&
          existing.single['result_hash'] == resultHash &&
          existing.single['executor_release_hash'] ==
              AgentEvaluationProductionExecutorPolicy.releaseHash) {
        return;
      }
      throw const AgentEvaluationProductionEvidenceException(
        'production executor recovery result already differs',
      );
    }
    context.database.execute(
      '''INSERT INTO eval_production_executor_results (
           run_id, result_json, result_hash, executor_release_hash,
           created_at_ms
         ) VALUES (?, ?, ?, ?, ?)''',
      <Object?>[
        context.runId,
        encoded,
        resultHash,
        AgentEvaluationProductionExecutorPolicy.releaseHash,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }
}

final class _PreparedProductionEvidence {
  _PreparedProductionEvidence({
    required this.executionId,
    required this.trialSlotId,
    required this.attemptNo,
    required this.runId,
    required this.originalLeaseEpoch,
    required this.originalLeaseOwner,
    required this.cellId,
    required this.manifestHash,
    required this.generationBundleHash,
    required this.modelRouteHash,
    required this.decodingConfigHash,
    required this.candidateRevision,
    required this.candidateHash,
    required List<AppLlmCallTraceEntry> traces,
    required this.meterSnapshot,
    required this.qualityEvidence,
    required this.judgeCandidateJson,
    required List<AgentEvaluationProviderCallEvidence> externalProviderCalls,
  }) : traces = List<AppLlmCallTraceEntry>.unmodifiable(traces),
       externalProviderCalls =
           List<AgentEvaluationProviderCallEvidence>.unmodifiable(
             externalProviderCalls,
           ) {
    for (final entry in <(String, String)>[
      (manifestHash, 'manifestHash'),
      (generationBundleHash, 'generationBundleHash'),
      (modelRouteHash, 'modelRouteHash'),
      (decodingConfigHash, 'decodingConfigHash'),
      (candidateHash, 'candidateHash'),
    ]) {
      AgentEvaluationHashes.requireDigest(entry.$1, entry.$2);
    }
    if (executionId.trim().isEmpty ||
        trialSlotId.trim().isEmpty ||
        attemptNo <= 0 ||
        runId.trim().isEmpty ||
        originalLeaseEpoch <= 0 ||
        originalLeaseOwner.trim().isEmpty ||
        cellId.trim().isEmpty ||
        candidateRevision < 0 ||
        traces.isEmpty ||
        meterSnapshot.calls.isEmpty) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production evidence identity is incomplete',
      );
    }
  }

  factory _PreparedProductionEvidence.fromJson(Map<String, Object?> value) {
    const keys = <String>{
      'schemaVersion',
      'executionId',
      'trialSlotId',
      'attemptNo',
      'runId',
      'originalLeaseEpoch',
      'originalLeaseOwner',
      'cellId',
      'manifestHash',
      'generationBundleHash',
      'modelRouteHash',
      'decodingConfigHash',
      'candidateRevision',
      'candidateHash',
      'traces',
      'meterSnapshot',
      'qualityEvidence',
      'judgeCandidateJson',
      'externalProviderCalls',
      'executorReleaseHash',
    };
    if (value.keys.toSet().length != keys.length ||
        !value.keys.toSet().containsAll(keys) ||
        value['schemaVersion'] != 'eval-production-prepared-evidence-v1' ||
        value['executorReleaseHash'] !=
            AgentEvaluationProductionExecutorPolicy.releaseHash ||
        value['traces'] is! List<Object?> ||
        value['externalProviderCalls'] is! List<Object?>) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production evidence JSON is malformed',
      );
    }
    final meter = _object(value['meterSnapshot'], 'meterSnapshot');
    final encodedCalls = meter['calls'];
    if (meter.keys.toSet().difference(const <String>{
          'trialSlotId',
          'attemptNo',
          'modelRouteHash',
          'model',
          'calls',
        }).isNotEmpty ||
        meter.length != 5 ||
        encodedCalls is! List<Object?>) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared meter snapshot is malformed',
      );
    }
    final prepared = _PreparedProductionEvidence(
      executionId: value['executionId'] as String,
      trialSlotId: value['trialSlotId'] as String,
      attemptNo: value['attemptNo'] as int,
      runId: value['runId'] as String,
      originalLeaseEpoch: value['originalLeaseEpoch'] as int,
      originalLeaseOwner: value['originalLeaseOwner'] as String,
      cellId: value['cellId'] as String,
      manifestHash: value['manifestHash'] as String,
      generationBundleHash: value['generationBundleHash'] as String,
      modelRouteHash: value['modelRouteHash'] as String,
      decodingConfigHash: value['decodingConfigHash'] as String,
      candidateRevision: value['candidateRevision'] as int,
      candidateHash: value['candidateHash'] as String,
      traces: <AppLlmCallTraceEntry>[
        for (final item in value['traces']! as List<Object?>)
          _traceFromJson(_object(item, 'trace')),
      ],
      meterSnapshot: AgentEvaluationMeterSnapshot.rehydrate(
        trialSlotId: meter['trialSlotId'] as String,
        attemptNo: meter['attemptNo'] as int,
        modelRouteHash: meter['modelRouteHash'] as String,
        model: meter['model'] as String,
        calls: <AgentEvaluationProviderCallEvidence>[
          for (final item in encodedCalls)
            _providerCallFromJson(_object(item, 'meterCall')),
        ],
      ),
      qualityEvidence: _qualityEvidenceFromJson(
        _object(value['qualityEvidence'], 'qualityEvidence'),
      ),
      judgeCandidateJson: value['judgeCandidateJson'] as String,
      externalProviderCalls: <AgentEvaluationProviderCallEvidence>[
        for (final item in value['externalProviderCalls']! as List<Object?>)
          _providerCallFromJson(_object(item, 'externalProviderCall')),
      ],
    );
    if (AgentEvaluationHashes.canonicalJson(prepared.toJson()) !=
        AgentEvaluationHashes.canonicalJson(value)) {
      throw const AgentEvaluationProductionEvidenceException(
        'prepared production evidence is not canonical',
      );
    }
    return prepared;
  }

  final String executionId;
  final String trialSlotId;
  final int attemptNo;
  final String runId;
  final int originalLeaseEpoch;
  final String originalLeaseOwner;
  final String cellId;
  final String manifestHash;
  final String generationBundleHash;
  final String modelRouteHash;
  final String decodingConfigHash;
  final int candidateRevision;
  final String candidateHash;
  final List<AppLlmCallTraceEntry> traces;
  final AgentEvaluationMeterSnapshot meterSnapshot;
  final AgentEvaluationQualityEvidence qualityEvidence;
  final String judgeCandidateJson;
  final List<AgentEvaluationProviderCallEvidence> externalProviderCalls;

  bool matches(AgentEvaluationTrialContext context) =>
      executionId == context.lease.executionId &&
      trialSlotId == context.lease.trialSlotId &&
      attemptNo == context.attemptNo &&
      runId == context.runId &&
      cellId == context.lease.cellId &&
      manifestHash == context.manifest.manifestHash &&
      generationBundleHash == context.cell.generationBundleHash &&
      modelRouteHash == context.cell.modelRouteHash &&
      decodingConfigHash == context.cell.decodingConfigHash &&
      candidateRevision >= 0 &&
      meterSnapshot.trialSlotId == trialSlotId &&
      meterSnapshot.attemptNo == attemptNo &&
      meterSnapshot.modelRouteHash == modelRouteHash;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 'eval-production-prepared-evidence-v1',
    'executionId': executionId,
    'trialSlotId': trialSlotId,
    'attemptNo': attemptNo,
    'runId': runId,
    'originalLeaseEpoch': originalLeaseEpoch,
    'originalLeaseOwner': originalLeaseOwner,
    'cellId': cellId,
    'manifestHash': manifestHash,
    'generationBundleHash': generationBundleHash,
    'modelRouteHash': modelRouteHash,
    'decodingConfigHash': decodingConfigHash,
    'candidateRevision': candidateRevision,
    'candidateHash': candidateHash,
    'traces': <Object?>[for (final trace in traces) trace.toJson()],
    'meterSnapshot': <String, Object?>{
      'trialSlotId': meterSnapshot.trialSlotId,
      'attemptNo': meterSnapshot.attemptNo,
      'modelRouteHash': meterSnapshot.modelRouteHash,
      'model': meterSnapshot.model,
      'calls': <Object?>[
        for (final call in meterSnapshot.calls) _providerCallToJson(call),
      ],
    },
    'qualityEvidence': _qualityEvidenceToJson(qualityEvidence),
    'judgeCandidateJson': judgeCandidateJson,
    'externalProviderCalls': <Object?>[
      for (final call in externalProviderCalls) _providerCallToJson(call),
    ],
    'executorReleaseHash': AgentEvaluationProductionExecutorPolicy.releaseHash,
  };
}

String _scenarioCommand(AgentEvaluationTrialContext context) {
  final fixture = context.scenario.inputFixture;
  final command = fixture['prompt'] ?? fixture['rules'] ?? fixture['scene'];
  if (command == null || command.toString().trim().isEmpty) {
    throw const AgentEvaluationProductionEvidenceException(
      'production scenario fixture omitted its scene command',
    );
  }
  final baseCommand = command.toString().trim();
  if (context.scenario.adversarialMutations.isEmpty) return baseCommand;
  final mutations = context.scenario.adversarialMutations.toList()..sort();
  final envelope = AgentEvaluationHashes.canonicalJson(<String, Object?>{
    'scenarioReleaseHash': context.scenario.releaseHash,
    'adversarialMutations': mutations,
  });
  return '$baseCommand\n\n[冻结评测变体；不得忽略]\n$envelope';
}

String _rawBundleHash(String value) =>
    value.startsWith('sha256:') ? value.substring(7) : value;

String _rawDigestValue(Object? value, String field) {
  if (value is! String) {
    throw AgentEvaluationProductionEvidenceException(
      'production $field is malformed',
    );
  }
  final raw = _rawBundleHash(value);
  try {
    AgentEvaluationHashes.requireDigest(raw, field);
  } on Object {
    throw AgentEvaluationProductionEvidenceException(
      'production $field is malformed',
    );
  }
  return raw;
}

Map<String, Object?> _providerCallToJson(
  AgentEvaluationProviderCallEvidence call,
) => <String, Object?>{
  'sequenceNo': call.sequenceNo,
  'modelRouteHash': call.modelRouteHash,
  'model': call.model,
  'promptTokens': call.promptTokens,
  'completionTokens': call.completionTokens,
  'succeeded': call.succeeded,
  if (call.failureKind != null) 'failureKind': call.failureKind!.name,
};

AgentEvaluationProviderCallEvidence _providerCallFromJson(
  Map<String, Object?> value,
) {
  const required = <String>{
    'sequenceNo',
    'modelRouteHash',
    'model',
    'promptTokens',
    'completionTokens',
    'succeeded',
  };
  const allowed = <String>{...required, 'failureKind'};
  if (!value.keys.toSet().containsAll(required) ||
      value.keys.toSet().difference(allowed).isNotEmpty ||
      value.length < required.length) {
    throw const AgentEvaluationProductionEvidenceException(
      'prepared provider call is malformed',
    );
  }
  final failureName = value['failureKind'];
  final call = AgentEvaluationProviderCallEvidence(
    sequenceNo: value['sequenceNo'] as int,
    modelRouteHash: value['modelRouteHash'] as String,
    model: value['model'] as String,
    promptTokens: value['promptTokens'] as int,
    completionTokens: value['completionTokens'] as int,
    succeeded: value['succeeded'] as bool,
    failureKind: failureName == null
        ? null
        : AppLlmFailureKind.values.byName(failureName as String),
  );
  if (AgentEvaluationHashes.canonicalJson(_providerCallToJson(call)) !=
      AgentEvaluationHashes.canonicalJson(value)) {
    throw const AgentEvaluationProductionEvidenceException(
      'prepared provider call is not canonical',
    );
  }
  return call;
}

Map<String, Object?> _qualityEvidenceToJson(
  AgentEvaluationQualityEvidence quality,
) => <String, Object?>{
  'scoreMicrosByDimension': quality.scoreMicrosByDimension,
  'judgePromptReleaseHash': quality.judgePromptReleaseHash,
  'judgeModelRouteHash': quality.judgeModelRouteHash,
  'rubricReleaseHash': quality.rubricReleaseHash,
  'aggregatorReleaseHash': quality.aggregatorReleaseHash,
  'evaluatedContentHash': quality.evaluatedContentHash,
  'externalJudgeOutputHash': quality.externalJudgeOutputHash,
  'externalEvaluationEvidenceHash': quality.externalEvaluationEvidenceHash,
  'deterministicQualityReceiptHash': quality.deterministicQualityReceiptHash,
  'judgeInjectionSafetyReceipt': quality.judgeInjectionSafetyReceipt?.toJson(),
};

AgentEvaluationQualityEvidence _qualityEvidenceFromJson(
  Map<String, Object?> value,
) {
  const keys = <String>{
    'scoreMicrosByDimension',
    'judgePromptReleaseHash',
    'judgeModelRouteHash',
    'rubricReleaseHash',
    'aggregatorReleaseHash',
    'evaluatedContentHash',
    'externalJudgeOutputHash',
    'externalEvaluationEvidenceHash',
    'deterministicQualityReceiptHash',
    'judgeInjectionSafetyReceipt',
  };
  if (value.length != keys.length || !value.keys.toSet().containsAll(keys)) {
    throw const AgentEvaluationProductionEvidenceException(
      'prepared quality evidence is malformed',
    );
  }
  final quality = AgentEvaluationQualityEvidence(
    scoreMicrosByDimension: _intMap(
      value['scoreMicrosByDimension'],
      'scoreMicrosByDimension',
    ),
    judgePromptReleaseHash: value['judgePromptReleaseHash'] as String,
    judgeModelRouteHash: value['judgeModelRouteHash'] as String,
    rubricReleaseHash: value['rubricReleaseHash'] as String,
    aggregatorReleaseHash: value['aggregatorReleaseHash'] as String,
    evaluatedContentHash: value['evaluatedContentHash'] as String,
    externalJudgeOutputHash: value['externalJudgeOutputHash'] as String,
    externalEvaluationEvidenceHash:
        value['externalEvaluationEvidenceHash'] as String,
    deterministicQualityReceiptHash:
        value['deterministicQualityReceiptHash'] as String?,
    judgeInjectionSafetyReceipt: value['judgeInjectionSafetyReceipt'] == null
        ? null
        : AgentEvaluationJudgeInjectionSafetyReceipt.fromJson(
            _object(
              value['judgeInjectionSafetyReceipt'],
              'judgeInjectionSafetyReceipt',
            ),
          ),
  );
  if (AgentEvaluationHashes.canonicalJson(_qualityEvidenceToJson(quality)) !=
      AgentEvaluationHashes.canonicalJson(value)) {
    throw const AgentEvaluationProductionEvidenceException(
      'prepared quality evidence is not canonical',
    );
  }
  return quality;
}

AppLlmCallTraceEntry _traceFromJson(Map<String, Object?> value) {
  PromptReleaseRef? releaseRef;
  if (value['promptReleaseRef'] != null) {
    final release = _object(value['promptReleaseRef'], 'promptReleaseRef');
    releaseRef = PromptReleaseRef(
      templateId: release['templateId'] as String,
      semanticVersion: release['semanticVersion'] as String,
      language: release['language'] as String,
      contentHash: release['contentHash'] as String,
    );
  }
  final trace = AppLlmCallTraceEntry(
    timestampMs: value['timestampMs'] as int,
    startedAtMs: value['startedAtMs'] as int?,
    completedAtMs: value['completedAtMs'] as int?,
    traceName: value['traceName'] as String,
    model: value['model'] as String,
    host: value['host'] as String,
    messageCount: value['messageCount'] as int,
    maxTokens: value['maxTokens'] as int,
    succeeded: value['succeeded'] as bool,
    latencyMs: value['latencyMs'] as int?,
    promptTokens: value['promptTokens'] as int?,
    completionTokens: value['completionTokens'] as int?,
    totalTokens: value['totalTokens'] as int?,
    estimatedPromptTokens: value['estimatedPromptTokens'] as int,
    estimatedCompletionTokens: value['estimatedCompletionTokens'] as int,
    promptChars: value['promptChars'] as int,
    completionChars: value['completionChars'] as int,
    failureKind: value['failureKind'] as String?,
    statusCode: value['statusCode'] as int?,
    errorDetail: value['errorDetail'] as String?,
    metadata: value['metadata'] == null
        ? const <String, Object?>{}
        : _object(value['metadata'], 'traceMetadata'),
    promptReleaseRef: releaseRef,
    promptVersion: value['promptVersion'] == null
        ? null
        : PromptVersion.fromJson(
            _object(value['promptVersion'], 'promptVersion'),
          ),
    stageId: value['stageId'] as String?,
    callSiteId: value['callSiteId'] as String?,
    variantId: value['variantId'] as String?,
    generationBundleHash: value['generationBundleHash'] as String?,
    renderedMessagesDigest: value['renderedMessagesDigest'] as String?,
    resolvedVariablesDigest: value['resolvedVariablesDigest'] as String?,
    rendererContractHash: value['rendererContractHash'] as String?,
    schemaType: value['schemaType'] as String?,
    schemaValid: value['schemaValid'] as bool?,
    schemaViolations: value['schemaViolations'] == null
        ? null
        : _stringList(value['schemaViolations'], 'schemaViolations'),
  );
  if (AgentEvaluationHashes.canonicalJson(trace.toJson()) !=
      AgentEvaluationHashes.canonicalJson(value)) {
    throw const AgentEvaluationProductionEvidenceException(
      'prepared formal trace is malformed or non-canonical',
    );
  }
  return trace;
}

Map<String, Object?> _resultToJson(AgentEvaluationTrialExecutionResult result) {
  final usage = result.usage;
  final quality = result.qualityEvidence;
  final hard = result.hardGateEvidence;
  if (usage == null || quality == null || hard == null) {
    throw const AgentEvaluationProductionEvidenceException(
      'release-capable executor result omitted typed evidence',
    );
  }
  final judgeCandidateJson = result.judgeCandidateJson;
  if (judgeCandidateJson == null) {
    throw const AgentEvaluationProductionEvidenceException(
      'release-capable executor result omitted replayable judge variables',
    );
  }
  _requireReplayableJudgeCandidateJson(
    judgeCandidateJson,
    result.evaluatedContent,
  );
  return <String, Object?>{
    'schemaVersion': 'eval-production-executor-result-v2',
    'outcome': <String, Object?>{
      'terminalState': result.outcome.terminalState.name,
      'failureCodes': result.outcome.failureCodes.toList()..sort(),
      'accepted': result.outcome.accepted,
      'sideEffectCounts': result.outcome.sideEffectCounts,
      'evidenceComplete': result.outcome.evidenceComplete,
    },
    'evaluatedContent': result.evaluatedContent,
    'judgeCandidateJson': judgeCandidateJson,
    'usage': usage.toJson(),
    'quality': _qualityEvidenceToJson(quality),
    'hardGate': <String, Object?>{
      'safetyPassed': hard.safetyPassed,
      'transactionPassed': hard.transactionPassed,
      'safetyVerifierReleaseHash': hard.safetyVerifierReleaseHash,
      'transactionVerifierReleaseHash': hard.transactionVerifierReleaseHash,
      'safetyEvidenceHash': hard.safetyEvidenceHash,
      'transactionEvidenceHash': hard.transactionEvidenceHash,
    },
    'productionStoryRunId': result.productionStoryRunId,
    'productionCandidateHash': result.productionCandidateHash,
    'productionReceiptId': result.productionReceiptId,
    'productionTransactionEvidenceHash':
        result.productionTransactionEvidenceHash,
    'productionExecutorReleaseHash': result.productionExecutorReleaseHash,
    'cacheSourceTrialSlotId': result.cacheSourceTrialSlotId,
  };
}

AgentEvaluationTrialExecutionResult _resultFromJson(
  Map<String, Object?> value,
) {
  if (value['schemaVersion'] != 'eval-production-executor-result-v2') {
    throw const AgentEvaluationProductionEvidenceException(
      'unsupported production executor recovery result',
    );
  }
  final outcome = _object(value['outcome'], 'outcome');
  final usage = _object(value['usage'], 'usage');
  final quality = _object(value['quality'], 'quality');
  final hard = _object(value['hardGate'], 'hardGate');
  if (usage['schemaVersion'] != 'eval-attempt-usage-v2') {
    throw const AgentEvaluationProductionEvidenceException(
      'production executor recovery requires frozen cost evidence',
    );
  }
  final recoveredUsage = _frozenUsageFromJson(usage);
  final evaluatedContent = value['evaluatedContent'] as String;
  final judgeCandidateJson = value['judgeCandidateJson'] as String;
  _requireReplayableJudgeCandidateJson(judgeCandidateJson, evaluatedContent);
  return AgentEvaluationTrialExecutionResult(
    outcome: ActualTrialOutcome(
      terminalState: TrialTerminalState.values.byName(
        outcome['terminalState'] as String,
      ),
      failureCodes: Set<String>.unmodifiable(
        _stringList(outcome['failureCodes'], 'failureCodes'),
      ),
      accepted: outcome['accepted'] as bool,
      sideEffectCounts: Map<String, int>.unmodifiable(
        _intMap(outcome['sideEffectCounts'], 'sideEffectCounts'),
      ),
      evidenceComplete: outcome['evidenceComplete'] as bool,
    ),
    evaluatedContent: evaluatedContent,
    judgeCandidateJson: judgeCandidateJson,
    usage: recoveredUsage,
    qualityEvidence: _qualityEvidenceFromJson(quality),
    hardGateEvidence: AgentEvaluationHardGateEvidence(
      safetyPassed: hard['safetyPassed'] as bool,
      transactionPassed: hard['transactionPassed'] as bool,
      safetyVerifierReleaseHash: hard['safetyVerifierReleaseHash'] as String,
      transactionVerifierReleaseHash:
          hard['transactionVerifierReleaseHash'] as String,
      safetyEvidenceHash: hard['safetyEvidenceHash'] as String,
      transactionEvidenceHash: hard['transactionEvidenceHash'] as String,
    ),
    productionStoryRunId: value['productionStoryRunId'] as String,
    productionCandidateHash: value['productionCandidateHash'] as String,
    productionReceiptId: value['productionReceiptId'] as String,
    productionTransactionEvidenceHash:
        value['productionTransactionEvidenceHash'] as String,
    productionExecutorReleaseHash:
        value['productionExecutorReleaseHash'] as String,
    cacheSourceTrialSlotId: value['cacheSourceTrialSlotId'] as String?,
  );
}

AgentEvaluationAttemptUsage _frozenUsageFromJson(Map<String, Object?> value) {
  final encodedCalls = value['providerCalls'];
  if (encodedCalls is! List) {
    throw const AgentEvaluationProductionEvidenceException(
      'production executor priced calls are malformed',
    );
  }
  final calls = <AgentEvaluationPricedProviderCall>[
    for (final encoded in encodedCalls)
      (() {
        final call = _object(encoded, 'providerCall');
        return AgentEvaluationPricedProviderCall(
          sequenceNo: call['sequenceNo'] as int,
          modelRouteHash: call['modelRouteHash'] as String,
          model: call['model'] as String,
          promptTokens: call['promptTokens'] as int,
          completionTokens: call['completionTokens'] as int,
          succeeded: call['succeeded'] as bool,
          costMicrousd: call['costMicrousd'] as int,
          purpose: call['purpose'] as String? ?? 'sut',
        );
      })(),
  ];
  final usage = AgentEvaluationAttemptUsage.frozen(
    priceTableHash: value['priceTableHash'] as String,
    providerCalls: calls,
  );
  if (usage.promptTokens != value['promptTokens'] ||
      usage.completionTokens != value['completionTokens'] ||
      usage.costMicrousd != value['costMicrousd'] ||
      usage.providerCallSetHash != value['providerCallSetHash'] ||
      usage.costEvidenceHash != value['costEvidenceHash']) {
    throw const AgentEvaluationProductionEvidenceException(
      'production executor cost evidence cannot be recomputed',
    );
  }
  return usage;
}

AgentEvaluationAttemptUsage _frozenUsage({
  required AgentEvaluationTrialContext context,
  required AgentEvaluationMeterSnapshot meterSnapshot,
  required AgentEvaluationFrozenPriceTable priceTable,
  Iterable<AgentEvaluationProviderCallEvidence> externalCalls =
      const <AgentEvaluationProviderCallEvidence>[],
}) {
  final calls = <AgentEvaluationPricedProviderCall>[];
  for (final call in meterSnapshot.calls) {
    if (call.modelRouteHash != context.cell.modelRouteHash) {
      throw const AgentEvaluationProductionEvidenceException(
        'failed provider usage belongs to another model route',
      );
    }
    calls.add(
      AgentEvaluationPricedProviderCall(
        sequenceNo: call.sequenceNo,
        modelRouteHash: call.modelRouteHash,
        model: call.model,
        promptTokens: call.promptTokens,
        completionTokens: call.completionTokens,
        succeeded: call.succeeded,
        costMicrousd: priceTable.costMicrousd(call),
        purpose: 'sut',
      ),
    );
  }
  for (final call in externalCalls) {
    calls.add(
      AgentEvaluationPricedProviderCall(
        sequenceNo: calls.length + 1,
        modelRouteHash: call.modelRouteHash,
        model: call.model,
        promptTokens: call.promptTokens,
        completionTokens: call.completionTokens,
        succeeded: call.succeeded,
        costMicrousd: priceTable.costMicrousd(call),
        purpose: 'externalJudge',
      ),
    );
  }
  final evaluatorCalls = calls.where((call) => call.purpose == 'externalJudge');
  if (evaluatorCalls.isNotEmpty) {
    final maxCalls = context.manifest.budgets['evaluatorCalls'];
    final maxTokens = context.manifest.budgets['evaluatorTokens'];
    final maxCost = context.manifest.budgets['evaluatorCostMicrousd'];
    final tokens = evaluatorCalls.fold<int>(
      0,
      (sum, call) => sum + call.promptTokens + call.completionTokens,
    );
    final cost = evaluatorCalls.fold<int>(
      0,
      (sum, call) => sum + call.costMicrousd,
    );
    if (maxCalls is! int ||
        maxTokens is! int ||
        maxCost is! int ||
        evaluatorCalls.length > maxCalls ||
        tokens > maxTokens ||
        cost > maxCost) {
      throw const AgentEvaluationProductionEvidenceException(
        'failed evaluator usage exceeded or omitted its frozen budget',
      );
    }
  }
  return AgentEvaluationAttemptUsage.frozen(
    priceTableHash: priceTable.releaseHash,
    providerCalls: calls,
  );
}

AgentEvaluationAttemptUsage _conservativeIndeterminateUsage({
  required AgentEvaluationTrialContext context,
  required AgentEvaluationProductionRouteRelease route,
  required AgentEvaluationFrozenPriceTable priceTable,
}) {
  final maxCalls = context.scenario.maxBudget['calls'];
  final maxTokens =
      context.scenario.maxBudget['maxTokens'] ??
      context.scenario.maxBudget['tokens'];
  if (maxCalls is! int ||
      maxCalls <= 0 ||
      maxTokens is! int ||
      maxTokens <= 0) {
    throw const AgentEvaluationProductionEvidenceException(
      'indeterminate recovery requires frozen positive call/token caps',
    );
  }

  AgentEvaluationProviderCallEvidence bound({
    required int promptTokens,
    required int completionTokens,
  }) => AgentEvaluationProviderCallEvidence(
    sequenceNo: 1,
    modelRouteHash: route.modelRouteHash,
    model: route.model,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    succeeded: false,
  );

  final promptOnlyCost = priceTable.costMicrousd(
    bound(promptTokens: maxTokens, completionTokens: 0),
  );
  final completionOnlyCost = priceTable.costMicrousd(
    bound(promptTokens: 0, completionTokens: maxTokens),
  );
  final chargeAsPrompt = promptOnlyCost >= completionOnlyCost;
  final calls = <AgentEvaluationPricedProviderCall>[];
  for (var index = 0; index < maxCalls; index += 1) {
    final evidence = AgentEvaluationProviderCallEvidence(
      sequenceNo: index + 1,
      modelRouteHash: route.modelRouteHash,
      model: route.model,
      promptTokens: index == 0 && chargeAsPrompt ? maxTokens : 0,
      completionTokens: index == 0 && !chargeAsPrompt ? maxTokens : 0,
      succeeded: false,
    );
    calls.add(
      AgentEvaluationPricedProviderCall(
        sequenceNo: evidence.sequenceNo,
        modelRouteHash: evidence.modelRouteHash,
        model: evidence.model,
        promptTokens: evidence.promptTokens,
        completionTokens: evidence.completionTokens,
        succeeded: false,
        costMicrousd: priceTable.costMicrousd(evidence),
      ),
    );
  }
  return AgentEvaluationAttemptUsage.frozen(
    priceTableHash: priceTable.releaseHash,
    providerCalls: calls,
  );
}

Map<String, Object?> _jsonObject(String encoded) {
  try {
    return _object(jsonDecode(encoded), 'executor result');
  } on AgentEvaluationProductionEvidenceException {
    rethrow;
  } on Object {
    throw const AgentEvaluationProductionEvidenceException(
      'production executor recovery JSON is malformed',
    );
  }
}

void _requireReplayableJudgeCandidateJson(
  String candidateJson,
  String evaluatedContent,
) {
  try {
    final candidate = _object(jsonDecode(candidateJson), 'judgeCandidateJson');
    if (candidate.keys.toSet().difference(const <String>{
          'opaqueCandidateLabel',
          'contentType',
          'quotedContent',
        }).isNotEmpty ||
        candidate.length != 3 ||
        candidate['opaqueCandidateLabel'] is! String ||
        (candidate['opaqueCandidateLabel'] as String).trim().isEmpty ||
        candidate['contentType'] != 'untrusted_quoted_candidate' ||
        candidate['quotedContent'] != evaluatedContent ||
        AgentEvaluationHashes.canonicalJson(candidate) != candidateJson) {
      throw const AgentEvaluationProductionEvidenceException(
        'persisted judge variables cannot replay the evaluated candidate',
      );
    }
  } on AgentEvaluationProductionEvidenceException {
    rethrow;
  } on Object {
    throw const AgentEvaluationProductionEvidenceException(
      'persisted judge variables are malformed',
    );
  }
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) {
    throw AgentEvaluationProductionEvidenceException(
      'production executor recovery $field is malformed',
    );
  }
  return <String, Object?>{
    for (final entry in value.entries) entry.key as String: entry.value,
  };
}

Map<String, int> _intMap(Object? value, String field) {
  final map = _object(value, field);
  if (map.values.any((item) => item is! int)) {
    throw AgentEvaluationProductionEvidenceException(
      'production executor recovery $field is malformed',
    );
  }
  return <String, int>{
    for (final entry in map.entries) entry.key: entry.value! as int,
  };
}

List<String> _stringList(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw AgentEvaluationProductionEvidenceException(
      'production executor recovery $field is malformed',
    );
  }
  return value.cast<String>();
}

/// Strict wrapper: callers cannot turn off gate or production evidence.
final class AgentEvaluationProductionReleaseRunner {
  const AgentEvaluationProductionReleaseRunner({required this.runner});

  final AgentEvaluationRunner runner;

  Future<AgentEvaluationRunReport> run({
    required ExperimentManifest manifest,
    required String executionId,
    required String workerId,
    required String actualBuildArtifactHash,
    required bool Function(String releaseRef) verifierExists,
    required AgentEvaluationProductionTrialExecutor executor,
    required AgentEvaluationCancellationToken cancellationToken,
    required void Function(AgentEvaluationProgress progress) onProgress,
    int leaseDurationMs = 60000,
    int? deadlineAtMs,
  }) => runner.run(
    manifest: manifest,
    executionId: executionId,
    workerId: workerId,
    actualBuildArtifactHash: actualBuildArtifactHash,
    verifierExists: verifierExists,
    trialExecutor: executor.execute,
    cancellationToken: cancellationToken,
    onProgress: onProgress,
    requireGateEvidence: true,
    requireProductionEvidence: true,
    leaseDurationMs: leaseDurationMs,
    deadlineAtMs: deadlineAtMs,
  );
}
