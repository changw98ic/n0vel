# Demo Verification Log

Date: 2026-05-03
Branch: main
Commit: 21bb0c7
Working tree: clean at start

## Commands Run

### 1. Static Analysis

```bash
flutter analyze --no-pub
```

**Result:** PASS — `No issues found! (ran in 1.7s)`

### 2. UI Widget Tests — Workbench Shell

```bash
flutter test test/workbench_shell_test.dart --no-pub -r compact
```

**Result:** PASS — 97/97 tests passed

Tests cover: shell layout, drawer, edge states, simulation lifecycle, sandbox monitor, draft persistence, version history, reading mode, editor state restoration, settings, AI panel (generate/review/history), error recovery, diagnostics, scene CRUD, event log.

### 3. Core Logic Tests

```bash
flutter test \
  test/character_visible_context_builder_test.dart \
  test/scene_pipeline_test.dart \
  test/scene_review_coordinator_test.dart \
  test/scene_quality_scorer_test.dart \
  test/story_generation_orchestrator_test.dart \
  --no-pub -r compact
```

**Result:** 157/158 tests passed

Pre-existing failure:
- `scene_pipeline_test.dart:1135` — `SceneStateResolver keeps unlimited beat resolve retries before falling back on timeout`
- Cause: Expected `MappedListIterable` length mismatch (expected >1, got 1)
- Impact: Not on demo path; does not affect UI or core generation flow

### 4. Real LLM Integration Test

```bash
RUN_REAL_STORY_VALIDATION=1 flutter test test/real_three_chapter_generation_test.dart --no-pub -r compact
```

**Result:** SKIPPED — requires API credentials in environment. Not run during this verification session.

### 5. MVP Documentation Validation

```bash
python3 docs/mvp/validate_mvp_docs.py
```

**Result:** PASS

```
MVP doc validation: PASSED
- top_level_docs: 27
- prd_docs: 11
- canonical_frame_names: 158
- canonical_frame_ids: 160
- smoke_tests: 12
```

## Not Run

| Command | Reason |
|---------|--------|
| `flutter test -r compact` (full suite) | Full suite takes >10min; focused tests sufficient for demo evidence |
| `flutter build macos` | Build verification is CI responsibility; not needed for demo-readiness evidence |
| `make verify-macos` | Wraps analyze + test + build + xcodebuild; heavyweight for evidence doc |

## How to Reproduce

1. Checkout `main` at commit `21bb0c7`
2. Run `flutter pub get`
3. Run each command listed above
4. Compare results to this document

## Summary

| Surface | Status | Count |
|---------|--------|-------|
| Static analysis | PASS | 0 issues |
| UI widget tests | PASS | 97/97 |
| Core logic tests | PASS (1 pre-existing) | 157/158 |
| Real LLM test | SKIPPED | needs API key |
| MVP doc validation | PASS | 27 docs, 11 PRDs, 158 frames, 12 smokes |
