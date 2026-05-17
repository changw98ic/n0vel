# Flow Configuration
flow:
  project: novel-writer
  codex_agent: planner
  claude_agent: executor
  wiki_root: .omc/wiki/flow/
  phases:
    plan: { agent: planner, model: auto }
    execute: { agent: executor, model: auto }
    verify: { agent: verifier, model: auto }
