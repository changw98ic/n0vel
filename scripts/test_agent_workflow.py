import json
import tempfile
import unittest
from pathlib import Path

from agent_workflow import init_workspace, validate_workspace


class AgentWorkflowTests(unittest.TestCase):
    def test_init_creates_relay_scheduler_workspace_with_experience_paths(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            task = root / "task.md"
            task.write_text("# Task\nBuild the feature.\n")

            workspace = init_workspace(root, task)

            self.assertEqual(workspace, root / ".agent-work")
            for relative in [
                "input",
                "scheduler",
                "state",
                "dispatch",
                "inbox",
                "handoff",
                "reports",
                "logs",
                "experience",
                "../agent-experience/entries",
                "../agent-experience/drafts",
            ]:
                self.assertTrue((workspace / relative).is_dir(), relative)

            run = json.loads((workspace / "state" / "run.json").read_text())
            self.assertEqual(run["status"], "initialized")
            self.assertEqual(run["main_agent_role"], "relay")
            self.assertEqual(run["scheduler_role"], "orchestrator")
            self.assertEqual(
                run["paths"]["experience_index"],
                str(root / "agent-experience" / "index.jsonl"),
            )

            main_instructions = (workspace / "scheduler" / "main-relay.md").read_text()
            self.assertIn("Do not split, reorder, validate, or decide task status", main_instructions)
            self.assertIn("Experience Index:", main_instructions)

            validation = validate_workspace(workspace)
            self.assertEqual(validation, [])

    def test_validate_reports_missing_dispatch_fields(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            task = root / "task.md"
            task.write_text("# Task\nBuild the feature.\n")
            workspace = init_workspace(root, task)

            (workspace / "dispatch" / "dispatch-001.md").write_text(
                "# Dispatch\n\n"
                "Dispatch ID: dispatch-001\n"
                "Target Agent: developer\n"
                "Instruction File: .agent-work/handoff/developer-task-001.md\n"
            )

            validation = validate_workspace(workspace)

            self.assertIn(
                "dispatch/dispatch-001.md missing required field: Expected Result File",
                validation,
            )

    def test_validate_accepts_dispatch_result_and_experience_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            task = root / "task.md"
            task.write_text("# Task\nBuild the feature.\n")
            workspace = init_workspace(root, task)

            (workspace / "handoff" / "developer-task-001.md").write_text("# Developer Task\n")
            (workspace / "inbox" / "developer-result-001.md").write_text(
                "# Agent Result\n\n"
                "Status: completed\n"
                "Result ID: developer-result-001\n"
                "Source Dispatch: dispatch-001\n"
                "Experience Candidates:\n"
                "- agent-experience/drafts/retry-policy.md\n"
            )
            (root / "agent-experience" / "drafts" / "retry-policy.md").write_text(
                "# Retry Policy\n\n"
                "Confidence: medium\n"
                "Scope: api-calls\n"
                "Summary: Retry transient API failures with bounded backoff.\n"
            )
            (workspace / "dispatch" / "dispatch-001.md").write_text(
                "# Dispatch\n\n"
                "Dispatch ID: dispatch-001\n"
                "Target Agent: developer\n"
                "Instruction File: .agent-work/handoff/developer-task-001.md\n"
                "Expected Result File: .agent-work/inbox/developer-result-001.md\n"
            )

            validation = validate_workspace(workspace)

            self.assertEqual(validation, [])


if __name__ == "__main__":
    unittest.main()
