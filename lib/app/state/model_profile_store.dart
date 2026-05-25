import '../llm/app_llm_client.dart';
import 'app_settings_storage.dart';
import 'app_settings_store.dart';
import 'app_store_listenable.dart';

export 'settings/default_provider_config.dart';
export 'settings/settings_models.dart';

/// Focused model-profile management facade.
///
/// This is intentionally a thin boundary over [AppSettingsStore] while settings
/// still owns persistence, secure key handling, provider routing, and connection
/// testing. UI and future provider-first migration work can depend on this
/// surface without reaching into the wider settings store.
class ModelProfileStore extends AppStoreListenable {
  ModelProfileStore({
    required AppSettingsStore settingsStore,
    bool disposeSettingsStore = false,
  }) : _settingsStore = settingsStore,
       _disposeSettingsStore = disposeSettingsStore {
    _settingsStore.addListener(_handleSettingsChanged);
  }

  final AppSettingsStore _settingsStore;
  final bool _disposeSettingsStore;

  AppSettingsSnapshot get settingsSnapshot => _settingsStore.snapshot;

  List<AppLlmProviderProfile> get profiles =>
      List<AppLlmProviderProfile>.unmodifiable(
        _settingsStore.snapshot.providerProfiles,
      );

  AppLlmProviderProfile get primaryProfile =>
      _settingsStore.snapshot.primaryProviderProfile;

  AppSettingsConnectionTestState get connectionTestState =>
      _settingsStore.connectionTestState;

  AppSettingsFeedback get feedback => _settingsStore.feedback;

  AppSettingsPersistenceIssue get activePersistenceIssue =>
      _settingsStore.activePersistenceIssue;

  bool get hasPersistenceIssue => _settingsStore.hasPersistenceIssue;

  AppLlmProviderProfile? profileById(String id) {
    final normalized = id.trim();
    if (normalized == 'primary') {
      return primaryProfile;
    }
    for (final profile in _settingsStore.snapshot.providerProfiles) {
      if (profile.id == normalized) {
        return profile;
      }
    }
    return null;
  }

  Future<AppSettingsSaveResult> upsertProfile(AppLlmProviderProfile profile) {
    return _settingsStore.upsertProviderProfile(_normalizeProfile(profile));
  }

  Future<AppSettingsSaveResult> addFromCatalog(
    String catalogEntryId, {
    bool setAsPrimary = false,
  }) {
    return _settingsStore.addProviderFromCatalog(
      catalogEntryId.trim(),
      setAsPrimary: setAsPrimary,
    );
  }

  Future<AppSettingsSaveResult> setPrimaryProfile(String id) {
    return _settingsStore.setPrimaryProviderProfile(id.trim());
  }

  Future<AppSettingsSaveResult> removeProfile(String id) {
    return _settingsStore.removeProviderProfile(id.trim());
  }

  Future<void> testProfileConnection(
    String id, {
    AppLlmTimeoutConfig? timeout,
    int? timeoutMs,
    int? maxConcurrentRequests,
    int? maxTokens,
  }) {
    final profile = profileById(id);
    if (profile == null) {
      throw StateError('No model profile found for "${id.trim()}".');
    }
    return _settingsStore.testConnection(
      providerName: profile.providerName,
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: profile.apiKey,
      timeout: timeout,
      timeoutMs: timeoutMs,
      maxConcurrentRequests: maxConcurrentRequests,
      maxTokens: maxTokens,
    );
  }

  void _handleSettingsChanged() {
    notifyListeners();
  }

  AppLlmProviderProfile _normalizeProfile(AppLlmProviderProfile profile) {
    return AppLlmProviderProfile(
      id: profile.id.trim(),
      providerName: profile.providerName.trim(),
      baseUrl: profile.baseUrl.trim(),
      model: profile.model.trim(),
      apiKey: profile.apiKey,
    );
  }

  @override
  void dispose() {
    _settingsStore.removeListener(_handleSettingsChanged);
    if (_disposeSettingsStore) {
      _settingsStore.dispose();
    }
    super.dispose();
  }
}
