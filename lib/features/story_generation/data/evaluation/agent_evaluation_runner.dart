import 'dart:async';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/evaluation/outcome_evaluation.dart';
import '../../domain/evaluation/pass3_evaluation.dart';
import 'agent_evaluation_fixture_sandbox.dart';
import 'agent_evaluation_cache_receipt_store.dart';
import 'agent_evaluation_ledger.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_manifest_store.dart';
import 'agent_evaluation_pass3_projection.dart';
import 'agent_evaluation_production_authority.dart';
import 'agent_evaluation_trace_context.dart';
import 'agent_evaluation_typed_evidence.dart';

class AgentEvaluationTransportException implements Exception {
  const AgentEvaluationTransportException(
    this.message, {
    this.requestedReplacementAttempts = 0,
    this.usage,
    this.judgeInjectionSafetyReceipt,
  });

  final String message;
  final int requestedReplacementAttempts;
  final AgentEvaluationAttemptUsage? usage;
  final AgentEvaluationJudgeInjectionSafetyReceipt? judgeInjectionSafetyReceipt;

  @override
  String toString() => 'AgentEvaluationTransportException: $message';
}

/// A provider-bound attempt whose completion cannot be proved after recovery.
///
/// Retrying this attempt could duplicate a paid provider call. The runner must
/// therefore retain its conservative usage, seal the slot as insufficient
/// evidence, and continue with later slots instead of replaying the provider.
final class AgentEvaluationIndeterminateProviderCompletionException
    extends AgentEvaluationTransportException {
  const AgentEvaluationIndeterminateProviderCompletionException(
    super.message, {
    required super.usage,
    super.judgeInjectionSafetyReceipt,
  });

  @override
  String toString() =>
      'AgentEvaluationIndeterminateProviderCompletionException: $message';
}

class AgentEvaluationCancellationToken {
  var _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

enum AgentEvaluationDurableRecoveryStage {
  prepared,
  accepted,
  outboxCompleted,
  finalPersisted,
}

typedef AgentEvaluationDurableSandboxCheckpointWriter =
    Future<AgentEvaluationSandboxRecoveryCheckpoint> Function({
      required AgentEvaluationDurableRecoveryStage stage,
      required String candidateHash,
    });

class AgentEvaluationProgress {
  const AgentEvaluationProgress({
    required this.executionId,
    required this.cellId,
    required this.scenarioId,
    required this.trialNo,
    required this.stage,
    required this.elapsedMs,
    required this.attemptedCalls,
    required this.latestStatus,
  });

  final String executionId;
  final String cellId;
  final String scenarioId;
  final int trialNo;
  final String stage;
  final int elapsedMs;
  final int attemptedCalls;
  final String latestStatus;
}

class AgentEvaluationTrialContext {
  const AgentEvaluationTrialContext({
    required this.manifest,
    required this.cell,
    required this.scenario,
    required this.lease,
    required this.attemptNo,
    required this.runId,
    required this.isolationTrialId,
    required this.database,
    this.sandboxDatabasePath,
    this.durableSandbox = false,
    this.acknowledgeDurableSandboxRuntimeDisposed,
    this.acquireSandboxConnectionOwner,
    this.releaseSandboxConnectionOwner,
    this.sandboxConnectionOwnerCount,
    this.persistDurableSandboxRecoveryCheckpoint,
    this.deadlineAtMs,
    required this.reportStage,
    required this.cancellationToken,
  });

  final ExperimentManifest manifest;
  final AgentEvaluationCellManifest cell;
  final ScenarioRelease scenario;
  final AgentEvaluationLease lease;
  final int attemptNo;
  final String runId;
  final String isolationTrialId;
  final Database database;
  final String? sandboxDatabasePath;
  final bool durableSandbox;
  final Future<String> Function(Database authoritativeDatabase)?
  acknowledgeDurableSandboxRuntimeDisposed;
  final void Function(String ownerId)? acquireSandboxConnectionOwner;
  final void Function(String ownerId)? releaseSandboxConnectionOwner;
  final int Function()? sandboxConnectionOwnerCount;
  final AgentEvaluationDurableSandboxCheckpointWriter?
  persistDurableSandboxRecoveryCheckpoint;
  final int? deadlineAtMs;
  final void Function(String stage, {String status}) reportStage;
  final AgentEvaluationCancellationToken cancellationToken;
}

class AgentEvaluationTrialExecutionResult {
  const AgentEvaluationTrialExecutionResult({
    required this.outcome,
    required this.evaluatedContent,
    this.usage,
    this.qualityEvidence,
    this.judgeCandidateJson,
    this.hardGateEvidence,
    this.productionStoryRunId,
    this.productionCandidateHash,
    this.productionReceiptId,
    this.productionTransactionEvidenceHash,
    this.productionExecutorReleaseHash,
    this.cacheSourceTrialSlotId,
  });

  final ActualTrialOutcome outcome;
  final String evaluatedContent;
  final AgentEvaluationAttemptUsage? usage;
  final AgentEvaluationQualityEvidence? qualityEvidence;

  /// Canonical, replayable variables rendered into the independent judge call.
  ///
  /// Production release results persist this instead of retaining only a
  /// digest that cannot reconstruct the request.
  final String? judgeCandidateJson;
  final AgentEvaluationHardGateEvidence? hardGateEvidence;
  final String? productionStoryRunId;
  final String? productionCandidateHash;
  final String? productionReceiptId;
  final String? productionTransactionEvidenceHash;
  final String? productionExecutorReleaseHash;
  final String? cacheSourceTrialSlotId;
}

typedef AgentEvaluationTrialExecutor =
    Future<AgentEvaluationTrialExecutionResult> Function(
      AgentEvaluationTrialContext context,
    );

class AgentEvaluationCellPass3Result {
  const AgentEvaluationCellPass3Result({
    required this.cellId,
    required this.scenarioReleaseHash,
    required this.trialResults,
    required this.pass3Eligible,
    required this.passed,
    required this.failureReasons,
  });

  final String cellId;
  final String scenarioReleaseHash;
  final Map<int, String> trialResults;
  final bool pass3Eligible;
  final bool passed;
  final Set<Pass3Failure> failureReasons;
}

class AgentEvaluationRunReport {
  const AgentEvaluationRunReport({
    required this.executionId,
    required this.cancelled,
    required this.deadlineExceeded,
    required this.cellPass3,
    required this.scenarioPass3,
  });

  final String executionId;
  final bool cancelled;
  final bool deadlineExceeded;
  final List<AgentEvaluationCellPass3Result> cellPass3;
  final Map<String, bool> scenarioPass3;
}

class AgentEvaluationRunner {
  AgentEvaluationRunner({
    required this.manifestStore,
    required this.ledger,
    required this.fixtureSandbox,
    this.outcomeComparator = const ExpectedOutcomeComparator(),
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AgentEvaluationManifestStore manifestStore;
  final AgentEvaluationLedger ledger;
  final AgentEvaluationFixtureSandbox fixtureSandbox;
  final ExpectedOutcomeComparator outcomeComparator;
  final int Function() _nowMs;
  final Map<String, AgentEvaluationTrialSandbox> _openedTrials = {};

  Future<AgentEvaluationRunReport> run({
    required ExperimentManifest manifest,
    required String executionId,
    required String workerId,
    required String actualBuildArtifactHash,
    required bool Function(String releaseRef) verifierExists,
    required AgentEvaluationTrialExecutor trialExecutor,
    required AgentEvaluationCancellationToken cancellationToken,
    required void Function(AgentEvaluationProgress progress) onProgress,
    bool requireGateEvidence = false,
    bool requireProductionEvidence = false,
    int leaseDurationMs = 60000,
    int? deadlineAtMs,
  }) {
    if (requireProductionEvidence && !requireGateEvidence) {
      throw const AgentEvaluationManifestException(
        'production evidence requires the strict gate evidence path',
      );
    }
    return manifestStore.preflightAndRun<Future<AgentEvaluationRunReport>>(
      manifest: manifest,
      actualBuildArtifactHash: actualBuildArtifactHash,
      verifierExists: verifierExists,
      requireExecutableBundles: requireGateEvidence,
      requireProductionAuthorities: requireProductionEvidence,
      providerCall: () => _runPreflighted(
        manifest: manifest,
        executionId: executionId,
        workerId: workerId,
        trialExecutor: trialExecutor,
        cancellationToken: cancellationToken,
        onProgress: onProgress,
        requireGateEvidence: requireGateEvidence,
        requireProductionEvidence: requireProductionEvidence,
        leaseDurationMs: leaseDurationMs,
        deadlineAtMs: deadlineAtMs,
      ),
    );
  }

  Future<AgentEvaluationRunReport> _runPreflighted({
    required ExperimentManifest manifest,
    required String executionId,
    required String workerId,
    required AgentEvaluationTrialExecutor trialExecutor,
    required AgentEvaluationCancellationToken cancellationToken,
    required void Function(AgentEvaluationProgress progress) onProgress,
    required bool requireGateEvidence,
    required bool requireProductionEvidence,
    required int leaseDurationMs,
    required int? deadlineAtMs,
  }) async {
    final cells = manifest.cells
        .map(
          (cell) => AgentEvaluationCellDefinition(
            generationBundleHash: cell.generationBundleHash,
            sutModelRouteHash: cell.modelRouteHash,
            scenarioReleaseHash: cell.scenarioReleaseHash,
            decodingConfigHash: cell.decodingConfigHash,
          ),
        )
        .toList(growable: false);
    ledger.createOrValidateExecution(
      executionId: executionId,
      experimentId: manifest.experimentId,
      cells: cells,
      createdAtMs: _nowMs(),
    );
    var cancelled = false;
    var deadlineExceeded = false;
    while (true) {
      final now = _nowMs();
      if (cancellationToken.isCancelled ||
          (deadlineAtMs != null && now >= deadlineAtMs)) {
        cancelled = cancellationToken.isCancelled;
        deadlineExceeded = !cancelled;
        _markExecutionCancelled(executionId, now);
        break;
      }
      final lease = ledger.claimNextSlot(
        executionId: executionId,
        owner: workerId,
        nowMs: now,
        leaseDurationMs: leaseDurationMs,
      );
      if (lease == null) break;
      try {
        await _runSlot(
          manifest: manifest,
          lease: lease,
          trialExecutor: trialExecutor,
          cancellationToken: cancellationToken,
          onProgress: onProgress,
          requireGateEvidence: requireGateEvidence,
          requireProductionEvidence: requireProductionEvidence,
          leaseDurationMs: leaseDurationMs,
          deadlineAtMs: deadlineAtMs,
        );
      } on _RunnerStopped catch (stopped) {
        _expireLease(lease, stopped.atMs);
        cancelled = stopped.cancelled;
        deadlineExceeded = !stopped.cancelled;
        _markExecutionCancelled(executionId, stopped.atMs);
        break;
      } catch (_) {
        _expireLease(lease, _nowMs());
        rethrow;
      }
    }
    return _buildReport(
      manifest: manifest,
      executionId: executionId,
      cancelled: cancelled,
      deadlineExceeded: deadlineExceeded,
    );
  }

  Future<void> _runSlot({
    required ExperimentManifest manifest,
    required AgentEvaluationLease lease,
    required AgentEvaluationTrialExecutor trialExecutor,
    required AgentEvaluationCancellationToken cancellationToken,
    required void Function(AgentEvaluationProgress progress) onProgress,
    required bool requireGateEvidence,
    required bool requireProductionEvidence,
    required int leaseDurationMs,
    required int? deadlineAtMs,
  }) async {
    final cell = manifest.cells.singleWhere(
      (cell) => cell.cellId == lease.cellId,
    );
    final scenario = manifest.scenarioSet.scenarios.singleWhere(
      (scenario) => scenario.releaseHash == cell.scenarioReleaseHash,
    );
    final armId =
        '${cell.generationBundleHash}:${cell.modelRouteHash}:${cell.decodingConfigHash}';
    final isolationTrialId = scenario.isolationMode == 'episode'
        ? AgentEvaluationHashes.domainHash('episode-trial-v1', <Object?>[
            lease.executionId,
            cell.generationBundleHash,
            cell.modelRouteHash,
            cell.decodingConfigHash,
            scenario.episodeId,
            lease.trialNo,
          ])
        : lease.trialSlotId;
    final isolationMode = scenario.isolationMode == 'episode'
        ? AgentEvaluationIsolationMode.episode
        : AgentEvaluationIsolationMode.independent;
    final resume = _attemptResumeState(
      lease: lease,
      requireGateEvidence: requireGateEvidence,
    );
    final latestGeneration = fixtureSandbox.isDurable
        ? ledger.readLatestSandboxGeneration(
            executionId: lease.executionId,
            isolationTrialId: isolationTrialId,
          )
        : null;
    final recoveryCheckpoint = fixtureSandbox.isDurable
        ? ledger.readLatestSandboxRecoveryCheckpoint(
            executionId: lease.executionId,
            trialSlotId: lease.trialSlotId,
            attemptNo: resume.attemptNo,
            attemptRunId: contextRunId(lease, resume.attemptNo),
            cellId: lease.cellId,
            manifestHash: manifest.manifestHash,
            isolationTrialId: isolationTrialId,
            isolationMode: scenario.isolationMode,
          )
        : null;
    if (fixtureSandbox.isDurable &&
        isolationMode == AgentEvaluationIsolationMode.episode &&
        (scenario.episodeStep ?? 1) > 1 &&
        latestGeneration == null) {
      throw const AgentEvaluationConflict(
        'episode successor has no committed sandbox generation',
      );
    }
    final sandbox = fixtureSandbox.isDurable
        ? fixtureSandbox.openLeaseTrial(
            armId: armId,
            trialId: isolationTrialId,
            isolationMode: isolationMode,
            leaseEpoch: lease.epoch,
            leaseOwner: lease.owner,
            leaseTrialSlotId: lease.trialSlotId,
            sourceDatabasePath:
                recoveryCheckpoint?.databasePath ??
                latestGeneration?.databasePath,
            expectedSourceFileHash:
                recoveryCheckpoint?.databaseFileHash ??
                latestGeneration?.databaseFileHash,
            expectedSourceFileSize: recoveryCheckpoint?.databaseFileSize,
            expectedSourceStateProjectionHash:
                recoveryCheckpoint?.stateProjectionHash,
          )
        : _openedTrials.putIfAbsent(
            isolationTrialId,
            () => fixtureSandbox.openTrial(
              armId: armId,
              trialId: isolationTrialId,
              isolationMode: isolationMode,
            ),
          );
    sandbox.requireEvidenceProfile(
      requireProductionEvidence
          ? AgentEvaluationRequiredEvidenceProfile.productionExecutorV1
          : AgentEvaluationRequiredEvidenceProfile.generic,
    );
    final startedAt = _nowMs();
    var attemptedCalls = resume.terminalAttemptCount;
    void progress(String stage, {String status = 'running'}) {
      onProgress(
        AgentEvaluationProgress(
          executionId: lease.executionId,
          cellId: lease.cellId,
          scenarioId: scenario.scenarioId,
          trialNo: lease.trialNo,
          stage: stage,
          elapsedMs: _nowMs() - startedAt,
          attemptedCalls: attemptedCalls,
          latestStatus: status,
        ),
      );
    }

    progress('slot', status: 'claimed');
    final maxTransportAttempts =
        manifest.transportAttemptPolicy['maxAttempts'] as int? ?? 1;
    if (maxTransportAttempts <= 0) {
      throw const AgentEvaluationManifestException(
        'transport maxAttempts must be positive',
      );
    }
    AgentEvaluationTrialExecutionResult? executionResult;
    AgentEvaluationTrialContext? successfulContext;
    final evidenceKeys = <AgentEvaluationEvidenceKey>[
      ...resume.persistedEvidenceKeys,
    ];
    var attemptNo = resume.attemptNo;
    int? observationAttemptNo = resume.lastTerminalAttemptNo;
    var indeterminateProviderCompletion = false;
    while (attemptedCalls < maxTransportAttempts) {
      _throwIfStopped(cancellationToken, deadlineAtMs);
      final runId = '${lease.trialSlotId}-attempt-$attemptNo';
      ledger.startAttempt(
        lease: lease,
        attemptNo: attemptNo,
        runId: runId,
        kind: 'content',
        startedAtMs: _nowMs(),
      );
      attemptedCalls += 1;
      progress('provider', status: 'attempt-$attemptedCalls');
      try {
        final context = AgentEvaluationTrialContext(
          manifest: manifest,
          cell: cell,
          scenario: scenario,
          lease: lease,
          attemptNo: attemptNo,
          runId: runId,
          isolationTrialId: isolationTrialId,
          database: sandbox.database,
          sandboxDatabasePath: sandbox.databasePath,
          durableSandbox: fixtureSandbox.isDurable,
          acknowledgeDurableSandboxRuntimeDisposed: fixtureSandbox.isDurable
              ? sandbox.acknowledgeRuntimeDisposed
              : null,
          acquireSandboxConnectionOwner: fixtureSandbox.isDurable
              ? sandbox.acquireConnectionOwner
              : null,
          releaseSandboxConnectionOwner: fixtureSandbox.isDurable
              ? sandbox.releaseConnectionOwner
              : null,
          sandboxConnectionOwnerCount: fixtureSandbox.isDurable
              ? () => sandbox.connectionOwnerCount
              : null,
          persistDurableSandboxRecoveryCheckpoint: fixtureSandbox.isDurable
              ? ({required stage, required candidateHash}) async {
                  AgentEvaluationHashes.requireDigest(
                    candidateHash,
                    'candidateHash',
                  );
                  final existing = ledger.readLatestSandboxRecoveryCheckpoint(
                    executionId: lease.executionId,
                    trialSlotId: lease.trialSlotId,
                    attemptNo: attemptNo,
                    attemptRunId: runId,
                    cellId: lease.cellId,
                    manifestHash: manifest.manifestHash,
                    isolationTrialId: isolationTrialId,
                    isolationMode: scenario.isolationMode,
                  );
                  final stageName = stage.name;
                  final stageNo = AgentEvaluationLedger
                      .sandboxRecoveryStageOrdinals[stageName]!;
                  if (existing != null && existing.checkpointNo >= stageNo) {
                    if (existing.candidateHash == candidateHash) {
                      fixtureSandbox.verifyRecoverySnapshot(
                        databasePath: existing.databasePath,
                        databaseFileHash: existing.databaseFileHash,
                        databaseFileSize: existing.databaseFileSize,
                        stateProjectionHash: existing.stateProjectionHash,
                      );
                      // Recovery code can replay already-crossed local
                      // boundaries. Returning the verified chain head is
                      // idempotent and never rolls the sandbox state back.
                      return existing;
                    }
                    throw const AgentEvaluationConflict(
                      'sandbox recovery checkpoint candidate changed',
                    );
                  }
                  final createdAtMs = _nowMs();
                  final checkpointIdentity = AgentEvaluationHashes.domainHash(
                    'eval-sandbox-recovery-file-v1',
                    <String, Object?>{
                      'executionId': lease.executionId,
                      'trialSlotId': lease.trialSlotId,
                      'attemptNo': attemptNo,
                      'runId': runId,
                      'leaseEpoch': lease.epoch,
                      'leaseOwner': lease.owner,
                      'stage': stageName,
                      'createdAtMs': createdAtMs,
                    },
                  );
                  final snapshot = sandbox.createRecoverySnapshot(
                    checkpointIdentity: checkpointIdentity,
                  );
                  return ledger.appendSandboxRecoveryCheckpoint(
                    lease: lease,
                    attemptNo: attemptNo,
                    attemptRunId: runId,
                    cellId: lease.cellId,
                    manifestHash: manifest.manifestHash,
                    isolationTrialId: isolationTrialId,
                    isolationMode: scenario.isolationMode,
                    stage: stageName,
                    candidateHash: candidateHash,
                    databasePath: snapshot.databasePath,
                    databaseFileHash: snapshot.databaseFileHash,
                    databaseFileSize: snapshot.databaseFileSize,
                    stateProjectionHash: snapshot.stateProjectionHash,
                    createdAtMs: createdAtMs,
                  );
                }
              : null,
          deadlineAtMs: deadlineAtMs,
          reportStage: progress,
          cancellationToken: cancellationToken,
        );
        executionResult = await _runWithLeaseHeartbeat(
          lease: lease,
          leaseDurationMs: leaseDurationMs,
          operation: () => AgentEvaluationTraceContext.run(
            AgentEvaluationTraceContext(
              experimentId: manifest.experimentId,
              executionId: lease.executionId,
              cellId: lease.cellId,
              trialSlotId: lease.trialSlotId,
              attemptNo: attemptNo,
              runId: runId,
              leaseEpoch: lease.epoch,
              leaseOwner: lease.owner,
              isolationTrialId: isolationTrialId,
              generationBundleHash: 'sha256:${cell.generationBundleHash}',
              evaluationBundleHash: 'sha256:${manifest.evaluationBundleHash}',
            ),
            () => trialExecutor(context),
          ),
        );
        successfulContext = context;
        if (requireGateEvidence) {
          final usage = executionResult!.usage;
          if (usage == null) {
            throw const AgentEvaluationManifestException(
              'release trial content attempt omitted typed usage evidence',
            );
          }
          if (requireProductionEvidence && !usage.hasFrozenCostEvidence) {
            throw const AgentEvaluationManifestException(
              'production attempt omitted frozen price/call-set evidence',
            );
          }
          evidenceKeys.add(
            _appendUsageObservation(
              manifest: manifest,
              lease: lease,
              attemptNo: attemptNo,
              usage: usage,
            ),
          );
        }
        observationAttemptNo = attemptNo;
        break;
      } on AgentEvaluationTransportException catch (error) {
        if (requireGateEvidence) {
          final usage = error.usage;
          if (usage == null) {
            throw const AgentEvaluationManifestException(
              'release trial transport attempt omitted typed usage evidence',
            );
          }
          if (requireProductionEvidence && !usage.hasFrozenCostEvidence) {
            throw const AgentEvaluationManifestException(
              'production transport attempt omitted frozen price evidence',
            );
          }
          evidenceKeys.add(
            _appendUsageObservation(
              manifest: manifest,
              lease: lease,
              attemptNo: attemptNo,
              usage: usage,
            ),
          );
          final injectionReceipt = error.judgeInjectionSafetyReceipt;
          if (injectionReceipt != null) {
            evidenceKeys.add(
              _appendJudgeInjectionObservation(
                manifest: manifest,
                lease: lease,
                attemptNo: attemptNo,
                receipt: injectionReceipt,
              ),
            );
          }
        }
        // Do not terminalize the attempt until its required usage evidence is
        // durably accepted. If validation or append fails, the started row is
        // intentionally reclaimable by a later lease epoch.
        ledger.finishAttempt(
          lease: lease,
          attemptNo: attemptNo,
          status: 'failed',
          finalKind: 'transport',
          finishedAtMs: _nowMs(),
        );
        observationAttemptNo = attemptNo;
        if (error is AgentEvaluationIndeterminateProviderCompletionException) {
          indeterminateProviderCompletion = true;
          break;
        }
        attemptNo += 1;
      }
    }
    _throwIfStopped(cancellationToken, deadlineAtMs);
    final evidenceAttemptNo = observationAttemptNo;
    if (evidenceAttemptNo == null) {
      throw const AgentEvaluationManifestException(
        'trial produced no provider attempt evidence',
      );
    }
    final executorOutcome = executionResult?.outcome;
    final actual = executorOutcome == null
        ? ActualTrialOutcome(
            terminalState: TrialTerminalState.failed,
            failureCodes: <String>{
              indeterminateProviderCompletion
                  ? 'provider.indeterminate_completion'
                  : 'provider.transport',
            },
            accepted: false,
            evidenceComplete: !indeterminateProviderCompletion,
          )
        : ActualTrialOutcome(
            terminalState: executorOutcome.terminalState,
            failureCodes: executorOutcome.failureCodes,
            accepted: executorOutcome.accepted,
            sideEffectCounts: <String, int>{
              ...executorOutcome.sideEffectCounts,
              ...fixtureSandbox.readProductionSideEffectCounts(),
            },
            evidenceComplete: executorOutcome.evidenceComplete,
          );
    final comparison = outcomeComparator.compare(
      expected: _expectedOutcome(scenario),
      actual: actual,
    );
    final evaluatedContent = executionResult?.evaluatedContent ?? '';
    final contentDigest = executionResult == null
        ? null
        : AgentEvaluationHashes.domainHash(
            'eval-trial-content-v1',
            evaluatedContent,
          );
    final cacheReceipts = AgentEvaluationCacheReceiptStore(db: ledger.db)
        .forAttempt(
          executionId: lease.executionId,
          trialSlotId: lease.trialSlotId,
          attemptNo: evidenceAttemptNo,
          runId:
              successfulContext?.runId ??
              '${lease.trialSlotId}-attempt-$evidenceAttemptNo',
        );
    final crossSlotHits = cacheReceipts.where(
      (receipt) =>
          receipt.hit && receipt.sourceTrialSlotId != lease.trialSlotId,
    );
    final cacheSource = crossSlotHits.isEmpty
        ? null
        : crossSlotHits.first.sourceTrialSlotId;
    final independence =
        executionResult != null &&
            evaluatedContent.isNotEmpty &&
            crossSlotHits.isEmpty
        ? TrialIndependence.independent
        : TrialIndependence.nonIndependent;
    final hardPass =
        comparison.isHardPass &&
        executionResult != null &&
        evaluatedContent.isNotEmpty &&
        independence == TrialIndependence.independent;
    if (requireGateEvidence && executionResult != null) {
      final quality = executionResult.qualityEvidence;
      if (quality == null) {
        throw const AgentEvaluationManifestException(
          'release trial content omitted frozen quality evidence',
        );
      }
      if (quality.evaluatedContentHash != contentDigest) {
        throw const AgentEvaluationManifestException(
          'external quality evidence is bound to different evaluated prose',
        );
      }
      final dimensions = quality.scoreMicrosByDimension.keys.toList()..sort();
      for (var index = 0; index < dimensions.length; index += 1) {
        final dimension = dimensions[index];
        final value = quality.valueFor(dimension);
        final evidenceHash = AgentEvaluationHashes.domainHash(
          'eval-quality-dimension-observation-v1',
          <String, Object?>{
            'trialSlotId': lease.trialSlotId,
            'attemptNo': evidenceAttemptNo,
            'dimensionId': dimension,
            'proseHash': contentDigest,
            'evaluationBundleHash': manifest.evaluationBundleHash,
            'value': value,
          },
        );
        final qualityObservation = AgentEvaluationObservationInput(
          observationId: '${lease.trialSlotId}-quality-$dimension',
          attemptNo: evidenceAttemptNo,
          sequenceNo: (evidenceAttemptNo - 1) * 10 + index + 1,
          stageId: 'quality',
          kind: 'dimension',
          itemKey: dimension,
          valueJson: AgentEvaluationHashes.canonicalJson(value),
          evidenceHash: evidenceHash,
          evaluationBundleHash: manifest.evaluationBundleHash,
          proseHash: contentDigest,
          createdAtMs: _nowMs(),
        );
        ledger.appendObservation(lease: lease, observation: qualityObservation);
        evidenceKeys.add(qualityObservation.evidenceKey);
      }
      final hardGates = executionResult.hardGateEvidence;
      if (hardGates == null) {
        throw const AgentEvaluationManifestException(
          'release trial content omitted independent safety/transaction evidence',
        );
      }
      for (var index = 0; index < 2; index += 1) {
        final gateKind = index == 0 ? 'safety' : 'transaction';
        final value = hardGates.valueFor(gateKind);
        final evidenceHash = AgentEvaluationHashes.domainHash(
          'eval-hard-gate-observation-v1',
          <String, Object?>{
            'trialSlotId': lease.trialSlotId,
            'attemptNo': evidenceAttemptNo,
            'gateKind': gateKind,
            'proseHash': contentDigest,
            'evaluationBundleHash': manifest.evaluationBundleHash,
            'value': value,
          },
        );
        final gateObservation = AgentEvaluationObservationInput(
          observationId: '${lease.trialSlotId}-hard-gate-$gateKind',
          attemptNo: evidenceAttemptNo,
          sequenceNo: (evidenceAttemptNo - 1) * 10 + index + 8,
          stageId: 'hard-gate',
          kind: gateKind,
          itemKey: 'singleton',
          valueJson: AgentEvaluationHashes.canonicalJson(value),
          evidenceHash: evidenceHash,
          evaluationBundleHash: manifest.evaluationBundleHash,
          proseHash: contentDigest,
          createdAtMs: _nowMs(),
        );
        ledger.appendObservation(lease: lease, observation: gateObservation);
        evidenceKeys.add(gateObservation.evidenceKey);
      }
    }
    if (requireProductionEvidence &&
        executionResult == null &&
        !indeterminateProviderCompletion) {
      throw const AgentEvaluationManifestException(
        'production release trial did not complete a production story run',
      );
    }
    if (requireProductionEvidence && executionResult != null) {
      final context = successfulContext;
      if (context == null) {
        throw const AgentEvaluationManifestException(
          'production release trial lost its formal attempt context',
        );
      }
      final verified = AgentEvaluationProductionDatabaseAuthority.verify(
        context: context,
        result: executionResult,
      );
      if (verified.proseHash != contentDigest ||
          verified.attemptRunId != contextRunId(lease, evidenceAttemptNo)) {
        throw const AgentEvaluationManifestException(
          'runner-owned production authority contradicts evaluated prose',
        );
      }
      ledger.appendProductionAuthorityReceipt(
        lease: lease,
        attemptNo: evidenceAttemptNo,
        authorityReceiptHash: _rawDigest(verified.authorityReceiptHash),
        authorityReleaseHash: _rawDigest(
          AgentEvaluationProductionDatabaseAuthority.releaseHash,
        ),
        attemptRunId: verified.attemptRunId,
        sandboxDatabasePath: verified.sandboxDatabasePath,
        candidateHash: _rawDigest(verified.candidateHash),
        commitReceiptId: verified.commitReceiptId,
        transactionEvidenceHash: _rawDigest(verified.transactionEvidenceHash),
        proseHash: _rawDigest(verified.proseHash),
        generationBundleHash: _rawDigest(verified.generationBundleHash),
        executorReleaseHash: _rawDigest(verified.executorReleaseHash),
        createdAtMs: _nowMs(),
      );
      final productionValue = <String, Object?>{
        'schemaVersion': 'eval-production-receipt-v2',
        'authorityReceiptHash': verified.authorityReceiptHash,
        'authorityReleaseHash':
            AgentEvaluationProductionDatabaseAuthority.releaseHash,
        'executorReleaseHash': verified.executorReleaseHash,
        'attemptRunId': verified.attemptRunId,
        'storyRunId': verified.attemptRunId,
        'candidateHash': verified.candidateHash,
        'receiptId': verified.commitReceiptId,
        'transactionEvidenceHash': verified.transactionEvidenceHash,
        'proseHash': contentDigest,
        'generationBundleHash': contextBundleHash(cell),
      };
      final productionObservation = AgentEvaluationObservationInput(
        observationId: '${lease.trialSlotId}-production-receipt',
        attemptNo: evidenceAttemptNo,
        sequenceNo: (evidenceAttemptNo - 1) * 10 + 10,
        stageId: 'production',
        kind: 'receipt',
        itemKey: 'singleton',
        valueJson: AgentEvaluationHashes.canonicalJson(productionValue),
        evidenceHash: AgentEvaluationHashes.domainHash(
          'eval-production-receipt-observation-v2',
          <String, Object?>{
            'trialSlotId': lease.trialSlotId,
            'attemptNo': evidenceAttemptNo,
            'value': productionValue,
          },
        ),
        evaluationBundleHash: manifest.evaluationBundleHash,
        proseHash: contentDigest,
        createdAtMs: _nowMs(),
      );
      ledger.appendObservation(
        lease: lease,
        observation: productionObservation,
      );
      evidenceKeys.add(productionObservation.evidenceKey);
    }
    final observationJson = AgentEvaluationHashes.canonicalJson(
      <String, Object?>{
        'terminalState': actual.terminalState.name,
        'failureCodes': actual.failureCodes.toList()..sort(),
        'accepted': actual.accepted,
        'sideEffectCounts': actual.sideEffectCounts,
        'evidenceComplete': actual.evidenceComplete,
        'contentDigest': contentDigest,
        'independence': independence.name,
        'isolationTrialId': isolationTrialId,
        'cacheSourceTrialSlotId': cacheSource,
        'productionStoryRunId': executionResult?.productionStoryRunId,
        'productionCandidateHash': executionResult?.productionCandidateHash,
        'productionReceiptId': executionResult?.productionReceiptId,
        'violations': comparison.violations.map((value) => value.name).toList()
          ..sort(),
      },
    );
    final evidenceHash = AgentEvaluationHashes.domainHash(
      'eval-outcome-observation-v1',
      jsonDecode(observationJson),
    );
    final observation = AgentEvaluationObservationInput(
      observationId: '${lease.trialSlotId}-outcome',
      attemptNo: evidenceAttemptNo,
      sequenceNo: requireGateEvidence ? (evidenceAttemptNo - 1) * 10 + 7 : 0,
      stageId: 'outcome',
      kind: 'comparison',
      itemKey: 'singleton',
      valueJson: observationJson,
      evidenceHash: evidenceHash,
      evaluationBundleHash: manifest.evaluationBundleHash,
      proseHash: contentDigest,
      createdAtMs: _nowMs(),
    );
    ledger.appendObservation(lease: lease, observation: observation);
    evidenceKeys.add(observation.evidenceKey);
    // The content attempt remains started until slot seal. The ledger commits
    // its terminal transition, sandbox generation, evidence root, and sealed
    // slot under one BEGIN IMMEDIATE transaction. A crash before that
    // transaction therefore leaves a reclaimable started attempt, never a
    // terminal attempt stranded in an unsealed slot.
    AgentEvaluationSandboxCommit? sandboxCommit;
    if (fixtureSandbox.isDurable && !indeterminateProviderCompletion) {
      final recoveryHead = ledger.readLatestSandboxRecoveryCheckpoint(
        executionId: lease.executionId,
        trialSlotId: lease.trialSlotId,
        attemptNo: evidenceAttemptNo,
        attemptRunId: contextRunId(lease, evidenceAttemptNo),
        cellId: lease.cellId,
        manifestHash: manifest.manifestHash,
        isolationTrialId: isolationTrialId,
        isolationMode: scenario.isolationMode,
      );
      if (recoveryHead != null) {
        fixtureSandbox.verifyRecoverySnapshot(
          databasePath: recoveryHead.databasePath,
          databaseFileHash: recoveryHead.databaseFileHash,
          databaseFileSize: recoveryHead.databaseFileSize,
          stateProjectionHash: recoveryHead.stateProjectionHash,
        );
      }
      final databaseFileHash = sandbox.closeAndHash();
      sandboxCommit = AgentEvaluationSandboxCommit(
        isolationTrialId: isolationTrialId,
        isolationMode: scenario.isolationMode,
        databasePath: sandbox.sealedDatabasePath,
        databaseFileHash: databaseFileHash,
        baseGenerationHash: latestGeneration?.generationHash,
      );
    } else if (fixtureSandbox.isDurable) {
      // The unsealed sandbox can contain a provider response that was never
      // checkpointed. Discard it instead of manufacturing production proof.
      sandbox.dispose();
    }
    final sealedResult = indeterminateProviderCompletion
        ? 'insufficientEvidence'
        : hardPass
        ? 'pass'
        : 'fail';
    ledger.sealSlot(
      lease: lease,
      result: sealedResult,
      expectedEvidence: evidenceKeys,
      sealedAtMs: _nowMs(),
      sandboxCommit: sandboxCommit,
      completeContentAttemptNo: executionResult == null
          ? null
          : evidenceAttemptNo,
    );
    if (fixtureSandbox.isDurable) {
      // This is intentionally after the atomic authority seal. Cleanup is
      // best-effort terminal hygiene: failures conservatively retain files and
      // can never fail the sealed slot or provoke a paid provider replay.
      final recoverySnapshotPaths = ledger
          .readTerminalSandboxRecoverySnapshotPaths(
            executionId: lease.executionId,
            trialSlotId: lease.trialSlotId,
          );
      sandbox.cleanupAfterTerminalSealBestEffort(
        recoverySnapshotPaths: recoverySnapshotPaths,
      );
    }
    progress('slot', status: sealedResult);
  }

  static String contextRunId(AgentEvaluationLease lease, int attemptNo) =>
      '${lease.trialSlotId}-attempt-$attemptNo';

  static String contextBundleHash(AgentEvaluationCellManifest cell) =>
      cell.generationBundleHash;

  Future<T> _runWithLeaseHeartbeat<T>({
    required AgentEvaluationLease lease,
    required int leaseDurationMs,
    required Future<T> Function() operation,
  }) async {
    Object? heartbeatFailure;
    final intervalMs = leaseDurationMs ~/ 3 < 10 ? 10 : leaseDurationMs ~/ 3;
    final timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (heartbeatFailure != null) return;
      try {
        ledger.renewLease(
          lease: lease,
          nowMs: _nowMs(),
          leaseDurationMs: leaseDurationMs,
        );
      } catch (error) {
        heartbeatFailure = error;
      }
    });
    try {
      final result = await operation();
      final failure = heartbeatFailure;
      if (failure != null) throw failure;
      // A final fenced read closes the race between the last heartbeat and
      // accepting a late provider response.
      ledger.performFencedMutation<void>(
        lease: lease,
        nowMs: _nowMs(),
        mutation: (_) {},
      );
      return result;
    } finally {
      timer.cancel();
    }
  }

  _AgentEvaluationAttemptResumeState _attemptResumeState({
    required AgentEvaluationLease lease,
    required bool requireGateEvidence,
  }) {
    final attempts = ledger.db.select(
      '''SELECT attempt_no, kind, status FROM eval_trial_attempts
         WHERE trial_slot_id = ? ORDER BY attempt_no''',
      <Object?>[lease.trialSlotId],
    );
    if (attempts.isEmpty) {
      return const _AgentEvaluationAttemptResumeState(
        attemptNo: 1,
        terminalAttemptCount: 0,
        persistedEvidenceKeys: <AgentEvaluationEvidenceKey>[],
      );
    }
    for (var index = 0; index < attempts.length; index += 1) {
      final row = attempts[index];
      if (row['attempt_no'] != index + 1) {
        throw const AgentEvaluationConflict(
          'trial attempt history is not contiguous',
        );
      }
    }
    final started = attempts
        .where((row) => row['status'] == 'started')
        .toList();
    if (started.length > 1 ||
        (started.isNotEmpty &&
            started.single['attempt_no'] != attempts.last['attempt_no']) ||
        attempts.any(
          (row) =>
              row['status'] != 'started' &&
              (row['status'] != 'failed' || row['kind'] != 'transport'),
        )) {
      throw const AgentEvaluationConflict(
        'trial attempt history cannot be resumed safely',
      );
    }
    final terminalAttemptCount = attempts.length - started.length;
    final attemptNo = started.isEmpty
        ? attempts.length + 1
        : started.single['attempt_no'] as int;
    final persistedEvidenceKeys = <AgentEvaluationEvidenceKey>[];
    if (requireGateEvidence && terminalAttemptCount > 0) {
      final rows = ledger.db.select(
        '''SELECT attempt_no, stage_id, kind, item_key
           FROM eval_observations
           WHERE trial_slot_id = ? AND attempt_no < ?
           ORDER BY attempt_no, sequence_no''',
        <Object?>[lease.trialSlotId, attemptNo],
      );
      persistedEvidenceKeys.addAll(
        rows.map(
          (row) => AgentEvaluationEvidenceKey(
            attemptNo: row['attempt_no'] as int,
            stageId: row['stage_id'] as String,
            kind: row['kind'] as String,
            itemKey: row['item_key'] as String,
          ),
        ),
      );
    }
    return _AgentEvaluationAttemptResumeState(
      attemptNo: attemptNo,
      terminalAttemptCount: terminalAttemptCount,
      lastTerminalAttemptNo: terminalAttemptCount == 0
          ? null
          : terminalAttemptCount,
      persistedEvidenceKeys: persistedEvidenceKeys,
    );
  }

  AgentEvaluationEvidenceKey _appendUsageObservation({
    required ExperimentManifest manifest,
    required AgentEvaluationLease lease,
    required int attemptNo,
    required AgentEvaluationAttemptUsage usage,
  }) {
    final value = usage.toJson();
    final evidenceHash = AgentEvaluationHashes.domainHash(
      'eval-attempt-usage-observation-v1',
      <String, Object?>{
        'trialSlotId': lease.trialSlotId,
        'attemptNo': attemptNo,
        'value': value,
      },
    );
    final observation = AgentEvaluationObservationInput(
      observationId: '${lease.trialSlotId}-usage-$attemptNo',
      attemptNo: attemptNo,
      sequenceNo: (attemptNo - 1) * 10,
      stageId: 'performance',
      kind: 'usage',
      itemKey: 'singleton',
      valueJson: AgentEvaluationHashes.canonicalJson(value),
      evidenceHash: evidenceHash,
      evaluationBundleHash: manifest.evaluationBundleHash,
      createdAtMs: _nowMs(),
    );
    ledger.appendObservation(lease: lease, observation: observation);
    return observation.evidenceKey;
  }

  AgentEvaluationEvidenceKey _appendJudgeInjectionObservation({
    required ExperimentManifest manifest,
    required AgentEvaluationLease lease,
    required int attemptNo,
    required AgentEvaluationJudgeInjectionSafetyReceipt receipt,
  }) {
    final value = receipt.toJson();
    final observation = AgentEvaluationObservationInput(
      observationId: '${lease.trialSlotId}-judge-injection-$attemptNo',
      attemptNo: attemptNo,
      sequenceNo: (attemptNo - 1) * 10 + 1,
      stageId: 'quality',
      kind: 'judge-injection',
      itemKey: 'singleton',
      valueJson: AgentEvaluationHashes.canonicalJson(value),
      evidenceHash: AgentEvaluationHashes.domainHash(
        'eval-judge-injection-observation-v1',
        <String, Object?>{
          'trialSlotId': lease.trialSlotId,
          'attemptNo': attemptNo,
          'receiptHash': receipt.receiptHash,
        },
      ),
      evaluationBundleHash: manifest.evaluationBundleHash,
      createdAtMs: _nowMs(),
    );
    ledger.appendObservation(lease: lease, observation: observation);
    return observation.evidenceKey;
  }

  ExpectedTrialOutcome _expectedOutcome(ScenarioRelease scenario) =>
      ExpectedTrialOutcome(
        terminalState: TrialTerminalState.values.firstWhere(
          (state) => state.name == scenario.expectedTerminalState,
        ),
        requiredFailureCodes: scenario.requiredFailureCodes.toSet(),
        allowedAdditionalFailureCodes: scenario.allowedAdditionalFailureCodes
            .toSet(),
        forbiddenFailureCodes: scenario.forbiddenFailureCodes.toSet(),
        acceptExpected: scenario.acceptExpected,
        forbiddenSideEffects: scenario.forbiddenSideEffects.toSet(),
      );

  void _throwIfStopped(
    AgentEvaluationCancellationToken cancellationToken,
    int? deadlineAtMs,
  ) {
    final now = _nowMs();
    if (cancellationToken.isCancelled) {
      throw _RunnerStopped(atMs: now, cancelled: true);
    }
    if (deadlineAtMs != null && now >= deadlineAtMs) {
      throw _RunnerStopped(atMs: now, cancelled: false);
    }
  }

  void _expireLease(AgentEvaluationLease lease, int nowMs) {
    try {
      ledger.performFencedMutation<void>(
        lease: lease,
        nowMs: nowMs,
        mutation: (database) => database.execute(
          '''UPDATE eval_trial_slots SET lease_expires_at_ms = ?, updated_at_ms = ?
             WHERE trial_slot_id = ? AND lease_epoch = ? AND lease_owner = ?''',
          <Object?>[nowMs, nowMs, lease.trialSlotId, lease.epoch, lease.owner],
        ),
      );
    } on AgentEvaluationLeaseLost {
      // A replacement worker already owns the slot; no further mutation is safe.
    }
  }

  void _markExecutionCancelled(String executionId, int nowMs) {
    ledger.db.execute(
      '''UPDATE eval_executions
         SET status = 'cancelled', started_at_ms = COALESCE(started_at_ms, created_at_ms),
           finished_at_ms = ?
         WHERE execution_id = ? AND status NOT IN ('completed', 'failed', 'cancelled')''',
      <Object?>[nowMs, executionId],
    );
  }

  AgentEvaluationRunReport _buildReport({
    required ExperimentManifest manifest,
    required String executionId,
    required bool cancelled,
    required bool deadlineExceeded,
  }) {
    final projectionReader = AgentEvaluationPass3ProjectionReader(ledger.db);
    final cellResults = <AgentEvaluationCellPass3Result>[];
    for (final cell in manifest.cells) {
      final projection = projectionReader.readCell(
        executionId: executionId,
        cellId: cell.cellId,
        evaluationBundleHash: manifest.evaluationBundleHash,
      );
      final eligible = manifest.trialsPerCell == 3 && projection.allSlotsSealed;
      cellResults.add(
        AgentEvaluationCellPass3Result(
          cellId: cell.cellId,
          scenarioReleaseHash: cell.scenarioReleaseHash,
          trialResults: projection.trialResults,
          pass3Eligible: eligible,
          passed: eligible && projection.result.passed,
          failureReasons: projection.result.failureReasons,
        ),
      );
    }
    final scenarioResults = <String, bool>{};
    for (final scenario in manifest.scenarioSet.scenarios) {
      final matching = cellResults.where(
        (cell) => cell.scenarioReleaseHash == scenario.releaseHash,
      );
      scenarioResults[scenario.releaseHash] =
          matching.isNotEmpty && matching.every((cell) => cell.passed);
    }
    return AgentEvaluationRunReport(
      executionId: executionId,
      cancelled: cancelled,
      deadlineExceeded: deadlineExceeded,
      cellPass3: List<AgentEvaluationCellPass3Result>.unmodifiable(cellResults),
      scenarioPass3: Map<String, bool>.unmodifiable(scenarioResults),
    );
  }
}

class _AgentEvaluationAttemptResumeState {
  const _AgentEvaluationAttemptResumeState({
    required this.attemptNo,
    required this.terminalAttemptCount,
    required this.persistedEvidenceKeys,
    this.lastTerminalAttemptNo,
  });

  final int attemptNo;
  final int terminalAttemptCount;
  final int? lastTerminalAttemptNo;
  final List<AgentEvaluationEvidenceKey> persistedEvidenceKeys;
}

class _RunnerStopped implements Exception {
  const _RunnerStopped({required this.atMs, required this.cancelled});

  final int atMs;
  final bool cancelled;
}

String _rawDigest(String value) =>
    value.startsWith('sha256:') ? value.substring(7) : value;
