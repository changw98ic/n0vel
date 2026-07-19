import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import 'ai_request_service.dart';
import 'app_settings_provider_management.dart';
import 'app_settings_store_ai_routing.dart';
import 'app_settings_store_feedback.dart';
import 'app_settings_store_logging.dart';
import 'app_settings_store_retry.dart';
import 'app_settings_store_save.dart';
import 'app_settings_store_utils.dart';
import 'app_store_listenable.dart';
import 'app_settings_storage.dart';
import 'llm_provider_service.dart';
import '../../domain/prompt_language.dart';
import '../../features/story_generation/domain/contracts/settings_contract.dart';
import 'settings/settings_models.dart';

export 'settings/default_provider_config.dart';
export 'settings/settings_models.dart';

class AppSettingsStore extends AppStoreListenable
    with
        AppSettingsProviderManagement,
        AppSettingsStoreLogging,
        AppSettingsStoreSave,
        AppSettingsStoreRetry,
        AppSettingsStoreAiRouting
    implements StoryGenerationSettingsContract {
  AppSettingsStore({
    AppSettingsStorage? storage,
    AppLlmClient? llmClient,
    AppLlmRequestPool? requestPool,
    AppEventLog? eventLog,
    AppEventBus? eventBus,
    AppLlmCallTraceSink? llmTraceSink,
  }) : _storage = storage ?? createDefaultAppSettingsStorage(),
       _llmClient = llmClient ?? createDefaultAppLlmClient(),
       _requestPool = requestPool ?? AppLlmRequestPool(maxConcurrent: 3),
       _eventLog = eventLog ?? AppEventLog(),
       _eventBus = eventBus,
       _llmTraceSink = llmTraceSink,
       _providerService = LlmProviderService(maxConcurrentRequests: 1),
       _snapshot = const AppSettingsSnapshot(
         providerName: 'OpenAI 兼容服务',
         baseUrl: 'https://api.example.com/v1',
         model: 'gpt-4.1-mini',
         apiKey: '',
         timeout: AppLlmTimeoutConfig.defaults,
         maxConcurrentRequests: 1,
         maxTokens: AppLlmChatRequest.unlimitedMaxTokens,
         hasApiKey: false,
         themePreference: AppThemePreference.light,
       ) {
    _aiRequestService = AiRequestService(
      llmClient: _llmClient,
      llmTraceSink: _llmTraceSink,
      eventLog: _eventLog,
    );
    _restore();
  }

  final AppSettingsStorage _storage;
  final AppLlmClient _llmClient;
  final AppLlmRequestPool _requestPool;
  final AppEventLog _eventLog;
  final AppEventBus? _eventBus;
  final AppLlmCallTraceSink? _llmTraceSink;
  final LlmProviderService _providerService;
  late final AiRequestService _aiRequestService;
  AppSettingsSnapshot _snapshot;
  AppSettingsFeedback _feedback = const AppSettingsFeedback();
  AppSettingsConnectionTestState _connectionTestState =
      const AppSettingsConnectionTestState.idle();
  AppSettingsPersistenceIssue _activePersistenceIssue =
      AppSettingsPersistenceIssue.none;
  String? _activePersistenceSummary;
  String? _activePersistenceDetail;
  bool _hasLocalMutations = false;

  // --- 统一 mixin 桥接（替代 5 套前缀的 bridge） ---
  @override
  AppSettingsSnapshot get storeSnapshot => _snapshot;
  @override
  set storeSnapshot(AppSettingsSnapshot value) => _snapshot = value;
  @override
  bool get storeHasLocalMutations => _hasLocalMutations;
  @override
  set storeHasLocalMutations(bool value) => _hasLocalMutations = value;
  @override
  AppSettingsFeedback get storeFeedback => _feedback;
  @override
  set storeFeedback(AppSettingsFeedback value) => _feedback = value;
  @override
  LlmProviderService get storeProviderService => _providerService;
  @override
  AiRequestService get storeAiRequestService => _aiRequestService;
  @override
  AppEventBus? get storeEventBus => _eventBus;
  @override
  AppLlmRequestPool get storeRequestPool => _requestPool;
  @override
  AppEventLog get storeEventLog => _eventLog;
  @override
  AppSettingsPersistenceIssue get storeActivePersistenceIssue =>
      _activePersistenceIssue;
  @override
  set storeActivePersistenceIssue(AppSettingsPersistenceIssue value) =>
      _activePersistenceIssue = value;
  @override
  String? get storeActivePersistenceSummary => _activePersistenceSummary;
  @override
  set storeActivePersistenceSummary(String? value) =>
      _activePersistenceSummary = value;
  @override
  String? get storeActivePersistenceDetail => _activePersistenceDetail;
  @override
  set storeActivePersistenceDetail(String? value) =>
      _activePersistenceDetail = value;
  @override
  AppSettingsConnectionTestState get storeConnectionTestState =>
      _connectionTestState;
  @override
  set storeConnectionTestState(AppSettingsConnectionTestState value) =>
      _connectionTestState = value;
  @override
  AppSettingsStorage get storeStorage => _storage;
  @override
  Future<AppSettingsSaveResult> storePersist() => _persist();
  @override
  void storeSyncRequestPoolLimits() => _syncRequestPoolLimits();
  @override
  Future<AppSettingsSaveResult> storeSave({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
    required AppLlmTimeoutConfig timeout,
    int? maxConcurrentRequests,
    int? maxTokens,
    bool notify = true,
  }) {
    return save(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: timeout,
      maxConcurrentRequests: maxConcurrentRequests,
      maxTokens: maxTokens,
      notify: notify,
    );
  }

  @override
  bool storeIsSupportedModel(String model) => isSupportedModelFromUtils(model);
  @override
  AppLlmRequestPool storeRequestPoolForProfile(String? providerProfileId) {
    if (providerProfileId == null ||
        providerProfileId.isEmpty ||
        providerProfileId == 'primary') {
      return _requestPool;
    }
    return _providerService.requestPoolForProfile(providerProfileId);
  }

  // --- 公开 getters ---

  @override
  PromptLanguage get promptLanguage => _snapshot.promptLanguage;

  AppSettingsSnapshot get snapshot => _snapshot;
  AppSettingsFeedback get feedback => _feedback;
  AppSettingsConnectionTestState get connectionTestState =>
      _connectionTestState;
  AppSettingsPersistenceIssue get activePersistenceIssue =>
      _activePersistenceIssue;
  bool get hasPersistenceIssue =>
      _activePersistenceIssue != AppSettingsPersistenceIssue.none;
  bool get hasValidBaseUrl {
    final uri = Uri.tryParse(_snapshot.baseUrl.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority;
  }

  bool get hasModel => _snapshot.model.trim().isNotEmpty;
  bool get _allowsEmptyApiKey =>
      _aiRequestService.isLocalCompatibleEndpoint(_snapshot.baseUrl);
  bool get _hasRequiredApiKey =>
      _snapshot.apiKey.trim().isNotEmpty || _allowsEmptyApiKey;

  bool isSupportedModel(String model) => isSupportedModelFromUtils(model);

  bool get hasSupportedModel =>
      isSupportedModel(_snapshot.model) || _allowsEmptyApiKey;
  bool get hasReadyConfiguration =>
      _hasRequiredApiKey && hasValidBaseUrl && hasModel && hasSupportedModel;

  bool get hasAnyReadyConfiguration =>
      hasReadyConfiguration ||
      _snapshot.providerProfiles.any(
        (p) => _providerService.isUsableProfile(
          p,
          isLocalCompatibleEndpoint:
              _aiRequestService.isLocalCompatibleEndpoint,
        ),
      );
  bool get canRunConnectionTest => hasReadyConfiguration;
  bool get canSaveConfiguration => hasReadyConfiguration;
  bool get canRetrySecureStoreAccess =>
      _activePersistenceIssue == AppSettingsPersistenceIssue.fileReadFailed ||
      _activePersistenceIssue == AppSettingsPersistenceIssue.fileWriteFailed;
  AppSettingsDiagnostic? get diagnostic {
    if (!hasPersistenceIssue ||
        _feedback.title == null ||
        _activePersistenceSummary == null) {
      return null;
    }
    return AppSettingsDiagnostic(
      issueCode: issueCode(_activePersistenceIssue),
      title: _feedback.title!,
      summary: _activePersistenceSummary!,
      detail: _activePersistenceDetail,
    );
  }

  String? get diagnosticReport {
    return diagnostic?.report;
  }

  // --- 简单设置方法 ---

  void _syncRequestPoolLimits() {
    final limit = _snapshot.maxConcurrentRequests;
    _requestPool.maxConcurrent = limit;
    final activeProfileIds = [
      for (final profile in _snapshot.providerProfiles) profile.id,
    ];
    _providerService.syncPoolLimits(limit, activeProfileIds);
  }

  Future<AppSettingsSaveResult> setThemePreference(
    AppThemePreference themePreference,
  ) async {
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(themePreference: themePreference);
    notifyListeners();
    return _persist();
  }

  Future<AppSettingsSaveResult> setPromptLanguage(
    PromptLanguage language,
  ) async {
    _hasLocalMutations = true;
    _snapshot = _snapshot.copyWith(promptLanguage: language);
    notifyListeners();
    return _persist();
  }

  // --- 持久化 ---

  Future<void> _restore() async {
    final restored = await _storage.load();
    final hasLoadIssue =
        _storage.lastLoadIssue != AppSettingsPersistenceIssue.none;
    if (restored == null && !hasLoadIssue) {
      return;
    }

    if (!_hasLocalMutations && restored != null) {
      _snapshot = AppSettingsSnapshot.fromJson(restored);
      _syncRequestPoolLimits();
    }

    if (hasLoadIssue) {
      final loadFeedback = feedbackForLoadIssue(
        _storage.lastLoadIssue,
        _storage.lastLoadDetail,
      );
      _activePersistenceIssue = loadFeedback.issue;
      _activePersistenceDetail = loadFeedback.detail;
      _activePersistenceSummary = loadFeedback.summary;
      _feedback = loadFeedback.feedback;
    } else if (!_hasLocalMutations) {
      _activePersistenceIssue = AppSettingsPersistenceIssue.none;
      _activePersistenceSummary = null;
      _activePersistenceDetail = null;
      _hasLocalMutations = false;
    }
    notifyListeners();
  }

  Future<AppSettingsSaveResult> _persist() async {
    final result = await _storage.save(_snapshot.toJson());
    if (result.issue == AppSettingsPersistenceIssue.none) {
      _hasLocalMutations = false;
    }
    return result;
  }
}
