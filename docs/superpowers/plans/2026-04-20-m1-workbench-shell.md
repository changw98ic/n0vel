# M1 Workbench Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap the Flutter desktop app and replace the default template with the MVP writing workbench shell.

**Architecture:** Keep the first slice intentionally thin: a Flutter app shell with shared theme tokens, a writing workbench route, and static shell regions matching the MVP UI baseline. Delay AI logic, persistence, and feature flows until the shell is stable.

**Tech Stack:** Flutter 3.27, Dart 3.9, flutter_test

---

### Task 1: Bootstrap the Flutter project

**Files:**
- Create: Flutter scaffold files in repo root
- Preserve: existing docs/, .omx/, Makefile

- [ ] Step 1: Generate framework scaffold in the existing repo.
- [ ] Step 2: Confirm scaffold files exist and docs remain intact.

### Task 2: Replace template with MVP app shell

**Files:**
- Modify: lib/main.dart
- Create: lib/app/app.dart
- Create: lib/app/theme/app_theme.dart
- Create: lib/features/workbench/presentation/workbench_shell_page.dart
- Test: test/workbench_shell_test.dart

- [ ] Step 1: Write a failing widget test for the workbench shell regions.
- [ ] Step 2: Implement the minimal app/theme/page files to pass that test.
- [ ] Step 3: Verify widget tests pass.

### Task 3: Polish and verify

**Files:**
- Modify: analysis_options.yaml (only if needed)
- Verify: flutter test, flutter analyze

- [ ] Step 1: Run tests and analyze.
- [ ] Step 2: Fix any diagnostics introduced by the shell slice.
