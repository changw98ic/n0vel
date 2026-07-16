import 'dart:async';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../../../../app/di/service_registration.dart';
import '../../../../app/di/service_registry.dart';
import '../../../../app/events/app_event_bus.dart';
import '../../../../app/llm/app_llm_client_contract.dart';
import '../../../../app/llm/app_llm_client_types.dart';
import '../../../../app/llm/app_llm_request_pool.dart';
import '../../../../app/logging/app_event_log.dart';
import '../../../../app/logging/app_event_log_storage.dart';
import '../../../../app/rag/hybrid_retriever.dart';
import '../../../../app/state/app_draft_storage_io.dart';
import '../../../../app/state/app_draft_storage.dart';
import '../../../../app/state/app_draft_store.dart';
import '../../../../app/state/app_scene_context_storage.dart';
import '../../../../app/state/app_scene_context_storage_io.dart';
import '../../../../app/state/app_scene_context_store.dart';
import '../../../../app/state/app_settings_storage.dart';
import '../../../../app/state/app_settings_store.dart';
import '../../../../app/state/app_version_storage_io.dart';
import '../../../../app/state/app_version_storage.dart';
import '../../../../app/state/app_version_store.dart';
import '../../../../app/state/app_workspace_storage.dart';
import '../../../../app/state/app_workspace_storage_io.dart';
import '../../../../app/state/app_workspace_store.dart';
import '../../../../app/state/project_storage.dart';
import '../../../../app/state/story_generation_run_storage_io.dart';
import '../../../../app/state/story_generation_run_store.dart';
import '../../../../app/state/story_generation_storage_io.dart';
import '../../../../app/state/story_generation_storage.dart';
import '../../../../app/state/story_generation_store.dart';
import '../../../../app/state/story_outline_storage.dart';
import '../../../../app/state/story_outline_storage_io.dart';
import '../../../../app/state/story_outline_store.dart';
import '../../../author_feedback/data/author_feedback_storage_io.dart';
import '../../../author_feedback/data/author_feedback_storage.dart';
import '../../../author_feedback/data/author_feedback_store.dart';
import '../../../review_tasks/data/review_task_storage.dart';
import '../../../review_tasks/data/review_task_storage_io.dart';
import '../../../review_tasks/data/review_task_store.dart';
import '../character_memory_store_io.dart';
import '../character_memory_store.dart';
import '../generation_commit_coordinator.dart';
import '../generation_ledger.dart';
import '../generation_ledger_candidate_finalizer.dart';
import '../generation_outbox_worker.dart';
import '../roleplay_session_store.dart';
import '../roleplay_session_store_io.dart';
import '../story_memory_storage.dart';
import '../story_memory_storage_io.dart';
import '../story_pipeline_factory.dart';
import '../story_prompt_registry.dart';
import 'agent_evaluation_metered_client.dart';
import 'agent_evaluation_execution_budget.dart';
import 'agent_evaluation_production_evidence.dart';
import 'agent_evaluation_production_executor.dart';
import 'agent_evaluation_runner.dart';
import 'agent_evaluation_trace_context.dart';

/// Builds the normal application story pipeline inside one evaluation sandbox.
///
/// The authoritative trial database is borrowed from
/// [AgentEvaluationTrialContext]. Normal app input stores retain their existing
/// path-based, short-handle adapters; every operation is awaited and fenced as
/// a sandbox owner until that adapter closes its handle. All other durable
/// pipeline dependencies resolve against the borrowed authoritative database.
/// No default authoring path is opened by this factory.
final class AgentEvaluationAppRuntimeFactory
    implements AgentEvaluationProductionRuntimeFactory {
  const AgentEvaluationAppRuntimeFactory({
    this.executionBudget,
    this.maxTokensPerCall,
  });

  final AgentEvaluationExecutionBudgetGuard? executionBudget;
  final int? maxTokensPerCall;

  @override
  Future<AgentEvaluationProductionRuntime> open({
    required AgentEvaluationTrialContext context,
    required StoryPromptRegistry promptRegistry,
    required AgentEvaluationProductionRouteRelease route,
    required AgentEvaluationProductionDecodingRelease decoding,
    required AppLlmClient providerClient,
  }) async {
    final databasePath = context.sandboxDatabasePath?.trim();
    if (databasePath == null || databasePath.isEmpty) {
      throw const AgentEvaluationProductionEvidenceException(
        'app production runtime requires a sandbox database path',
      );
    }
    _validateFrozenArm(context, promptRegistry, route, decoding);
    int? maxCallsPerAttempt;
    int? maxTokensPerAttempt;
    if (executionBudget != null) {
      final frozenMaxCalls = context.scenario.maxBudget['calls'];
      final frozenMaxTokens =
          context.scenario.maxBudget['maxTokens'] ??
          context.scenario.maxBudget['tokens'];
      if (frozenMaxCalls is! int ||
          frozenMaxCalls <= 0 ||
          frozenMaxTokens is! int ||
          frozenMaxTokens <= 0) {
        throw const AgentEvaluationProductionEvidenceException(
          'release app runtime requires frozen attempt call/token caps',
        );
      }
      maxCallsPerAttempt = frozenMaxCalls;
      maxTokensPerAttempt = frozenMaxTokens;
    }

    final meter = AgentEvaluationMeteredAppLlmClient(
      inner: providerClient,
      model: route.model,
      provider: route.provider,
      baseUrl: route.baseUrl,
      frozenModelRouteHash: route.modelRouteHash,
      frozenTimeout: route.timeout,
      frozenApiKey: route.apiKey,
      executionBudget: executionBudget,
      frozenMaxCompletionTokens: maxTokensPerCall,
      maxCallsPerAttempt: maxCallsPerAttempt,
      maxTokensPerAttempt: maxTokensPerAttempt,
      returnFailedResultAfterAccounting: true,
    );
    final traceSink = AgentEvaluationAttemptTraceSink();
    final eventBus = AppEventBus();
    final eventLog = AppEventLog(
      storage: const _MemoryOnlyEventLogStorage(),
      sessionId: 'agent-eval-${context.isolationTrialId}',
    );
    final requestPool = AppLlmRequestPool(
      maxConcurrent: decoding.maxConcurrentRequests,
    );
    final runtimeClient = maxTokensPerCall == null
        ? meter
        : _EvaluationMaxTokenClient(
            delegate: meter,
            maxTokensPerCall: maxTokensPerCall!,
          );
    final settingsStore = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: runtimeClient,
      requestPool: requestPool,
      eventLog: eventLog,
      eventBus: eventBus,
      llmTraceSink: traceSink,
    );
    final saved = await settingsStore.save(
      providerName: route.provider.name,
      baseUrl: route.baseUrl,
      model: route.model,
      apiKey: route.apiKey,
      timeout: route.timeout,
      maxConcurrentRequests: decoding.maxConcurrentRequests,
      maxTokens: maxTokensPerCall,
      notify: false,
    );
    if (!saved.succeededWithoutWarnings ||
        settingsStore.snapshot.model != route.model ||
        (maxTokensPerCall != null &&
            settingsStore.snapshot.maxTokens != maxTokensPerCall) ||
        settingsStore.snapshot.providerName.toAppLlmProvider() !=
            route.provider) {
      settingsStore.dispose();
      eventBus.dispose();
      throw const AgentEvaluationProductionEvidenceException(
        'app settings could not preserve the frozen production route',
      );
    }

    final inputState = await _EvaluationInputState.load(
      context: context,
      databasePath: databasePath,
      fixture: context.scenario.inputFixture,
    );
    final workspaceStore = AppWorkspaceStore(
      storage: inputState.workspaceStorage,
      eventBus: eventBus,
    );
    final draftStore = AppDraftStore(
      storage: inputState.draftStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );
    final versionStore = AppVersionStore(
      storage: inputState.versionStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );
    final outlineStore = StoryOutlineStore(
      storage: inputState.outlineStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );
    final generationStore = StoryGenerationStore(
      storage: inputState.generationStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );
    final sceneContextStore = AppSceneContextStore(
      storage: inputState.sceneContextStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );
    final authorFeedbackStore = AuthorFeedbackStore(
      storage: inputState.authorFeedbackStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );
    final reviewTaskStore = ReviewTaskStore(
      storage: inputState.reviewTaskStorage,
      workspaceStore: workspaceStore,
      eventBus: eventBus,
    );

    final registry = ServiceRegistry()
      ..registerSingleton<sqlite3.Database>(context.database, owned: false)
      ..registerSingleton<AppEventBus>(eventBus)
      ..registerSingleton<AppEventLog>(eventLog)
      ..registerSingleton<AppLlmClient>(runtimeClient, owned: false)
      ..registerSingleton<AppLlmRequestPool>(requestPool)
      ..registerSingleton<StoryPromptRegistry>(promptRegistry, owned: false)
      ..registerSingleton<AppSettingsStore>(settingsStore)
      ..registerSingleton<AppWorkspaceStore>(workspaceStore)
      ..registerSingleton<AppDraftStore>(draftStore)
      ..registerSingleton<AppVersionStore>(versionStore)
      ..registerSingleton<StoryOutlineStore>(outlineStore)
      ..registerSingleton<StoryGenerationStore>(generationStore)
      ..registerSingleton<AppSceneContextStore>(sceneContextStore)
      ..registerSingleton<AuthorFeedbackStore>(authorFeedbackStore)
      ..registerSingleton<ReviewTaskStore>(reviewTaskStore)
      ..registerSingleton<StoryGenerationLifecycleRunIdFactory>(
        _formalLifecycleRunId,
        owned: false,
      );

    final runStorage = SqliteStoryGenerationRunStorage.borrowed(
      context.database,
    );
    final runtimeOwnerId = 'app-runtime:${context.runId}';
    context.acquireSandboxConnectionOwner?.call(runtimeOwnerId);
    try {
      registerAppServices(registry);
      _registerIsolatedRunStore(registry, storage: runStorage);
      _validateDurableServices(
        registry,
        context.database,
        runStorage: runStorage,
        shortConnectionFence: inputState.shortConnectionFence,
      );
      await generationStore.ready;
      await authorFeedbackStore.ready;
      await reviewTaskStore.ready;
      await inputState.waitUntilApplied(
        workspaceStore: workspaceStore,
        draftStore: draftStore,
        versionStore: versionStore,
        outlineStore: outlineStore,
        generationStore: generationStore,
        sceneContextStore: sceneContextStore,
        authorFeedbackStore: authorFeedbackStore,
        reviewTaskStore: reviewTaskStore,
      );
      final runStore = registry.resolve<StoryGenerationRunStore>();
      await runStore.ready;
      return _AgentEvaluationAppRuntime(
        registry: registry,
        database: context.database,
        databasePath: databasePath,
        isolationTrialId: context.isolationTrialId,
        generationBundleHash: context.cell.generationBundleHash,
        modelRouteHash: context.cell.modelRouteHash,
        decodingConfigHash: context.cell.decodingConfigHash,
        initialIsolationMode: context.scenario.isolationMode,
        promptRegistry: promptRegistry,
        workspaceStore: workspaceStore,
        inputState: inputState,
        draftStore: draftStore,
        versionStore: versionStore,
        outlineStore: outlineStore,
        generationStore: generationStore,
        sceneContextStore: sceneContextStore,
        authorFeedbackStore: authorFeedbackStore,
        reviewTaskStore: reviewTaskStore,
        runStore: runStore,
        runStorage: runStorage,
        shortConnectionFence: inputState.shortConnectionFence,
        releaseConnectionOwner: context.releaseSandboxConnectionOwner == null
            ? null
            : () => context.releaseSandboxConnectionOwner!(runtimeOwnerId),
        meter: meter,
        traceSink: traceSink,
      );
    } catch (_) {
      try {
        registry.disposeAll();
      } finally {
        try {
          await inputState.shortConnectionFence.close();
        } finally {
          try {
            runStorage.dispose();
          } finally {
            context.releaseSandboxConnectionOwner?.call(runtimeOwnerId);
          }
        }
      }
      rethrow;
    }
  }
}

final class _EvaluationMaxTokenClient implements AppLlmClient {
  const _EvaluationMaxTokenClient({
    required this.delegate,
    required this.maxTokensPerCall,
  });

  final AppLlmClient delegate;
  final int maxTokensPerCall;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) {
    final requested = request.maxTokens;
    if (maxTokensPerCall < AppLlmChatRequest.defaultMaxTokens ||
        maxTokensPerCall > AppLlmChatRequest.maximumMaxTokens) {
      throw StateError(
        'frozen token ceiling cannot be represented by transport normalization',
      );
    }
    if (requested < AppLlmChatRequest.unlimitedMaxTokens) {
      throw StateError('production request has an invalid token limit');
    }
    final bounded = requested == AppLlmChatRequest.unlimitedMaxTokens
        ? maxTokensPerCall
        : AppLlmChatRequest.normalizeMaxTokens(requested);
    if (bounded > maxTokensPerCall) {
      throw StateError('production request exceeds the frozen token ceiling');
    }
    // llm-call-site: boundary.evaluation.max-token
    return delegate.chat(
      AppLlmChatRequest(
        baseUrl: request.baseUrl,
        apiKey: request.apiKey,
        model: request.model,
        timeout: request.timeout,
        maxTokens: bounded,
        messages: request.messages,
        provider: request.provider,
        onPartialText: request.onPartialText,
        formalCacheIdentity: request.formalCacheIdentity,
      ),
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

void _registerIsolatedRunStore(
  ServiceRegistry registry, {
  required SqliteStoryGenerationRunStorage storage,
}) {
  registry.registerFactory<StoryGenerationRunStore>(
    (r) => StoryGenerationRunStore(
      settingsStore: r.resolve<AppSettingsStore>(),
      workspaceStore: r.resolve<AppWorkspaceStore>(),
      generationStore: r.resolve<StoryGenerationStore>(),
      sceneContextStore: r.resolve<AppSceneContextStore>(),
      outlineStore: r.resolve<StoryOutlineStore>(),
      authorFeedbackStore: r.resolve<AuthorFeedbackStore>(),
      roleplaySessionStore: r.resolve<RoleplaySessionStore>(),
      characterMemoryStore: r.resolve<CharacterMemoryStore>(),
      reviewTaskStore: r.resolve<ReviewTaskStore>(),
      storage: storage,
      draftStore: r.resolve<AppDraftStore>(),
      generationLedger: r.resolve<GenerationLedgerSqliteStore>(),
      generationCandidateFinalizer: GenerationLedgerCandidateFinalizer(
        ledger: r.resolve<GenerationLedgerSqliteStore>(),
        promptRegistry: r.resolve<StoryPromptRegistry>(),
      ),
      generationCommitCoordinator: r.resolve<GenerationCommitCoordinator>(),
      generationOutboxWorker: r.resolve<GenerationOutboxWorker>(),
      eventBus: r.resolve<AppEventBus>(),
      lifecycleRunIdFactory: r.resolve<StoryGenerationLifecycleRunIdFactory>(),
      allowLocalOnlyFallback: false,
      formalEvaluation: true,
      orchestratorFactory: (_) => r.resolve<StoryPipelineFactory>().create(),
    ),
  );
}

/// Fences every normal path-based storage operation until its Future proves
/// that the adapter's short SQLite handle has closed.
final class _SandboxShortConnectionFence {
  _SandboxShortConnectionFence({
    required AgentEvaluationTrialContext context,
    required String databasePath,
  }) : _authoritativeDatabase = context.database,
       _databasePath = _canonicalDatabasePath(databasePath),
       _acquireOwner = context.acquireSandboxConnectionOwner,
       _releaseOwner = context.releaseSandboxConnectionOwner {
    final hasAcquire = _acquireOwner != null;
    final hasRelease = _releaseOwner != null;
    if (hasAcquire != hasRelease ||
        (context.durableSandbox && (!hasAcquire || !hasRelease))) {
      throw const AgentEvaluationProductionEvidenceException(
        'durable app runtime requires complete short-connection owner fencing',
      );
    }
    _verifyAuthoritativeBoundary(requireAutocommit: true);
  }

  final sqlite3.Database _authoritativeDatabase;
  final String _databasePath;
  final void Function(String ownerId)? _acquireOwner;
  final void Function(String ownerId)? _releaseOwner;
  final Set<Completer<void>> _pending = <Completer<void>>{};
  final Set<String> _activeOwners = <String>{};
  var _sequence = 0;
  var _closed = false;

  bool usesAuthoritativeDatabase(sqlite3.Database database) =>
      identical(database, _authoritativeDatabase);

  Future<T> guard<T>(String operationId, Future<T> Function() operation) async {
    if (_closed) {
      throw StateError('sandbox short-connection fence is closed');
    }
    _sequence += 1;
    final ownerId = 'short-sqlite:$operationId:$_sequence';
    final completion = Completer<void>();
    if (!_activeOwners.add(ownerId) || !_pending.add(completion)) {
      throw StateError('duplicate sandbox short-connection owner');
    }
    try {
      _acquireOwner?.call(ownerId);
    } catch (_) {
      _activeOwners.remove(ownerId);
      _pending.remove(completion);
      rethrow;
    }
    try {
      return await operation();
    } finally {
      try {
        _verifyAuthoritativeBoundary();
      } finally {
        try {
          _releaseOwner?.call(ownerId);
        } finally {
          _activeOwners.remove(ownerId);
          _pending.remove(completion);
          if (!completion.isCompleted) completion.complete();
        }
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    while (_pending.isNotEmpty) {
      await Future.wait<void>(
        _pending.map((completion) => completion.future).toList(growable: false),
      );
    }
    if (_activeOwners.isNotEmpty) {
      throw StateError('sandbox short SQLite handles remain active');
    }
    _verifyAuthoritativeBoundary(requireAutocommit: true);
  }

  void _verifyAuthoritativeBoundary({bool requireAutocommit = false}) {
    if (requireAutocommit && !_authoritativeDatabase.autocommit) {
      throw const AgentEvaluationProductionEvidenceException(
        'sandbox authoritative database retained an open transaction',
      );
    }
    final databases = _authoritativeDatabase.select('PRAGMA database_list');
    final main = databases.where((row) => row['name'] == 'main').toList();
    final attached = databases.where(
      (row) => row['name'] != 'main' && row['name'] != 'temp',
    );
    if (main.length != 1 ||
        attached.isNotEmpty ||
        _canonicalDatabasePath(main.single['file'] as String) !=
            _databasePath) {
      throw const AgentEvaluationProductionEvidenceException(
        'sandbox short-connection fence escaped its authoritative database',
      );
    }
  }
}

final class _FencedWorkspaceStorage implements AppWorkspaceStorage {
  const _FencedWorkspaceStorage({
    required AppWorkspaceStorage delegate,
    required _SandboxShortConnectionFence fence,
    required String storageId,
  }) : _delegate = delegate,
       _fence = fence,
       _storageId = storageId;

  final AppWorkspaceStorage _delegate;
  final _SandboxShortConnectionFence _fence;
  final String _storageId;

  @override
  Future<Map<String, Object?>?> load() =>
      _fence.guard('$_storageId.load', _delegate.load);

  @override
  Future<void> save(Map<String, Object?> data) =>
      _fence.guard('$_storageId.save', () => _delegate.save(data));

  @override
  Future<void> clear() => _fence.guard('$_storageId.clear', _delegate.clear);
}

final class _FencedProjectStorage
    implements
        AppDraftStorage,
        AppVersionStorage,
        StoryOutlineStorage,
        StoryGenerationStorage,
        AppSceneContextStorage,
        AuthorFeedbackStorage,
        ReviewTaskStorage {
  const _FencedProjectStorage({
    required ProjectStorage delegate,
    required _SandboxShortConnectionFence fence,
    required String storageId,
  }) : _delegate = delegate,
       _fence = fence,
       _storageId = storageId;

  final ProjectStorage _delegate;
  final _SandboxShortConnectionFence _fence;
  final String _storageId;

  @override
  Future<Map<String, Object?>?> load({required String projectId}) => _fence
      .guard('$_storageId.load', () => _delegate.load(projectId: projectId));

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) =>
      _fence.guard(
        '$_storageId.save',
        () => _delegate.save(data, projectId: projectId),
      );

  @override
  Future<void> clear({String? projectId}) => _fence.guard(
    '$_storageId.clear',
    () => _delegate.clear(projectId: projectId),
  );

  @override
  Future<void> clearProject(String projectId) => _fence.guard(
    '$_storageId.clear-project',
    () => _delegate.clearProject(projectId),
  );
}

String _canonicalDatabasePath(String path) {
  final file = File(path).absolute;
  return file.existsSync() ? file.resolveSymbolicLinksSync() : file.path;
}

final class _EvaluationInputState {
  _EvaluationInputState._({
    required this.workspaceStorage,
    required this.draftStorage,
    required this.versionStorage,
    required this.outlineStorage,
    required this.generationStorage,
    required this.sceneContextStorage,
    required this.authorFeedbackStorage,
    required this.reviewTaskStorage,
    required this.shortConnectionFence,
    required this.workspace,
    required this.draft,
    required this.version,
    required this.outline,
    required this.generation,
    required this.sceneContext,
    required this.authorFeedback,
    required this.reviewTasks,
    required this.projectId,
    required this.sceneScopeId,
    required this.requiresFixtureWorkspace,
  });

  final AppWorkspaceStorage workspaceStorage;
  final AppDraftStorage draftStorage;
  final AppVersionStorage versionStorage;
  final StoryOutlineStorage outlineStorage;
  final StoryGenerationStorage generationStorage;
  final AppSceneContextStorage sceneContextStorage;
  final AuthorFeedbackStorage authorFeedbackStorage;
  final ReviewTaskStorage reviewTaskStorage;
  final _SandboxShortConnectionFence shortConnectionFence;
  final Map<String, Object?>? workspace;
  final Map<String, Object?>? draft;
  final Map<String, Object?>? version;
  final Map<String, Object?>? outline;
  final Map<String, Object?>? generation;
  final Map<String, Object?>? sceneContext;
  final Map<String, Object?>? authorFeedback;
  final Map<String, Object?>? reviewTasks;
  final String projectId;
  final String sceneScopeId;
  final bool requiresFixtureWorkspace;

  static Future<_EvaluationInputState> load({
    required AgentEvaluationTrialContext context,
    required String databasePath,
    required Map<String, Object?> fixture,
  }) async {
    final fence = _SandboxShortConnectionFence(
      context: context,
      databasePath: databasePath,
    );
    final workspaceStorage = _FencedWorkspaceStorage(
      delegate: SqliteAppWorkspaceStorage(dbPath: databasePath),
      fence: fence,
      storageId: 'workspace',
    );
    _FencedProjectStorage projectStorage(
      String storageId,
      ProjectStorage delegate,
    ) => _FencedProjectStorage(
      delegate: delegate,
      fence: fence,
      storageId: storageId,
    );
    final draftStorage = projectStorage(
      'draft',
      SqliteAppDraftStorage(dbPath: databasePath),
    );
    final versionStorage = projectStorage(
      'version',
      SqliteAppVersionStorage(dbPath: databasePath),
    );
    final outlineStorage = projectStorage(
      'outline',
      SqliteStoryOutlineStorage(
        dbPath: databasePath,
        requireExistingSchema: true,
      ),
    );
    final generationStorage = projectStorage(
      'generation',
      SqliteStoryGenerationStorage(
        dbPath: databasePath,
        requireExistingSchema: true,
      ),
    );
    final sceneContextStorage = projectStorage(
      'scene-context',
      SqliteAppSceneContextStorage(dbPath: databasePath),
    );
    final authorFeedbackStorage = projectStorage(
      'author-feedback',
      SqliteAuthorFeedbackStorage(dbPath: databasePath),
    );
    final reviewTaskStorage = projectStorage(
      'review-task',
      SqliteReviewTaskStorage(dbPath: databasePath),
    );
    final workspace = await workspaceStorage.load();
    final fixtureProjectId = fixture['projectId']?.toString().trim() ?? '';
    final fixtureSceneId = fixture['sceneId']?.toString().trim() ?? '';
    final fixtureScopeId = fixture['sceneScopeId']?.toString().trim() ?? '';
    final projectId = fixtureProjectId.isNotEmpty
        ? fixtureProjectId
        : workspace?['currentProjectId']?.toString().trim() ?? '';
    final sceneId = fixtureSceneId.isNotEmpty
        ? fixtureSceneId
        : _workspaceSceneId(workspace, projectId);
    final sceneScopeId = fixtureScopeId.isNotEmpty
        ? fixtureScopeId
        : projectId.isEmpty || sceneId.isEmpty
        ? ''
        : '$projectId::$sceneId';

    final loaded = await Future.wait<Map<String, Object?>?>([
      if (sceneScopeId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        draftStorage.load(projectId: sceneScopeId),
      if (sceneScopeId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        versionStorage.load(projectId: sceneScopeId),
      if (projectId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        outlineStorage.load(projectId: projectId),
      if (projectId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        generationStorage.load(projectId: projectId),
      if (sceneScopeId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        sceneContextStorage.load(projectId: sceneScopeId),
      if (projectId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        authorFeedbackStorage.load(projectId: projectId),
      if (projectId.isEmpty)
        Future<Map<String, Object?>?>.value()
      else
        reviewTaskStorage.load(projectId: projectId),
    ]);
    return _EvaluationInputState._(
      workspaceStorage: workspaceStorage,
      draftStorage: draftStorage,
      versionStorage: versionStorage,
      outlineStorage: outlineStorage,
      generationStorage: generationStorage,
      sceneContextStorage: sceneContextStorage,
      authorFeedbackStorage: authorFeedbackStorage,
      reviewTaskStorage: reviewTaskStorage,
      shortConnectionFence: fence,
      workspace: workspace,
      draft: loaded[0],
      version: loaded[1],
      outline: loaded[2],
      generation: loaded[3],
      sceneContext: loaded[4],
      authorFeedback: loaded[5],
      reviewTasks: loaded[6],
      projectId: projectId,
      sceneScopeId: sceneScopeId,
      requiresFixtureWorkspace:
          fixtureProjectId.isNotEmpty ||
          fixtureSceneId.isNotEmpty ||
          fixtureScopeId.isNotEmpty,
    );
  }

  Future<void> waitUntilApplied({
    required AppWorkspaceStore workspaceStore,
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    required StoryOutlineStore outlineStore,
    required StoryGenerationStore generationStore,
    required AppSceneContextStore sceneContextStore,
    required AuthorFeedbackStore authorFeedbackStore,
    required ReviewTaskStore reviewTaskStore,
  }) async {
    for (var turn = 0; turn < 64; turn += 1) {
      await Future<void>.delayed(Duration.zero);
      await generationStore.waitUntilReady();
      await authorFeedbackStore.waitUntilReady();
      await reviewTaskStore.waitUntilReady();
      try {
        validateApplied(
          workspaceStore: workspaceStore,
          draftStore: draftStore,
          versionStore: versionStore,
          outlineStore: outlineStore,
          generationStore: generationStore,
          sceneContextStore: sceneContextStore,
          authorFeedbackStore: authorFeedbackStore,
          reviewTaskStore: reviewTaskStore,
        );
        return;
      } on AgentEvaluationProductionEvidenceException {
        // Store constructors restore asynchronously. Give workspace-driven
        // scope changes a bounded number of microtask turns to settle.
      }
    }
    validateApplied(
      workspaceStore: workspaceStore,
      draftStore: draftStore,
      versionStore: versionStore,
      outlineStore: outlineStore,
      generationStore: generationStore,
      sceneContextStore: sceneContextStore,
      authorFeedbackStore: authorFeedbackStore,
      reviewTaskStore: reviewTaskStore,
    );
  }

  void validateApplied({
    required AppWorkspaceStore workspaceStore,
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    required StoryOutlineStore outlineStore,
    required StoryGenerationStore generationStore,
    required AppSceneContextStore sceneContextStore,
    required AuthorFeedbackStore authorFeedbackStore,
    required ReviewTaskStore reviewTaskStore,
  }) {
    if ((requiresFixtureWorkspace && workspace == null) ||
        (workspace != null &&
            !_workspaceMatches(
              expected: workspace!,
              actual: workspaceStore.exportJson(),
            )) ||
        (projectId.isNotEmpty &&
            workspaceStore.currentProjectId != projectId) ||
        (sceneScopeId.isNotEmpty &&
            workspaceStore.currentSceneScopeId != sceneScopeId) ||
        !_matchesIfPresent(draft, draftStore.exportJson()) ||
        !_matchesIfPresent(version, versionStore.exportJson()) ||
        !_matchesIfPresent(outline, outlineStore.exportJson()) ||
        !_matchesIfPresent(generation, generationStore.exportJson()) ||
        !_matchesIfPresent(sceneContext, sceneContextStore.exportJson()) ||
        !_matchesIfPresent(authorFeedback, authorFeedbackStore.exportJson()) ||
        !_matchesIfPresent(reviewTasks, reviewTaskStore.exportJson())) {
      throw const AgentEvaluationProductionEvidenceException(
        'normal app input stores did not hydrate from the sandbox fixture',
      );
    }
  }
}

String _workspaceSceneId(Map<String, Object?>? workspace, String projectId) {
  final projects = workspace?['projects'];
  if (projects is! List) return '';
  for (final project in projects) {
    if (project is Map && project['id']?.toString() == projectId) {
      return project['sceneId']?.toString().trim() ?? '';
    }
  }
  return '';
}

bool _workspaceMatches({
  required Map<String, Object?> expected,
  required Map<String, Object?> actual,
}) {
  return _storageSubset(actual['projects'], expected['projects']) &&
      _storageSubset(
        actual['charactersByProject'],
        expected['charactersByProject'],
      ) &&
      _storageSubset(actual['scenesByProject'], expected['scenesByProject']) &&
      actual['currentProjectId']?.toString() ==
          expected['currentProjectId']?.toString();
}

bool _matchesIfPresent(
  Map<String, Object?>? expected,
  Map<String, Object?> actual,
) => expected == null || _storageSubset(actual, expected);

bool _storageSubset(Object? actual, Object? expected) {
  if (expected is Map) {
    if (actual is! Map) return false;
    for (final entry in expected.entries) {
      if (!actual.containsKey(entry.key) ||
          !_storageSubset(actual[entry.key], entry.value)) {
        return false;
      }
    }
    return true;
  }
  if (expected is List) {
    if (actual is! List || actual.length != expected.length) return false;
    for (var index = 0; index < expected.length; index += 1) {
      if (!_storageSubset(actual[index], expected[index])) return false;
    }
    return true;
  }
  return actual == expected;
}

final class _AgentEvaluationAppRuntime
    implements AgentEvaluationProductionRuntime {
  _AgentEvaluationAppRuntime({
    required ServiceRegistry registry,
    required sqlite3.Database database,
    required this.databasePath,
    required this.isolationTrialId,
    required this.generationBundleHash,
    required this.modelRouteHash,
    required this.decodingConfigHash,
    required String initialIsolationMode,
    required this.promptRegistry,
    required AppWorkspaceStore workspaceStore,
    required _EvaluationInputState inputState,
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    required StoryOutlineStore outlineStore,
    required StoryGenerationStore generationStore,
    required AppSceneContextStore sceneContextStore,
    required AuthorFeedbackStore authorFeedbackStore,
    required ReviewTaskStore reviewTaskStore,
    required this.runStore,
    required SqliteStoryGenerationRunStorage runStorage,
    required _SandboxShortConnectionFence shortConnectionFence,
    required void Function()? releaseConnectionOwner,
    required this.meter,
    required this.traceSink,
  }) : _registry = registry,
       _runStorage = runStorage,
       _shortConnectionFence = shortConnectionFence,
       _releaseConnectionOwner = releaseConnectionOwner,
       _database = database,
       _initialIsolationMode = initialIsolationMode,
       _workspaceStore = workspaceStore,
       _inputState = inputState,
       _draftStore = draftStore,
       _versionStore = versionStore,
       _outlineStore = outlineStore,
       _generationStore = generationStore,
       _sceneContextStore = sceneContextStore,
       _authorFeedbackStore = authorFeedbackStore,
       _reviewTaskStore = reviewTaskStore;

  final ServiceRegistry _registry;
  final SqliteStoryGenerationRunStorage _runStorage;
  final _SandboxShortConnectionFence _shortConnectionFence;
  final void Function()? _releaseConnectionOwner;
  final sqlite3.Database _database;
  final String _initialIsolationMode;
  final AppWorkspaceStore _workspaceStore;
  final _EvaluationInputState _inputState;
  final AppDraftStore _draftStore;
  final AppVersionStore _versionStore;
  final StoryOutlineStore _outlineStore;
  final StoryGenerationStore _generationStore;
  final AppSceneContextStore _sceneContextStore;
  final AuthorFeedbackStore _authorFeedbackStore;
  final ReviewTaskStore _reviewTaskStore;
  var _disposed = false;

  @override
  final String isolationTrialId;

  @override
  final String generationBundleHash;

  @override
  final String modelRouteHash;

  @override
  final String decodingConfigHash;

  @override
  final String databasePath;

  @override
  final StoryPromptRegistry promptRegistry;

  @override
  final StoryGenerationRunStore runStore;

  @override
  final AgentEvaluationMeteredAppLlmClient meter;

  @override
  final AgentEvaluationAttemptTraceSink traceSink;

  @override
  Future<void> prepare(AgentEvaluationTrialContext context) async {
    if (_disposed) {
      throw StateError('app evaluation runtime is disposed');
    }
    final trace = AgentEvaluationTraceContext.current;
    final command = _fixtureCommand(context.scenario.inputFixture);
    if (!identical(context.database, _database) ||
        context.sandboxDatabasePath?.trim() != databasePath ||
        context.isolationTrialId != isolationTrialId ||
        context.cell.generationBundleHash != generationBundleHash ||
        context.cell.modelRouteHash != modelRouteHash ||
        context.cell.decodingConfigHash != decodingConfigHash ||
        context.scenario.isolationMode != _initialIsolationMode ||
        _rawBundleHash(promptRegistry.generationBundle.bundleHash) !=
            generationBundleHash ||
        trace == null ||
        trace.experimentId != context.manifest.experimentId ||
        trace.executionId != context.lease.executionId ||
        trace.cellId != context.lease.cellId ||
        trace.trialSlotId != context.lease.trialSlotId ||
        trace.attemptNo != context.attemptNo ||
        trace.runId != context.runId ||
        trace.leaseEpoch != context.lease.epoch ||
        trace.leaseOwner != context.lease.owner ||
        trace.isolationTrialId != context.isolationTrialId ||
        trace.generationBundleHash != 'sha256:$generationBundleHash' ||
        trace.evaluationBundleHash !=
            'sha256:${context.manifest.evaluationBundleHash}' ||
        command.isEmpty) {
      throw const AgentEvaluationProductionEvidenceException(
        'app runtime context contradicts its frozen sandbox identity',
      );
    }
    _validateFixtureWorkspace(context.scenario.inputFixture, _workspaceStore);
    _inputState.validateApplied(
      workspaceStore: _workspaceStore,
      draftStore: _draftStore,
      versionStore: _versionStore,
      outlineStore: _outlineStore,
      generationStore: _generationStore,
      sceneContextStore: _sceneContextStore,
      authorFeedbackStore: _authorFeedbackStore,
      reviewTaskStore: _reviewTaskStore,
    );
    if (context.cancellationToken.isCancelled) {
      throw const AgentEvaluationProductionEvidenceException(
        'cancelled trial cannot prepare the production runtime',
      );
    }
    await runStore.ready;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      _registry.disposeAll();
    } finally {
      try {
        await _shortConnectionFence.close();
      } finally {
        try {
          _runStorage.dispose();
        } finally {
          _releaseConnectionOwner?.call();
        }
      }
    }
  }
}

void _validateFrozenArm(
  AgentEvaluationTrialContext context,
  StoryPromptRegistry promptRegistry,
  AgentEvaluationProductionRouteRelease route,
  AgentEvaluationProductionDecodingRelease decoding,
) {
  if (_rawBundleHash(promptRegistry.generationBundle.bundleHash) !=
          context.cell.generationBundleHash ||
      route.modelRouteHash != context.cell.modelRouteHash ||
      !AgentEvaluationProductionRouteRelease.routeMatchesManifestContract(
        route,
        context.manifest,
      ) ||
      route.providerApiRevision != context.manifest.providerApiRevision ||
      route.sdkAdapterReleaseHash != context.manifest.sdkAdapterReleaseHash ||
      decoding.decodingConfigHash != context.cell.decodingConfigHash ||
      decoding.streamingAllowed ||
      decoding.maxConcurrentRequests != 1 ||
      decoding.tokenLimitPolicy != 'production-call-site-max-tokens-v1') {
    throw const AgentEvaluationProductionEvidenceException(
      'app runtime arm does not match the frozen manifest cell',
    );
  }
  _fixtureCommand(context.scenario.inputFixture);
}

void _validateDurableServices(
  ServiceRegistry registry,
  sqlite3.Database database, {
  required SqliteStoryGenerationRunStorage runStorage,
  required _SandboxShortConnectionFence shortConnectionFence,
}) {
  final ledger = registry.resolve<GenerationLedgerSqliteStore>();
  final coordinator = registry.resolve<GenerationCommitCoordinator>();
  final memory = registry.resolve<StoryMemoryStorage>();
  final roleplay = registry.resolve<RoleplaySessionStore>();
  final characterMemory = registry.resolve<CharacterMemoryStore>();
  final retriever = registry.resolve<HybridRetriever>();
  registry.resolve<GenerationOutboxWorker>();
  if (!shortConnectionFence.usesAuthoritativeDatabase(database) ||
      !runStorage.usesDatabase(database) ||
      !identical(ledger.db, database) ||
      !identical(coordinator.db, database) ||
      memory is! StoryMemoryStorageIO ||
      !identical(memory.db, database) ||
      roleplay is! RoleplaySessionStoreIO ||
      !identical(roleplay.db, database) ||
      characterMemory is! CharacterMemoryStoreIO ||
      !identical(characterMemory.db, database) ||
      !identical(retriever.ftsStorage.db, database)) {
    throw const AgentEvaluationProductionEvidenceException(
      'durable app services escaped the evaluation sandbox database',
    );
  }
  ledger.ensureTables();
  coordinator.ensureTables();
}

String _formalLifecycleRunId(String _) {
  final current = AgentEvaluationTraceContext.current;
  if (current == null) {
    throw StateError('formal lifecycle run id requested outside evaluation');
  }
  return current.runId;
}

String _fixtureCommand(Map<String, Object?> fixture) {
  final command = fixture['prompt'] ?? fixture['rules'] ?? fixture['scene'];
  final normalized = command?.toString().trim() ?? '';
  if (normalized.isEmpty) {
    throw const AgentEvaluationProductionEvidenceException(
      'production scenario fixture omitted its scene command',
    );
  }
  return normalized;
}

void _validateFixtureWorkspace(
  Map<String, Object?> fixture,
  AppWorkspaceStore workspace,
) {
  final expectedProjectId = fixture['projectId']?.toString().trim();
  final expectedSceneId = fixture['sceneId']?.toString().trim();
  final expectedScopeId = fixture['sceneScopeId']?.toString().trim();
  if ((expectedProjectId != null &&
          expectedProjectId.isNotEmpty &&
          expectedProjectId != workspace.currentProjectId) ||
      (expectedSceneId != null &&
          expectedSceneId.isNotEmpty &&
          expectedSceneId != workspace.currentScene.id) ||
      (expectedScopeId != null &&
          expectedScopeId.isNotEmpty &&
          expectedScopeId != workspace.currentSceneScopeId) ||
      workspace.currentProjectId.isEmpty ||
      workspace.currentScene.id.isEmpty ||
      workspace.currentSceneScopeId.isEmpty) {
    throw const AgentEvaluationProductionEvidenceException(
      'scenario fixture does not address the isolated runtime workspace',
    );
  }
}

String _rawBundleHash(String value) =>
    value.startsWith('sha256:') ? value.substring(7) : value;

final class _MemoryOnlyEventLogStorage implements AppEventLogStorage {
  const _MemoryOnlyEventLogStorage();

  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
