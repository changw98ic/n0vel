# Provider-first Production Bootstrap Decision Record

> Plan ID: M4-19
> Related Issues: #58, #23
> Date: 2026-05-25
> Status: Decision recorded

## 1. Decision

Do not remove the production `ServiceRegistry` bootstrap yet.

The app now has native Riverpod provider defaults for the app-bootstrap graph,
plus projection and command surfaces for the first run/workspace split. However,
the normal `NovelWriterApp` startup path still intentionally creates a
`ServiceRegistry` and applies `appProviderOverridesForRegistry(registry)` so
Riverpod and the registry share the same singleton instances during production
startup. The provider-first startup path exists only as a debug/test switch.

The next cutover should happen only after the go/no-go gates in this document
are satisfied and verified on a dedicated branch.

## 2. Current Evidence

| Area | Current state | Evidence |
| --- | --- | --- |
| Normal app bootstrap | Registry-owned by default | `lib/app/app.dart` creates a `ServiceRegistry` unless `NovelWriterApp.debugUseProviderBootstrap` is true. |
| Riverpod coexistence | Registry instances are injected into native providers | `appProviderOverridesForRegistry()` overrides 23 providers, including infrastructure, DB-backed stores, feature stores, workspace/settings, and run store. |
| Native provider graph | Exists and is testable without registry | `NovelWriterApp.debugUseProviderBootstrap` plus `createTestProviderOverrides()` exercises provider-first startup in tests. |
| Disposal model | Split by bootstrap path | Native providers dispose owned stores; registry overrides remove listeners but leave final disposal to `ServiceRegistry.disposeAll()`. |
| Crash/corruption startup | Still tied to registry registration in normal startup | `registerAppServices(_registry!)` can throw `DatabaseCorruptedException`, which drives the corruption recovery screen. |
| Run state split | Started, not complete | Run projection, command facade, snapshot repository, and session controller have been extracted, but feedback/scope/pipeline side effects still live in `StoryGenerationRunStore`. |

## 3. Why This Is A No-go Today

Removing the registry from production bootstrap now would be too early because:

1. The provider-first path is still debug/test-only and controlled by static
   test switches, not a production bootstrap option.
2. Database corruption handling is currently coupled to
   `registerAppServices()` throwing during registry service registration.
3. Registry coexistence still protects production from duplicate singleton
   graphs while native providers and legacy consumers overlap.
4. `StoryGenerationRunStore` is narrower after M4-17 and M4-18, but it still
   coordinates pipeline execution, feedback, review tasks, and workspace scope
   side effects.
5. The project has smoke coverage for provider-first startup, but not enough
   production-parity coverage for crash recovery, existing persisted data,
   corrupted database recovery, and macOS desktop startup without registry
   overrides.

## 4. Go Criteria For Removing Registry Bootstrap

The production cutover may proceed only when every criterion below has direct
evidence.

| Gate | Required evidence | Minimum verification |
| --- | --- | --- |
| First-class provider bootstrap | `NovelWriterApp` can start with native providers without using debug-only static flags. | Widget test plus production code review showing no reliance on `debugUseProviderBootstrap` for the normal path. |
| Startup parity | Registry and provider-first bootstrap both show the same default home, settings-driven theme, route registration, crash overlay behavior, and clean-shutdown marking. | Paired widget tests in `test/app_initialization_integration_test.dart`. |
| Corruption recovery parity | Provider-first bootstrap handles authoring DB corruption with the same recovery UI path as registry bootstrap. | Test or integration fixture that injects a corrupted DB open failure through the provider path. |
| Storage parity | Provider-first bootstrap uses the same default storage factories and authoring DB path as the registry path. | Provider tests for storage providers plus a fresh-profile startup smoke. |
| Singleton safety | No production startup path creates both registry-owned and provider-owned versions of the same store. | Test asserting one bootstrap owner per run; review of `ProviderScope` overrides. |
| Disposal safety | Provider-first startup disposes stores, database, event bus, and request pool resources in a deterministic order without double-dispose. | Widget teardown tests and focused provider disposal tests. |
| Legacy lookup audit | No feature or UI code depends on resolving app services from `ServiceRegistry`. | `rg "resolve<|serviceRegistryProvider|ServiceRegistry" lib` reviewed with only bootstrap/test-bridge exceptions remaining. |
| Run-store split readiness | Remaining run side-effect collaborators have clear boundaries or dedicated tests before bootstrap ownership changes. | At least feedback/scope/pipeline side-effect tests stay green after cutover branch. |
| CI and desktop smoke | Both GitHub workflows pass, and macOS startup is checked against fresh and existing local data. | `Flutter Analyze and Test`, `Verify macOS`, and manual or scripted macOS smoke notes. |

If any gate is missing, the decision remains no-go.

## 5. Cutover Sequence

1. Add a production provider bootstrap constructor or configuration path that
   does not use debug static flags.
2. Move database open/corruption handling behind a provider-owned startup
   boundary that can surface `DatabaseCorruptedException` before `MaterialApp`
   builds.
3. Add paired registry/provider-first startup tests for home, theme, crash
   recovery, clean shutdown, and provider graph resolution.
4. Run the legacy lookup audit and remove feature-level registry access that is
   not part of bootstrap coexistence.
5. Flip the default startup path to provider-first while keeping a short-lived
   registry fallback flag for rollback.
6. After CI and desktop smoke pass, remove `appProviderOverridesForRegistry()`
   only when no production path still needs registry-owned singleton sharing.

## 6. Rollback Strategy

The cutover branch must keep a reversible fallback until at least one green CI
cycle and desktop smoke pass:

1. Restore registry bootstrap as the default startup owner.
2. Re-enable `appProviderOverridesForRegistry(registry)` in `NovelWriterApp`.
3. Keep native provider defaults in place; they are additive and already tested.
4. Revert only the default-owner flip and any corruption-path rewiring that
   caused the regression.

## 7. Next Work After M4-19

Continue splitting the remaining wide run-store responsibilities before trying
the production bootstrap cutover:

1. Extract feedback/review task side-effect coordination from
   `StoryGenerationRunStore`.
2. Extract scene/project scope cleanup coordination if it grows beyond the
   session controller.
3. Add provider-first production bootstrap tests that do not rely on debug
   flags.
4. Revisit this decision record and mark each go criterion with current
   evidence before opening the cutover implementation issue.
