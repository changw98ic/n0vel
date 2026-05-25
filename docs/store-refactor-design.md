# Store Split and Projection Layer Design

> Plan ID: M4-13
> Related Issues: #52, #23
> Base branch: `feature/m4-12-provider-bootstrap`
> Status: Design handoff

## 1. Purpose

M4-02 through M4-12 moved the app's default store surfaces to native
Riverpod providers while keeping `ServiceRegistry` as the production bootstrap
compatibility owner. The next M4 work should stop treating mutable store
instances as the primary UI state shape and introduce read-focused projections
that can be tested and evolved independently.

This document defines the split boundaries, projection API shape, migration
order, verification strategy, and rollback rules for that next phase. It is a
design-only slice: no production code is changed by M4-13.

## 2. Current State After M4-12

The current app state surface has three layers:

| Layer | Current status | Notes |
| --- | --- | --- |
| Native provider defaults | Complete for infrastructure, DB-backed services, core stores, feature stores, and `StoryGenerationRunStore` | Default provider construction no longer depends on `serviceRegistryProvider`. |
| Production bootstrap compatibility | Still active | `NovelWriterApp` normally creates a registry and applies `appProviderOverridesForRegistry()` so startup still shares registry-owned singleton instances. |
| Provider-first smoke path | Test-only | `NovelWriterApp.debugUseProviderBootstrap` can boot with explicit native provider overrides and without a registry override. |

Remaining M4 work is no longer "make providers exist"; it is "make the state
shape safe, smaller, and explicit."

## 3. Problems To Solve

### 3.1 Mutable Store Instances Leak Too Much Surface

Most providers still expose mutable store objects such as `AppWorkspaceStore`,
`AppSettingsStore`, and `StoryGenerationRunStore`. Consumers can call any method
on the store and can accidentally couple UI rebuilds to implementation details.

### 3.2 `StoryGenerationRunStore` Is Still A Wide Orchestrator

`StoryGenerationRunStore` owns or coordinates:

- current scene run snapshot
- per-scene snapshot cache
- director feedback cache
- run cancellation tokens
- pipeline runner construction
- storage restore/save
- author feedback and review task side effects
- workspace scene/project scope changes
- project deletion cleanup

That width is acceptable for the provider migration phase, but it blocks a
clean run center, background-run projection, and future local API endpoints.

### 3.3 Project-Scoped Stores Have Similar Restore Patterns

`AppProjectScopedStore` already centralizes workspace-scope restore logic for
many stores, but UI code still reads store-specific mutable objects. The next
phase should preserve the existing persistence behavior while adding stable
read models on top.

## 4. Design Principles

1. Keep existing stores as command owners until their behavior is covered by
   projections and focused tests.
2. Add read-only projections before moving write commands.
3. Keep projection data immutable and serializable where practical.
4. Move one user-visible workflow at a time.
5. Do not remove registry bootstrap compatibility until production startup,
   crash recovery, and persisted storage paths have provider-first coverage.

## 5. Projection Model

Introduce projection providers under `lib/app/state/projection/`:

```dart
class WorkbenchProjection {
  final ProjectSummaryProjection project;
  final SceneSummaryProjection scene;
  final DraftProjection draft;
  final RunProjection run;
  final List<ReviewTaskProjection> reviewTasks;
}

class RunProjection {
  final String sceneScopeId;
  final String runId;
  final StoryGenerationRunPhase phase;
  final bool isRunning;
  final String? failureSummary;
  final List<RunStageProjection> stages;
  final int candidateCount;
}
```

Projection providers should read the existing store providers and derive
immutable view objects:

```dart
final runProjectionProvider = Provider<RunProjection>((ref) {
  final runStore = ref.watch(storyGenerationRunStoreProvider);
  return RunProjection.fromSnapshot(
    sceneScopeId: runStore.activeSceneScopeId,
    snapshot: runStore.snapshot,
  );
});
```

The first implementation can be synchronous `Provider`s because current stores
already expose in-memory state. Later work may convert projections to
`AsyncNotifierProvider` only when the projection itself performs restore or IO.

## 6. Command Model

Write operations should stay on stores during the first projection phase. Once
projections are stable, add thin command providers for workflows that need a
restricted command surface:

```dart
abstract interface class RunCommands {
  Future<void> runCurrentScene();
  Future<void> retryRecoveredRun();
  Future<void> discardRecoveredRun();
  Future<void> cancelCurrentRun();
}
```

Initial command providers may delegate directly to existing stores:

```dart
final runCommandsProvider = Provider<RunCommands>((ref) {
  return StoryGenerationRunCommands(ref.watch(storyGenerationRunStoreProvider));
});
```

This keeps behavior stable while preventing new UI from depending on the full
mutable store API.

## 7. Store Split Boundaries

### 7.1 `StoryGenerationRunStore`

Split by responsibility, not by current private fields:

| Target unit | Owns | Does not own |
| --- | --- | --- |
| `RunSessionController` | active run token, cancellation, retry entry points | persistence, UI messages |
| `RunSnapshotRepository` | save/load/clear of run snapshots by scene scope | pipeline execution |
| `RunProjectionAssembler` | immutable run timeline, candidate counts, recovery flags | mutation commands |
| `RunFeedbackCoordinator` | author feedback and review task side effects | run token lifecycle |
| `RunScopeCoordinator` | scene/project scope changes and project deletion cleanup | pipeline execution |

M4 should implement these as private collaborators first, inside or adjacent to
the existing run-store module. Public provider names should not change until
Workbench and run-center projections are green.

### 7.2 Workspace Store

`AppWorkspaceStore` should keep command ownership for now because it is central
to project/scene CRUD. Add projections first:

- `WorkspaceCatalogProjection`: projects and last-opened metadata
- `CurrentProjectProjection`: current project, breadcrumb, transfer state
- `SceneCursorProjection`: current scene, scope ID, scene list summaries
- `ProjectResourceProjection`: character/world/audit/resource counts

### 7.3 Project-Scoped Stores

Stores based on `AppProjectScopedStore` should expose small projections:

- `DraftProjection`: dirty state, body length, scene scope
- `SceneContextProjection`: context status and restore readiness
- `SimulationProjection`: selected session and status
- `ReviewTaskProjection`: open/recent task counts and visible tasks

These projections should avoid exposing backing storage payloads directly.

### 7.4 Settings Store

`AppSettingsStore` can be split later. For projection work, expose:

- `LlmProfileProjection`
- `RequestPolicyProjection`
- `UiPrefsProjection`
- `SecretStatusProjection` with no raw secret values

## 8. Migration Order

| Slice | Goal | Files likely touched | Acceptance |
| --- | --- | --- | --- |
| M4-14 | Add projection directory and run projection | `lib/app/state/projection/`, run tests | Run Center can read `RunProjection` without direct snapshot mapping logic. |
| M4-15 | Add workspace/current-scene projections | projection files, workbench tests | Workbench shell can read project/scene summaries from projections. |
| M4-16 | Add command provider facades for run workflows | projection/command files, workbench tests | New UI calls command providers instead of full run store where feasible. |
| M4-17 | Extract run snapshot repository collaborator | run store module, run-store tests | Behavior unchanged; snapshot persistence covered by existing tests. |
| M4-18 | Extract run session/scope collaborators | run store module, workbench tests | Cancel/retry/scene-switch behavior unchanged. |
| M4-19 | Provider-first production bootstrap decision record | docs and maybe app tests | Clear go/no-go criteria before removing registry bootstrap. |

## 9. Testing Strategy

Each implementation slice should include:

- focused unit tests for projection constructors and edge cases
- provider tests using `createTestProviderOverrides()`
- widget regression tests for any Workbench or Run Center consumer migration
- local `flutter analyze`
- focused `flutter test` commands covering touched stores/widgets
- CI checks after push

The first projection slice should avoid changing persistence behavior. If a
test requires storage mutation changes, that slice is too large.

## 10. Rollback Strategy

Projection additions are additive. If a slice regresses behavior:

1. Revert the projection consumer migration first.
2. Keep projection model files only if they are unused and harmless.
3. Revert collaborator extraction if store behavior becomes hard to reason
   about.
4. Do not delete existing store methods until at least one follow-up slice has
   proven replacement commands and projections in CI.

## 11. Open Questions

- Should projections be plain Dart DTOs or generated immutable data classes?
  Recommendation: plain Dart DTOs for M4; avoid new dependencies.
- Should command providers be interfaces immediately?
  Recommendation: use small interfaces only for broad workflows such as runs.
- Should `ServiceRegistry` be removed before run-store splitting?
  Recommendation: no. Keep bootstrap compatibility until provider-first
  production startup has crash-recovery and storage coverage.
