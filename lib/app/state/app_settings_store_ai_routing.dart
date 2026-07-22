import '../llm/app_llm_client.dart';
import '../llm/app_llm_call_site_inventory.dart';
import '../llm/app_llm_canonical_hash.dart';
import '../llm/app_llm_prompt_release.dart';
import '../llm/app_llm_prompt_invocation.dart';
import '../llm/app_llm_request_pool.dart';
import '../../features/story_generation/domain/contracts/settings_contract.dart';
import 'ai_request_service.dart';
import 'app_store_listenable.dart';
import 'llm_provider_service.dart';
import 'settings/settings_models.dart';

/// Settings store AI 请求路由与 trace 摘要。
///
/// 从 AppSettingsStore 中提取，通过 mixin 组合保持 store 公开 API 不变。
mixin AppSettingsStoreAiRouting on AppStoreListenable {
  // --- Store 字段访问器（由 AppSettingsStore 实现） ---

  AppSettingsSnapshot get storeSnapshot;
  AiRequestService get storeAiRequestService;
  LlmProviderService get storeProviderService;
  AppLlmRequestPool get storeRequestPool;

  /// 根据 providerProfileId 获取对应的请求池。
  AppLlmRequestPool storeRequestPoolForProfile(String? providerProfileId);

  // --- AI 请求路由 ---

  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) => _requestAiCompletion(
    messages: messages,
    maxTokens: maxTokens,
    traceName: traceName,
    traceMetadata: traceMetadata,
    promptReleaseRef: promptReleaseRef,
    promptInvocationEvidence: promptInvocationEvidence,
    promptVersion: promptVersion,
    stageId: stageId,
    callSiteId: callSiteId,
    variantId: variantId,
    generationBundleHash: generationBundleHash,
    dispatchEvidenceNonce: null,
    formalDispatchIntent: null,
    committedIntentAuthority: null,
    physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.adaptive,
    singlePhysicalRouteLease: null,
  );

  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  }) => _requestAiCompletion(
    messages: messages,
    maxTokens: maxTokens,
    traceName: traceName,
    traceMetadata: traceMetadata,
    promptReleaseRef: promptReleaseRef,
    promptInvocationEvidence: promptInvocationEvidence,
    promptVersion: promptVersion,
    stageId: stageId,
    callSiteId: callSiteId,
    variantId: variantId,
    generationBundleHash: generationBundleHash,
    dispatchEvidenceNonce: dispatchEvidenceNonce,
    formalDispatchIntent: formalDispatchIntent,
    committedIntentAuthority: committedIntentAuthority,
    physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
    singlePhysicalRouteLease: routeLease,
  );

  Future<AppLlmChatResult> _requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    required int? maxTokens,
    required String? traceName,
    required Map<String, Object?> traceMetadata,
    required PromptReleaseRef? promptReleaseRef,
    required PromptInvocationEvidence? promptInvocationEvidence,
    required PromptVersion? promptVersion,
    required String? stageId,
    required String? callSiteId,
    required String? variantId,
    required String? generationBundleHash,
    required String? dispatchEvidenceNonce,
    required Map<String, Object?>? formalDispatchIntent,
    required Object? committedIntentAuthority,
    required AppLlmPhysicalDispatchPolicy physicalDispatchPolicy,
    required StoryGenerationSinglePhysicalDispatchRouteLease?
    singlePhysicalRouteLease,
  }) {
    final callSiteAuthority = AppLlmCallSiteAuthority.registeredPrompt(
      promptReleaseRef: promptReleaseRef,
      promptInvocationEvidence: promptInvocationEvidence,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      generationBundleHash: generationBundleHash,
    );
    if (callSiteAuthority is! AppLlmRegisteredPromptAuthority) {
      throw StateError('central product dispatch requires prompt authority');
    }
    final resolvedTraceName = traceName ?? _inferTraceName(messages);
    late final ResolvedRequestSettings resolved;
    late final AppSettingsSnapshot requestSnapshot;
    late final AppLlmRequestPool requestPool;
    AppSettingsFormalRouteAuthority? validatedFormalRouteAuthority;
    if (physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single) {
      final lease = singlePhysicalRouteLease;
      if (lease is! _AppSettingsSinglePhysicalDispatchRouteLease ||
          lease.traceName != resolvedTraceName) {
        throw const AppLlmPhysicalDispatchPreflightException(
          'invalid-frozen-route-lease',
          'single physical dispatch requires its original frozen route lease',
        );
      }
      final current = _resolveRequestSettings(resolvedTraceName);
      if (!lease.matches(current, storeSnapshot)) {
        throw const AppLlmPhysicalDispatchPreflightException(
          'frozen-route-mutated',
          'provider settings changed after single-dispatch route preflight',
        );
      }
      if (formalDispatchIntent == null || committedIntentAuthority == null) {
        throw const AppLlmPhysicalDispatchPreflightException(
          'missing-committed-intent-authority',
          'single physical dispatch requires its re-read journal authority',
        );
      }
      final frozenRouteHash = AppLlmCanonicalHash.domainHash(
        'story-generation-configured-model-route-v1',
        lease.credentialFreeIdentity,
      );
      if (formalDispatchIntent['selectedRouteBindingHash'] != frozenRouteHash) {
        throw const AppLlmPhysicalDispatchPreflightException(
          'committed-intent-route-mismatch',
          'the committed intent does not bind the active frozen route lease',
        );
      }
      validatedFormalRouteAuthority = AppSettingsFormalRouteAuthority._(
        routeIdentity: lease.credentialFreeIdentity,
        formalDispatchIntent: formalDispatchIntent,
      );
      resolved = lease.resolved;
      requestSnapshot = lease.snapshot;
      requestPool = lease.requestPool;
    } else {
      if (formalDispatchIntent != null || committedIntentAuthority != null) {
        throw const AppLlmPhysicalDispatchPreflightException(
          'adaptive-committed-intent-authority',
          'adaptive dispatch must not carry formal journal authority',
        );
      }
      resolved = _resolveRequestSettings(resolvedTraceName);
      requestSnapshot = storeSnapshot;
      requestPool = storeRequestPoolForProfile(resolved.providerProfileId);
    }
    final route = ResolvedProviderRoute(
      providerName: resolved.providerName,
      baseUrl: resolved.baseUrl,
      model: resolved.model,
      apiKey: resolved.apiKey,
      providerProfileId: resolved.providerProfileId,
    );

    // 构建备用 provider 列表用于 failover。
    final failoverEndpoints =
        physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single
        ? const <FailoverEndpoint>[]
        : storeAiRequestService.buildFailoverEndpoints(
            profiles: requestSnapshot.providerProfiles,
            excludeProfileId: resolved.providerProfileId,
          );

    // llm-call-site: boundary.settings.central-request
    return storeAiRequestService.requestCompletion(
      snapshot: requestSnapshot,
      route: route,
      requestPool: requestPool,
      requestPoolForProvider: storeRequestPoolForProfile,
      messages: messages,
      maxTokens: maxTokens,
      traceName: resolvedTraceName,
      traceMetadata: traceMetadata,
      promptReleaseRef: promptReleaseRef,
      promptInvocationEvidence: promptInvocationEvidence,
      promptVersion: promptVersion,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      generationBundleHash: generationBundleHash,
      failoverEndpoints: failoverEndpoints,
      physicalDispatchPolicy: physicalDispatchPolicy,
      dispatchEvidenceNonce: dispatchEvidenceNonce,
      formalDispatchIntent: formalDispatchIntent,
      committedIntentAuthority: committedIntentAuthority,
      formalDispatchRouteIdentity:
          singlePhysicalRouteLease?.credentialFreeIdentity,
      validatedFormalRouteAuthority: validatedFormalRouteAuthority,
      callSiteAuthority: callSiteAuthority,
    );
  }

  /// 推断 trace 名称。
  String _inferTraceName(List<AppLlmChatMessage> messages) {
    for (final message in messages.reversed) {
      for (final rawLine in message.content.split('\n')) {
        final line = rawLine.trim();
        for (final prefix in const ['任务类型', '任务']) {
          if (line.startsWith('$prefix:') || line.startsWith('$prefix：')) {
            final value = line.substring(prefix.length + 1).trim();
            if (value.isNotEmpty) return value;
          }
        }
      }
    }
    return 'ai_completion';
  }

  String providerSummaryForTrace(String traceName) {
    final routedSettings = _resolveRequestSettings(traceName);
    final source = routedSettings.providerProfileId == null
        ? '默认配置'
        : '路由：${routedSettings.providerProfileId}';
    return '${routedSettings.providerName} · '
        '${storeAiRequestService.normalizeRequestedModel(routedSettings.model)}（$source）';
  }

  String generationProviderSummary() {
    const traceNames = [
      'scene_generation',
      'scene_roleplay_turn',
      'scene_roleplay_arbitrate',
      'scene_editorial',
      'scene_review',
    ];
    final summaries = <String>{
      for (final traceName in traceNames) providerSummaryForTrace(traceName),
    };
    if (summaries.length == 1) {
      return summaries.single;
    }
    return summaries.join('；');
  }

  /// Returns the credential-free route snapshot that governs a story call.
  /// The caller hashes this object before persisting experiment provenance.
  /// Ordering is significant because it is the configured failover order.
  Object? storyGenerationModelRouteIdentity({required String traceName}) {
    final normalizedTraceName = traceName.trim();
    if (normalizedTraceName.isEmpty) return null;
    final resolved = _resolveRequestSettings(normalizedTraceName);
    final failovers = storeAiRequestService.buildFailoverEndpoints(
      profiles: storeSnapshot.providerProfiles,
      excludeProfileId: resolved.providerProfileId,
    );
    return <String, Object?>{
      'contract': 'story-generation-model-route-v1',
      'traceName': normalizedTraceName,
      'primary': <String, Object?>{
        'providerName': resolved.providerName,
        'baseUrl': resolved.baseUrl,
        'model': resolved.model,
        if (resolved.providerProfileId != null)
          'providerProfileId': resolved.providerProfileId,
      },
      'failover': <Object?>[
        for (final endpoint in failovers)
          <String, Object?>{
            'id': endpoint.id,
            'baseUrl': endpoint.baseUrl,
            'model': endpoint.model,
            'provider': endpoint.provider.name,
            'isLocal': endpoint.isLocal,
            if (endpoint.providerProfileId != null)
              'providerProfileId': endpoint.providerProfileId,
          },
      ],
    };
  }

  /// Returns the effective credential-free route for the experiment-only
  /// primary dispatch. Configured fallback endpoints are intentionally absent
  /// because the corresponding request contract cannot use them.
  StoryGenerationSinglePhysicalDispatchRouteLease?
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  }) {
    final normalizedTraceName = traceName.trim();
    if (normalizedTraceName.isEmpty) return null;
    if (!storeAiRequestService.supportsSinglePhysicalDispatch) return null;
    final resolved = _resolveRequestSettings(normalizedTraceName);
    final normalizedBaseUrl = resolved.baseUrl.trim();
    try {
      validateAppLlmSinglePhysicalDispatchRoute(
        baseUrl: normalizedBaseUrl,
        apiKey: resolved.apiKey,
        model: resolved.model,
      );
    } on AppLlmPhysicalDispatchPreflightException {
      return null;
    }
    final selectedEndpoint = AppLlmDispatchResolution(
      endpointId: resolved.providerProfileId ?? 'primary',
      baseUrl: normalizedBaseUrl,
      model: storeAiRequestService.normalizeRequestedModel(resolved.model),
      provider: storeAiRequestService.providerForSettings(
        resolved.providerName,
        normalizedBaseUrl,
      ),
      isLocal: storeAiRequestService.isLocalCompatibleEndpoint(
        normalizedBaseUrl,
      ),
      physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
      providerProfileId: resolved.providerProfileId,
    );
    final identity = <String, Object?>{
      'contract': 'story-generation-single-physical-dispatch-route-v1',
      'traceName': normalizedTraceName,
      'physicalDispatchPolicy': AppLlmPhysicalDispatchPolicy.single.name,
      'cachePolicy': 'bypass-read-write',
      'streamFallback': false,
      'gatewayRetries': 0,
      'providerFailover': false,
      'reconnectProbe': false,
      'selectedEndpoint': selectedEndpoint.toCredentialFreeJson(),
    };
    return _AppSettingsSinglePhysicalDispatchRouteLease(
      traceName: normalizedTraceName,
      resolved: resolved,
      snapshot: storeSnapshot,
      requestPool: storeRequestPoolForProfile(resolved.providerProfileId),
      credentialFreeIdentity: Map<String, Object?>.unmodifiable(identity),
    );
  }

  /// 解析请求路由，返回用于 AI 请求的配置。
  /// 委托给 LlmProviderService.resolveRoute。
  ResolvedRequestSettings _resolveRequestSettings(String traceName) {
    final route = storeProviderService.resolveRoute(
      traceName,
      storeSnapshot.requestProviderRoutes,
      storeSnapshot.providerProfiles,
      isLocalCompatibleEndpoint:
          storeAiRequestService.isLocalCompatibleEndpoint,
    );
    if (route != null) {
      return ResolvedRequestSettings(
        providerName: route.providerName,
        baseUrl: route.baseUrl,
        model: route.model,
        apiKey: route.apiKey,
        providerProfileId: route.providerProfileId,
      );
    }
    return ResolvedRequestSettings(
      providerName: storeSnapshot.providerName,
      baseUrl: storeSnapshot.baseUrl,
      model: storeSnapshot.model,
      apiKey: storeSnapshot.apiKey,
    );
  }
}

/// One-shot proof that AppSettingsStore matched the caller's private route
/// lease against current settings and the complete committed intent.
@pragma('vm:isolate-unsendable')
final class AppSettingsFormalRouteAuthority {
  AppSettingsFormalRouteAuthority._({
    required Object routeIdentity,
    required Map<String, Object?> formalDispatchIntent,
  }) : _routeDigest = AppLlmCanonicalHash.domainHash(
         'app-settings-formal-route-authority-v1',
         routeIdentity,
       ),
       _intentDigest = AppLlmCanonicalHash.domainHash(
         'story-generation-attempt-intent-record-v1',
         formalDispatchIntent,
       );

  final String _routeDigest;
  final String _intentDigest;
  bool _consumed = false;

  bool consumeFor({
    required Object routeIdentity,
    required Map<String, Object?> formalDispatchIntent,
  }) {
    if (_consumed) return false;
    _consumed = true;
    return _routeDigest ==
            AppLlmCanonicalHash.domainHash(
              'app-settings-formal-route-authority-v1',
              routeIdentity,
            ) &&
        _intentDigest ==
            AppLlmCanonicalHash.domainHash(
              'story-generation-attempt-intent-record-v1',
              formalDispatchIntent,
            );
  }
}

final class _AppSettingsSinglePhysicalDispatchRouteLease
    implements StoryGenerationSinglePhysicalDispatchRouteLease {
  const _AppSettingsSinglePhysicalDispatchRouteLease({
    required this.traceName,
    required this.resolved,
    required this.snapshot,
    required this.requestPool,
    required this.credentialFreeIdentity,
  });

  final String traceName;
  final ResolvedRequestSettings resolved;
  final AppSettingsSnapshot snapshot;
  final AppLlmRequestPool requestPool;

  @override
  final Object credentialFreeIdentity;

  bool matches(
    ResolvedRequestSettings current,
    AppSettingsSnapshot currentSnapshot,
  ) =>
      current.providerName == resolved.providerName &&
      current.baseUrl == resolved.baseUrl &&
      current.model == resolved.model &&
      current.apiKey == resolved.apiKey &&
      current.providerProfileId == resolved.providerProfileId &&
      currentSnapshot.maxTokens == snapshot.maxTokens &&
      currentSnapshot.timeout.connectTimeoutMs ==
          snapshot.timeout.connectTimeoutMs &&
      currentSnapshot.timeout.sendTimeoutMs == snapshot.timeout.sendTimeoutMs &&
      currentSnapshot.timeout.receiveTimeoutMs ==
          snapshot.timeout.receiveTimeoutMs &&
      currentSnapshot.timeout.idleTimeoutMs == snapshot.timeout.idleTimeoutMs;
}
