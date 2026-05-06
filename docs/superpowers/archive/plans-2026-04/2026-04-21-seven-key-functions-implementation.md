# Seven Key Functions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the seven remaining prototype-only module closures into usable local-first feature flows inside the current Flutter app.

**Architecture:** Keep the app local-first and store-driven. Push richer editable state into existing app stores, upgrade pages from browse-only/static displays to real editable flows, and preserve deterministic testability for provider/simulation behavior through explicit state machines rather than external service dependence.

**Tech Stack:** Flutter, ChangeNotifier stores, sqlite-backed local persistence, widget tests

---

### Task 1: Workspace-driven editing closures

**Files:**
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/state/app_workspace_store.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/style/presentation/style_panel_page.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/characters/presentation/character_library_page.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/worldbuilding/presentation/worldbuilding_page.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/audit/presentation/audit_center_page.dart`

- [ ] Add the missing editable/project-scoped state needed for style questionnaire data, style JSON validation results, character details, world node details, and audit issue status/ignore data.
- [ ] Replace static detail panes with editable local-first forms and action flows that mutate the workspace store.
- [ ] Wire reference/jump summaries so these modules expose meaningful linked-scene context instead of placeholder-only copy.

### Task 2: Settings/workbench/sandbox closures

**Files:**
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/state/app_settings_store.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/state/app_simulation_store.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/settings/presentation/settings_shell_page.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/workbench/presentation/workbench_shell_page.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/sandbox/presentation/sandbox_monitor_page.dart`

- [ ] Replace fixed-success settings connection behavior with a richer local-first connection-test state machine that maps to the documented success/error outcomes.
- [ ] Strengthen workbench AI/simulation gating and summaries so the module behaves like a usable local-first closure instead of a static demo.
- [ ] Make sandbox output more scene-aware/stateful while preserving existing prompt-edit and feedback flows.

### Task 3: Regression coverage

**Files:**
- Modify: `/Users/chengwen/dev/novel-wirter/test/style_panel_test.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/test/reference_surfaces_test.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/test/settings_persistence_test.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/test/workbench_shell_test.dart`

- [ ] Add/expand widget tests so the new closures are locked with failing-then-passing coverage.
- [ ] Cover the new editable flows, validation states, state transitions, and persistence boundaries.

### Task 4: Verification and sign-off

**Files:**
- Modify only if verification finds regressions

- [ ] Run `flutter analyze`
- [ ] Run `flutter test -r compact`
- [ ] Run `flutter build web`
- [ ] Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter build macos`
- [ ] Run architect review, then deslop on changed files only, then rerun verification
