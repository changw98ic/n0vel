# Novel Writer Codex Defaults

This file is the project's standing instruction for Codex sessions opened in
this repository.

## Default Agent Workflow

Treat Codex native subagents as the default workflow for **all** work in
this repository — including trivial lookups and single-file edits.
The user should not need to repeatedly say "use subagents" or
paste the agent-workflow prompt.

This is an explicit standing user request to prefer the flow project's
process for non-trivial work. Simple queries and single-file edits may
run solo without the full flow pattern.

### Flow Project Declaration

- **Location**: `/Users/chengwen/dev/flow`
- **Entrypoint**: `/Users/chengwen/dev/flow/flow` (Bash CLI, v0.2.0)
- **How to invoke**: `flow pipeline novel-writer "<task>"` runs the full
  plan → execute → verify loop automatically. For manual control:
  `flow plan novel-writer "<task>"` → `flow execute novel-writer <id>`
  → `flow verify novel-writer <id>`. All commands assume `$PWD` or
  `FLOW_ROOT` resolves to `/Users/chengwen/dev/flow`; use the absolute
  path if the script is not on `$PATH`.
- **Default behavior for Codex tasks**: When the leader classifies a task
  as `flow`, run it through the flow CLI's `pipeline` command (or the
  manual plan/execute/verify sequence) instead of raw subagent delegation.
  The flow CLI handles ACP bridge dispatch, durable jobs, wiki handoff,
  and verification — do not reimplement these.
- **If flow is unavailable**: If `/Users/chengwen/dev/flow/flow` does not
  exist or the CLI exits non-zero on invocation, fall back to native
  Codex subagent lanes (explore → executor → verifier) as described
  below. Report the fallback to the user so they know flow was skipped.

Leader protocol:
- First classify the task as `solo`, `flow`, or `OMX-runtime`.
- Use `solo` for simple lookups, single-file edits, or one-command
  verifications that do not require cross-module reasoning.
- Use `flow` for tasks involving more than 3 files, multiple
  modules, command execution with side effects, or final verification
  claims. These must follow the full classification, delegation, and
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
- The Codex leader must never execute shell commands or edit files directly.
  All command execution and file edits must be delegated through
  Claude ACP, using the flow project's ACP bridge rather than local
  Claude/`ask-claude` print-mode execution.
- If Claude ACP is unavailable or fails after one retry, the leader
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

## RTK Command Prefix

OMX agent-flow and auto-team workers use a `rtk_cmd()` helper that prefixes
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
