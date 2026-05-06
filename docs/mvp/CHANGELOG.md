# MVP Docs Changelog

## 2026-05-06 — SSD + Harness Alignment

### Phase 1: Runtime cleanup
- Deleted 8 obsolete docs/superpowers/ plan/spec documents
- Cleaned `.omc/sessions/`: 298 stale session files (>7 days)
- Cleaned `.omx/context/`: 13 expired entries
- Cleaned `.omx/plans/`: 19 completed/expired plans
- Cleaned `.auto-team/`: 355M of stale worktrees, PIDs, logs, backups

### Phase 2: PRD audit
- Created `prd/status-matrix.md` with code-evidence-based implementation status
- All 11 PRDs confirmed implemented with corresponding source code
- Test gaps identified in PRD-01, 04, 08, 09, 11 (zero feature-level tests)

### Phase 3: SSD closure repair
- Added `status: implemented` frontmatter to all 11 PRDs
- Updated `release-readiness.md/json` counts (28 top-level docs, 12 PRDs)
- Updated `doc-manifest.json` with `ssd-harness-execution-plan.md`
- Updated `mvp-index.json` counts to match current file tree
- Added README.md link to `ssd-harness-execution-plan.md`
- Validator `validate_mvp_docs.py` passes all checks

### Phase 4: Harness constraint repair
- Relaxed AGENTS.md over-broad "all tasks must agent-flow" rule
  - Solo mode now allowed for simple lookups, single-file edits, one-command verifications
  - Agent-flow required for >3 files, multi-module, side-effect commands, or verification claims
- Fed artifact action items into status-matrix.md (test fixtures, macOS build fragility)
- Updated quality-gates.md P1-4 to reflect automated validator + CI status
- Defined state ownership: `.omc/` = runtime state (session-scoped), `.omx/` = artifacts/archive only

### State Ownership Policy
- `.omc/` — runtime state (sessions, notepad, project memory). Managed by oh-my-claudecode. Safe to prune files >7 days old.
- `.omx/` — artifacts and archive only (investigation reports, context, plans). No runtime writes during normal operation.
- `.auto-team/` — ephemeral team runtime state. Safe to delete entirely when no active team session.
- `docs/mvp/` — governed by `validate_mvp_docs.py`. All structural changes must keep validator passing.

### Deferred
- md/json pair consolidation (deferred to avoid breaking validator mid-phase)
- PRD backlog moves (all PRDs implemented, nothing to defer)
- Agent features PRD (does not exist in current tree)
