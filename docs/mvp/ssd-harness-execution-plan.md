# SSD + Harness Granular Execution Plan

This plan decomposes the SSD + Harness cleanup into the smallest practical execution units. Each unit is designed to be independently runnable, auditable, and recoverable.

## Execution Rules

- Execute phases in order: Phase 1 and Phase 2 remove obsolete state/docs before Phase 3 and Phase 4 add structure.
- Commit after each phase, for exactly five commits total unless a phase is blocked.
- Keep each subtask narrow enough that failure identifies a specific directory, document set, script, or gate.
- Do not mix cleanup, docs consolidation, harness policy, and verification in one commit.
- Before destructive deletion, run a read-only inventory subtask and record the deletion rule used.
- Prefer deletion and consolidation over new abstractions.
- Do not add dependencies unless explicitly requested.
- Do not edit fake/mock tests, snapshots, fixtures, or test doubles merely to make tests pass.
- Use Lore Commit Protocol for every commit.

## Phase 1: Runtime And Dead-Spec Cleanup

Goal: remove stale runtime trash and stage already-deleted dead specs without introducing new structure.

### P1.0 Execution Surface Health Check

Input: local execution environment.

Action: run a no-op command through the selected execution surface and require a fixed response.

Output: execution surface is confirmed usable, or the phase stops with a clear blocker.

Verification: fixed response is received within timeout.

Commit: none.

### P1.1 Inventory Cleanup Targets

Input: `.omc/sessions/`, `.omx/context/`, `.omx/plans/`, `.auto-team/`, and git status for `docs/superpowers/` deletions.

Action: produce a read-only inventory of candidate files, sizes, age buckets, and deletion rationale.

Output: deletion manifest grouped by cleanup rule.

Verification: manifest includes only Phase 1 paths.

Commit: none.

### P1.2 Clean `.omc/sessions/`

Input: P1.1 manifest for `.omc/sessions/`.

Action: delete only session files older than 7 days.

Output: stale session files removed.

Verification: report count and total size removed; retain newer sessions.

Commit: none.

### P1.3 Clean `.omx/context/`

Input: P1.1 manifest for `.omx/context/`.

Action: delete expired context entries and retain the most recent 7 days where timestamps are available.

Output: expired context removed.

Verification: report deleted count and conservative retains.

Commit: none.

### P1.4 Clean `.omx/plans/`

Input: P1.1 manifest for `.omx/plans/`.

Action: delete completed or expired plans; keep unclear active/planning artifacts.

Output: stale plans removed.

Verification: report deleted plans and retained ambiguous plans.

Commit: none.

### P1.5 Clean `.auto-team/`

Input: P1.1 manifest for `.auto-team/`.

Action: if no active auto-team runtime is detected, remove runtime JSON such as `queue.json` and `*.json`; remove broader runtime trash only if clearly safe.

Output: stale auto-team runtime state removed.

Verification: report exact removed paths and active-runtime check used.

Commit: none.

### P1.6 Stage Dead `docs/superpowers/` Deletions

Input: git status entries under `docs/superpowers/`.

Action: stage already-deleted plans/specs only.

Output: dead spec deletions staged.

Verification: staged scope contains only intended Phase 1 deletions plus runtime cleanup changes.

Commit: none.

### P1.7 Commit Phase 1

Input: staged Phase 1 changes.

Action: commit with Lore Commit Protocol.

Output: Phase 1 cleanup commit.

Verification: commit hash recorded; working tree reviewed for non-Phase-1 leftovers without altering them.

Commit: `cleanup: remove stale runtime and dead spec state` or equivalent why-oriented Lore message.

## Phase 2: PRD Audit And Documentation Reduction

Goal: determine actual PRD implementation status from code evidence, then consolidate or backlog docs accordingly.

### P2.0 Inventory MVP Docs

Input: `docs/mvp/` and related PRD/index files.

Action: list PRDs, coverage docs, JSON companions, README pairs, and milestone/quality-gate docs.

Output: docs inventory with suspected duplicates.

Verification: count reconciles with expected 11 PRDs and 27-ish docs, or discrepancies are recorded.

Commit: none.

### P2.1 Map PRDs To Code Entry Points

Input: PRD list from P2.0 and repository source tree.

Action: for each PRD, identify claimed features, likely source files, tests, and CLI/app paths.

Output: PRD-to-code evidence map.

Verification: each active-looking PRD has at least one code search or command-based evidence note.

Commit: none.

### P2.2 Run Focused Code Verification For Each PRD

Input: P2.1 evidence map.

Action: run the smallest relevant command/search/test/analyze path that proves whether each PRD is implemented.

Output: per-PRD verification result.

Verification: no PRD status is assigned from docs-only inference.

Commit: none.

### P2.3 Create `status-matrix.md`

Input: P2.1 and P2.2 results.

Action: write `docs/mvp/prd/status-matrix.md` with columns: PRD name, status, implementation coverage, blockers.

Output: status matrix grounded in code evidence.

Verification: every PRD has a row and evidence basis.

Commit: none.

### P2.4 Consolidate Coverage Markdown And JSON Pairs

Input: `*-coverage.md` and `*-coverage.json` pairs.

Action: merge each pair into one `.md` file with YAML frontmatter carrying structured metadata.

Output: fewer coverage files.

Verification: no lost fields from JSON metadata.

Commit: none.

### P2.5 Consolidate README Markdown And JSON Pairs

Input: `README.md` and `README.json` pairs where present.

Action: merge JSON metadata into README frontmatter or a clearly labeled metadata section.

Output: README pairs collapsed.

Verification: metadata remains discoverable from the resulting markdown.

Commit: none.

### P2.6 Move Unstarted PRDs To Backlog

Input: `status-matrix.md` rows with unimplemented or zero-coverage status.

Action: move unstarted PRDs to `docs/mvp/prd/backlog/`.

Output: backlog contains deferred/unstarted PRDs.

Verification: backlog PRDs are excluded from milestone validation scope.

Commit: none.

### P2.7 Defer Agent Feature 4 And 5

Input: `prd-agent-features.md`.

Action: mark Feature 4 and Feature 5 as `deferred`; keep only F1-F3 active.

Output: active scope narrowed.

Verification: document no longer implies F4/F5 are maintained active work.

Commit: none.

### P2.8 Commit Phase 2

Input: Phase 2 doc audit/consolidation/backlog changes.

Action: commit with Lore Commit Protocol.

Output: Phase 2 commit.

Verification: doc count target is `<=15` files where feasible; deviations are explained.

Commit: `docs: align MVP PRDs with implemented scope` or equivalent why-oriented Lore message.

## Phase 3: SSD Closure Repair

Goal: make the spec-status-document loop enforceable and auditable.

### P3.0 Define Active PRD Set

Input: Phase 2 `status-matrix.md` and backlog moves.

Action: identify active PRDs that still participate in milestone validation.

Output: active PRD list.

Verification: active set excludes backlog.

Commit: none.

### P3.1 Add PRD Status Frontmatter

Input: active PRDs.

Action: add or update YAML frontmatter with `status: draft|planning|implemented|verified`.

Output: every active PRD has status metadata.

Verification: status values are in the allowed state machine and do not regress known status.

Commit: none.

### P3.2 Locate Existing MVP Docs Validator References

Input: CI workflows, docs index, scripts directories.

Action: find references to `validate_mvp_docs.py` and `mvp-docs-check.yml`.

Output: validator integration map.

Verification: distinguish missing script from stale reference.

Commit: none.

### P3.3 Implement `validate_mvp_docs.py`

Input: active PRD set, status rules, index rules, cross-reference rules.

Action: create or repair validator script to check PRD status, docs completeness, cross references, and index consistency.

Output: runnable validator.

Verification: script runs locally and reports actionable failures.

Commit: none.

### P3.4 Integrate Validator Into `mvp-docs-check.yml`

Input: validator script and existing CI workflow.

Action: ensure CI invokes the validator from the correct working directory.

Output: docs check workflow includes MVP validator.

Verification: workflow command matches actual script path.

Commit: none.

### P3.5 Update `mvp-index.json`

Input: current post-cleanup docs tree.

Action: remove nonexistent file references, add required active entries, exclude backlog where appropriate.

Output: precise MVP index.

Verification: index paths match actual file locations.

Commit: none.

### P3.6 Create `docs/mvp/CHANGELOG.md`

Input: Phase 1-3 decisions and resulting structure.

Action: record spec changes, removals, deferred scope, and validator introduction.

Output: SSD changelog.

Verification: changelog has dated entries and audit rationale.

Commit: none.

### P3.7 Commit Phase 3

Input: status frontmatter, validator, CI integration, index, changelog.

Action: commit with Lore Commit Protocol.

Output: Phase 3 commit.

Verification: validator evidence recorded in commit/report.

Commit: `docs: make SSD status loop enforceable` or equivalent why-oriented Lore message.

## Phase 4: Harness Constraint Repair

Goal: make the harness protective without forcing unnecessary multi-agent overhead, and feed investigation artifacts back into status tracking.

### P4.0 Read Harness Constraint Surface

Input: `AGENTS.md` and project-doc instructions.

Action: identify exact lines enforcing all-task agent-flow and Claude-only execution.

Output: harness constraint map.

Verification: changes are scoped to policy text, not unrelated instructions.

Commit: none.

### P4.1 Relax Over-Broad Task Rule

Input: P4.0 constraint map.

Action: change `all tasks` to tasks involving more than 3 files, multiple modules, command execution with side effects, or final verification claims; allow simple queries and single-file edits to run solo.

Output: balanced harness policy.

Verification: high-risk tasks still require agent-flow.

Commit: none.

### P4.2 Inventory `.omx/artifacts/` Reports

Input: `.omx/artifacts/`.

Action: identify the 20 most relevant investigation reports, or all reports if fewer.

Output: artifact audit list.

Verification: each selected report has date/title/source path.

Commit: none.

### P4.3 Extract Open Action Items

Input: P4.2 selected reports.

Action: extract unresolved action items, blockers, and decisions.

Output: normalized blocker/action list.

Verification: each action item links back to a source artifact.

Commit: none.

### P4.4 Feed Actions Into `status-matrix.md`

Input: P4.3 normalized actions and existing PRD rows.

Action: add relevant blockers to `docs/mvp/prd/status-matrix.md`.

Output: feedback loop closed into PRD status.

Verification: no orphan high-priority artifact action remains untracked or deliberately rejected.

Commit: none.

### P4.5 Define State Ownership Policy

Input: `.omc`, `.omx`, AGENTS/state-management docs.

Action: document `.omc` as runtime state and `.omx` as artifacts/archive only, or explicitly record any exception needed by tooling.

Output: one canonical state policy.

Verification: policy matches actual retained directory structure.

Commit: none.

### P4.6 Update `quality-gates.md`

Input: status matrix, validator, current gate owner assignments.

Action: close completed gates, remove stale owners, and align gate language with current reality.

Output: current quality gate document.

Verification: no gate claims completion without evidence.

Commit: none.

### P4.7 Commit Phase 4

Input: harness policy, artifact feedback, state policy, quality gates.

Action: commit with Lore Commit Protocol.

Output: Phase 4 commit.

Verification: policy diff is narrow and blockers are represented in status matrix.

Commit: `docs: make harness constraints proportional` or equivalent why-oriented Lore message.

## Phase 5: Verification And Final Alignment

Goal: prove code and docs are consistent, then make the final cleanup commit if needed.

### P5.0 Inventory Verification Commands

Input: project tooling and CI workflows.

Action: identify exact commands for Flutter analyze, Flutter tests, and MVP docs check.

Output: verification command list.

Verification: commands are copied from project config where possible.

Commit: none.

### P5.1 Run `flutter analyze`

Input: current workspace after Phases 1-4.

Action: run Flutter static analysis.

Output: analyzer result.

Verification: pass required before continuing; failures trigger fix loop.

Commit: none unless fixes are needed.

### P5.2 Run `flutter test`

Input: current workspace after analyzer passes.

Action: run Flutter tests.

Output: test result.

Verification: pass required before continuing; failures trigger fix loop.

Commit: none unless fixes are needed.

### P5.3 Run MVP Docs Check

Input: validator and CI docs workflow.

Action: run `validate_mvp_docs.py` directly or via the configured docs check command.

Output: docs consistency result.

Verification: active PRDs have valid status and implementation coverage greater than 0%.

Commit: none unless fixes are needed.

### P5.4 Fix Verification Failures In Narrow Loops

Input: failures from P5.1-P5.3.

Action: fix one failure class at a time without editing fake/mock assets merely to pass.

Output: targeted fixes.

Verification: rerun only the failed gate first, then full gate sequence.

Commit: include fixes in Phase 5 commit.

### P5.5 Final Working Tree Review

Input: git status after verification.

Action: ensure only intended Phase 5 changes remain unstaged.

Output: clean staging plan.

Verification: no runtime trash or untracked cleanup artifacts remain unintentionally.

Commit: none.

### P5.6 Commit Phase 5

Input: final verification/fix changes.

Action: commit with Lore Commit Protocol.

Output: final commit.

Verification: record exact passing commands.

Commit: `docs: complete SSD and harness alignment` or equivalent why-oriented Lore message.

## Stop Conditions

- Stop after any destructive-scope ambiguity that cannot be resolved from manifests.
- Stop if PRD audit shows implementation coverage is broadly near zero and the product direction should be reset to MVP-minimal before continuing.
- Stop if verification requires changing mocks/fakes/snapshots only to paper over production behavior changes.
- Stop if execution surface fails health checks and no user override permits direct execution.

## Final Report Template

The final report should include:

- Phase commits with hashes.
- Changed files and removed directories.
- Simplifications made.
- PRD status matrix summary.
- Validator and CI evidence.
- Remaining risks and intentionally deferred work.
