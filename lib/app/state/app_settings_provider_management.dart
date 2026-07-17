import 'ai_request_service.dart';
import 'app_settings_storage.dart';
import 'app_store_listenable.dart';
import 'llm_provider_service.dart';
import 'settings/default_provider_config.dart';
import 'settings/settings_models.dart';

/// Provider profile 与路由管理方法。
///
/// 从 AppSettingsStore 中提取，通过 mixin 组合保持 store 公开 API 不变。
/// 需要 store 提供字段访问器（通过抽象 getter）。
mixin AppSettingsProviderManagement on AppStoreListenable {
  // --- Store 字段访问器（由 AppSettingsStore 实现） ---

  AppSettingsSnapshot get storeSnapshot;
  set storeSnapshot(AppSettingsSnapshot value);
  LlmProviderService get storeProviderService;
  AiRequestService get storeAiRequestService;
  bool get storeHasLocalMutations;
  set storeHasLocalMutations(bool value);
  Future<AppSettingsSaveResult> storePersist();
  void storeSyncRequestPoolLimits();

  // --- Provider Profile 管理 ---

  Future<AppSettingsSaveResult> upsertProviderProfile(
    AppLlmProviderProfile profile,
  ) async {
    storeHasLocalMutations = true;
    if (profile.id == 'primary') {
      final normalizedModel = storeAiRequestService.normalizeRequestedModel(
        profile.model,
      );
      final nextProfiles = storeProviderService.syncPrimaryProfile(
        storeSnapshot.providerProfiles,
        providerName: profile.providerName,
        baseUrl: profile.baseUrl,
        model: normalizedModel,
        apiKey: profile.apiKey,
      );
      storeSnapshot = storeSnapshot.copyWith(
        providerName: profile.providerName,
        baseUrl: profile.baseUrl,
        model: normalizedModel,
        apiKey: profile.apiKey,
        hasApiKey: profile.apiKey.isNotEmpty,
        providerProfiles: nextProfiles,
      );
      storeSyncRequestPoolLimits();
      notifyListeners();
      return storePersist();
    }
    final updated = [
      for (final existing in storeSnapshot.providerProfiles)
        if (existing.id == profile.id) profile else existing,
    ];
    if (!updated.any((p) => p.id == profile.id)) {
      updated.add(profile);
    }
    storeSnapshot = storeSnapshot.copyWith(providerProfiles: updated);
    storeSyncRequestPoolLimits();
    notifyListeners();
    return storePersist();
  }

  Future<AppSettingsSaveResult> addProviderFromCatalog(
    String catalogEntryId, {
    bool setAsPrimary = false,
  }) async {
    final entry = _providerCatalogEntryById(catalogEntryId);
    if (entry == null) {
      return const AppSettingsSaveResult();
    }
    final existing = storeProviderService.profileById(
      storeSnapshot.providerProfiles,
      entry.id,
    );
    final apiKey = existing?.apiKey ?? '';
    final profile = entry.toProfile(apiKey: apiKey);
    if (!setAsPrimary) {
      return upsertProviderProfile(profile);
    }

    storeHasLocalMutations = true;
    final nextProfiles = storeProviderService.syncPrimaryProfile(
      storeSnapshot.providerProfiles,
      providerName: profile.providerName,
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: apiKey,
    );
    storeSnapshot = storeSnapshot.copyWith(
      providerName: profile.providerName,
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: apiKey,
      hasApiKey: apiKey.isNotEmpty,
      providerProfiles: nextProfiles,
    );
    storeSyncRequestPoolLimits();
    notifyListeners();
    return storePersist();
  }

  Future<AppSettingsSaveResult> setPrimaryProviderProfile(String id) async {
    final profile = storeProviderService.profileById(
      storeSnapshot.providerProfiles,
      id,
    );
    if (profile == null) {
      return const AppSettingsSaveResult();
    }
    return upsertProviderProfile(
      AppLlmProviderProfile(
        id: 'primary',
        providerName: profile.providerName,
        baseUrl: profile.baseUrl,
        model: profile.model,
        apiKey: profile.apiKey,
      ),
    );
  }

  Future<AppSettingsSaveResult> removeProviderProfile(String id) async {
    final result = storeProviderService.removeProviderProfile(
      id,
      storeSnapshot.providerProfiles,
      storeSnapshot.requestProviderRoutes,
    );
    if (!result.changed) {
      return const AppSettingsSaveResult();
    }
    storeHasLocalMutations = true;
    storeSnapshot = storeSnapshot.copyWith(
      providerProfiles: result.profiles,
      requestProviderRoutes: result.routes,
    );
    storeSyncRequestPoolLimits();
    notifyListeners();
    return storePersist();
  }

  Future<AppSettingsSaveResult> upsertRequestProviderRoute(
    AppLlmRequestProviderRoute route,
  ) async {
    storeHasLocalMutations = true;
    final updated = storeProviderService.upsertRoute(
      route,
      storeSnapshot.requestProviderRoutes,
    );
    storeSnapshot = storeSnapshot.copyWith(requestProviderRoutes: updated);
    notifyListeners();
    return storePersist();
  }

  Future<AppSettingsSaveResult>
  applySingleChapterGenerationProviderPreset() async {
    storeHasLocalMutations = true;
    final defaultApiKey =
        storeAiRequestService.isZhipuBaseUrl(storeSnapshot.baseUrl)
        ? storeSnapshot.apiKey
        : '';
    final profilesById = {
      for (final profile in storeSnapshot.providerProfiles) profile.id: profile,
    };
    for (final preset in singleChapterProviderPresetProfiles) {
      final existing = profilesById[preset.id];
      profilesById[preset.id] = AppLlmProviderProfile(
        id: preset.id,
        providerName: preset.providerName,
        baseUrl: preset.baseUrl,
        model: preset.model,
        apiKey: existing?.apiKey ?? preset.apiKey,
      );
    }
    final routesByPattern = {
      for (final route in storeSnapshot.requestProviderRoutes)
        route.traceNamePattern: route,
    };
    for (final preset in singleChapterProviderPresetRoutes) {
      routesByPattern[preset.traceNamePattern] = preset;
    }
    final nextProfiles = storeProviderService.syncPrimaryProfile(
      profilesById.values.toList(),
      providerName: singleChapterDefaultProviderName,
      baseUrl: singleChapterDefaultBaseUrl,
      model: singleChapterDefaultModel,
      apiKey: defaultApiKey,
    );
    storeSnapshot = storeSnapshot.copyWith(
      providerName: singleChapterDefaultProviderName,
      baseUrl: singleChapterDefaultBaseUrl,
      model: singleChapterDefaultModel,
      apiKey: defaultApiKey,
      hasApiKey: defaultApiKey.isNotEmpty,
      providerProfiles: nextProfiles,
      requestProviderRoutes: routesByPattern.values.toList(),
    );
    storeSyncRequestPoolLimits();
    notifyListeners();
    return storePersist();
  }

  Future<AppSettingsSaveResult> removeRequestProviderRoute(
    String traceNamePattern,
  ) async {
    final updated = storeProviderService.removeRoute(
      traceNamePattern,
      storeSnapshot.requestProviderRoutes,
    );
    if (updated == null) {
      return const AppSettingsSaveResult();
    }
    storeHasLocalMutations = true;
    storeSnapshot = storeSnapshot.copyWith(requestProviderRoutes: updated);
    notifyListeners();
    return storePersist();
  }

  // --- Private helpers ---

  AppLlmProviderCatalogEntry? _providerCatalogEntryById(String id) {
    final normalized = id.trim();
    for (final entry in appLlmProviderCatalogEntries) {
      if (entry.id == normalized) return entry;
    }
    return null;
  }
}
