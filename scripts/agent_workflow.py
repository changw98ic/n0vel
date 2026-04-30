#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional


WORKSPACE_DIR = ".agent-work"
EXPERIENCE_DIR = "agent-experience"

WORKSPACE_SUBDIRS = [
    "input",
    "scheduler",
    "state",
    "dispatch",
    "inbox",
    "handoff",
    "reports",
    "logs",
    "experience",
]

REQUIRED_DISPATCH_FIELDS = [
    "Dispatch ID",
    "Target Agent",
    "Instruction File",
    "Expected Result File",
]

REQUIRED_RESULT_FIELDS = [
    "Status",
    "Result ID",
    "Source Dispatch",
]


def init_workspace(root: Path, task_file: Path, workspace_name: str = WORKSPACE_DIR) -> Path:
    root = root.resolve()
    task_file = task_file.resolve()
    workspace = root / workspace_name
    experience_root = root / EXPERIENCE_DIR
    experience_index = experience_root / "index.jsonl"

    for subdir in WORKSPACE_SUBDIRS:
        (workspace / subdir).mkdir(parents=True, exist_ok=True)
    (experience_root / "entries").mkdir(parents=True, exist_ok=True)
    (experience_root / "drafts").mkdir(parents=True, exist_ok=True)

    if not experience_index.exists():
        experience_index.write_text("")

    task_text = task_file.read_text()
    input_task = workspace / "input" / "task.md"
    input_task.write_text(task_text)

    now = datetime.now(timezone.utc).isoformat()
    run = {
        "status": "initialized",
        "created_at": now,
        "main_agent_role": "relay",
        "scheduler_role": "orchestrator",
        "paths": {
            "workspace": str(workspace),
            "input_task": str(input_task),
            "main_relay_instruction": str(workspace / "scheduler" / "main-relay.md"),
            "state": str(workspace / "state" / "run.json"),
            "dispatch_dir": str(workspace / "dispatch"),
            "inbox_dir": str(workspace / "inbox"),
            "handoff_dir": str(workspace / "handoff"),
            "final_report": str(workspace / "reports" / "final-report.md"),
            "experience_index": str(experience_index),
            "experience_entries_dir": str(experience_root / "entries"),
            "experience_drafts_dir": str(experience_root / "drafts"),
            "run_experience_snapshot": str(workspace / "experience" / "snapshot.md"),
        },
    }
    (workspace / "state" / "run.json").write_text(json.dumps(run, indent=2) + "\n")
    (workspace / "scheduler" / "main-relay.md").write_text(
        _main_relay_instructions(input_task, experience_index, workspace)
    )
    (workspace / "scheduler" / "scheduler-request.md").write_text(
        _scheduler_request(input_task, workspace, experience_index)
    )
    (workspace / "logs" / "main-agent.log").write_text(
        f"{now} initialized relay workspace from {task_file}\n"
    )
    return workspace


def validate_workspace(workspace: Path) -> List[str]:
    workspace = workspace.resolve()
    errors: List[str] = []

    for subdir in WORKSPACE_SUBDIRS:
        if not (workspace / subdir).is_dir():
            errors.append(f"missing required directory: {subdir}")

    for relative in [
        "input/task.md",
        "scheduler/main-relay.md",
        "scheduler/scheduler-request.md",
        "state/run.json",
    ]:
        if not (workspace / relative).is_file():
            errors.append(f"missing required file: {relative}")

    run = _read_json(workspace / "state" / "run.json")
    if run is not None:
        if run.get("main_agent_role") != "relay":
            errors.append("state/run.json main_agent_role must be relay")
        if run.get("scheduler_role") != "orchestrator":
            errors.append("state/run.json scheduler_role must be orchestrator")
        experience_index = run.get("paths", {}).get("experience_index")
        if experience_index and not Path(experience_index).is_file():
            errors.append(f"missing experience index: {experience_index}")

    for dispatch_file in sorted((workspace / "dispatch").glob("*.md")):
        fields = _front_matterish_fields(dispatch_file.read_text())
        for field in REQUIRED_DISPATCH_FIELDS:
            if field not in fields:
                errors.append(
                    f"dispatch/{dispatch_file.name} missing required field: {field}"
                )

    for result_file in sorted((workspace / "inbox").glob("*.md")):
        text = result_file.read_text()
        fields = _front_matterish_fields(text)
        for field in REQUIRED_RESULT_FIELDS:
            if field not in fields:
                errors.append(f"inbox/{result_file.name} missing required field: {field}")
        for candidate in _experience_candidates(text):
            candidate_path = _resolve_protocol_path(workspace, candidate)
            if not candidate_path.is_file():
                errors.append(
                    f"inbox/{result_file.name} references missing experience candidate: {candidate}"
                )

    return errors


def _main_relay_instructions(input_task: Path, experience_index: Path, workspace: Path) -> str:
    return f"""# Main Agent Relay Instructions

Input Task: {input_task}
Workspace: {workspace}
Experience Index: {experience_index}

Role:
You are a relay, not the scheduler. Pass file paths and messages exactly as
specified by the scheduler.

Rules:
- Send `Scheduler Request` to the scheduler subagent first.
- When the scheduler writes a file under `dispatch/`, read only the routing
  fields: `Target Agent`, `Instruction File`, and `Expected Result File`.
- Deliver the instruction file path to the target agent.
- Do not split, reorder, validate, or decide task status.
- Do not choose experience entries. The scheduler owns retrieval, injection,
  and promotion of experience-library entries.
- Wait for the target agent to write the expected result file or report the
  missing file back to the scheduler.
- Return only result file paths and delivery status to the scheduler.
- When `reports/final-report.md` exists and scheduler state is completed,
  summarize that report to the user.

Scheduler Request: {workspace / "scheduler" / "scheduler-request.md"}
"""


def _scheduler_request(input_task: Path, workspace: Path, experience_index: Path) -> str:
    return f"""# Scheduler Request

Input Task: {input_task}
Workspace: {workspace}
Experience Index: {experience_index}

You are the scheduler subagent. Own planning, task decomposition, dispatch,
test routing, repair loops, and final reporting.

Main-agent boundary:
- The main agent only relays file paths and child-agent results.
- Any file under `dispatch/` is an instruction for the main agent to deliver.
- Every dispatch must include `Target Agent`, `Instruction File`, and
  `Expected Result File`.

Experience-library boundary:
- You decide which experience entries to read.
- You may write a run-local snapshot to `experience/snapshot.md`.
- You may ask workers to propose drafts under `../agent-experience/drafts/`.
- You decide which drafts are promoted into `../agent-experience/entries/`
  and indexed in `../agent-experience/index.jsonl`.
"""


def _front_matterish_fields(text: str) -> Dict[str, str]:
    fields: Dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line or line.lstrip().startswith("-"):
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        if key:
            fields[key] = value.strip()
    return fields


def _experience_candidates(text: str) -> Iterable[str]:
    in_section = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "Experience Candidates:":
            in_section = True
            continue
        if in_section and stripped.endswith(":") and not stripped.startswith("-"):
            in_section = False
        if in_section and stripped.startswith("- "):
            yield stripped[2:].strip()


def _resolve_protocol_path(workspace: Path, protocol_path: str) -> Path:
    path = Path(protocol_path)
    if path.is_absolute():
        return path
    root = workspace.parent
    return (root / path).resolve()


def _read_json(path: Path) -> Optional[dict]:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize and validate agent relay workspaces.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="create a .agent-work relay workspace")
    init_parser.add_argument("--root", type=Path, default=Path.cwd())
    init_parser.add_argument("--task-file", type=Path, required=True)
    init_parser.add_argument("--workspace-name", default=WORKSPACE_DIR)

    validate_parser = subparsers.add_parser("validate", help="validate a relay workspace")
    validate_parser.add_argument("workspace", type=Path)

    args = parser.parse_args()

    if args.command == "init":
        workspace = init_workspace(args.root, args.task_file, args.workspace_name)
        print(workspace)
        return 0

    if args.command == "validate":
        errors = validate_workspace(args.workspace)
        for error in errors:
            print(error)
        return 1 if errors else 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
