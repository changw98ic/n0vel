import '../llm/app_llm_request_pool.dart';
import 'app_settings_store.dart';

/// Provider profile 与 request route 的 CRUD 服务。
///
/// 从 AppSettingsStore 中提取，专门管理多 provider 配置的增删改查、
/// 路由规则匹配、请求池生命周期。AppSettingsStore 通过组合持有本实例，
/// 对外公开 API 签名不变。
class LlmProviderService {
  LlmProviderService({required int maxConcurrentRequests})
      : _defaultPool = AppLlmRequestPool(maxConcurrent: maxConcurrentRequests),
        _maxConcurrentRequests = maxConcurrentRequests;

  final AppLlmRequestPool _defaultPool;
  final Map<String, AppLlmRequestPool> _profilePools = {};
  int _maxConcurrentRequests;

  /// 获取指定 profile 对应的请求池；无 profile 时返回默认池。
  AppLlmRequestPool requestPoolForProfile(String? providerProfileId) {
    if (providerProfileId == null || providerProfileId.isEmpty) {
      return _defaultPool;
    }
    return _profilePools.putIfAbsent(
      providerProfileId,
      () => AppLlmRequestPool(maxConcurrent: _maxConcurrentRequests),
    );
  }

  /// 同步请求池并发上限，并清理已删除 profile 的孤立池。
  void syncPoolLimits(
    int maxConcurrentRequests,
    List<String> activeProfileIds,
  ) {
    _maxConcurrentRequests = maxConcurrentRequests;
    _defaultPool.maxConcurrent = maxConcurrentRequests;
    _profilePools.removeWhere(
      (profileId, _) => !activeProfileIds.contains(profileId),
    );
    for (final pool in _profilePools.values) {
      pool.maxConcurrent = maxConcurrentRequests;
    }
  }

  /// 判断 profile 是否可用（baseUrl、model 非空，apiKey 满足要求）。
  bool isUsableProfile(
    AppLlmProviderProfile profile, {
    required bool Function(String baseUrl) isLocalCompatibleEndpoint,
  }) {
    final hasBaseUrl = profile.baseUrl.trim().isNotEmpty;
    final hasModel = profile.model.trim().isNotEmpty;
    final hasApiKey = profile.apiKey.trim().isNotEmpty ||
        isLocalCompatibleEndpoint(profile.baseUrl);
    return hasBaseUrl && hasModel && hasApiKey;
  }

  /// 从 profile 列表中查找指定 id 的 profile。
  AppLlmProviderProfile? profileById(
    List<AppLlmProviderProfile> profiles,
    String id,
  ) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// 将 primary profile 同步到列表头部（替换已有或插入首位）。
  List<AppLlmProviderProfile> syncPrimaryProfile(
    List<AppLlmProviderProfile> profiles, {
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) {
    final primary = AppLlmProviderProfile(
      id: 'primary',
      providerName:
          providerName.trim().isEmpty ? '默认模型服务' : providerName.trim(),
      baseUrl: baseUrl.trim(),
      model: model.trim(),
      apiKey: apiKey,
    );
    final updated = <AppLlmProviderProfile>[];
    var inserted = false;
    for (final profile in profiles) {
      if (profile.id == primary.id) {
        if (!inserted) {
          updated.add(primary);
          inserted = true;
        }
      } else {
        updated.add(profile);
      }
    }
    if (!inserted) {
      updated.insert(0, primary);
    }
    return List<AppLlmProviderProfile>.unmodifiable(updated);
  }

  /// 对给定 traceName 进行路由匹配，返回解析后的请求配置。
  /// 无匹配路由时返回 null，调用者应使用默认快照配置。
  ResolvedProviderRoute? resolveRoute(
    String traceName,
    List<AppLlmRequestProviderRoute> routes,
    List<AppLlmProviderProfile> profiles, {
    required bool Function(String baseUrl) isLocalCompatibleEndpoint,
  }) {
    for (final route in routes) {
      if (!route.matches(traceName)) continue;
      final profile = profileById(profiles, route.providerProfileId);
      if (profile == null ||
          !isUsableProfile(
            profile,
            isLocalCompatibleEndpoint: isLocalCompatibleEndpoint,
          )) {
        continue;
      }
      return ResolvedProviderRoute(
        providerName: profile.providerName,
        baseUrl: profile.baseUrl,
        model: profile.model,
        apiKey: profile.apiKey,
        providerProfileId: profile.id,
      );
    }
    return null;
  }

  /// 删除指定 profile，同时清理指向该 profile 的路由规则。
  RemoveProviderProfileResult removeProviderProfile(
    String id,
    List<AppLlmProviderProfile> profiles,
    List<AppLlmRequestProviderRoute> routes,
  ) {
    final updatedProfiles = <AppLlmProviderProfile>[
      for (final p in profiles)
        if (p.id != id) p,
    ];
    if (updatedProfiles.length == profiles.length) {
      return const RemoveProviderProfileResult(changed: false);
    }
    final orphanedPatterns = <String>{
      for (final route in routes)
        if (route.providerProfileId == id) route.traceNamePattern,
    };
    var updatedRoutes = routes;
    if (orphanedPatterns.isNotEmpty) {
      updatedRoutes = [
        for (final route in routes)
          if (!orphanedPatterns.contains(route.traceNamePattern)) route,
      ];
    }
    return RemoveProviderProfileResult(
      changed: true,
      profiles: updatedProfiles,
      routes: updatedRoutes,
    );
  }

  /// Upsert 一条路由规则。
  List<AppLlmRequestProviderRoute> upsertRoute(
    AppLlmRequestProviderRoute route,
    List<AppLlmRequestProviderRoute> routes,
  ) {
    final updated = <AppLlmRequestProviderRoute>[
      for (final existing in routes)
        if (existing.traceNamePattern == route.traceNamePattern)
          route
        else
          existing,
    ];
    if (!updated.any((r) => r.traceNamePattern == route.traceNamePattern)) {
      updated.add(route);
    }
    return updated;
  }

  /// 删除一条路由规则；未找到时返回 null。
  List<AppLlmRequestProviderRoute>? removeRoute(
    String traceNamePattern,
    List<AppLlmRequestProviderRoute> routes,
  ) {
    final updated = <AppLlmRequestProviderRoute>[
      for (final r in routes)
        if (r.traceNamePattern != traceNamePattern) r,
    ];
    if (updated.length == routes.length) return null;
    return updated;
  }
}

/// 路由解析结果。
class ResolvedProviderRoute {
  const ResolvedProviderRoute({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.providerProfileId,
  });

  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;
  final String? providerProfileId;
}

/// removeProviderProfile 的返回值。
class RemoveProviderProfileResult {
  const RemoveProviderProfileResult({
    required this.changed,
    this.profiles = const [],
    this.routes = const [],
  });

  final bool changed;
  final List<AppLlmProviderProfile> profiles;
  final List<AppLlmRequestProviderRoute> routes;
}

