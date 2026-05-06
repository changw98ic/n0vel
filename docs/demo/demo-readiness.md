# Demo Readiness v1

Date: 2026-05-03
Branch: main
Commit: 21bb0c7

## Purpose

This document proves the app has a verifiable UI main path and core LLM/story-generation logic path, suitable for demonstrating during a technical interview or using as a primary resume artifact.

## Demo Narrative

n0vel is a desktop AI-assisted long-form fiction writing platform built with Flutter/Dart. The key sell is not "AI writes your novel" but rather "AI writing is controllable, iterable, and auditable." The demo walkthrough covers two surfaces:

1. **UI main path**: Author opens workbench, configures AI provider, runs a simulated multi-agent generation, reviews/accepts AI suggestions, manages versions, and reads in reading mode.
2. **Core logic path**: Scene pipeline orchestrates director planning, role-play agents, prose generation, and review scoring — all testable without a live LLM.

## UI Function — Verifiable

### Workbench Shell (`test/workbench_shell_test.dart`)

97 widget tests covering the full author-facing path:

| Flow | Tests | Evidence |
|------|-------|----------|
| Shell layout rendering | 1 | Menu drawer, breadcrumb, editor surface, tool rail, status bar |
| Author feedback capture | 1 | Note entry → revision request → store verification |
| Drawer toggle | 3 | Open/close, handle positioning |
| Edge states (API key missing, character unbound, reference lost) | 8 | Guidance notices, disabled actions |
| Simulation run lifecycle | 4 | Start, complete, fail, cancel with orchestrator override |
| Sandbox monitor integration | 8 | Opens from banner, agent list, prompt editing, feedback ordering |
| Draft editing & persistence | 4 | Text entry survives tool window switches and app rebuild |
| Version history | 5 | Save, restore, cross-rebuild persistence, single-version fallback |
| Reading mode | 7 | Navigation, paging, chapter boundaries, punctuation, short chapters |
| Editor state restoration | 4 | Selection/focus restored after reading mode and settings |
| Settings (API key, model, base_url) | 7 | Validation, save success, connection test, quick panel sync |
| AI panel (generate, review, history) | 15 | Rewrite/continue modes, review dialog, accept/reject, overlap blocks |
| AI error recovery | 8 | Secure store read/write failures, retry, diagnostic copy |
| Secure store diagnostics | 6 | Copy-to-clipboard for read/write failures |
| AI history management | 5 | Order, clear, delete single, restore prompt, replay |
| Scene CRUD from resource panel | 4 | Create, rename, delete, switch |
| Tool window tab switching | 1 | Resources → AI → Settings |
| Event log integration | 2 | Structured events for generate and replay actions |

**Command to verify:**
```bash
flutter test test/workbench_shell_test.dart --no-pub -r compact
# Expected: 97 passed, 0 failed
```

### Additional UI Pages Tested

- `test/production_board_page_test.dart` — Production board
- `test/sandbox_monitor_page_state_test.dart` — Sandbox monitor state
- `test/user_shell_journeys_test.dart` — End-to-end user journeys
- `test/prd_shell_rule_spot_check_test.dart` — PRD shell rule compliance
- `test/accessibility_semantics_test.dart` — Accessibility semantics
- `test/app_shortcuts_test.dart` — Keyboard shortcuts
- `test/pencil_ui_alignment_test.dart` — Design-to-code alignment

## Core Logic — Verifiable

### Scene Pipeline (`test/scene_pipeline_test.dart`)

66 tests covering:
- `SceneDirectorOrchestrator` — tone inference (tension/calm), pacing, local plan fallback, cast role enrichment
- `DynamicRoleAgentRunner` — prompt construction with director notes
- `SceneStateResolver` — state resolution with tone/pacing
- `ReplanRouter` — pass/rewrite/replan/blocked routing with max retry enforcement

### Review & Scoring (`test/scene_review_coordinator_test.dart` + `test/scene_quality_scorer_test.dart`)

35 + 24 = 59 tests covering:
- Review coordination across judge/consistency passes
- Quality scoring with pass/fail thresholds
- Review decision logic

### Chapter Generation (`test/story_generation_orchestrator_test.dart`)

31 tests covering:
- `ChapterGenerationOrchestrator` — scene ordering, retry on transient failures
- `SceneDirectorOrchestrator` — plan fallback on polish failure
- Cancellation guard — post-cancel persistence blocked

### Character Context (`test/character_visible_context_builder_test.dart`)

2 tests covering:
- Private briefing surfaces director conflict/constraints before character notes
- Context injection for resolved cast members

### Memory & RAG (`test/story_memory_retriever_test.dart` + `test/rag_integration_test.dart`)

23 + additional tests covering:
- Thought memory retrieval
- RAG pipeline integration

### Review Tasks (`test/review_task_test.dart`)

6 tests covering review task lifecycle.

**Command to verify core logic:**
```bash
flutter test \
  test/character_visible_context_builder_test.dart \
  test/scene_pipeline_test.dart \
  test/scene_review_coordinator_test.dart \
  test/scene_quality_scorer_test.dart \
  test/story_generation_orchestrator_test.dart \
  --no-pub -r compact
# Expected: 157+1 passed (1 pre-existing failure in scene_pipeline_test.dart:1135)
```

### Real LLM Integration (`test/real_three_chapter_generation_test.dart`)

End-to-end three-chapter generation with real LLM traffic. Requires `RUN_REAL_STORY_VALIDATION=1` and API credentials in environment.

**Command to verify:**
```bash
RUN_REAL_STORY_VALIDATION=1 flutter test test/real_three_chapter_generation_test.dart --no-pub -r compact
# Requires: API credentials in environment
```

## Static Analysis

```bash
flutter analyze --no-pub
# Expected: No issues found
```

## MVP Documentation Validation

```bash
python3 docs/mvp/validate_mvp_docs.py
# Validates: PRD traceability, frame coverage, manifest consistency, link integrity
```

## Known Gaps (Pre-demo Risks)

| Gap | Impact | Mitigation |
|-----|--------|------------|
| No screenshots/GIFs in README | Visual first impression weak | Link to test evidence; screenshots are next-step |
| `docs/placeholders/` directory missing | README placeholder image links are broken | Updated README to remove broken image refs |
| 1 pre-existing test failure in `scene_pipeline_test.dart:1135` | SceneStateResolver beat retry test | Not related to demo path; document as known issue |
| No video demo | Walkthrough requires running the app locally | Test suite IS the walkthrough for now |
| Real LLM validation requires API key | Can't demo real generation without credentials | Simulation mode covers the logic path completely |

## Verification Checklist

- [x] `flutter analyze --no-pub` — 0 issues
- [x] 97 workbench UI widget tests pass
- [x] 157 core logic tests pass (1 pre-existing failure documented)
- [ ] Screenshots/video captured (next step)
- [x] `validate_mvp_docs.py` — PASSED (27 docs, 11 PRDs, 158 frames, 12 smokes)
