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
