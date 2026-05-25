import 'dart:math';

import 'app_llm_client_types.dart';

enum ModelRoutingTaskKind {
  sceneDraft,
  proseRevision,
  reviewGate,
  polish,
  summary,
  planning,
  roleplay,
  embeddingOrRetrieval,
  utility,
}

enum ModelRoutePrivacyMode { projectDefault, localOnly }

enum ModelRouteBudgetMode {
  taskDefault,
  qualityFirst,
  balanced,
  costFirst,
  localOnly,
}

enum ModelRouteCapability { chat, streaming, jsonMode, embedding }

enum ModelRouteDecisionStatus { selected, needsUserAction }

class ModelQualityThreshold {
  const ModelQualityThreshold({required this.minimum, required this.preferred});

  final double minimum;
  final double preferred;
}

class ModelCostTarget {
  const ModelCostTarget({required this.softUsd, required this.hardUsd});

  final double softUsd;
  final double hardUsd;
}

class ModelRouteWeights {
  const ModelRouteWeights({
    required this.quality,
    required this.cost,
    required this.latency,
    required this.reliability,
  });

  final double quality;
  final double cost;
  final double latency;
  final double reliability;
}

class ModelRoutingPolicy {
  const ModelRoutingPolicy({
    this.thresholdsByTask = const {},
    this.costTargetsByTask = const {},
    this.weightsByBudgetMode = const {},
    this.allowRemoteFallbackForPrivateTasks = false,
  });

  final Map<ModelRoutingTaskKind, ModelQualityThreshold> thresholdsByTask;
  final Map<ModelRoutingTaskKind, ModelCostTarget> costTargetsByTask;
  final Map<ModelRouteBudgetMode, ModelRouteWeights> weightsByBudgetMode;
  final bool allowRemoteFallbackForPrivateTasks;

  static const defaults = ModelRoutingPolicy(
    thresholdsByTask: _defaultQualityThresholds,
    costTargetsByTask: _defaultCostTargets,
    weightsByBudgetMode: _defaultRouteWeights,
  );

  ModelQualityThreshold thresholdFor(ModelRoutingTaskKind taskKind) =>
      thresholdsByTask[taskKind] ??
      _defaultQualityThresholds[taskKind] ??
      const ModelQualityThreshold(minimum: 0.7, preferred: 0.82);

  ModelCostTarget costTargetFor(ModelRoutingTaskKind taskKind) =>
      costTargetsByTask[taskKind] ??
      _defaultCostTargets[taskKind] ??
      const ModelCostTarget(softUsd: 0.02, hardUsd: 0.06);

  ModelRouteWeights weightsFor(ModelRouteBudgetMode budgetMode) {
    final effectiveMode = budgetMode == ModelRouteBudgetMode.taskDefault
        ? ModelRouteBudgetMode.balanced
        : budgetMode;
    return weightsByBudgetMode[effectiveMode] ??
        _defaultRouteWeights[effectiveMode] ??
        _defaultRouteWeights[ModelRouteBudgetMode.balanced]!;
  }
}

class ModelRouteProfile {
  const ModelRouteProfile({
    required this.id,
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.hasApiKey,
    required this.qualityScore,
    required this.inputCostPerMillionTokens,
    required this.outputCostPerMillionTokens,
    this.latencyP50Ms,
    this.latencyP95Ms,
    this.maxContextTokens,
    this.capabilities = const {},
    this.disabled = false,
    this.circuitOpen = false,
    this.reliabilityScore = 1.0,
    this.reliabilityPenalty = 0.0,
    this.recentHardGatePenalty = 0.0,
  });

  final String id;
  final String providerName;
  final String baseUrl;
  final String model;
  final bool hasApiKey;
  final double qualityScore;
  final double inputCostPerMillionTokens;
  final double outputCostPerMillionTokens;
  final int? latencyP50Ms;
  final int? latencyP95Ms;
  final int? maxContextTokens;
  final Set<ModelRouteCapability> capabilities;
  final bool disabled;
  final bool circuitOpen;
  final double reliabilityScore;
  final double reliabilityPenalty;
  final double recentHardGatePenalty;

  bool get isLocalCompatibleEndpoint {
    final uri = Uri.tryParse(baseUrl.trim());
    final host = uri?.host.toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.localhost');
  }

  bool get hasInsecureRemoteScheme {
    final uri = Uri.tryParse(baseUrl.trim());
    final scheme = uri?.scheme.toLowerCase() ?? '';
    return scheme == 'http' && !isLocalCompatibleEndpoint;
  }

  bool get isComplete {
    return id.trim().isNotEmpty &&
        providerName.trim().isNotEmpty &&
        baseUrl.trim().isNotEmpty &&
        model.trim().isNotEmpty &&
        (hasApiKey || isLocalCompatibleEndpoint);
  }
}

class ModelRouteRequest {
  const ModelRouteRequest({
    required this.taskKind,
    required this.estimatedInputTokens,
    required this.estimatedOutputTokens,
    required this.profiles,
    this.locale,
    this.pipelineStageId,
    this.manualProfileId,
    this.primaryProfileId,
    this.privacyMode = ModelRoutePrivacyMode.projectDefault,
    this.budgetMode = ModelRouteBudgetMode.taskDefault,
    this.requiredCapabilities = const {},
    this.excludedProfileIds = const {},
    this.previousFailureKind,
  });

  final ModelRoutingTaskKind taskKind;
  final int estimatedInputTokens;
  final int estimatedOutputTokens;
  final List<ModelRouteProfile> profiles;
  final String? locale;
  final String? pipelineStageId;
  final String? manualProfileId;
  final String? primaryProfileId;
  final ModelRoutePrivacyMode privacyMode;
  final ModelRouteBudgetMode budgetMode;
  final Set<ModelRouteCapability> requiredCapabilities;
  final Set<String> excludedProfileIds;
  final AppLlmFailureKind? previousFailureKind;
}

class ModelRouteDecision {
  const ModelRouteDecision({
    required this.status,
    required this.selectedProfileId,
    required this.reasonCodes,
    required this.estimatedCostUsd,
    required this.expectedQuality,
    this.fallbackProfileIds = const [],
    this.rejectionReasons = const {},
    required this.taskKind,
    required this.budgetMode,
    required this.estimatedInputTokens,
    required this.estimatedOutputTokens,
  });

  final ModelRouteDecisionStatus status;
  final String? selectedProfileId;
  final List<String> reasonCodes;
  final double estimatedCostUsd;
  final double expectedQuality;
  final List<String> fallbackProfileIds;
  final Map<String, List<String>> rejectionReasons;
  final ModelRoutingTaskKind taskKind;
  final ModelRouteBudgetMode budgetMode;
  final int estimatedInputTokens;
  final int estimatedOutputTokens;

  List<String> get rejectedProfileIds =>
      List<String>.unmodifiable(rejectionReasons.keys);

  Map<String, Object?> toTraceJson() {
    return {
      'kind': 'model_route_decision',
      'taskKind': taskKind.name,
      'budgetMode': budgetMode.name,
      'status': status.name,
      if (selectedProfileId != null) 'selectedProfileId': selectedProfileId,
      if (fallbackProfileIds.isNotEmpty)
        'fallbackProfileIds': fallbackProfileIds,
      'reasonCodes': reasonCodes,
      'estimatedInputTokens': estimatedInputTokens,
      'estimatedOutputTokens': estimatedOutputTokens,
      'estimatedCostUsd': estimatedCostUsd,
      'expectedQuality': expectedQuality,
    };
  }
}

class DefaultModelRouter {
  const DefaultModelRouter({this.policy = ModelRoutingPolicy.defaults});

  final ModelRoutingPolicy policy;

  ModelRouteDecision choose(ModelRouteRequest request) {
    final effectiveBudget = _effectiveBudgetMode(request);
    final rejected = <String, List<String>>{};
    final trimmedManualProfileId = request.manualProfileId?.trim();
    final manualProfileId =
        trimmedManualProfileId == null || trimmedManualProfileId.isEmpty
        ? null
        : trimmedManualProfileId;

    final sourceProfiles = manualProfileId == null
        ? request.profiles
        : request.profiles
              .where((profile) => profile.id.trim() == manualProfileId)
              .toList(growable: false);

    if (sourceProfiles.isEmpty && manualProfileId != null) {
      return _needsUserAction(
        request,
        effectiveBudget,
        rejected,
        reasonCodes: const ['manual_profile_missing', 'needs_user_action'],
      );
    }

    final hardFiltered = <ModelRouteProfile>[];
    for (final profile in sourceProfiles) {
      final reasons = _hardFilterReasons(profile, request);
      if (reasons.isEmpty) {
        hardFiltered.add(profile);
      } else {
        rejected[profile.id] = reasons;
      }
    }

    if (manualProfileId != null && rejected.containsKey(manualProfileId)) {
      return _needsUserAction(
        request,
        effectiveBudget,
        rejected,
        reasonCodes: const ['manual_profile_rejected', 'needs_user_action'],
      );
    }

    final qualityFiltered = _applyQualityFloor(hardFiltered, request, rejected);
    final candidates = _applyCostHardTarget(qualityFiltered, request, rejected);

    if (candidates.isEmpty) {
      return _needsUserAction(
        request,
        effectiveBudget,
        rejected,
        reasonCodes: [
          if (manualProfileId != null)
            'manual_profile_rejected'
          else
            'no_valid_profiles',
          'needs_user_action',
        ],
      );
    }

    final ranked = _rankCandidates(candidates, request, effectiveBudget);
    final selected = ranked.first;
    final fallbackProfileIds = ranked
        .skip(1)
        .map((profile) => profile.id)
        .toList(growable: false);
    final target = policy.costTargetFor(request.taskKind);
    final selectedCost = estimateCostUsd(
      selected,
      estimatedInputTokens: request.estimatedInputTokens,
      estimatedOutputTokens: request.estimatedOutputTokens,
    );
    final reasonCodes = <String>[
      if (manualProfileId != null) 'manual_profile_selected',
      if (_isQualitySensitive(request.taskKind)) 'quality_sensitive_task',
      if (_isCostSensitive(request.taskKind)) 'cost_sensitive_task',
      if (request.previousFailureKind == AppLlmFailureKind.timeout)
        'timeout_fallback',
      'quality_floor_passed',
      if (selectedCost <= target.softUsd)
        'cost_soft_target_passed'
      else
        'cost_soft_target_exceeded',
      if (_isCostSensitive(request.taskKind) && selectedCost <= target.hardUsd)
        'cost_hard_target_passed',
      'selected_by_utility',
    ];

    return ModelRouteDecision(
      status: ModelRouteDecisionStatus.selected,
      selectedProfileId: selected.id,
      reasonCodes: List<String>.unmodifiable(reasonCodes),
      estimatedCostUsd: selectedCost,
      expectedQuality: _effectiveQuality(selected),
      fallbackProfileIds: List<String>.unmodifiable(fallbackProfileIds),
      rejectionReasons: _freezeRejections(rejected),
      taskKind: request.taskKind,
      budgetMode: effectiveBudget,
      estimatedInputTokens: request.estimatedInputTokens,
      estimatedOutputTokens: request.estimatedOutputTokens,
    );
  }

  double estimateCostUsd(
    ModelRouteProfile profile, {
    required int estimatedInputTokens,
    required int estimatedOutputTokens,
  }) {
    final inputCost =
        estimatedInputTokens / 1000000 * profile.inputCostPerMillionTokens;
    final outputCost =
        estimatedOutputTokens / 1000000 * profile.outputCostPerMillionTokens;
    return inputCost + outputCost;
  }

  ModelRouteDecision _needsUserAction(
    ModelRouteRequest request,
    ModelRouteBudgetMode budgetMode,
    Map<String, List<String>> rejected, {
    required List<String> reasonCodes,
  }) {
    return ModelRouteDecision(
      status: ModelRouteDecisionStatus.needsUserAction,
      selectedProfileId: null,
      reasonCodes: List<String>.unmodifiable(reasonCodes),
      estimatedCostUsd: 0,
      expectedQuality: 0,
      rejectionReasons: _freezeRejections(rejected),
      taskKind: request.taskKind,
      budgetMode: budgetMode,
      estimatedInputTokens: request.estimatedInputTokens,
      estimatedOutputTokens: request.estimatedOutputTokens,
    );
  }

  List<String> _hardFilterReasons(
    ModelRouteProfile profile,
    ModelRouteRequest request,
  ) {
    final reasons = <String>[];
    final totalTokens =
        request.estimatedInputTokens + request.estimatedOutputTokens;
    if (profile.disabled) reasons.add('profile_disabled');
    if (!profile.isComplete) reasons.add('profile_incomplete');
    if (profile.hasInsecureRemoteScheme) reasons.add('insecure_scheme');
    if (request.excludedProfileIds.contains(profile.id)) {
      reasons.add('excluded_after_failure');
    }
    if (request.privacyMode == ModelRoutePrivacyMode.localOnly &&
        !profile.isLocalCompatibleEndpoint) {
      reasons.add('privacy_local_only');
    }
    if (!profile.capabilities.containsAll(request.requiredCapabilities)) {
      reasons.add('missing_capability');
    }
    if (profile.maxContextTokens != null &&
        totalTokens > profile.maxContextTokens!) {
      reasons.add('context_window_exceeded');
    }
    if (profile.circuitOpen) reasons.add('circuit_open');
    return reasons;
  }

  List<ModelRouteProfile> _applyQualityFloor(
    List<ModelRouteProfile> profiles,
    ModelRouteRequest request,
    Map<String, List<String>> rejected,
  ) {
    final threshold = policy.thresholdFor(request.taskKind);
    final accepted = <ModelRouteProfile>[];
    for (final profile in profiles) {
      if (_effectiveQuality(profile) < threshold.minimum) {
        rejected[profile.id] = [
          ...?rejected[profile.id],
          'quality_floor_failed',
        ];
      } else {
        accepted.add(profile);
      }
    }
    return accepted;
  }

  List<ModelRouteProfile> _applyCostHardTarget(
    List<ModelRouteProfile> profiles,
    ModelRouteRequest request,
    Map<String, List<String>> rejected,
  ) {
    if (!_isCostSensitive(request.taskKind)) return profiles;
    final target = policy.costTargetFor(request.taskKind);
    final hasProfileWithinHardTarget = profiles.any((profile) {
      return estimateCostUsd(
            profile,
            estimatedInputTokens: request.estimatedInputTokens,
            estimatedOutputTokens: request.estimatedOutputTokens,
          ) <=
          target.hardUsd;
    });
    if (!hasProfileWithinHardTarget) return profiles;

    final accepted = <ModelRouteProfile>[];
    for (final profile in profiles) {
      final cost = estimateCostUsd(
        profile,
        estimatedInputTokens: request.estimatedInputTokens,
        estimatedOutputTokens: request.estimatedOutputTokens,
      );
      if (cost > target.hardUsd) {
        rejected[profile.id] = [
          ...?rejected[profile.id],
          'cost_hard_target_exceeded',
        ];
      } else {
        accepted.add(profile);
      }
    }
    return accepted;
  }

  List<ModelRouteProfile> _rankCandidates(
    List<ModelRouteProfile> candidates,
    ModelRouteRequest request,
    ModelRouteBudgetMode budgetMode,
  ) {
    final ranked = List<ModelRouteProfile>.of(candidates);
    ranked.sort((a, b) {
      final scoreA = _utility(a, request, budgetMode);
      final scoreB = _utility(b, request, budgetMode);
      final scoreCompare = scoreB.compareTo(scoreA);
      if (scoreCompare != 0) return scoreCompare;

      final primaryProfileId = request.primaryProfileId?.trim();
      if (primaryProfileId != null && primaryProfileId.isNotEmpty) {
        if (a.id == primaryProfileId && b.id != primaryProfileId) return -1;
        if (b.id == primaryProfileId && a.id != primaryProfileId) return 1;
      }

      final costA = estimateCostUsd(
        a,
        estimatedInputTokens: request.estimatedInputTokens,
        estimatedOutputTokens: request.estimatedOutputTokens,
      );
      final costB = estimateCostUsd(
        b,
        estimatedInputTokens: request.estimatedInputTokens,
        estimatedOutputTokens: request.estimatedOutputTokens,
      );
      final costCompare = costA.compareTo(costB);
      if (costCompare != 0) return costCompare;

      final latencyCompare = _latencyP95(a).compareTo(_latencyP95(b));
      if (latencyCompare != 0) return latencyCompare;

      if (a.isLocalCompatibleEndpoint != b.isLocalCompatibleEndpoint) {
        return a.isLocalCompatibleEndpoint ? -1 : 1;
      }

      return a.id.compareTo(b.id);
    });
    return ranked;
  }

  double _utility(
    ModelRouteProfile profile,
    ModelRouteRequest request,
    ModelRouteBudgetMode budgetMode,
  ) {
    final target = policy.costTargetFor(request.taskKind);
    final weights = _weightsFor(request, budgetMode);
    final cost = estimateCostUsd(
      profile,
      estimatedInputTokens: request.estimatedInputTokens,
      estimatedOutputTokens: request.estimatedOutputTokens,
    );
    final normalizedCost = target.hardUsd <= 0
        ? 0.0
        : (cost / target.hardUsd).clamp(0.0, 1.0);
    final normalizedLatency = (_latencyP95(profile) / _latencyTargetMs(request))
        .clamp(0.0, 1.0);
    return weights.quality * _effectiveQuality(profile).clamp(0.0, 1.0) -
        weights.cost * normalizedCost -
        weights.latency * normalizedLatency +
        weights.reliability * profile.reliabilityScore.clamp(0.0, 1.0);
  }

  ModelRouteWeights _weightsFor(
    ModelRouteRequest request,
    ModelRouteBudgetMode budgetMode,
  ) {
    final base = policy.weightsFor(budgetMode);
    if (request.previousFailureKind != AppLlmFailureKind.timeout) return base;
    return ModelRouteWeights(
      quality: base.quality,
      cost: base.cost * 0.6,
      latency: max(base.latency, 0.45),
      reliability: base.reliability,
    );
  }

  double _effectiveQuality(ModelRouteProfile profile) {
    return (profile.qualityScore -
            profile.reliabilityPenalty -
            profile.recentHardGatePenalty)
        .clamp(0.0, 1.0);
  }

  int _latencyP95(ModelRouteProfile profile) =>
      profile.latencyP95Ms ?? profile.latencyP50Ms ?? 1500;

  int _latencyTargetMs(ModelRouteRequest request) {
    if (request.previousFailureKind == AppLlmFailureKind.timeout) return 1000;
    switch (request.taskKind) {
      case ModelRoutingTaskKind.utility:
      case ModelRoutingTaskKind.summary:
      case ModelRoutingTaskKind.embeddingOrRetrieval:
        return 1200;
      case ModelRoutingTaskKind.sceneDraft:
      case ModelRoutingTaskKind.proseRevision:
      case ModelRoutingTaskKind.reviewGate:
      case ModelRoutingTaskKind.polish:
      case ModelRoutingTaskKind.planning:
      case ModelRoutingTaskKind.roleplay:
        return 2500;
    }
  }

  ModelRouteBudgetMode _effectiveBudgetMode(ModelRouteRequest request) {
    if (request.privacyMode == ModelRoutePrivacyMode.localOnly ||
        request.budgetMode == ModelRouteBudgetMode.localOnly) {
      return ModelRouteBudgetMode.localOnly;
    }
    if (request.previousFailureKind == AppLlmFailureKind.timeout) {
      return ModelRouteBudgetMode.balanced;
    }
    if (request.budgetMode != ModelRouteBudgetMode.taskDefault) {
      return request.budgetMode;
    }
    if (_isQualitySensitive(request.taskKind)) {
      return ModelRouteBudgetMode.qualityFirst;
    }
    if (_isCostSensitive(request.taskKind)) {
      return ModelRouteBudgetMode.costFirst;
    }
    return ModelRouteBudgetMode.balanced;
  }

  bool _isQualitySensitive(ModelRoutingTaskKind taskKind) {
    switch (taskKind) {
      case ModelRoutingTaskKind.sceneDraft:
      case ModelRoutingTaskKind.proseRevision:
      case ModelRoutingTaskKind.reviewGate:
      case ModelRoutingTaskKind.roleplay:
        return true;
      case ModelRoutingTaskKind.polish:
      case ModelRoutingTaskKind.summary:
      case ModelRoutingTaskKind.planning:
      case ModelRoutingTaskKind.embeddingOrRetrieval:
      case ModelRoutingTaskKind.utility:
        return false;
    }
  }

  bool _isCostSensitive(ModelRoutingTaskKind taskKind) {
    switch (taskKind) {
      case ModelRoutingTaskKind.summary:
      case ModelRoutingTaskKind.embeddingOrRetrieval:
      case ModelRoutingTaskKind.utility:
        return true;
      case ModelRoutingTaskKind.sceneDraft:
      case ModelRoutingTaskKind.proseRevision:
      case ModelRoutingTaskKind.reviewGate:
      case ModelRoutingTaskKind.polish:
      case ModelRoutingTaskKind.planning:
      case ModelRoutingTaskKind.roleplay:
        return false;
    }
  }

  Map<String, List<String>> _freezeRejections(
    Map<String, List<String>> rejected,
  ) {
    return Map<String, List<String>>.unmodifiable({
      for (final entry in rejected.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    });
  }
}

const _defaultQualityThresholds = <ModelRoutingTaskKind, ModelQualityThreshold>{
  ModelRoutingTaskKind.reviewGate: ModelQualityThreshold(
    minimum: 0.92,
    preferred: 0.96,
  ),
  ModelRoutingTaskKind.sceneDraft: ModelQualityThreshold(
    minimum: 0.86,
    preferred: 0.92,
  ),
  ModelRoutingTaskKind.proseRevision: ModelQualityThreshold(
    minimum: 0.86,
    preferred: 0.92,
  ),
  ModelRoutingTaskKind.roleplay: ModelQualityThreshold(
    minimum: 0.84,
    preferred: 0.90,
  ),
  ModelRoutingTaskKind.polish: ModelQualityThreshold(
    minimum: 0.82,
    preferred: 0.90,
  ),
  ModelRoutingTaskKind.planning: ModelQualityThreshold(
    minimum: 0.78,
    preferred: 0.86,
  ),
  ModelRoutingTaskKind.summary: ModelQualityThreshold(
    minimum: 0.70,
    preferred: 0.82,
  ),
  ModelRoutingTaskKind.embeddingOrRetrieval: ModelQualityThreshold(
    minimum: 0.68,
    preferred: 0.78,
  ),
  ModelRoutingTaskKind.utility: ModelQualityThreshold(
    minimum: 0.60,
    preferred: 0.72,
  ),
};

const _defaultCostTargets = <ModelRoutingTaskKind, ModelCostTarget>{
  ModelRoutingTaskKind.reviewGate: ModelCostTarget(
    softUsd: 0.040,
    hardUsd: 0.120,
  ),
  ModelRoutingTaskKind.sceneDraft: ModelCostTarget(
    softUsd: 0.060,
    hardUsd: 0.180,
  ),
  ModelRoutingTaskKind.proseRevision: ModelCostTarget(
    softUsd: 0.040,
    hardUsd: 0.120,
  ),
  ModelRoutingTaskKind.roleplay: ModelCostTarget(
    softUsd: 0.040,
    hardUsd: 0.120,
  ),
  ModelRoutingTaskKind.polish: ModelCostTarget(softUsd: 0.030, hardUsd: 0.090),
  ModelRoutingTaskKind.planning: ModelCostTarget(
    softUsd: 0.025,
    hardUsd: 0.075,
  ),
  ModelRoutingTaskKind.summary: ModelCostTarget(softUsd: 0.010, hardUsd: 0.030),
  ModelRoutingTaskKind.embeddingOrRetrieval: ModelCostTarget(
    softUsd: 0.005,
    hardUsd: 0.020,
  ),
  ModelRoutingTaskKind.utility: ModelCostTarget(softUsd: 0.005, hardUsd: 0.020),
};

const _defaultRouteWeights = <ModelRouteBudgetMode, ModelRouteWeights>{
  ModelRouteBudgetMode.qualityFirst: ModelRouteWeights(
    quality: 0.65,
    cost: 0.15,
    latency: 0.10,
    reliability: 0.10,
  ),
  ModelRouteBudgetMode.balanced: ModelRouteWeights(
    quality: 0.50,
    cost: 0.25,
    latency: 0.10,
    reliability: 0.15,
  ),
  ModelRouteBudgetMode.costFirst: ModelRouteWeights(
    quality: 0.35,
    cost: 0.50,
    latency: 0.05,
    reliability: 0.10,
  ),
  ModelRouteBudgetMode.localOnly: ModelRouteWeights(
    quality: 0.45,
    cost: 0.30,
    latency: 0.10,
    reliability: 0.15,
  ),
};
