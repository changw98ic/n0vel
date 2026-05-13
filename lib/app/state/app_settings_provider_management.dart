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

  AppSettingsSnapshot get providerManagementSnapshot;
  set providerManagementSnapshot(AppSettingsSnapshot value);
  LlmProviderService get providerService;
  AiRequestService get aiRequestServiceForProviderManagement;
  bool get hasLocalMutations;
  set hasLocalMutations(bool value);
  Future<AppSettingsSaveResult> persistSnapshot();
  void syncRequestPoolLimits();

  // --- Provider Profile 管理 ---

  Future<AppSettingsSaveResult> upsertProviderProfile(
    AppLlmProviderProfile profile,
  ) async {
    hasLocalMutations = true;
    if (profile.id == 'primary') {
      final normalizedModel = aiRequestServiceForProviderManagement
          .normalizeRequestedModel(profile.model);
      final nextProfiles = providerService.syncPrimaryProfile(
        providerManagementSnapshot.providerProfiles,
        providerName: profile.providerName,
        baseUrl: profile.baseUrl,
        model: normalizedModel,
        apiKey: profile.apiKey,
      );
      providerManagementSnapshot = providerManagementSnapshot.copyWith(
        providerName: profile.providerName,
        baseUrl: profile.baseUrl,
        model: normalizedModel,
        apiKey: profile.apiKey,
        hasApiKey: profile.apiKey.isNotEmpty,
        providerProfiles: nextProfiles,
      );
      syncRequestPoolLimits();
      notifyListeners();
      return persistSnapshot();
    }
    final updated = [
      for (final existing in providerManagementSnapshot.providerProfiles)
        if (existing.id == profile.id) profile else existing,
    ];
    if (!updated.any((p) => p.id == profile.id)) {
      updated.add(profile);
    }
    providerManagementSnapshot =
        providerManagementSnapshot.copyWith(providerProfiles: updated);
    syncRequestPoolLimits();
    notifyListeners();
    return persistSnapshot();
  }

  Future<AppSettingsSaveResult> addProviderFromCatalog(
    String catalogEntryId, {
    bool setAsPrimary = false,
  }) async {
    final entry = _providerCatalogEntryById(catalogEntryId);
    if (entry == null) {
      return const AppSettingsSaveResult();
    }
    final existing = providerService.profileById(
      providerManagementSnapshot.providerProfiles,
      entry.id,
    );
    final apiKey = existing?.apiKey ?? '';
    final profile = entry.toProfile(apiKey: apiKey);
    if (!setAsPrimary) {
      return upsertProviderProfile(profile);
    }

    hasLocalMutations = true;
    final nextProfiles = providerService.syncPrimaryProfile(
      providerManagementSnapshot.providerProfiles,
      providerName: profile.providerName,
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: apiKey,
    );
    providerManagementSnapshot = providerManagementSnapshot.copyWith(
      providerName: profile.providerName,
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: apiKey,
      hasApiKey: apiKey.isNotEmpty,
      providerProfiles: nextProfiles,
    );
    syncRequestPoolLimits();
    notifyListeners();
    return persistSnapshot();
  }

  Future<AppSettingsSaveResult> setPrimaryProviderProfile(String id) async {
    final profile = providerService.profileById(
      providerManagementSnapshot.providerProfiles,
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
    final result = providerService.removeProviderProfile(
      id,
      providerManagementSnapshot.providerProfiles,
      providerManagementSnapshot.requestProviderRoutes,
    );
    if (!result.changed) {
      return const AppSettingsSaveResult();
    }
    hasLocalMutations = true;
    providerManagementSnapshot = providerManagementSnapshot.copyWith(
      providerProfiles: result.profiles,
      requestProviderRoutes: result.routes,
    );
    syncRequestPoolLimits();
    notifyListeners();
    return persistSnapshot();
  }

  Future<AppSettingsSaveResult> upsertRequestProviderRoute(
    AppLlmRequestProviderRoute route,
  ) async {
    hasLocalMutations = true;
    final updated = providerService.upsertRoute(
      route,
      providerManagementSnapshot.requestProviderRoutes,
    );
    providerManagementSnapshot =
        providerManagementSnapshot.copyWith(requestProviderRoutes: updated);
    notifyListeners();
    return persistSnapshot();
  }

  Future<AppSettingsSaveResult>
  applySingleChapterGenerationProviderPreset() async {
    hasLocalMutations = true;
    final defaultApiKey =
        aiRequestServiceForProviderManagement.isZhipuBaseUrl(
          providerManagementSnapshot.baseUrl,
        )
            ? providerManagementSnapshot.apiKey
            : '';
    final profilesById = {
      for (final profile in providerManagementSnapshot.providerProfiles)
        profile.id: profile,
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
      for (final route in providerManagementSnapshot.requestProviderRoutes)
        route.traceNamePattern: route,
    };
    for (final preset in singleChapterProviderPresetRoutes) {
      routesByPattern[preset.traceNamePattern] = preset;
    }
    final nextProfiles = providerService.syncPrimaryProfile(
      profilesById.values.toList(),
      providerName: singleChapterDefaultProviderName,
      baseUrl: singleChapterDefaultBaseUrl,
      model: singleChapterDefaultModel,
      apiKey: defaultApiKey,
    );
    providerManagementSnapshot = providerManagementSnapshot.copyWith(
      providerName: singleChapterDefaultProviderName,
      baseUrl: singleChapterDefaultBaseUrl,
      model: singleChapterDefaultModel,
      apiKey: defaultApiKey,
      hasApiKey: defaultApiKey.isNotEmpty,
      providerProfiles: nextProfiles,
      requestProviderRoutes: routesByPattern.values.toList(),
    );
    syncRequestPoolLimits();
    notifyListeners();
    return persistSnapshot();
  }

  Future<AppSettingsSaveResult> removeRequestProviderRoute(
    String traceNamePattern,
  ) async {
    final updated = providerService.removeRoute(
      traceNamePattern,
      providerManagementSnapshot.requestProviderRoutes,
    );
    if (updated == null) {
      return const AppSettingsSaveResult();
    }
    hasLocalMutations = true;
    providerManagementSnapshot =
        providerManagementSnapshot.copyWith(requestProviderRoutes: updated);
    notifyListeners();
    return persistSnapshot();
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
