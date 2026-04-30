# Agent File Relay Workflow

This is a platform-neutral workflow for Codex, Claude Code, and other agent
runtimes. It uses files as the contract between a main agent, a scheduler
subagent, and worker subagents.

## Core Principle

The main agent is a relay. It passes instruction file paths to subagents and
passes result file paths back to the scheduler. It does not plan, split,
prioritize, validate, retry, or decide completion.

The scheduler subagent owns orchestration. It reads the task, selects experience
entries, creates dispatch files, interprets worker results, runs repair loops,
and writes the final report.

## Roles

| Role | Responsibility | Must Not Do |
| --- | --- | --- |
| Main agent | Relay file paths and messages between scheduler and target subagents | Split tasks, decide order, validate results, select experience |
| Scheduler subagent | Own planning, task queue, dispatch, retries, final report, experience handling | Edit implementation directly unless explicitly configured as a worker |
| Planner subagent | Write or refine a plan when scheduler requests it | Dispatch other agents |
| Developer subagent | Implement one assigned task and write a result file | Reassign work or modify unrelated files |
| Tester subagent | Verify one assigned result and write a test result file | Fix production code or change tests to hide failures |

## File Layout

```text
.agent-work/
  input/
    task.md
  scheduler/
    main-relay.md
    scheduler-request.md
  state/
    run.json
    task-queue.json
  dispatch/
    dispatch-001.md
  inbox/
    developer-result-001.md
    tester-result-001.md
  handoff/
    planner-task-001.md
    developer-task-001.md
    tester-task-001.md
    fix-task-001.md
  reports/
    plan.md
    final-report.md
  logs/
    main-agent.log
    scheduler.log
  experience/
    snapshot.md

agent-experience/
  index.jsonl
  entries/
  drafts/
```

`.agent-work/` is runtime state for one run. `agent-experience/` is the durable
experience library. Projects can choose whether to commit `agent-experience/`
or keep it local.

## Main Agent Loop

1. Create or receive `.agent-work/input/task.md`.
2. Send `.agent-work/scheduler/scheduler-request.md` to the scheduler subagent.
3. Wait for scheduler dispatch files under `.agent-work/dispatch/`.
4. For each dispatch, read only:
   - `Target Agent`
   - `Instruction File`
   - `Expected Result File`
5. Send the instruction file path to the target agent.
6. Wait for the target agent to write the expected result file.
7. Tell the scheduler the result file path.
8. Repeat until scheduler writes `.agent-work/reports/final-report.md` and marks
   the run completed.
9. Summarize the final report to the user.

## Scheduler Loop

1. Read `.agent-work/input/task.md`.
2. Read `agent-experience/index.jsonl` and choose relevant entries.
3. Write `.agent-work/experience/snapshot.md` for run-local context.
4. Write or request a plan.
5. Create task queue entries with ownership, dependencies, status, original
   developer, original tester, and repair attempt count.
6. Write dispatch files for planner, developer, and tester work.
7. Interpret result files returned by the main agent.
8. On test failure, dispatch fixes to the original developer and acceptance to
   the original tester for at most three repair cycles.
9. Promote useful experience drafts into `agent-experience/entries/` and append
   metadata to `agent-experience/index.jsonl`.
10. Write `.agent-work/reports/final-report.md`.

## Bootstrap

Use the helper script to create a workspace from a task file:

```bash
python3 scripts/agent_workflow.py init --root . --task-file /path/to/task.md
python3 scripts/agent_workflow.py validate .agent-work
```

The script only scaffolds and validates files. It does not schedule work or
invoke agents.
