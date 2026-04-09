# Team Commit Hygiene Finalization Guide

- team: phase2-optimization-split-ai-c
- generated_at: 2026-04-06T01:58:05.774Z
- lore_commit_protocol_required: true
- runtime_commits_are_scaffolding: true

## Suggested Leader Finalization Prompt

```text
Team "phase2-optimization-split-ai-c" is ready for commit finalization. Treat runtime-originated commits (auto-checkpoints, merge/cherry-picks, cross-rebases, shutdown checkpoints) as temporary scaffolding rather than final history. Do not reuse operational commit subjects verbatim. Use the completed task descriptions and resulting diffs to infer semantic commit boundaries. Rewrite or squash the operational history into clean Lore-format final commit(s) with intent-first subjects and relevant trailers. Use task subjects/results and shutdown diff reports to choose semantic commit boundaries and rationale.
```

## Task Summary

- task-1 | status=pending | owner=worker-1 | subject=Implement: phase2 optimization: split ai_config_page, optimize reader_page lifec
  - description: Implement the core functionality for: phase2 optimization: split ai_config_page, optimize reader_page lifecycle, audit and fix obvious Stateful resource disposal leaks
- task-2 | status=pending | owner=worker-2 | subject=Test: phase2 optimization: split ai_config_page, optimize reader_page lifecycle,
  - description: Write tests and verify: phase2 optimization: split ai_config_page, optimize reader_page lifecycle, audit and fix obvious Stateful resource disposal leaks
- task-3 | status=pending | owner=worker-3 | subject=Review and document: phase2 optimization: split ai_config_page, optimize reader_
  - description: Review code quality and update documentation for: phase2 optimization: split ai_config_page, optimize reader_page lifecycle, audit and fix obvious Stateful resource disposal leaks

## Runtime Operational Ledger

- No runtime-originated commit activity recorded.

## Finalization Guidance

1. Treat `omx(team): ...` runtime commits as temporary scaffolding, not as the final PR history.
2. Reconcile checkpoint, merge/cherry-pick, cross-rebase, and shutdown checkpoint activity into semantic Lore-format final commit(s).
3. Use task outcomes, code diffs, and shutdown diff reports to name and scope the final commits.

## Recommended Next Steps

1. Inspect the current branch diff/log and identify which runtime-originated commits should be squashed or rewritten.
2. Derive semantic commit boundaries from completed task subjects, code diffs, and shutdown reports rather than from omx(team) operational commit subjects.
3. Create final commit messages in Lore format with intent-first subjects and only the trailers that add decision context.
