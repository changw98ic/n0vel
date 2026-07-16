import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_providers.dart' as providers;
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/state/local_settings_file.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_metered_client.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_side_effects.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_runner.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/outcome_evaluation.dart';
import 'package:sqlite3/sqlite3.dart';

class RealAgentEvaluationAuthorization {
  RealAgentEvaluationAuthorization._({
    required this.runEnabled,
    required this.costAcknowledged,
    required this.providerName,
    required this.baseUrl,
    required this.apiKey,
    required this.requiredModels,
    required this.timeoutMs,
    required this.skipReason,
  });

  factory RealAgentEvaluationAuthorization.fromEnvironmentAndSettings(
    Map<String, String> environment,
    Map<String, String> settings,
  ) {
    const glm = providers.AppLlmProviderRegistry.zhipuCodingPlanCn;
    final runEnabled = environment['RUN_REAL_AGENT_EVAL'] == '1';
    final costAcknowledged = environment['REAL_LLM_COST_ACK'] == 'YES';
    final apiKey =
        environment['NOVEL_BENCHMARK_API_KEY'] ??
        environment['ZHIPU_API_KEY'] ??
        environment['ANTHROPIC_AUTH_TOKEN'] ??
        settings['ANTHROPIC_AUTH_TOKEN'] ??
        settings['apiKey'] ??
        '';
    final baseUrl =
        environment['NOVEL_BENCHMARK_BASE_URL'] ??
        environment['ZHIPU_BASE_URL'] ??
        settings['baseUrl'] ??
        glm.defaultBaseUrl;
    final modelSource =
        environment['AGENT_EVAL_REQUIRED_MODELS'] ??
        environment['NOVEL_BENCHMARK_MODEL'] ??
        environment['ZHIPU_MODEL'] ??
        settings['model'] ??
        'glm-5.1';
    final requiredModels = modelSource
        .split(',')
        .map((model) => model.trim())
        .where((model) => model.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final timeoutMs =
        int.tryParse(environment['REAL_AI_TIMEOUT_MS'] ?? '') ??
        int.tryParse(settings['timeoutMs'] ?? '') ??
        180000;
    final skipReason = AgentEvaluationRealProviderEntryGate.legacyDecision(
      entryPoint: 'test/test_support/real_agent_evaluation_harness.dart',
      environment: environment,
    ).denialReason;
    return RealAgentEvaluationAuthorization._(
      runEnabled: runEnabled,
      costAcknowledged: costAcknowledged,
      providerName: _providerNameForBaseUrl(baseUrl),
      baseUrl: baseUrl,
      apiKey: apiKey,
      requiredModels: List.unmodifiable(requiredModels),
      timeoutMs: timeoutMs.clamp(1000, 600000),
      skipReason: skipReason,
    );
  }

  static Future<RealAgentEvaluationAuthorization> resolve({
    required Map<String, String> environment,
    File? localSettingsFile,
  }) async {
    final settings = await loadLocalSettingsFile(file: localSettingsFile);
    return RealAgentEvaluationAuthorization.fromEnvironmentAndSettings(
      environment,
      settings,
    );
  }

  final bool runEnabled;
  final bool costAcknowledged;
  final String providerName;
  final String baseUrl;
  final String apiKey;
  final List<String> requiredModels;
  final int timeoutMs;
  final String? skipReason;

  bool get authorized => skipReason == null;

  Map<String, Object?> toSafeJson() => {
    'provider': providerName,
    'requiredModels': requiredModels,
    'timeoutMs': timeoutMs,
    'authorized': authorized,
  };
}

String _providerNameForBaseUrl(String baseUrl) {
  final path = Uri.tryParse(baseUrl.trim())?.path.toLowerCase() ?? '';
  return path.contains('/anthropic') ? '智谱 GLM (Anthropic protocol)' : '智谱 GLM';
}

class RealAgentEvaluationReleasePlan {
  RealAgentEvaluationReleasePlan._({
    required this.scenarios,
    required this.fixtureCount,
    required this.outlineSceneCount,
    required this.generationArms,
    required this.modelByRouteHash,
    required this.decodingConfigHash,
    required this.declaredCells,
    required this.trialsPerCell,
    required this.deadline,
    required this.maxProviderCalls,
    required this.maxTotalTokens,
  });

  factory RealAgentEvaluationReleasePlan.create({
    required List<String> requiredModels,
    Duration deadline = const Duration(minutes: 90),
    int? maxProviderCalls,
    int? maxTotalTokens,
  }) {
    final scenarios = _releaseScenarios();
    final champion = StoryPromptRegistry.current();
    final challenger = StoryPromptRegistry.causalityChallenger();
    final generationArms = <String, String>{
      'champion': _rawDigest(champion.generationBundle.bundleHash),
      'challenger': _rawDigest(challenger.generationBundle.bundleHash),
    };
    final modelByRouteHash = <String, String>{
      for (final model in requiredModels)
        AgentEvaluationMeteredAppLlmClient.modelRouteHashFor(model): model,
    };
    final decodingConfigHash = _digest('decoding-config', 'release-v1');
    final cells = ExperimentManifest.expandCanonicalCells(
      generationBundleHashes: generationArms.values,
      modelRouteHashes: modelByRouteHash.keys,
      scenarios: scenarios,
      decodingConfigHashes: [decodingConfigHash],
    );
    final expectedCalls = cells.length * 3;
    return RealAgentEvaluationReleasePlan._(
      scenarios: List.unmodifiable(scenarios),
      fixtureCount: 10,
      outlineSceneCount: 10,
      generationArms: Map.unmodifiable(generationArms),
      modelByRouteHash: Map.unmodifiable(modelByRouteHash),
      decodingConfigHash: decodingConfigHash,
      declaredCells: List.unmodifiable(cells),
      trialsPerCell: 3,
      deadline: deadline,
      maxProviderCalls: maxProviderCalls ?? expectedCalls,
      maxTotalTokens: maxTotalTokens ?? expectedCalls * 1024,
    );
  }

  final List<ScenarioRelease> scenarios;
  final int fixtureCount;
  final int outlineSceneCount;
  final Map<String, String> generationArms;
  final Map<String, String> modelByRouteHash;
  final String decodingConfigHash;
  final List<AgentEvaluationCellManifest> declaredCells;
  final int trialsPerCell;
  final Duration deadline;
  final int maxProviderCalls;
  final int maxTotalTokens;

  int get expectedProviderCalls => declaredCells.length * trialsPerCell;

  RealAgentEvaluationReleasePlan copyWith({
    List<AgentEvaluationCellManifest>? declaredCells,
  }) => RealAgentEvaluationReleasePlan._(
    scenarios: scenarios,
    fixtureCount: fixtureCount,
    outlineSceneCount: outlineSceneCount,
    generationArms: generationArms,
    modelByRouteHash: modelByRouteHash,
    decodingConfigHash: decodingConfigHash,
    declaredCells: List.unmodifiable(declaredCells ?? this.declaredCells),
    trialsPerCell: trialsPerCell,
    deadline: deadline,
    maxProviderCalls: maxProviderCalls,
    maxTotalTokens: maxTotalTokens,
  );

  void preflight() {
    final expectedEpisodeSteps = {
      for (var step = 1; step <= 10; step += 1) step,
    };
    final actualEpisodeSteps = scenarios
        .map((scenario) => scenario.episodeStep)
        .toSet();
    if (scenarios.length != 10 ||
        fixtureCount != 10 ||
        outlineSceneCount != 10 ||
        scenarios.any(
          (scenario) => scenario.episodeId != 'release-episode-1',
        ) ||
        actualEpisodeSteps.length != expectedEpisodeSteps.length ||
        !actualEpisodeSteps.containsAll(expectedEpisodeSteps) ||
        generationArms.keys.toSet().difference({
          'champion',
          'challenger',
        }).isNotEmpty ||
        generationArms.length != 2 ||
        modelByRouteHash.isEmpty ||
        trialsPerCell != 3 ||
        deadline <= Duration.zero ||
        maxProviderCalls < expectedProviderCalls ||
        maxTotalTokens <= 0) {
      throw StateError('real evaluation release plan is incomplete');
    }
    final expected = ExperimentManifest.expandCanonicalCells(
      generationBundleHashes: generationArms.values,
      modelRouteHashes: modelByRouteHash.keys,
      scenarios: scenarios,
      decodingConfigHashes: [decodingConfigHash],
    );
    final expectedIds = expected.map((cell) => cell.cellId).toList();
    final actualIds = declaredCells.map((cell) => cell.cellId).toList();
    if (actualIds.toSet().length != actualIds.length ||
        !_sameStrings(expectedIds, actualIds)) {
      throw StateError(
        'releaseScenarioSet × model × arm matrix is missing or duplicated',
      );
    }
  }

  ExperimentManifest manifest() {
    final scenarioSet = ScenarioSetRelease(
      setId: 'real-agent-release-episode',
      version: '1.0.0',
      scenarios: scenarios,
      fixtureCount: fixtureCount,
      outlineSceneCount: outlineSceneCount,
      holdout: false,
      createdAtMs: 1,
    );
    return ExperimentManifest(
      experimentId:
          'real-agent-eval-${scenarioSet.releaseHash.substring(0, 12)}',
      scenarioSet: scenarioSet,
      generationBundleHashes: generationArms.values.toList(),
      evaluationBundleHash: _evaluationBundleHash,
      modelRouteHashes: modelByRouteHash.keys.toList(),
      decodingConfigHashes: [decodingConfigHash],
      cells: declaredCells,
      pipelineConfigHash: _digest('pipeline', 'production-story-pipeline'),
      providerConfigHashWithoutSecrets: _digest('provider', 'glm'),
      providerApiRevision: 'glm-api-release-v1',
      sdkAdapterReleaseHash: _digest('adapter', 'app-llm-v1'),
      tokenizerReleaseHash: _digest('tokenizer', 'provider-reported-v1'),
      priceTableHash: _digest('price', 'unpriced-smoke-v1'),
      codeCommit: 'workspace-build',
      sourceTreeHash: _digest('source-tree', 'workspace-build'),
      buildArtifactHash: _buildArtifactHash,
      runtimeReleaseHash: _digest('runtime', 'dart-flutter-v1'),
      trialsPerCell: trialsPerCell,
      seedPolicy: const {'mode': 'provider-recorded'},
      trialIsolationPolicy: const {
        'mode': 'episode-fixture-snapshot',
        'episodeSceneCount': 10,
      },
      transportAttemptPolicy: const {'maxAttempts': 1},
      performanceSamplingPolicy: const {'minimumPairedSamples': 20},
      qualityComparisonPolicyHash: _digest('quality-policy', 'release-v1'),
      holdoutAccessPolicy: HoldoutAccessPolicy(
        policyHash: _digest('holdout-policy', 'not-holdout'),
        accessBudget: 0,
        accessOrdinal: 0,
      ),
      budgets: {
        'maxProviderCalls': maxProviderCalls,
        'maxTotalTokens': maxTotalTokens,
        'deadlineMs': deadline.inMilliseconds,
      },
      qualityThresholds: const {'claimScope': 'real-provider-matrix-smoke'},
      createdAtMs: 1,
    );
  }
}

enum RealAgentEvaluationExecutionMode { realProvider, testDouble }

enum RealAgentEvaluationRunStatus { skipped, completed }

class RealAgentEvaluationProgress {
  const RealAgentEvaluationProgress({
    required this.scenarioId,
    required this.trialNo,
    required this.stage,
    required this.elapsedMs,
    required this.calls,
    required this.tokens,
    required this.status,
  });

  final String scenarioId;
  final int trialNo;
  final String stage;
  final int elapsedMs;
  final int calls;
  final int tokens;
  final String status;

  String get safeLine =>
      'scenario=$scenarioId trial=$trialNo stage=$stage elapsedMs=$elapsedMs '
      'calls=$calls tokens=$tokens status=$status';
}

class RealAgentEvaluationRunResult {
  const RealAgentEvaluationRunResult({
    required this.status,
    required this.realProviderEvidence,
    required this.releasePassed,
    required this.providerCalls,
    required this.totalTokens,
    required this.totalLatencyMs,
    required this.jsonReportPath,
    required this.markdownReportPath,
    required this.skipReason,
  });

  final RealAgentEvaluationRunStatus status;
  final bool realProviderEvidence;
  final bool releasePassed;
  final int providerCalls;
  final int totalTokens;
  final int totalLatencyMs;
  final String? jsonReportPath;
  final String? markdownReportPath;
  final String? skipReason;
}

class RealAgentEvaluationHarness {
  RealAgentEvaluationHarness({
    required this.authorization,
    required this.plan,
    required this.providerClient,
    required this.executionMode,
    this.outputDirectory,
    this.onProgress,
  });

  final RealAgentEvaluationAuthorization authorization;
  final RealAgentEvaluationReleasePlan plan;
  final AppLlmClient providerClient;
  final RealAgentEvaluationExecutionMode executionMode;
  final Directory? outputDirectory;
  final void Function(RealAgentEvaluationProgress progress)? onProgress;

  Directory? _workDirectory;
  Database? _authorityDb;
  AgentEvaluationFixtureSandbox? _fixtureSandbox;
  var _disposed = false;

  Future<RealAgentEvaluationRunResult> run() async {
    if (_disposed) throw StateError('real evaluation harness is disposed');
    if (!authorization.authorized) {
      return RealAgentEvaluationRunResult(
        status: RealAgentEvaluationRunStatus.skipped,
        realProviderEvidence: false,
        releasePassed: false,
        providerCalls: 0,
        totalTokens: 0,
        totalLatencyMs: 0,
        jsonReportPath: null,
        markdownReportPath: null,
        skipReason: authorization.skipReason,
      );
    }
    plan.preflight();
    _initialize();
    final manifest = plan.manifest();
    var providerCalls = 0;
    var totalTokens = 0;
    var totalLatencyMs = 0;
    final executionId =
        'real-agent-eval-${DateTime.now().microsecondsSinceEpoch}';
    final startedAt = DateTime.now();
    final deadlineAtMs = startedAt.add(plan.deadline).millisecondsSinceEpoch;
    final runner = AgentEvaluationRunner(
      manifestStore: AgentEvaluationManifestStore(db: _authorityDb!),
      ledger: AgentEvaluationLedger(db: _authorityDb!),
      fixtureSandbox: _fixtureSandbox!,
    );
    final report = await runner.run(
      manifest: manifest,
      executionId: executionId,
      workerId: 'real-agent-eval-worker',
      actualBuildArtifactHash: manifest.buildArtifactHash,
      verifierExists: _knownVerifierRefs.contains,
      cancellationToken: AgentEvaluationCancellationToken(),
      deadlineAtMs: deadlineAtMs,
      onProgress: (progress) {
        onProgress?.call(
          RealAgentEvaluationProgress(
            scenarioId: progress.scenarioId,
            trialNo: progress.trialNo,
            stage: progress.stage,
            elapsedMs: progress.elapsedMs,
            calls: providerCalls,
            tokens: totalTokens,
            status: progress.latestStatus,
          ),
        );
      },
      trialExecutor: (context) async {
        if (providerCalls >= plan.maxProviderCalls) {
          throw StateError('frozen provider call budget exceeded');
        }
        final model = plan.modelByRouteHash[context.cell.modelRouteHash];
        if (model == null) throw StateError('unknown frozen model route');
        final promptRegistry = _promptRegistryForArm(
          context.cell.generationBundleHash,
        );
        final release = promptRegistry.resolve(
          stageId: 'editorial',
          callSiteId: 'scene-editorial-generator',
          variantId: 'zh',
        );
        context.reportStage('scene-generation', status: 'dispatch');
        providerCalls += 1;
        final stopwatch = Stopwatch()..start();
        final response = await providerClient.chat(
          AppLlmChatRequest(
            baseUrl: authorization.baseUrl,
            apiKey: authorization.apiKey,
            model: model,
            provider: authorization.providerName.toAppLlmProvider(),
            timeout: AppLlmTimeoutConfig.uniform(authorization.timeoutMs),
            maxTokens: 512,
            messages: [
              AppLlmChatMessage(
                role: 'system',
                content: release.systemTemplate,
              ),
              AppLlmChatMessage(
                role: 'user',
                content: context.scenario.inputFixture['prompt']! as String,
              ),
            ],
          ),
        );
        stopwatch.stop();
        totalLatencyMs += response.latencyMs ?? stopwatch.elapsedMilliseconds;
        final promptTokens = response.promptTokens;
        final completionTokens = response.completionTokens;
        if (promptTokens == null || completionTokens == null) {
          throw StateError(
            'real evaluation requires exact provider prompt/completion tokens',
          );
        }
        final usedTokens = promptTokens + completionTokens;
        totalTokens += usedTokens;
        if (totalTokens > plan.maxTotalTokens) {
          throw StateError('frozen token budget exceeded');
        }
        if (!response.succeeded) {
          throw AgentEvaluationTransportException(
            response.failureKind?.name ?? 'provider failure',
          );
        }
        context.reportStage('deterministic-verification', status: 'complete');
        final hasContent = (response.text ?? '').trim().isNotEmpty;
        return AgentEvaluationTrialExecutionResult(
          outcome: ActualTrialOutcome(
            terminalState: hasContent
                ? TrialTerminalState.accepted
                : TrialTerminalState.failed,
            failureCodes: hasContent
                ? const {}
                : const {'provider.invalid_content'},
            accepted: hasContent,
            evidenceComplete: true,
          ),
          evaluatedContent: response.text ?? '',
        );
      },
    );
    final releasePassed =
        !report.cancelled &&
        !report.deadlineExceeded &&
        report.cellPass3.isNotEmpty &&
        report.cellPass3.every((cell) => cell.passed);
    final paths = _writeReports(
      executionId: executionId,
      report: report,
      providerCalls: providerCalls,
      totalTokens: totalTokens,
      totalLatencyMs: totalLatencyMs,
      releasePassed: releasePassed,
      startedAt: startedAt,
    );
    return RealAgentEvaluationRunResult(
      status: RealAgentEvaluationRunStatus.completed,
      realProviderEvidence:
          executionMode == RealAgentEvaluationExecutionMode.realProvider &&
          providerCalls > 0,
      releasePassed: releasePassed,
      providerCalls: providerCalls,
      totalTokens: totalTokens,
      totalLatencyMs: totalLatencyMs,
      jsonReportPath: paths.$1,
      markdownReportPath: paths.$2,
      skipReason: null,
    );
  }

  void _initialize() {
    if (_authorityDb != null) return;
    final work = Directory.systemTemp.createTempSync('real-agent-eval-work-');
    _workDirectory = work;
    try {
      final authority = sqlite3.open('${work.path}/authority.sqlite');
      authority.execute('PRAGMA foreign_keys = ON');
      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations,
      ).ensureSchema(authority);
      _authorityDb = authority;
      _seedPublishedBundles(authority, plan.generationArms.values);
      final fixturePath = '${work.path}/fixture.sqlite';
      final fixture = sqlite3.open(fixturePath);
      fixture.execute(
        'CREATE TABLE episode_state (step INTEGER PRIMARY KEY, value TEXT)',
      );
      fixture.dispose();
      final productionPath = '${work.path}/production.sqlite';
      sqlite3.open(productionPath).dispose();
      _fixtureSandbox = AgentEvaluationFixtureSandbox.create(
        fixtureDatabasePath: fixturePath,
        productionDatabasePath: productionPath,
        temporaryParent: work,
      );
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  (String, String) _writeReports({
    required String executionId,
    required AgentEvaluationRunReport report,
    required int providerCalls,
    required int totalTokens,
    required int totalLatencyMs,
    required bool releasePassed,
    required DateTime startedAt,
  }) {
    final directory =
        outputDirectory ??
        Directory.systemTemp.createTempSync('real-agent-eval-report-');
    directory.createSync(recursive: true);
    final safePayload = <String, Object?>{
      'reportType':
          executionMode == RealAgentEvaluationExecutionMode.realProvider
          ? 'real-provider-matrix-smoke'
          : 'test-double-matrix-smoke',
      'claimScope': 'provider-execution-and-pass3-smoke',
      'releaseEligible': false,
      'realProviderEvidence':
          executionMode == RealAgentEvaluationExecutionMode.realProvider &&
          providerCalls > 0,
      'executionId': executionId,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'provider': authorization.toSafeJson(),
      'matrix': {
        'scenarioCount': plan.scenarios.length,
        'fixtureCount': plan.fixtureCount,
        'outlineSceneCount': plan.outlineSceneCount,
        'requiredModelCount': plan.modelByRouteHash.length,
        'generationArms': plan.generationArms.keys.toList()..sort(),
        'trialsPerCell': plan.trialsPerCell,
        'cellCount': plan.declaredCells.length,
        'expectedProviderCalls': plan.expectedProviderCalls,
      },
      'execution': {
        'providerCalls': providerCalls,
        'totalTokens': totalTokens,
        'totalLatencyMs': totalLatencyMs,
        'cancelled': report.cancelled,
        'deadlineExceeded': report.deadlineExceeded,
        'cellPass3Passed': report.cellPass3.where((cell) => cell.passed).length,
        'cellPass3Total': report.cellPass3.length,
        'releasePassed': releasePassed,
      },
    };
    final jsonPath = '${directory.path}/agent-evaluation-release-report.json';
    final markdownPath = '${directory.path}/agent-evaluation-release-report.md';
    File(jsonPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(safePayload),
    );
    File(markdownPath).writeAsStringSync(
      [
        '# Agent Evaluation Smoke Matrix',
        '',
        '- Claim scope: provider execution and Pass³ smoke',
        '- Release eligible: false',
        '- Real provider evidence: ${safePayload['realProviderEvidence']}',
        '- Execution: `$executionId`',
        '- Scenarios: ${plan.scenarios.length}',
        '- Models: ${plan.modelByRouteHash.length}',
        '- Arms: champion, challenger',
        '- Trials per cell: ${plan.trialsPerCell}',
        '- Expected provider calls: ${plan.expectedProviderCalls}',
        '- Actual provider calls: $providerCalls',
        '- Total tokens: $totalTokens',
        '- Total latency ms: $totalLatencyMs',
        '- Cell Pass³: ${report.cellPass3.where((cell) => cell.passed).length}/${report.cellPass3.length}',
        '- Smoke matrix passed: $releasePassed',
      ].join('\n'),
    );
    return (jsonPath, markdownPath);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _fixtureSandbox?.dispose();
    _fixtureSandbox = null;
    _authorityDb?.dispose();
    _authorityDb = null;
    final work = _workDirectory;
    if (work != null && work.existsSync()) work.deleteSync(recursive: true);
    _workDirectory = null;
  }
}

StoryPromptRegistry _promptRegistryForArm(String generationBundleHash) {
  final champion = StoryPromptRegistry.current();
  if (_rawDigest(champion.generationBundle.bundleHash) ==
      generationBundleHash) {
    return champion;
  }
  final challenger = StoryPromptRegistry.causalityChallenger();
  if (_rawDigest(challenger.generationBundle.bundleHash) ==
      generationBundleHash) {
    return challenger;
  }
  throw StateError('unknown executable generation arm');
}

String _rawDigest(String value) {
  const prefix = 'sha256:';
  final raw = value.startsWith(prefix) ? value.substring(prefix.length) : value;
  AgentEvaluationHashes.requireDigest(raw, 'generationBundleHash');
  return raw;
}

const _knownVerifierRefs = {
  'real-content-verifier@1.0.0',
  'real-quality-rubric@1.0.0',
  'expected-outcome-comparator@1.0.0',
};
final _evaluationBundleHash = _digest('evaluation-bundle', 'real-release-v1');
final _buildArtifactHash = _digest('build-artifact', 'workspace-build');

List<ScenarioRelease> _releaseScenarios() => [
  for (var step = 1; step <= 10; step += 1)
    ScenarioRelease(
      scenarioId: 'release-episode-scene-$step',
      version: '1.0.0',
      difficulty: 'release',
      inputFixture: {
        'episodeId': 'release-episode-1',
        'episodeStep': step,
        'prompt':
            '第 $step 场：调查者在旧港追查被篡改的门禁记录。'
            '写出一个有行动、对白、因果推进和场尾压力的短场景。',
      },
      fixtureHash: _digest('release-fixture', 'scene-$step'),
      isolationMode: 'episode',
      episodeId: 'release-episode-1',
      episodeStep: step,
      requiredCapabilities: const ['story-generation'],
      adversarialMutations: const ['none-release-control'],
      verifierReleaseRefs: const ['real-content-verifier@1.0.0'],
      rubricReleaseRef: 'real-quality-rubric@1.0.0',
      expectedTerminalState: 'accepted',
      requiredFailureCodes: const [],
      allowedAdditionalFailureCodes: const [],
      forbiddenFailureCodes: const ['provider.invalid_content'],
      outcomeComparatorReleaseRef: 'expected-outcome-comparator@1.0.0',
      forbiddenSideEffects: const <String>[
        AgentEvaluationProductionSideEffectKeys.authoritativeWrite,
      ],
      acceptExpected: true,
      referenceFacts: {'episodeStep': step},
      maxBudget: const {'calls': 1, 'maxTokens': 512},
    ),
];

void _seedPublishedBundles(Database db, Iterable<String> bundleHashes) {
  var ordinal = 0;
  for (final hash in bundleHashes) {
    db.execute(
      '''INSERT INTO generation_bundles (
           bundle_hash, bundle_id, releases_json, created_at_ms
         ) VALUES (?, ?, '[]', 1)''',
      [hash, 'real-release-arm-${ordinal++}'],
    );
  }
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'real-release-evaluator', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    [
      _evaluationBundleHash,
      _digest('rubric', 'real-v1'),
      _digest('aggregator', 'real-v1'),
      _digest('taxonomy', 'real-v1'),
    ],
  );
}

String _digest(String domain, String value) =>
    AgentEvaluationHashes.domainHash('real-agent-eval-$domain-v1', value);

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
