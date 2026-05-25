# Model Routing Design

> Plan ID: M8-06
> Related Issues: #79, #23
> Base branch: `feature/m8-05-review-package-export`
> Target branch: `feature/m8-06-model-routing-design`
> Implementation handoff: M8-07, `lib/app/llm/model_router.dart`
> Status: Design

## 1. Purpose and Non-Goals

### 1.1 Purpose

M8-06 defines the routing contract that lets n0vel choose a model profile by
task value instead of only by the current primary provider. The router should
balance quality, cost, latency, reliability, privacy, and user intent while
preserving the existing LLM safety posture:

1. **Author control first** - an explicit provider/profile choice always wins
   unless it violates security or availability constraints.
2. **Quality gates for creative risk** - review, editorial, and finalization
   tasks require higher quality thresholds than summaries or utility tasks.
3. **Cost-aware defaults** - low-risk tasks can use cheaper or local profiles
   when they still meet the minimum quality floor.
4. **Fail closed on sensitive work** - privacy-sensitive tasks do not fall back
   to remote profiles unless the user has allowed that route.
5. **Observable decisions** - every automatic route produces a small redacted
   decision trace for debugging, CI fixtures, and Production views.

### 1.2 Non-Goals

1. **No runtime implementation in M8-06** - this document does not add
   `model_router.dart` or change request execution.
2. **No dynamic learning loop yet** - M8-07 may consume configured scores and
   recorded metrics, but it does not train or tune models automatically.
3. **No new provider adapters** - routing works across existing provider
   profiles.
4. **No bypass of `AppLlmClientGateway`** - retries, failure mapping, circuit
   breakers, and SSE handling remain in the existing gateway/client layer.
5. **No secret exposure** - route traces must not include prompt text, API
   keys, authorization headers, or raw request payloads.

## 2. Existing Constraints

The router sits above the current LLM request layer and below feature-level
commands:

```text
Workbench / Pipeline / Production action
        |
        v
ModelRouter.choose(request)
        |
        v
Selected AppLlmProviderProfile + fallback chain
        |
        v
AppLlmClientGateway
  AppLlmRetryPolicy
  AppLlmRequestExecutionPolicy
  AppLlmFailureKind mapping
  AppLlmFailoverChain
        |
        v
Provider adapter / HTTP client
```

Important existing pieces:

| Existing module | Role in the routing design |
|-----------------|----------------------------|
| `AppLlmProviderProfile` | Stores provider name, base URL, model, key state, and profile id. |
| `ModelProfileStore` / settings provider management | Owns profile CRUD and primary-profile selection. |
| `AppLlmRetryPolicy` | Owns retry attempts, backoff, jitter, and retryable `AppLlmFailureKind` values. |
| `AppLlmRequestExecutionPolicy` | Owns request-pool concurrency and start pacing. |
| `AppLlmClientGateway` | Owns execution, failure handling, and reconnection behavior. |
| `AppLlmFailureKind` | Supplies stable failure categories for fallback decisions. |

M8-07 should reuse these seams. Routing chooses a profile and records why; it
does not duplicate transport, retry, or provider-specific HTTP behavior.

## 3. Routing Inputs

### 3.1 Task Kind

Each request must declare a task kind. The initial vocabulary is intentionally
small and maps to current pipeline/workbench behavior.

| Task kind | Typical caller | Quality pressure | Cost pressure |
|-----------|----------------|------------------|---------------|
| `sceneDraft` | Scene pipeline, "write current scene" | High | Medium |
| `proseRevision` | AI rewrite, candidate improvement | High | Medium |
| `reviewGate` | Review/hard-gate checks | Very high | Low |
| `polish` | Final polish pass | High | Medium |
| `summary` | History, context, review package summaries | Medium | High |
| `planning` | Scene plan / outline | Medium-high | Medium |
| `roleplay` | Character/council simulation | High | Medium |
| `embeddingOrRetrieval` | Future retrieval/index helpers | Medium | Very high |
| `utility` | Connection tests, labels, lightweight transforms | Low-medium | Very high |

### 3.2 Route Request

The request should contain only metadata needed for routing:

```dart
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

class ModelRouteRequest {
  const ModelRouteRequest({
    required this.taskKind,
    required this.estimatedInputTokens,
    required this.estimatedOutputTokens,
    this.locale,
    this.pipelineStageId,
    this.manualProfileId,
    this.privacyMode = ModelRoutePrivacyMode.projectDefault,
    this.budgetMode = ModelRouteBudgetMode.balanced,
    this.requiredCapabilities = const {},
  });

  final ModelRoutingTaskKind taskKind;
  final int estimatedInputTokens;
  final int estimatedOutputTokens;
  final String? locale;
  final String? pipelineStageId;
  final String? manualProfileId;
  final ModelRoutePrivacyMode privacyMode;
  final ModelRouteBudgetMode budgetMode;
  final Set<ModelRouteCapability> requiredCapabilities;
}
```

The request must not include message content. Token estimates are enough for
cost scoring and keep routing traces safe by construction.

### 3.3 Profile Metadata

`AppLlmProviderProfile` should remain the user-facing profile object. M8-07 can
add routing metadata beside it rather than overloading API-key settings:

```dart
class ModelProfileRoutingMetadata {
  const ModelProfileRoutingMetadata({
    required this.profileId,
    required this.qualityScore,
    required this.inputCostPerMillionTokens,
    required this.outputCostPerMillionTokens,
    this.latencyP50Ms,
    this.latencyP95Ms,
    this.maxContextTokens,
    this.capabilities = const {},
    this.localOnly = false,
    this.remoteAllowed = true,
    this.disabled = false,
  });

  final String profileId;
  final double qualityScore; // 0.0 to 1.0
  final double inputCostPerMillionTokens;
  final double outputCostPerMillionTokens;
  final int? latencyP50Ms;
  final int? latencyP95Ms;
  final int? maxContextTokens;
  final Set<ModelRouteCapability> capabilities;
  final bool localOnly;
  final bool remoteAllowed;
  final bool disabled;
}
```

Routing metadata may be hand-configured at first. Later Production metrics can
update latency, reliability, and observed cost without changing the route API.

## 4. 质量阈值 / Quality Thresholds

Each task has a quality floor. A route is invalid if its expected quality is
below the floor after applying reliability penalties.

| Task kind | Minimum quality | Preferred quality | Notes |
|-----------|-----------------|-------------------|-------|
| `reviewGate` | 0.92 | 0.96 | Hard gates protect accepted text and memory writeback. |
| `sceneDraft` | 0.86 | 0.92 | Creative generation should not degrade to a weak profile silently. |
| `proseRevision` | 0.86 | 0.92 | Rewrites affect author-visible prose and need high fidelity. |
| `roleplay` | 0.84 | 0.90 | Character-state continuity matters more than raw speed. |
| `polish` | 0.82 | 0.90 | Output must preserve accepted content. |
| `planning` | 0.78 | 0.86 | Plans can be corrected before prose generation. |
| `summary` | 0.70 | 0.82 | Summaries are useful but less risky. |
| `embeddingOrRetrieval` | 0.68 | 0.78 | Cost and consistency matter more than prose quality. |
| `utility` | 0.60 | 0.72 | Lightweight transforms may use cheaper/local models. |

Rules:

1. `reviewGate`, `sceneDraft`, `proseRevision`, and `roleplay` are
   **quality-sensitive**. They may fall back only to profiles that still meet
   the minimum quality floor.
2. If no profile meets the floor for a quality-sensitive task, the router must
   return `needsUserAction` instead of picking a cheaper low-quality model.
3. `summary`, `embeddingOrRetrieval`, and `utility` are **cost-sensitive**.
   They may degrade to cheaper profiles as long as their floor is met.
4. Observed hard-gate failures should reduce a profile's effective quality for
   the failing task kind until the circuit/reliability window recovers.

Effective quality:

```text
effectiveQuality =
  configuredQualityScore
  - reliabilityPenalty
  - recentHardGatePenalty
  - missingCapabilityPenalty
```

`missingCapabilityPenalty` should normally be implemented as a hard filter, but
keeping it visible in the formula helps explain trace output.

## 5. 成本目标 / Cost Targets

Cost scoring uses estimated tokens before the request and actual usage after
the request when provider responses include token counts.

```text
estimatedCost =
  estimatedInputTokens / 1_000_000 * inputCostPerMillionTokens
  + estimatedOutputTokens / 1_000_000 * outputCostPerMillionTokens
```

Default per-request target bands:

| Task kind | Soft target | Hard target | Behavior above hard target |
|-----------|-------------|-------------|-----------------------------|
| `reviewGate` | $0.040 | $0.120 | Ask user or use explicit quality preset. |
| `sceneDraft` | $0.060 | $0.180 | Try equivalent cheaper profile before blocking. |
| `proseRevision` | $0.040 | $0.120 | Prefer cheaper profile if quality remains above floor. |
| `roleplay` | $0.040 | $0.120 | Prefer lower latency only after quality is satisfied. |
| `polish` | $0.030 | $0.090 | Prefer balanced route. |
| `planning` | $0.025 | $0.075 | Prefer balanced or cheap route. |
| `summary` | $0.010 | $0.030 | Use cheapest valid route by default. |
| `embeddingOrRetrieval` | $0.005 | $0.020 | Use cheapest compatible route. |
| `utility` | $0.005 | $0.020 | Use local/cheap route whenever possible. |

Budget modes adjust weights, not hard safety floors:

| Budget mode | Quality weight | Cost weight | Latency weight | Intended use |
|-------------|----------------|-------------|----------------|--------------|
| `qualityFirst` | 0.65 | 0.15 | 0.10 | Final prose, review gates, important scenes. |
| `balanced` | 0.50 | 0.30 | 0.10 | Default writing workflow. |
| `costFirst` | 0.35 | 0.50 | 0.10 | Summaries, utilities, budget-constrained projects. |
| `localOnly` | 0.45 | 0.30 | 0.15 | Privacy-sensitive or offline work. |

The remaining weight is reserved for reliability. M8-07 should keep the
weights configurable in code or settings without exposing an overly complex UI.

## 6. 路由规则 / Routing Rules

The router is a deterministic filter-then-rank pipeline.

### 6.1 Hard Filters

Apply filters in this order:

1. **Manual profile** - if `manualProfileId` is present, validate only that
   profile. Reject it if it is disabled, unusable, insecure, missing required
   capabilities, or blocked by privacy mode.
2. **Enabled profile** - remove disabled or incomplete profiles.
3. **Security** - keep the existing local HTTP exception, but reject insecure
   non-localhost endpoints.
4. **Privacy** - when privacy mode is local-only, keep only local-compatible
   profiles.
5. **Capability** - require context size, streaming support, JSON support, or
   embedding capability when the task needs them.
6. **Circuit/retry state** - remove profiles currently blocked by failure state
   unless no other valid route exists and the task is explicitly retryable.
7. **Quality floor** - remove profiles below the minimum quality threshold for
   the task kind.
8. **Cost hard target** - for cost-sensitive tasks, remove profiles above the
   hard target when at least one valid cheaper route remains.

If all profiles are filtered out, return a decision with `status:
needsUserAction` and redacted reason codes.

### 6.2 Ranking Formula

For remaining profiles:

```text
utility =
  qualityWeight * normalizedQuality
  - costWeight * normalizedCost
  - latencyWeight * normalizedLatency
  + reliabilityWeight * normalizedReliability
```

Where:

| Field | Normalization |
|-------|---------------|
| `normalizedQuality` | `effectiveQuality`, clamped to `0.0..1.0`. |
| `normalizedCost` | `estimatedCost / hardTarget`, clamped to `0.0..1.0`. |
| `normalizedLatency` | `latencyP95Ms / latencyTargetMs`, clamped to `0.0..1.0`; unknown latency is `0.5`. |
| `normalizedReliability` | `1.0 - recentRetryOrFailureRate`, clamped to `0.0..1.0`. |

Tie-breakers are stable and should be applied in this order:

1. Explicit primary profile when it is within 5% of the top utility.
2. Lower estimated cost.
3. Lower latency p95.
4. Local-compatible profile for privacy-friendly workflows.
5. Lexicographic profile id for deterministic tests.

### 6.3 Fallback and 降级 Rules

Fallback is chosen when the selected profile fails with a retryable or
recoverable `AppLlmFailureKind`.

| Failure kind | Fallback behavior |
|--------------|-------------------|
| `rateLimited` | Try the next valid profile in the same quality band, then cheaper equivalent provider. |
| `timeout` | Try a lower-latency valid profile; keep quality floor. |
| `network` | Try alternate provider or local profile if privacy allows. |
| `server` | Try alternate provider after gateway retry policy is exhausted. |
| `modelNotFound` | Remove profile from this decision window and choose next valid route. |
| `invalidResponse` | For `reviewGate`, stop and request user action; for utility tasks, try next profile. |
| `unauthorized` | Do not retry other profiles with the same secret/profile; surface settings action. |
| `insecureScheme` | Fail closed; do not fall back to the insecure endpoint. |

Fallback order:

1. Same provider, equivalent model/profile with quality above floor.
2. Alternate provider in the same quality band.
3. Cheaper compatible profile if the task is cost-sensitive and quality floor
   still passes.
4. Local-compatible profile if privacy mode permits and the task can degrade.
5. `needsUserAction` for critical tasks or if no valid profile remains.

The fallback chain must be computed up front and included in the decision trace
as profile ids and reason codes, not prompts or secrets.

## 7. Proposed M8-07 API Surface

M8-07 should implement a pure Dart router first, with no network calls.

```dart
class ModelRoutingPolicy {
  const ModelRoutingPolicy({
    required this.thresholdsByTask,
    required this.costTargetsByTask,
    required this.weightsByBudgetMode,
    this.allowRemoteFallbackForPrivateTasks = false,
  });

  final Map<ModelRoutingTaskKind, ModelQualityThreshold> thresholdsByTask;
  final Map<ModelRoutingTaskKind, ModelCostTarget> costTargetsByTask;
  final Map<ModelRouteBudgetMode, ModelRouteWeights> weightsByBudgetMode;
  final bool allowRemoteFallbackForPrivateTasks;
}

class ModelRouteDecision {
  const ModelRouteDecision({
    required this.status,
    required this.selectedProfileId,
    required this.reasonCodes,
    required this.estimatedCost,
    required this.expectedQuality,
    this.fallbackProfileIds = const [],
  });

  final ModelRouteDecisionStatus status;
  final String? selectedProfileId;
  final List<String> reasonCodes;
  final double estimatedCost;
  final double expectedQuality;
  final List<String> fallbackProfileIds;
}

abstract interface class ModelRouter {
  ModelRouteDecision choose(ModelRouteRequest request);
}
```

Recommended implementation files:

| File | Responsibility |
|------|----------------|
| `lib/app/llm/model_router.dart` | Pure routing types, default policy, deterministic chooser. |
| `test/app/llm/model_router_test.dart` or `test/model_router_test.dart` | Unit tests for filters, ranking, fallback, and trace redaction. |
| Optional provider wiring file | Future integration with `ModelProfileStore` and settings. |

The pure router should accept plain profile metadata lists so tests can avoid
settings-store setup and provider secrets.

## 8. Observability and Privacy

Each decision should emit a compact trace object:

```json
{
  "kind": "model_route_decision",
  "taskKind": "sceneDraft",
  "budgetMode": "balanced",
  "selectedProfileId": "primary",
  "fallbackProfileIds": ["local-fast"],
  "reasonCodes": [
    "quality_floor_passed",
    "cost_soft_target_passed",
    "primary_profile_tiebreak"
  ],
  "estimatedInputTokens": 1200,
  "estimatedOutputTokens": 1800,
  "estimatedCost": 0.042,
  "expectedQuality": 0.91
}
```

Rules:

1. No prompt text.
2. No chat messages.
3. No API keys or headers.
4. No base URL query strings.
5. Profile ids are allowed because they already appear in local settings and
   are useful for debugging.
6. Actual token usage, latency, retry count, and final failure kind may be
   appended after execution for Production views.

## 9. Settings and UI Contract

The initial UI should stay simple:

| Setting | Options | Default |
|---------|---------|---------|
| Routing mode | `manual`, `balanced`, `qualityFirst`, `costFirst`, `localOnly` | `manual` until M8-07 integration is stable. |
| Task overrides | Optional profile per task kind | None. |
| Project budget | Daily/project soft cap | Off. |
| Remote fallback for private tasks | On/off | Off. |

Manual mode preserves current behavior. Automatic modes only change profile
selection after the user opts in or after a later migration explicitly enables
it.

## 10. M8-07 Test Plan

M8-07 acceptance tests should cover:

1. Chooses the highest-quality valid profile for `reviewGate`.
2. Chooses the cheapest valid profile for `summary` when quality floor passes.
3. Rejects disabled, incomplete, or insecure non-localhost profiles.
4. Respects `manualProfileId` and reports why a manual profile is rejected.
5. Respects `localOnly` privacy mode.
6. Applies cost hard targets for cost-sensitive tasks.
7. Builds a fallback chain for `rateLimited`, `timeout`, `network`, and
   `server` failures without crossing privacy boundaries.
8. Fails closed for `unauthorized` and `insecureScheme`.
9. Produces deterministic tie-breaks.
10. Emits redacted route traces with no prompt, message, key, or header fields.

## 11. Rollback Strategy

M8-06 is docs-only and can be reverted cleanly. M8-07 should keep runtime
integration behind routing mode:

1. `manual` mode uses the existing primary profile path.
2. If router construction fails, fall back to manual mode and record a local
   warning event.
3. If route scoring produces `needsUserAction`, do not silently choose a model.
4. If Production metrics are unavailable, use configured metadata defaults.

## 12. Acceptance Checklist

- [x] Defines 质量阈值 / quality thresholds.
- [x] Defines 成本目标 / cost targets.
- [x] Defines 路由规则 / routing rules.
- [x] Defines fallback and degradation behavior.
- [x] Names the M8-07 implementation target: `model_router.dart`.
- [x] Reuses existing LLM concepts: `AppLlmFailureKind`,
  `AppLlmRetryPolicy`, `AppLlmRequestExecutionPolicy`, provider profiles, and
  gateway execution.
- [x] Keeps M8-06 out of runtime implementation scope.
