# Novel Writer Codex Defaults

This file is the project's standing instruction for Codex sessions opened in
this repository.

## Default Agent Workflow

Treat Codex native subagents as the default workflow for **all** work in
this repository — including trivial lookups and single-file edits.
The user should not need to repeatedly say "use subagents" or
paste the agent-workflow prompt.

Leader protocol:
- First classify the task as `solo`, `multi-agent`, or `OMX-runtime`.
- Use `solo` for simple lookups, single-file edits, or one-command
  verifications that do not require cross-module reasoning.
- Use `multi-agent` for tasks involving more than 3 files, multiple
  modules, command execution with side effects, or final verification
  claims. These should follow the full classification, delegation, and
  verification pattern.
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
- The Codex leader should keep shell commands and file edits focused on the
  current task and avoid broad, unbounded changes.
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

## GitHub Issue Record Policy

- Every durable content update must have a GitHub issue record before or during
  the change. This includes README, docs, AGENTS/project guidance,
  user-facing copy, architecture reports, and other persistent content
  artifacts.
- Update the issue with the resulting commit or PR when available, plus
  verification performed and any known gaps.
- Temporary local logs, generated traces, and throwaway test outputs do not need
  separate issues unless they become durable project artifacts.
- The standing policy is tracked in
  https://github.com/changw98ic/n0vel/issues/2.

## RTK Command Prefix

OMX runtime and auto-team workers use a `rtk_cmd()` helper that prefixes
any shell tool command with `rtk` when the `rtk` binary is on `$PATH`; when
`rtk` is not installed the original command runs unchanged (graceful
degradation).

- **Scope**: all shell tool invocations in agent prompts, verification steps,
  and planner review prompts — `flutter`, `dart`, `bash -n`, `make`, or any
  other tool command.
- **Out of scope**: the `claude` / `codex` agent processes themselves, and
  bare `bash` invocations that re-enter this script (worker respawn, tmux
  windows) — these are process lifecycle, not tool commands.
- **Usage**: `$(rtk_cmd flutter analyze --no-pub)` produces either
  `rtk flutter analyze --no-pub` or `flutter analyze --no-pub`.

## Safety And Verification

- Proceed automatically on clear, reversible work.
- Ask only for destructive, irreversible, credential, or materially branching
  decisions.
- Do not revert user changes unless explicitly asked.
- Run focused analyze/tests after code changes and report exact verification.
- Final reports must include changed files, simplifications made, and remaining
  risks.
