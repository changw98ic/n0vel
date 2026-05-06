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

### Deferred
- md/json pair consolidation (deferred to avoid breaking validator mid-phase)
- PRD backlog moves (all PRDs implemented, nothing to defer)
- Agent features PRD (does not exist in current tree)
