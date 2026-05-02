# Novel Writer Codex Defaults

This file is the project's standing instruction for Codex sessions opened in
this repository.

## Default Agent Workflow

Treat Codex native subagents as the default workflow for **all** work in
this repository — including trivial lookups and single-file edits.
The user should not need to repeatedly say "use subagents" or
paste the agent-workflow prompt.

This is an explicit standing user request to use agent-flow for every task.
All tasks — including trivial one-shot lookups and single-file edits — must
follow the full agent-flow pattern: classify, delegate, verify. No exceptions.

Leader protocol:
- First classify the task as `agent-flow` or `OMX-runtime`.
- Use `agent-flow` for every task, with no `solo` exception. Even small,
  low-risk lookups or single-file edits must go through the agent-flow
  classification, delegation, and verification pattern.
- Use native subagents for bounded discovery, implementation, review, or
  verification lanes whenever a task requires repository inspection, command
  execution, file edits, or final evidence.
- Use `OMX-runtime` only when an OMX CLI/team runtime is actually available or
  the user explicitly asks to launch one.

Recommended lanes:
- `explore`: read-only codebase mapping, logs, current behavior, and risk
  discovery.
- `executor`: bounded implementation or refactor work with a clear write scope.
- `test-engineer` or `verifier`: regression tests, command evidence, and
  completion checks.
- `code-reviewer` or `critic`: review non-trivial changes before final claims.

Delegation rules:
- Keep child-agent tasks bounded, independent, and verifiable.
- The Codex leader must never execute shell commands or edit files directly.
  All command execution and file edits must be delegated through
  Claude/`ask-claude`. When invoking Claude CLI for execution, always include
  the permission bypass flag: `claude --dangerously-skip-permissions -p ...`.
- If Claude/`ask-claude` is unavailable or fails after one retry, the leader
  must stop and report the failure to the user. Do not fall back to direct
  execution. No exceptions.
- Do not use `worker` outside active OMX team/swarm runtime.
- Prefer inherited model defaults; use role/effort before explicit model
  overrides.
- Maximum 6 child agents at once; prefer 2-4 for normal work.
- The leader owns integration, final verification, and the final user report.

Novel-generation quality defaults:
- For chapter/scene generation work, inspect logs and generated text when
  available.
- Evaluate output from a reader perspective, not only from implementation
  correctness.
- Preserve character/council memory through the pipeline; do not restart agent
  context from scratch unless the task explicitly asks for a reset.
- For quality gates, target 95 as the passing threshold unless the user gives a
  different number.

## Safety And Verification

- Proceed automatically on clear, reversible work.
- Ask only for destructive, irreversible, credential, or materially branching
  decisions.
- Do not revert user changes unless explicitly asked.
- Run focused analyze/tests after code changes and report exact verification.
- Final reports must include changed files, simplifications made, and remaining
  risks.
