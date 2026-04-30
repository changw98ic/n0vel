# Agent Workflow File Protocol

This protocol keeps orchestration outside the main agent. Every decision-making
step belongs to the scheduler subagent.

## Dispatch File

Path:

```text
.agent-work/dispatch/dispatch-001.md
```

Required fields:

```md
# Dispatch

Dispatch ID: dispatch-001
From: scheduler
To: main-agent
Target Agent: developer
Instruction File: .agent-work/handoff/developer-task-001.md
Expected Result File: .agent-work/inbox/developer-result-001.md

Main Agent Rule:
Deliver the instruction file path to Target Agent. Do not interpret, modify,
split, reorder, or validate the task. Wait for Expected Result File, then
return that path to scheduler.
```

The main agent reads routing fields only. The scheduler is responsible for
choosing target agent, timing, and expected result path.

## Handoff File

Path:

```text
.agent-work/handoff/developer-task-001.md
```

Recommended fields:

```md
# Developer Task

Task ID: developer-task-001
Assigned By: scheduler
Expected Result File: .agent-work/inbox/developer-result-001.md
Experience Snapshot: .agent-work/experience/snapshot.md
Relevant Experience:
- agent-experience/entries/api-retry-policy.md

Scope:
- ...

Files:
- ...

Instructions:
- ...

Verification:
- ...

Result Requirements:
- Write the expected result file.
- Include changed files, verification evidence, blockers, and experience
  candidates.
```

## Result File

Path:

```text
.agent-work/inbox/developer-result-001.md
```

Required fields:

```md
# Agent Result

Status: completed
Result ID: developer-result-001
Source Dispatch: dispatch-001

Changed Files:
- path/to/file

Verification:
- command: ...
  result: pass

Blockers:
- none

Experience Candidates:
- agent-experience/drafts/useful-lesson.md
```

Allowed `Status` values:

- `completed`
- `pass`
- `fail`
- `blocked`
- `partial`

Only the scheduler interprets the status.

## State File

Path:

```text
.agent-work/state/run.json
```

Minimum shape:

```json
{
  "status": "initialized",
  "main_agent_role": "relay",
  "scheduler_role": "orchestrator",
  "paths": {
    "input_task": ".agent-work/input/task.md",
    "dispatch_dir": ".agent-work/dispatch",
    "inbox_dir": ".agent-work/inbox",
    "final_report": ".agent-work/reports/final-report.md",
    "experience_index": "agent-experience/index.jsonl"
  }
}
```

Suggested `status` values:

- `initialized`
- `planning`
- `dispatching`
- `waiting_for_result`
- `repairing`
- `completed`
- `failed`

## Task Queue

Path:

```text
.agent-work/state/task-queue.json
```

Suggested task item:

```json
{
  "task_id": "task-001",
  "role": "developer",
  "status": "pending",
  "instruction_file": ".agent-work/handoff/developer-task-001.md",
  "expected_result_file": ".agent-work/inbox/developer-result-001.md",
  "developer_agent_id": null,
  "tester_agent_id": null,
  "repair_attempts": 0,
  "max_repair_attempts": 3,
  "depends_on": []
}
```

The scheduler owns this file. The main agent does not edit it.

## Experience Library

Path:

```text
agent-experience/
  index.jsonl
  entries/
  drafts/
```

`index.jsonl` line format:

```json
{"id":"api-retry-policy","path":"agent-experience/entries/api-retry-policy.md","tags":["api","retry"],"scope":"llm-calls","confidence":"high","last_verified":"2026-04-30"}
```

Entry file format:

```md
# API Retry Policy

ID: api-retry-policy
Scope: llm-calls
Confidence: high
Last Verified: 2026-04-30
Source: .agent-work/reports/final-report.md

## Lesson

...

## Applies When

...

## Do Not Apply When

...

## Verification

...
```

Workers may write drafts, but only the scheduler promotes drafts to entries and
updates `index.jsonl`.
