# codex advisor artifact

- Provider: codex
- Exit code: 1
- Created at: 2026-04-06T04:58:19.006Z

## Original task

Review the AI provider architecture in this Flutter writing assistant project for security, correctness, and architectural risks.

Architecture summary:
- AIProvider abstract class with complete(), validateConnection(), countTokens(), getAvailableModels()
- AIProviderRegistry singleton with register()/get() pattern
- 5 providers: OpenAI, Anthropic, Ollama, Azure OpenAI, Custom (OpenAI-compatible)
- FlutterSecureStorage for API keys (encryptedSharedPreferences on Android, Keychain on iOS)
- Regular config in SharedPreferences
- 4-layer cache: L1 memory (LRU, 1000 entries), L2 exact match (MD5 hash, 24h TTL), L3 semantic (Levenshtein, disabled), L4 provider cache
- 3-tier model system: thinking (complex reasoning), middle (balanced), fast (quick responses)
- AIUsageRecords table for all API call logging
- Retry logic: maxRetries=3, timeout=30s
- Streaming support with SSE parsing
- Variable substitution in prompts via replaceAll

Key files:
- lib/core/services/ai/ai_service.dart - Main orchestrator
- lib/core/services/ai/providers/*.dart - Provider implementations
- lib/core/services/ai/cache/cache_manager.dart - 4-layer cache
- lib/core/services/ai/models/model_config.dart - Config + tier system
- lib/features/ai_config/data/ai_config_repository.dart - Config persistence

Focus on:
1. Security vulnerabilities (key exposure, injection, SSRF, data leaks)
2. Singleton registry thread-safety concerns
3. Cache poisoning or collision risks (MD5 for L2)
4. Error handling gaps (streaming failures, partial responses)
5. Retry logic robustness (idempotency, backoff strategy)
6. Input validation on custom endpoints (SSRF risk)
7. Token counting accuracy risks
8. Database logging privacy (prompt/response stored?)
9. Missing rate limiting or cost controls
10. Provider failover / resilience patterns

## Final prompt

Review the AI provider architecture in this Flutter writing assistant project for security, correctness, and architectural risks.

Architecture summary:
- AIProvider abstract class with complete(), validateConnection(), countTokens(), getAvailableModels()
- AIProviderRegistry singleton with register()/get() pattern
- 5 providers: OpenAI, Anthropic, Ollama, Azure OpenAI, Custom (OpenAI-compatible)
- FlutterSecureStorage for API keys (encryptedSharedPreferences on Android, Keychain on iOS)
- Regular config in SharedPreferences
- 4-layer cache: L1 memory (LRU, 1000 entries), L2 exact match (MD5 hash, 24h TTL), L3 semantic (Levenshtein, disabled), L4 provider cache
- 3-tier model system: thinking (complex reasoning), middle (balanced), fast (quick responses)
- AIUsageRecords table for all API call logging
- Retry logic: maxRetries=3, timeout=30s
- Streaming support with SSE parsing
- Variable substitution in prompts via replaceAll

Key files:
- lib/core/services/ai/ai_service.dart - Main orchestrator
- lib/core/services/ai/providers/*.dart - Provider implementations
- lib/core/services/ai/cache/cache_manager.dart - 4-layer cache
- lib/core/services/ai/models/model_config.dart - Config + tier system
- lib/features/ai_config/data/ai_config_repository.dart - Config persistence

Focus on:
1. Security vulnerabilities (key exposure, injection, SSRF, data leaks)
2. Singleton registry thread-safety concerns
3. Cache poisoning or collision risks (MD5 for L2)
4. Error handling gaps (streaming failures, partial responses)
5. Retry logic robustness (idempotency, backoff strategy)
6. Input validation on custom endpoints (SSRF risk)
7. Token counting accuracy risks
8. Database logging privacy (prompt/response stored?)
9. Missing rate limiting or cost controls
10. Provider failover / resilience patterns

## Raw output

```text
OpenAI Codex v0.118.0 (research preview)
--------
workdir: C:\Users\changw98\dev\writing_assistant
model: gpt-5.4
provider: openai
approval: never
sandbox: danger-full-access
reasoning effort: high
reasoning summaries: none
session id: 019d6124-8f2a-7771-8313-630a9c15d286
--------
user
Review the AI provider architecture in this Flutter writing assistant project for security, correctness, and architectural risks.

Architecture summary:
- AIProvider abstract class with complete(), validateConnection(), countTokens(), getAvailableModels()
- AIProviderRegistry singleton with register()/get() pattern
- 5 providers: OpenAI, Anthropic, Ollama, Azure OpenAI, Custom (OpenAI-compatible)
- FlutterSecureStorage for API keys (encryptedSharedPreferences on Android, Keychain on iOS)
- Regular config in SharedPreferences
- 4-layer cache: L1 memory (LRU, 1000 entries), L2 exact match (MD5 hash, 24h TTL), L3 semantic (Levenshtein, disabled), L4 provider cache
- 3-tier model system: thinking (complex reasoning), middle (balanced), fast (quick responses)
- AIUsageRecords table for all API call logging
- Retry logic: maxRetries=3, timeout=30s
- Streaming support with SSE parsing
- Variable substitution in prompts via replaceAll

Key files:
- lib/core/services/ai/ai_service.dart - Main orchestrator
- lib/core/services/ai/providers/*.dart - Provider implementations
- lib/core/services/ai/cache/cache_manager.dart - 4-layer cache
- lib/core/services/ai/models/model_config.dart - Config + tier system
- lib/features/ai_config/data/ai_config_repository.dart - Config persistence

Focus on:
1. Security vulnerabilities (key exposure, injection, SSRF, data leaks)
2. Singleton registry thread-safety concerns
3. Cache poisoning or collision risks (MD5 for L2)
4. Error handling gaps (streaming failures, partial responses)
5. Retry logic robustness (idempotency, backoff strategy)
6. Input validation on custom endpoints (SSRF risk)
7. Token counting accuracy risks
8. Database logging privacy (prompt/response stored?)
9. Missing rate limiting or cost controls
10. Provider failover / resilience patterns
codex
Reviewing the AI provider stack as a code/security audit, not just against the summary. I’m pulling the project-specific memory, the `security-review` skill instructions, and the relevant service/provider files first so the findings are grounded in actual code paths.
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "rg -n \"writing_assistant|SearchService|VectorIndex|FTS5|ai_config|ai_service|provider\" C:\\Users\\changw98\\.codex\\memories\\MEMORY.md" in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'rg --files lib/core/services/ai lib/features/ai_config/data' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "Get-Content C:\\Users\\changw98\\.codex\\skills\\security-review\\SKILL.md -TotalCount 220" in C:\Users\changw98\dev\writing_assistant
 succeeded in 145ms:
---
name: security-review
description: Run a comprehensive security review on code
---

# Security Review Skill

Conduct a thorough security audit checking for OWASP Top 10 vulnerabilities, hardcoded secrets, and unsafe patterns.

## When to Use

This skill activates when:
- User requests "security review", "security audit"
- After writing code that handles user input
- After adding new API endpoints
- After modifying authentication/authorization logic
- Before deploying to production
- After adding external dependencies

## What It Does

## GPT-5.4 Guidance Alignment

- Default to concise, evidence-dense progress and completion reporting unless the user or risk level requires more detail.
- Treat newer user task updates as local overrides for the active workflow branch while preserving earlier non-conflicting constraints.
- If correctness depends on additional inspection, retrieval, execution, or verification, keep using the relevant tools until the security review is grounded.
- Continue through clear, low-risk, reversible next steps automatically; ask only when the next step is materially branching, destructive, or preference-dependent.

Delegates to the `security-reviewer` agent (THOROUGH tier) for deep security analysis:

1. **OWASP Top 10 Scan**
   - A01: Broken Access Control
   - A02: Cryptographic Failures
   - A03: Injection (SQL, NoSQL, Command, XSS)
   - A04: Insecure Design
   - A05: Security Misconfiguration
   - A06: Vulnerable and Outdated Components
   - A07: Identification and Authentication Failures
   - A08: Software and Data Integrity Failures
   - A09: Security Logging and Monitoring Failures
   - A10: Server-Side Request Forgery (SSRF)

2. **Secrets Detection**
   - Hardcoded API keys
   - Passwords in source code
   - Private keys in repo
   - Tokens and credentials
   - Connection strings with secrets

3. **Input Validation**
   - All user inputs sanitized
   - SQL/NoSQL injection prevention
   - Command injection prevention
   - XSS prevention (output escaping)
   - Path traversal prevention

4. **Authentication/Authorization**
   - Proper password hashing (bcrypt, argon2)
   - Session management security
   - Access control enforcement
   - JWT implementation security

5. **Dependency Security**
   - Run `npm audit` for known vulnerabilities
   - Check for outdated dependencies
   - Identify high-severity CVEs

## Agent Delegation

```
delegate(
  role="security-reviewer",
  tier="THOROUGH",
  prompt="SECURITY REVIEW TASK

Conduct comprehensive security audit of codebase.

Scope: [specific files or entire codebase]

Security Checklist:
1. OWASP Top 10 scan
2. Hardcoded secrets detection
3. Input validation review
4. Authentication/authorization review
5. Dependency vulnerability scan (npm audit)

Output: Security review report with:
- Summary of findings by severity (CRITICAL, HIGH, MEDIUM, LOW)
- Specific file:line locations
- CVE references where applicable
- Remediation guidance for each issue
- Overall security posture assessment"
)
```

## External Model Consultation (Preferred)

The security-reviewer agent SHOULD consult Codex for cross-validation.

### Protocol
1. **Form your OWN security analysis FIRST** - Complete the review independently
2. **Consult for validation** - Cross-check findings with Codex
3. **Critically evaluate** - Never blindly adopt external findings
4. **Graceful fallback** - Never block if tools unavailable

### When to Consult
- Authentication/authorization code
- Cryptographic implementations
- Input validation for untrusted data
- High-risk vulnerability patterns
- Production deployment code

### When to Skip
- Low-risk utility code
- Well-audited patterns
- Time-critical security assessments
- Code with existing security tests

### Tool Usage
Before first MCP tool use, call `ToolSearch("mcp")` to discover deferred MCP tools.
Use `mcp__x__ask_codex` with `agent_role: "security-reviewer"`.
If ToolSearch finds no MCP tools, fall back to the `security-reviewer` agent.

**Note:** Security second opinions are high-value. Consider consulting for CRITICAL/HIGH findings.

## Output Format

```
SECURITY REVIEW REPORT
======================

Scope: Entire codebase (42 files scanned)
Scan Date: 2026-01-24T14:30:00Z

CRITICAL (2)
------------
1. src/api/auth.ts:89 - Hardcoded API Key
   Finding: AWS API key hardcoded in source code
   Impact: Credential exposure if code is public or leaked
   Remediation: Move to environment variables, rotate key immediately
   Reference: OWASP A02:2021 鈥?Cryptographic Failures

2. src/db/query.ts:45 - SQL Injection Vulnerability
   Finding: User input concatenated directly into SQL query
   Impact: Attacker can execute arbitrary SQL commands
   Remediation: Use parameterized queries or ORM
   Reference: OWASP A03:2021 鈥?Injection

HIGH (5)
--------
3. src/auth/password.ts:22 - Weak Password Hashing
   Finding: Passwords hashed with MD5 (cryptographically broken)
   Impact: Passwords can be reversed via rainbow tables
   Remediation: Use bcrypt or argon2 with appropriate work factor
   Reference: OWASP A02:2021 鈥?Cryptographic Failures

4. src/components/UserInput.tsx:67 - XSS Vulnerability
   Finding: User input rendered with dangerouslySetInnerHTML
   Impact: Cross-site scripting attack vector
   Remediation: Sanitize HTML or use safe rendering
   Reference: OWASP A03:2021 鈥?Injection (XSS)

5. src/api/upload.ts:34 - Path Traversal Vulnerability
   Finding: User-controlled filename used without validation
   Impact: Attacker can read/write arbitrary files
   Remediation: Validate and sanitize filenames, use allowlist
   Reference: OWASP A01:2021 鈥?Broken Access Control

...

MEDIUM (8)
----------
...

LOW (12)
--------
...

DEPENDENCY VULNERABILITIES
--------------------------
Found 3 vulnerabilities via npm audit:

CRITICAL: axios@0.21.0 - Server-Side Request Forgery (CVE-2021-3749)
  Installed: axios@0.21.0
  Fix: npm install axios@0.21.2

HIGH: lodash@4.17.19 - Prototype Pollution (CVE-2020-8203)
  Installed: lodash@4.17.19
  Fix: npm install lodash@4.17.21

...

OVERALL ASSESSMENT
------------------
Security Posture: POOR (2 CRITICAL, 5 HIGH issues)

Immediate Actions Required:
1. Rotate exposed AWS API key
2. Fix SQL injection in db/query.ts
3. Upgrade password hashing to bcrypt
4. Update vulnerable dependencies

Recommendation: DO NOT DEPLOY until CRITICAL and HIGH issues resolved.
```

## Security Checklist

The security-reviewer agent verifies:

### Authentication & Authorization
- [ ] Passwords hashed with strong algorithm (bcrypt/argon2)
- [ ] Session tokens cryptographically random
- [ ] JWT tokens properly signed and validated
- [ ] Access control enforced on all protected resources
- [ ] No authentication bypass vulnerabilities

### Input Validation
- [ ] All user inputs validated and sanitized
- [ ] SQL queries use parameterization (no string concatenation)
- [ ] NoSQL queries prevent injection

 succeeded in 229ms:
2:scope: reconcile the writing-assistant docs into one baseline, then compare the repo against that baseline; use when the user asks to resolve doc conflicts or measure implementation gaps in the paired `writing_assistant` checkout.
3:applies_to: cwd=C:\Users\changw98; reuse_rule=scope covers this checkout plus `C:\Users\changw98\dev\writing_assistant`; re-check if the doc baseline or repo layout changes
9:- rollout_summaries/2026-04-04T10-02-18-hWN7-writing_assistant_project_architecture_review_and_2_0_1_revi.md (cwd=C:\Users\changw98, rollout_path=C:\Users\changw98\.codex\sessions\2026\04\04\rollout-2026-04-04T18-02-18-019d57f1-8039-7ab1-8025-04972701e805.jsonl, updated_at=2026-04-04T10:30:26+00:00, thread_id=019d57f1-8039-7ab1-8025-04972701e805)
19:- rollout_summaries/2026-04-04T16-18-33-ilzb-writing_assistant_docs_conflict_resolution_and_repo_gap_anal.md (cwd=C:\Users\changw98, rollout_path=C:\Users\changw98\.codex\sessions\2026\04\05\rollout-2026-04-05T00-18-33-019d5949-f98c-72e1-9740-dfa102e72179.jsonl, updated_at=2026-04-04T16:29:35+00:00, thread_id=019d5949-f98c-72e1-9740-dfa102e72179)
23:- writing-assistant-features.md, writing-assistant-project.md, writing_assistant, SearchService, StorageEngine, SearchEngine, VectorIndex, OpenAIProvider, workflow_node_runs, localStore, FTS5, TODO, flutter test
35:- the repo already has Flutter / Riverpod / Drift / go_router / secure storage wiring, but the biggest gaps are search abstraction, multi-provider AI, and a functioning workflow execution loop [Task 2]
36:- `lib/core/database/database.dart` already has FTS5 triggers, but there is no dedicated `SearchService` / `StorageEngine` / `SearchEngine` / `VectorIndex` abstraction yet [Task 2]
37:- `lib/core/services/ai/ai_service.dart` still registers only `OpenAIProvider` [Task 2]

 succeeded in 229ms:
lib/features/ai_config/data\ai_config_repository.dart
lib/core/services/ai\providers\openai_provider.dart
lib/core/services/ai\providers\ollama_provider.dart
lib/core/services/ai\providers\custom_provider.dart
lib/core/services/ai\providers\azure_openai_provider.dart
lib/core/services/ai\providers\anthropic_provider.dart
lib/core/services/ai\providers\ai_provider.dart
lib/core/services/ai\models\model_config.dart
lib/core/services/ai\models\model_config.freezed.dart
lib/core/services/ai\ai_service.freezed.dart
lib/core/services/ai\ai_service.dart
lib/core/services/ai\models\model_config.g.dart
lib/core/services/ai\models\provider_config.g.dart
lib/core/services/ai\models\provider_config.freezed.dart
lib/core/services/ai\models\provider_config.dart
lib/core/services/ai\models\prompt_template.g.dart
lib/core/services/ai\models\prompt_template.freezed.dart
lib/core/services/ai\models\prompt_template.dart
lib/core/services/ai\models\model_tier.dart
lib/core/services/ai\cache\cache_manager.dart

codex
The repo memory is relevant here because a prior baseline note says this checkout only registered `OpenAIProvider` at that time. I’m checking whether that is still true in code or if the current implementation diverged from the older snapshot before I score the architecture risks.
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$lines = Get-Content C:'"\\Users\\changw98\\.codex\\memories\\MEMORY.md; "'$start=31; $end=38; for($i=$start;$i -le $end;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }' in C:\Users\changw98\dev\writing_assistant
 succeeded in 149ms:
31:## Reusable knowledge
32:
33:- `writing-assistant-project.md` is the implementation baseline; `writing-assistant-architecture.md` is only a supplement, and `writing-assistant-features.md` is the scope doc [Task 1]
34:- the conflicts that mattered were `settings` super-table vs split entities, `character_relationships` vs `relationship_heads + relationship_events`, and `workflow_definitions / workflow_instances` vs `ai_tasks + workflow_node_runs + workflow_checkpoints` [Task 1]
35:- the repo already has Flutter / Riverpod / Drift / go_router / secure storage wiring, but the biggest gaps are search abstraction, multi-provider AI, and a functioning workflow execution loop [Task 2]
36:- `lib/core/database/database.dart` already has FTS5 triggers, but there is no dedicated `SearchService` / `StorageEngine` / `SearchEngine` / `VectorIndex` abstraction yet [Task 2]
37:- `lib/core/services/ai/ai_service.dart` still registers only `OpenAIProvider` [Task 2]
38:- `lib/core/services/workflow_service.dart` has node abstractions, but execution and recovery are still placeholder-like in key paths [Task 2]

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "Get-Content C:\\Users\\changw98\\.codex\\memories\\rollout_summaries\\2026-04-04T16-18-33-ilzb-writing_assistant_docs_conflict_resolution_and_repo_gap_anal.md -TotalCount 120" in C:\Users\changw98\dev\writing_assistant
 succeeded in 150ms:
thread_id: 019d5949-f98c-72e1-9740-dfa102e72179
updated_at: 2026-04-04T16:29:35+00:00
rollout_path: C:\Users\changw98\.codex\sessions\2026\04\05\rollout-2026-04-05T00-18-33-019d5949-f98c-72e1-9740-dfa102e72179.jsonl
cwd: C:\Users\changw98

# Reconciled the writing-assistant docs into one baseline and measured repo-vs-architecture gap

Rollout context: the user first asked to analyze three documentation files under C:\Users\changw98 (features, project, architecture), then said to resolve the conflicts, and later asked to inspect C:\Users\changw98\dev\writing_assistant against the architecture. The work happened from C:\Users\changw98 and C:\Users\changw98\dev\writing_assistant.

## Task 1: Resolve documentation conflicts

Outcome: success

Preference signals:
- The user said simply "瑙ｅ喅鍐茬獊" after the initial comparison, indicating they wanted the agent to take action and converge the docs rather than just report problems.
- The user accepted the idea of making `writing-assistant-project.md` the single implementation baseline and demoting `writing-assistant-architecture.md` to a supporting document, implying they prefer one source of truth over dual competing specs.
- The user later asked to inspect the repo against the architecture, which suggests they care about practical alignment with the chosen baseline, not just doc cleanup.

Key steps:
- Read the three UTF-8 docs to avoid terminal encoding corruption.
- Compared the docs by headings and key terms to identify conflicts in data model, relationship model, workflow model, platform strategy, and obvious typos/numbering issues.
- Rewrote `writing-assistant-architecture.md` into a v2.0.2 "鎶€鏈灦鏋勮ˉ鍏呰鏄? aligned to `writing-assistant-project.md`.
- Updated `writing-assistant-features.md` to fix the typo "鐩稿叧鑺傝壊" 鈫?"鐩稿叧瑙掕壊" and renumbered the architecture section headings from `8.x` to `12.x`.
- Added a note to `writing-assistant-project.md` stating it is the current鍞竴瀹炵幇鍩虹嚎 and that `writing-assistant-architecture.md` is only a supplement.

Failures and how to do differently:
- The initial `Get-Content` output was garbled due to encoding; switching to `-Encoding UTF8` (and setting console output encoding to UTF-8) was necessary to read the docs correctly.
- The first architecture draft was too much like a second full spec; the successful rewrite explicitly constrained it to a supplement and removed competing model definitions.

Reusable knowledge:
- In this repo, the stable doc baseline is now: `writing-assistant-features.md` for scope, `writing-assistant-project.md` for implementation/database baseline, and `writing-assistant-architecture.md` only as a supporting explanation.
- The concrete conflicts that mattered were: `settings` super-table vs split entities, `character_relationships` vs `relationship_heads + relationship_events`, and old `workflow_definitions / workflow_instances` vs `ai_tasks + workflow_node_runs + workflow_checkpoints`.
- There was an actual SQL bug in the old architecture draft: a trigger on `character_actions` referenced `NEW.volume_id`, which does not exist on that table.

References:
- `C:\Users\changw98\writing-assistant-project.md` updated to state it is the鍞竴瀹炵幇鍩虹嚎 and link the architecture doc as a supplement.
- `C:\Users\changw98\writing-assistant-architecture.md` rewritten as "鍐欎綔鍔╂墜鎶€鏈灦鏋勮ˉ鍏呰鏄? v2.0.2.
- `C:\Users\changw98\writing-assistant-features.md` typo fixed: `鐩稿叧鑺傝壊` 鈫?`鐩稿叧瑙掕壊`.
- Conflict examples from the review: `settings` table vs split entity tables; `character_relationships` vs `relationship_heads + relationship_events`; `workflow_definitions / workflow_instances / workflow_executions` vs `ai_tasks + workflow_node_runs + workflow_checkpoints`.

## Task 2: Compare repository implementation to the architecture baseline

Outcome: success

Preference signals:
- The user asked to "鏌ョ湅C:\\Users\\changw98\\dev\\writing_assistant 鐪嬬湅璺熸灦鏋勬湁澶氬ぇ宸窛", indicating they want a practical gap analysis tied directly to the current baseline.
- The user accepted a direct, evidence-based comparison rather than a high-level architectural review, so future similar tasks should prioritize concrete file paths, TODOs, and missing modules.

Key steps:
- Inspected the repo root, `pubspec.yaml`, `lib/main.dart`, `lib/app/routes.dart`, `lib/core/database/database.dart`, key table files, `AIService`, `workflow_service.dart`, and several feature services/pages.
- Verified the repo is not a blank scaffold: major feature areas and database tables exist, and routes are wired for work/settings/editor/review/AI detection/timeline/POV/statistics/reading/AI config.
- Checked for missing or partial capabilities by searching for `TODO` markers and by comparing implemented modules against the architecture.
- Attempted to run `flutter test`, but the shell did not have `flutter` in `PATH`, so runtime validation was not possible in this environment.

Failures and how to do differently:
- `flutter test` failed immediately because `flutter` was not available on `PATH` (`CommandNotFoundException`). Future similar checks in this environment should first verify Flutter CLI availability or use the repo's installed toolchain path if known.
- Some feature directories exist but are empty or partially duplicated by newer naming (`pov`, `reader`, `stats`, `workflow` vs active `pov_generation`, `reading_mode`, `statistics`), so directory existence alone was misleading; file-level checks were needed.

Reusable knowledge:
- The repo is roughly 60%鈥?0% aligned to the baseline: structure and many tables/pages exist, but the major gaps are search abstraction, multi-provider AI support, and a functioning workflow execution loop.
- `lib/core/database/database.dart` already creates FTS5 triggers for chapter search, but there is still no dedicated `SearchService` or `StorageEngine / SearchEngine / VectorIndex` abstraction in `lib/core/services`.
- `lib/core/services/ai/ai_service.dart` currently only registers `OpenAIProvider`; multi-provider support (Claude/Ollama/custom) is still not actually implemented.
- `lib/core/services/workflow_service.dart` has node abstractions (`AINode`, `ParallelNode`, `ReviewNode`, `DataNode`) but much of the execution path is still placeholder-like and not a complete resumption/parallelization engine.
- Many feature pages contain `TODO` markers for actions that are expected by the architecture, such as reader navigation/bookmarks/notes, review launching/saving, timeline event creation, stats export, and AI config persistence/testing.
- The repo has a naming split: active modules are `pov_generation`, `reading_mode`, and `statistics`, while the architecture baseline uses `pov`, `reader`, and `stats`; future alignment work should avoid mixing those names casually.

References:
- `C:\Users\changw98\dev\writing_assistant\pubspec.yaml` shows the stack already in use: Flutter, Riverpod, Drift, go_router, secure storage, etc.
- `C:\Users\changw98\dev\writing_assistant\lib\app\routes.dart` wires the main feature pages.
- `C:\Users\changw98\dev\writing_assistant\lib\core\database\database.dart` has `createFTSIndexes()` and the Drift table list.
- `C:\Users\changw98\dev\writing_assistant\lib\core\database\tables\workflow.dart` contains the current workflow tables (`AiTasks`, `WorkflowNodeRuns`, `WorkflowCheckpoints`).
- `C:\Users\changw98\dev\writing_assistant\lib\core\services\ai\ai_service.dart` registers only `OpenAIProvider`.
- `C:\Users\changw98\dev\writing_assistant\lib\core\services\workflow_service.dart` still has placeholder-style execution in several node types.
- `C:\Users\changw98\dev\writing_assistant\lib\features\reading_mode\presentation\pages\reader_page.dart`, `review_center_page.dart`, `timeline_page.dart`, `statistics_page.dart`, and `ai_detection_page.dart` contain visible TODOs for key actions.
- `flutter test` failed with `CommandNotFoundException: 鏃犳硶灏嗏€渇lutter鈥濋」璇嗗埆涓?cmdlet...` because Flutter CLI was not available in the shell.

codex
I’m splitting the audit: one lane for security-specific issues in the provider/config/cache code, one lane for correctness and resilience patterns in the orchestrator and registry. In parallel I’m reading the primary files locally so I can integrate concrete findings with line references instead of forwarding a generic review.
collab: SpawnAgent
collab: SpawnAgent
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/features/ai_config/data/ai_config_repository.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/ai_service.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/cache/cache_manager.dart' in C:\Users\changw98\dev\writing_assistant
 succeeded in 309ms:
import 'dart:convert';
import 'dart:collection';

import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';

/// Prompt 缂撳瓨绠＄悊鍣?/// 鏀寔 L1-L4 鍥涘眰缂撳瓨绛栫暐
class PromptCacheManager {
  final int _maxMemoryCacheSize;
  final Duration _exactCacheTTL;
  final double _semanticSimilarityThreshold;

  PromptCacheManager({
    int maxMemoryCacheSize = 1000,
    Duration exactCacheTTL = const Duration(hours: 24),
    double semanticSimilarityThreshold = 0.95,
  })  : _maxMemoryCacheSize = maxMemoryCacheSize,
        _exactCacheTTL = exactCacheTTL,
        _semanticSimilarityThreshold = semanticSimilarityThreshold;

  /// L1: 鍐呭瓨缂撳瓨锛堜細璇濆唴锛?  final LinkedHashMap<String, CacheEntry> _memoryCache = LinkedHashMap();

  /// L2: 绮剧‘鍖归厤缂撳瓨锛堣法浼氳瘽锛?  final Map<String, CacheEntry> _exactCache = {};

  /// L3: 璇箟缂撳瓨锛堢浉浼艰姹傦級
  final List<SemanticCacheEntry> _semanticCache = [];

  /// 缂撳瓨灞傜骇寮€鍏?  bool enableL1 = true;
  bool enableL2 = true;
  bool enableL3 = false; // 榛樿鍏抽棴锛岄渶瑕佸悜閲忔敮鎸?  bool enableL4 = true;  // 渚涘簲鍟嗙骇缂撳瓨

  /// 鐢熸垚缂撳瓨閿?  String _generateKey(String prompt, String modelId, {Map<String, dynamic>? params}) {
    final content = '$prompt|$modelId|${jsonEncode(params ?? {})}';
    return md5.convert(utf8.encode(content)).toString();
  }

  /// 鏌ユ壘缂撳瓨
  CacheEntry? find(String prompt, String modelId, {Map<String, dynamic>? params}) {
    final key = _generateKey(prompt, modelId, params: params);

    // L1: 鍐呭瓨缂撳瓨
    if (enableL1) {
      final entry = _memoryCache[key];
      if (entry != null && !entry.isExpired) {
        return entry;
      }
    }

    // L2: 绮剧‘鍖归厤
    if (enableL2) {
      final entry = _exactCache[key];
      if (entry != null && !entry.isExpired) {
        // 鎻愬崌鍒?L1
        _memoryCache[key] = entry;
        _evictIfNeeded();
        return entry;
      }
    }

    // L3: 璇箟缂撳瓨
    if (enableL3) {
      final entry = _findSemanticMatch(prompt, modelId);
      if (entry != null) {
        return entry.entry;
      }
    }

    return null;
  }

  /// 瀛樺偍鍒扮紦瀛?  void store(
    String prompt,
    String modelId,
    String response, {
    Map<String, dynamic>? params,
    int? inputTokens,
    int? outputTokens,
  }) {
    final key = _generateKey(prompt, modelId, params: params);
    final now = DateTime.now();

    final entry = CacheEntry(
      key: key,
      response: response,
      createdAt: now,
      expiresAt: now.add(_exactCacheTTL),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );

    // L1
    if (enableL1) {
      _memoryCache[key] = entry;
      _evictIfNeeded();
    }

    // L2
    if (enableL2) {
      _exactCache[key] = entry;
    }
  }

  /// L3: 璇箟鍖归厤鏌ユ壘
  SemanticCacheEntry? _findSemanticMatch(String prompt, String modelId) {
    // 杩欓噷闇€瑕佸悜閲忕浉浼煎害璁＄畻锛岀畝鍖栧疄鐜颁娇鐢ㄧ紪杈戣窛绂?    for (final entry in _semanticCache) {
      if (entry.modelId == modelId &&
          entry.similarity(prompt) >= _semanticSimilarityThreshold &&
          !entry.entry.isExpired) {
        return entry;
      }
    }
    return null;
  }

  /// 娓呯悊杩囨湡缂撳瓨
  void cleanup() {
    _memoryCache.removeWhere((_, entry) => entry.isExpired);
    _exactCache.removeWhere((_, entry) => entry.isExpired);
    _semanticCache.removeWhere((entry) => entry.entry.isExpired);
  }

  /// 娓呯┖鎵€鏈夌紦瀛?  void clear() {
    _memoryCache.clear();
    _exactCache.clear();
    _semanticCache.clear();
  }

  /// 椹遍€愮瓥鐣ワ紙LRU锛?  void _evictIfNeeded() {
    while (_memoryCache.length > _maxMemoryCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  /// 缁熻淇℃伅
  CacheStats get stats => CacheStats(
        l1Count: _memoryCache.length,
        l2Count: _exactCache.length,
        l3Count: _semanticCache.length,
      );
}

/// 缂撳瓨鏉＄洰
class CacheEntry {
  final String key;
  final String response;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? inputTokens;
  final int? outputTokens;

  CacheEntry({
    required this.key,
    required this.response,
    required this.createdAt,
    required this.expiresAt,
    this.inputTokens,
    this.outputTokens,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 璇箟缂撳瓨鏉＄洰
class SemanticCacheEntry {
  final String prompt;
  final String modelId;
  final CacheEntry entry;

  SemanticCacheEntry({
    required this.prompt,
    required this.modelId,
    required this.entry,
  });

  /// 璁＄畻鐩镐技搴︼紙绠€鍖栫増锛屽疄闄呭簲浣跨敤鍚戦噺锛?  double similarity(String other) {
    // 浣跨敤 Levenshtein 璺濈鐨勭畝鍖栫増鏈?    final distance = _levenshteinDistance(prompt, other);
    final maxLen = prompt.length > other.length ? prompt.length : other.length;
    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List.generate(s2.length + 1, (i) => i);
    List<int> curr = List.filled(s2.length + 1, 0);

    for (int i = 1; i <= s1.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost,
        ].min;
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[s2.length];
  }
}

/// 缂撳瓨缁熻
class CacheStats {
  final int l1Count;
  final int l2Count;
  final int l3Count;

  CacheStats({
    required this.l1Count,
    required this.l2Count,
    required this.l3Count,
  });

  int get total => l1Count + l2Count + l3Count;
}

 succeeded in 321ms:
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/services/ai/models/model_config.dart' as core_model;
import '../../../core/services/ai/models/model_tier.dart' as core_tier;
import '../../../core/services/ai/models/provider_config.dart' as core_provider;
import '../../../core/services/ai/providers/anthropic_provider.dart';
import '../../../core/services/ai/providers/azure_openai_provider.dart';
import '../../../core/services/ai/providers/custom_provider.dart';
import '../../../core/services/ai/providers/ollama_provider.dart';
import '../../../core/services/ai/providers/openai_provider.dart';
import '../domain/model_config.dart';

/// AI 閰嶇疆浠撳簱
class AIConfigRepository {
  static const String _keyPrefix = 'ai_config_';
  static const String _defaultLocalProviderType = 'custom';
  static const String _defaultLocalModelName = 'google/gemma-4-26b-a4b';
  static const String _defaultLocalEndpoint = 'http://127.0.0.1:1234/v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// 鑾峰彇妯″瀷閰嶇疆
  Future<ModelConfig?> getModelConfig(ModelTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}model_${tier.name}';

    final providerType = prefs.getString('${key}_provider');
    final modelName = prefs.getString('${key}_model');
    final apiEndpoint = prefs.getString('${key}_endpoint');
    final temperature = prefs.getDouble('${key}_temperature') ?? 0.7;
    final maxTokens = prefs.getInt('${key}_max_tokens') ?? 4096;
    final topP = prefs.getDouble('${key}_top_p') ?? 1.0;
    final frequencyPenalty = prefs.getDouble('${key}_frequency_penalty') ?? 0.0;
    final presencePenalty = prefs.getDouble('${key}_presence_penalty') ?? 0.0;
    final isEnabled = prefs.getBool('${key}_enabled') ?? true;
    final lastValidatedAt = prefs.getInt('${key}_validated_at') != null
        ? DateTime.fromMillisecondsSinceEpoch(
            prefs.getInt('${key}_validated_at')!,
          )
        : null;
    final isValid = prefs.getBool('${key}_is_valid') ?? false;

    if (providerType == null || modelName == null) {
      // 杩斿洖榛樿閰嶇疆
      return ModelConfig(
        tier: tier,
        providerType: providerType ?? _defaultLocalProviderType,
        modelName: modelName ?? _defaultLocalModelName,
        apiEndpoint: apiEndpoint ?? _defaultLocalEndpoint,
        temperature: temperature,
        maxOutputTokens: maxTokens,
        topP: topP,
        frequencyPenalty: frequencyPenalty,
        presencePenalty: presencePenalty,
        isEnabled: isEnabled,
        lastValidatedAt: lastValidatedAt,
        isValid: isValid,
      );
    }

    return ModelConfig(
      tier: tier,
      providerType: providerType,
      modelName: modelName,
      apiEndpoint: apiEndpoint,
      temperature: temperature,
      maxOutputTokens: maxTokens,
      topP: topP,
      frequencyPenalty: frequencyPenalty,
      presencePenalty: presencePenalty,
      isEnabled: isEnabled,
      lastValidatedAt: lastValidatedAt,
      isValid: isValid,
    );
  }

  /// 淇濆瓨妯″瀷閰嶇疆
  Future<void> saveModelConfig({
    required ModelTier tier,
    required String providerType,
    required String modelName,
    String? apiEndpoint,
    String? apiKey,
    double temperature = 0.7,
    int maxOutputTokens = 4096,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}model_${tier.name}';

    // 淇濆瓨閰嶇疆鍒?SharedPreferences
    await prefs.setString('${key}_provider', providerType);
    await prefs.setString('${key}_model', modelName);
    if (apiEndpoint != null) {
      await prefs.setString('${key}_endpoint', apiEndpoint);
    }
    await prefs.setDouble('${key}_temperature', temperature);
    await prefs.setInt('${key}_max_tokens', maxOutputTokens);

    // API Key 浣跨敤 flutter_secure_storage 瀹夊叏瀛樺偍
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.write(key: '${key}_apikey', value: apiKey);
    }
  }

  /// 娴嬭瘯杩炴帴
  Future<bool> testConnection(ModelTier tier) async {
    try {
      // 鑾峰彇璇ュ眰绾х殑閰嶇疆
      final config = await getModelConfig(tier);
      if (config == null) {
        return false;
      }

      // 浠庡畨鍏ㄥ瓨鍌ㄤ腑璇诲彇 API Key
      final apiKey = await _getApiKey(tier);
      final providerType = config.providerType.toLowerCase();
      final requiresApiKey =
          providerType != 'ollama' && providerType != 'custom';
      if (requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
        return false;
      }

      // 鏍规嵁鎻愪緵鍟嗙被鍨嬫祴璇曡繛鎺?      switch (config.providerType.toLowerCase()) {
        case 'openai':
          return await _testOpenAIConnection(apiKey ?? '', config);
        case 'anthropic':
          return await _testAnthropicConnection(apiKey ?? '', config);
        case 'azure':
          return await _testAzureConnection(apiKey ?? '', config);
        case 'ollama':
          return await _testOllamaConnection(config);
        case 'custom':
          return await _testCustomConnection(apiKey ?? '', config);
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// 浠庡畨鍏ㄥ瓨鍌ㄨ幏鍙?API Key
  Future<String?> _getApiKey(ModelTier tier) async {
    final key = '${_keyPrefix}model_${tier.name}';
    try {
      return await _secureStorage.read(key: '${key}_apikey');
    } catch (_) {
      return null;
    }
  }

  /// 娴嬭瘯 OpenAI 杩炴帴
  Future<bool> _testOpenAIConnection(String apiKey, ModelConfig config) async {
    try {
      final provider = OpenAIProvider(dio: Dio());
      return provider.validateConnection(
        _buildProviderConfig(
          apiKey: apiKey,
          config: config,
          type: core_model.AIProviderType.openai,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 娴嬭瘯 Anthropic 杩炴帴
  Future<bool> _testAnthropicConnection(
    String apiKey,
    ModelConfig config,
  ) async {
    try {
      final provider = AnthropicProvider(dio: Dio());
      return provider.validateConnection(
        _buildProviderConfig(
          apiKey: apiKey,
          config: config,
          type: core_model.AIProviderType.anthropic,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 娴嬭瘯 Azure 杩炴帴
  Future<bool> _testAzureConnection(String apiKey, ModelConfig config) async {
    try {
      final provider = AzureOpenAIProvider(dio: Dio());
      return provider.validateConnection(
        _buildProviderConfig(
          apiKey: apiKey,
          config: config,
          type: core_model.AIProviderType.azure,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 娴嬭瘯 Ollama 杩炴帴
  Future<bool> _testOllamaConnection(ModelConfig config) async {
    try {
      final provider = OllamaProvider(dio: Dio());
      return provider.validateConnection(
        _buildProviderConfig(
          apiKey: '',
          config: config,
          type: core_model.AIProviderType.ollama,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 娴嬭瘯鑷畾涔夌鐐硅繛鎺?  Future<bool> _testCustomConnection(String apiKey, ModelConfig config) async {
    try {
      final provider = CustomProvider(dio: Dio());
      return provider.validateConnection(
        _buildProviderConfig(
          apiKey: apiKey,
          config: config,
          type: core_model.AIProviderType.custom,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// 鑾峰彇鎵€鏈夋ā鍨嬮厤缃?  Future<List<ModelConfig>> getAllModelConfigs() async {
    final configs = <ModelConfig>[];
    for (final tier in ModelTier.values) {
      final config = await getModelConfig(tier);
      if (config != null) {
        configs.add(config);
      }
    }
    return configs;
  }

  Future<core_model.ModelConfig?> getCoreModelConfig(ModelTier tier) async {
    final config = await getModelConfig(tier);
    if (config == null) {
      return null;
    }

    return core_model.ModelConfig(
      id: '${tier.name}_${config.providerType}_${config.modelName}',
      tier: _toCoreTier(tier),
      displayName: '${config.providerType}:${config.modelName}',
      providerType: config.providerType,
      modelName: config.modelName,
      apiEndpoint: config.apiEndpoint,
      temperature: config.temperature,
      maxOutputTokens: config.maxOutputTokens,
      topP: config.topP,
      frequencyPenalty: config.frequencyPenalty,
      presencePenalty: config.presencePenalty,
      isEnabled: config.isEnabled,
      lastValidatedAt: config.lastValidatedAt,
      isValid: config.isValid,
    );
  }

  Future<core_provider.ProviderConfig?> getCoreProviderConfig(
    ModelTier tier,
  ) async {
    final config = await getModelConfig(tier);
    if (config == null) {
      return null;
    }

    final apiKey = await _getApiKey(tier);
    return _buildProviderConfig(
      apiKey: apiKey ?? '',
      config: config,
      type: _toCoreProviderType(config.providerType),
    );
  }

  /// 鑾峰彇鍔熻兘鏄犲皠鍒楄〃
  Future<List<FunctionMapping>> getFunctionMappings() async {
    // 杩斿洖榛樿鏄犲皠
    return AIFunction.values
        .map((f) => FunctionMapping(functionKey: f.key))
        .toList();
  }

  /// 鏇存柊鍔熻兘鏄犲皠
  Future<void> updateFunctionMapping({
    required String functionKey,
    required ModelTier tier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}mapping_$functionKey';
    await prefs.setString(key, tier.name);
  }

  /// 鑾峰彇 Prompt 妯℃澘鍒楄〃
  Future<List<PromptTemplate>> getPromptTemplates() async {
    // 杩斿洖榛樿妯℃澘
    return [
      PromptTemplate(
        id: 'continuation',
        name: '缁啓妯℃澘',
        description: '鐢ㄤ簬 AI 缁啓鍐呭',
        systemPrompt: '浣犳槸涓€浣嶄笓涓氱殑灏忚浣滃鍔╂墜銆傝鏍规嵁缁欏畾鐨勪笂涓嬫枃锛岃嚜鐒跺湴缁啓鏁呬簨鍐呭銆備繚鎸佹枃椋庝竴鑷达紝娉ㄦ剰鎯呰妭杩炶疮鎬с€?,
        iconName: 'edit_note',
        createdAt: DateTime.now(),
      ),
      PromptTemplate(
        id: 'dialogue',
        name: '瀵硅瘽鐢熸垚妯℃澘',
        description: '鍩轰簬瑙掕壊妗ｆ鐢熸垚瀵硅瘽',
        systemPrompt: '浣犳槸涓€浣嶄笓涓氱殑灏忚瀵硅瘽浣滃銆傝鏍规嵁瑙掕壊鎬ф牸鍜屾儏澧冿紝鐢熸垚绗﹀悎瑙掕壊鐗圭偣鐨勫璇濄€?,
        iconName: 'chat',
        createdAt: DateTime.now(),
      ),
      PromptTemplate(
        id: 'review',
        name: '绔犺妭瀹℃煡妯℃澘',
        description: '澶氱淮搴﹀鏌ョ珷鑺傝川閲?,
        systemPrompt: '浣犳槸涓€浣嶄笓涓氱殑灏忚缂栬緫銆傝浠庤瀹氫竴鑷存€с€佽鑹睴OC銆佸墽鎯呴€昏緫銆佽妭濂忔妸鎺х瓑缁村害瀹℃煡缁欏畾鐨勭珷鑺傚唴瀹广€?,
        iconName: 'rate_review',
        createdAt: DateTime.now(),
      ),
      PromptTemplate(
        id: 'character_sim',
        name: '瑙掕壊鎺ㄦ紨妯℃澘',
        description: '鎵紨瑙掕壊杩涜琛屼负鎺ㄦ紨',
        systemPrompt: '璇峰畬鍏ㄦ矇娴稿湪缁欏畾瑙掕壊鐨勮瑙掍腑銆傛牴鎹鑹茬殑鎬ф牸銆佷环鍊艰銆佽璇濋鏍煎拰褰撳墠鎯呭锛屾帹婕旇鑹插彲鑳界殑鍙嶅簲銆佸喅绛栧拰鍐呭績娲诲姩銆?,
        iconName: 'person',
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// 淇濆瓨 Prompt 妯℃澘
  Future<void> savePromptTemplate(PromptTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}prompt_${template.id}';

    await prefs.setString(key, template.id);
    await prefs.setString('${key}_name', template.name);
    await prefs.setString('${key}_description', template.description);
    await prefs.setString('${key}_system', template.systemPrompt);
    if (template.userPromptTemplate != null) {
      await prefs.setString('${key}_user', template.userPromptTemplate!);
    }
    await prefs.setString('${key}_icon', template.iconName);
    await prefs.setInt(
      '${key}_created',
      template.createdAt.millisecondsSinceEpoch,
    );
    if (template.updatedAt != null) {
      await prefs.setInt(
        '${key}_updated',
        template.updatedAt!.millisecondsSinceEpoch,
      );
    }
  }

  /// 鑾峰彇浣跨敤缁熻
  Future<UsageStats> getUsageStats() async {
    // 杩斿洖妯℃嫙鏁版嵁
    return UsageStats(
      todayRequests: 45,
      todayTokens: 12500,
      weekRequests: 320,
      weekTokens: 89000,
      monthRequests: 1200,
      monthTokens: 350000,
      byModel: {
        'gpt-4': ModelUsageStats(
          requests: 150,
          tokens: 45000,
          estimatedCost: 1.35,
        ),
        'gpt-3.5-turbo': ModelUsageStats(
          requests: 850,
          tokens: 250000,
          estimatedCost: 0.50,
        ),
        'claude-3-opus': ModelUsageStats(
          requests: 200,
          tokens: 55000,
          estimatedCost: 2.75,
        ),
      },
      byFunction: {
        'continuation': FunctionUsageStats(requests: 500, tokens: 150000),
        'dialogue': FunctionUsageStats(requests: 300, tokens: 80000),
        'review': FunctionUsageStats(requests: 150, tokens: 45000),
        'extraction': FunctionUsageStats(requests: 100, tokens: 30000),
        'characterSim': FunctionUsageStats(requests: 50, tokens: 25000),
      },
    );
  }

  /// 璁板綍 API 璋冪敤
  Future<void> logApiCall({
    required ModelTier tier,
    required AIFunction function,
    required int inputTokens,
    required int outputTokens,
    required bool success,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final callHistory = prefs.getStringList('ai_api_call_history') ?? [];

    final record = {
      'timestamp': DateTime.now().toIso8601String(),
      'tier': tier.name,
      'function': function.name,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'totalTokens': inputTokens + outputTokens,
      'success': success,
    };

    callHistory.add(jsonEncode(record));

    // 鍙繚鐣欐渶杩?000鏉¤褰?    if (callHistory.length > 1000) {
      callHistory.removeRange(0, callHistory.length - 1000);
    }

    await prefs.setStringList('ai_api_call_history', callHistory);
  }

  /// 璁板綍AI閰嶇疆鍙樻洿
  Future<void> logConfigChange({
    required ModelTier tier,
    required String changeType,
    required Map<String, dynamic> oldValue,
    required Map<String, dynamic> newValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final configHistory = prefs.getStringList('ai_config_change_history') ?? [];

    final record = {
      'timestamp': DateTime.now().toIso8601String(),
      'tier': tier.name,
      'changeType': changeType,
      'oldValue': oldValue,
      'newValue': newValue,
    };

    configHistory.add(jsonEncode(record));

    // 鍙繚鐣欐渶杩?00鏉￠厤缃彉鏇磋褰?    if (configHistory.length > 500) {
      configHistory.removeRange(0, configHistory.length - 500);
    }

    await prefs.setStringList('ai_config_change_history', configHistory);
  }

  /// 鑾峰彇API璋冪敤鍘嗗彶
  Future<List<Map<String, dynamic>>> getApiCallHistory({
    int limit = 100,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final callHistory = prefs.getStringList('ai_api_call_history') ?? [];

    return callHistory
        .take(limit)
        .map((record) => jsonDecode(record) as Map<String, dynamic>)
        .toList();
  }

  /// 鑾峰彇閰嶇疆鍙樻洿鍘嗗彶
  Future<List<Map<String, dynamic>>> getConfigChangeHistory({
    int limit = 100,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final configHistory = prefs.getStringList('ai_config_change_history') ?? [];

    return configHistory
        .take(limit)
        .map((record) => jsonDecode(record) as Map<String, dynamic>)
        .toList();
  }

  core_provider.ProviderConfig _buildProviderConfig({
    required String apiKey,
    required ModelConfig config,
    required core_model.AIProviderType type,
  }) {
    return core_provider.ProviderConfig(
      id: 'ai_config_${config.tier.name}_${type.name}',
      type: type,
      name: type.displayName,
      apiKey: apiKey,
      apiEndpoint: config.apiEndpoint,
    );
  }

  core_tier.ModelTier _toCoreTier(ModelTier tier) {
    return switch (tier) {
      ModelTier.thinking => core_tier.ModelTier.thinking,
      ModelTier.middle => core_tier.ModelTier.middle,
      ModelTier.fast => core_tier.ModelTier.fast,
    };
  }

  core_model.AIProviderType _toCoreProviderType(String providerType) {
    return switch (providerType.toLowerCase()) {
      'openai' => core_model.AIProviderType.openai,
      'anthropic' || 'claude' => core_model.AIProviderType.anthropic,
      'ollama' => core_model.AIProviderType.ollama,
      'azure' => core_model.AIProviderType.azure,
      _ => core_model.AIProviderType.custom,
    };
  }
}

 succeeded in 330ms:
import 'dart:async';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get/get.dart' as getx;
import 'package:uuid/uuid.dart';

import '../../../features/ai_config/data/ai_config_repository.dart';
import '../../../features/ai_config/domain/model_config.dart' as feature_config;
import '../../database/database.dart';
import 'cache/cache_manager.dart';
import 'models/model_config.dart';
import 'models/model_tier.dart';
import 'models/provider_config.dart';
import 'providers/ai_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/azure_openai_provider.dart';
import 'providers/custom_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

part 'ai_service.freezed.dart';

extension StringToAIProviderType on String {
  AIProviderType toProviderType() {
    final lower = toLowerCase();
    return switch (lower) {
      'openai' => AIProviderType.openai,
      'anthropic' || 'claude' => AIProviderType.anthropic,
      'ollama' => AIProviderType.ollama,
      'azure' => AIProviderType.azure,
      _ => AIProviderType.custom,
    };
  }
}

@freezed
class AIResponse with _$AIResponse {
  const factory AIResponse({
    required String content,
    required int inputTokens,
    required int outputTokens,
    required String modelId,
    required Duration responseTime,
    required bool fromCache,
    String? requestId,
    Map<String, dynamic>? metadata,
  }) = _AIResponse;
}

@freezed
class AIRequestConfig with _$AIRequestConfig {
  const factory AIRequestConfig({
    required AIFunction function,
    String? systemPrompt,
    required String userPrompt,
    Map<String, dynamic>? variables,
    ModelTier? overrideTier,
    String? overrideModelId,
    @Default(true) bool useCache,
    @Default(true) bool stream,
    @Default(1.0) double temperature,
    int? maxTokens,
    void Function(String)? onStreamChunk,
  }) = _AIRequestConfig;
}

sealed class AIResult<T> {
  const AIResult();
}

class AISuccess<T> extends AIResult<T> {
  final T data;
  final AIResponse response;

  const AISuccess(this.data, this.response);
}

class AIFailure<T> extends AIResult<T> {
  final String error;
  final String? errorCode;
  final int? statusCode;

  const AIFailure(this.error, {this.errorCode, this.statusCode});
}

class AIException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic originalError;

  const AIException(
    this.message, {
    this.code,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'AIException: $message';
}

class TokenCountException extends AIException {
  const TokenCountException(int current, int max)
    : super(
        'Token count exceeds limit: $current > $max',
        code: 'TOKEN_LIMIT_EXCEEDED',
      );
}

class AIService extends getx.GetxController {
  final PromptCacheManager _cacheManager;
  final AIProviderRegistry _providerRegistry;
  final AppDatabase _db;
  final Uuid _uuid;

  AIService()
    : _cacheManager = PromptCacheManager(),
      _providerRegistry = AIProviderRegistry(),
      _db = getx.Get.find<AppDatabase>(),
      _uuid = const Uuid() {
    _registerDefaultProviders();
  }

  void _registerDefaultProviders() {
    _providerRegistry.register(OpenAIProvider());
    _providerRegistry.register(AnthropicProvider());
    _providerRegistry.register(OllamaProvider());
    _providerRegistry.register(AzureOpenAIProvider());
    _providerRegistry.register(CustomProvider());
  }

  Future<AIResponse> generate({
    required String prompt,
    required AIRequestConfig config,
  }) async {
    final stopwatch = Stopwatch()..start();
    final modelConfig = await _getModelConfig(config);
    if (modelConfig == null) {
      throw AIException('No model configured for ${config.function.key}');
    }

    if (config.useCache) {
      final cached = _cacheManager.find(
        prompt,
        modelConfig.id,
        params: {
          'temperature': config.temperature,
          'maxTokens': config.maxTokens,
        },
      );
      if (cached != null) {
        stopwatch.stop();
        await _recordAIUsage(
          functionType: config.function.key,
          modelId: modelConfig.id,
          tier: modelConfig.tier.name,
          status: 'success',
          inputTokens: cached.inputTokens ?? 0,
          outputTokens: cached.outputTokens ?? 0,
          responseTimeMs: stopwatch.elapsed.inMilliseconds,
          fromCache: true,
        );
        return AIResponse(
          content: cached.response,
          inputTokens: cached.inputTokens ?? 0,
          outputTokens: cached.outputTokens ?? 0,
          modelId: modelConfig.id,
          responseTime: stopwatch.elapsed,
          fromCache: true,
        );
      }
    }

    final providerConfig = await _getProviderConfig(modelConfig);
    if (providerConfig == null) {
      throw AIException(
        'No provider config found for ${modelConfig.providerType}',
      );
    }

    final provider = _providerRegistry.get(
      modelConfig.providerType.toProviderType(),
    );
    if (provider == null) {
      throw AIException(
        'No provider registered for ${modelConfig.providerType}',
      );
    }

    final systemPrompt =
        config.systemPrompt ?? _getDefaultSystemPrompt(config.function);
    final userPrompt = _buildUserPrompt(prompt, config);

    try {
      final response = await provider.complete(
        config: providerConfig,
        model: modelConfig,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: config.temperature,
        maxTokens: config.maxTokens,
        stream: false,
      );

      if (config.useCache) {
        _cacheManager.store(
          prompt,
          modelConfig.id,
          response.content,
          params: {
            'temperature': config.temperature,
            'maxTokens': config.maxTokens,
          },
          inputTokens: response.inputTokens,
          outputTokens: response.outputTokens,
        );
      }

      await _recordAIUsage(
        functionType: config.function.key,
        modelId: modelConfig.id,
        tier: modelConfig.tier.name,
        status: 'success',
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        responseTimeMs: response.responseTime.inMilliseconds,
        requestId: response.requestId,
        fromCache: false,
        metadata: response.metadata,
      );

      return response;
    } catch (error) {
      await _recordAIUsage(
        functionType: config.function.key,
        modelId: modelConfig.id,
        tier: modelConfig.tier.name,
        status: 'error',
        inputTokens: 0,
        outputTokens: 0,
        responseTimeMs: stopwatch.elapsed.inMilliseconds,
        errorMessage: error.toString(),
        fromCache: false,
      );
      rethrow;
    }
  }

  Stream<String> generateStream({
    required String prompt,
    required AIRequestConfig config,
  }) async* {
    final modelConfig = await _getModelConfig(config);
    if (modelConfig == null) {
      throw AIException('No model configured for ${config.function.key}');
    }

    final providerConfig = await _getProviderConfig(modelConfig);
    if (providerConfig == null) {
      throw AIException(
        'No provider config found for ${modelConfig.providerType}',
      );
    }

    final provider = _providerRegistry.get(
      modelConfig.providerType.toProviderType(),
    );
    if (provider == null) {
      throw AIException(
        'No provider registered for ${modelConfig.providerType}',
      );
    }

    final systemPrompt =
        config.systemPrompt ?? _getDefaultSystemPrompt(config.function);
    final userPrompt = _buildUserPrompt(prompt, config);
    final controller = StreamController<String>();
    final buffer = StringBuffer();
    final stopwatch = Stopwatch()..start();

    try {
      unawaited(
        provider
            .complete(
              config: providerConfig,
              model: modelConfig,
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              temperature: config.temperature,
              maxTokens: config.maxTokens,
              stream: true,
              onStreamChunk: (chunk) {
                buffer.write(chunk);
                config.onStreamChunk?.call(chunk);
                controller.add(chunk);
              },
            )
            .then((_) async {
              stopwatch.stop();
              final tokens = await provider.countTokens(
                buffer.toString(),
                modelConfig.modelName,
              );
              if (config.useCache) {
                _cacheManager.store(
                  prompt,
                  modelConfig.id,
                  buffer.toString(),
                  params: {
                    'temperature': config.temperature,
                    'maxTokens': config.maxTokens,
                  },
                  inputTokens: tokens,
                  outputTokens: tokens,
                );
              }
              await _recordAIUsage(
                functionType: config.function.key,
                modelId: modelConfig.id,
                tier: modelConfig.tier.name,
                status: 'success',
                inputTokens: tokens,
                outputTokens: tokens,
                responseTimeMs: stopwatch.elapsed.inMilliseconds,
                fromCache: false,
              );
              await controller.close();
            })
            .catchError((error) async {
              await _recordAIUsage(
                functionType: config.function.key,
                modelId: modelConfig.id,
                tier: modelConfig.tier.name,
                status: 'error',
                inputTokens: 0,
                outputTokens: 0,
                responseTimeMs: stopwatch.elapsed.inMilliseconds,
                errorMessage: error.toString(),
                fromCache: false,
              );
              controller.addError(error);
              controller.close();
            }),
      );

      yield* controller.stream;
    } finally {
      await controller.close();
    }
  }

  Future<ModelConfig?> _getModelConfig(AIRequestConfig config) async {
    final repo = getx.Get.find<AIConfigRepository>();
    final featureTier = _toFeatureTier(
      config.overrideTier ?? config.function.defaultTier,
    );
    return repo.getCoreModelConfig(featureTier);
  }

  Future<ProviderConfig?> _getProviderConfig(ModelConfig modelConfig) async {
    final repo = getx.Get.find<AIConfigRepository>();
    final featureTier = _toFeatureTier(modelConfig.tier);
    return repo.getCoreProviderConfig(featureTier);
  }

  String _getDefaultSystemPrompt(AIFunction function) {
    return switch (function) {
      AIFunction.continuation => '浣犳槸涓€浣嶄笓涓氱殑灏忚浣滃鍔╂墜锛岃鏍规嵁涓婁笅鏂囪嚜鐒剁画鍐欍€?,
      AIFunction.dialogue => '浣犳槸涓€浣嶄笓涓氱殑灏忚瀵硅瘽浣滃锛岃鐢熸垚绗﹀悎瑙掕壊璁惧畾鐨勫璇濄€?,
      AIFunction.characterSimulation => '浣犳槸涓€浣嶄笓涓氱殑瑙掕壊鎵紨鍔╂墜锛岃鏍规嵁瑙掕壊璁惧畾杩涜鎺ㄦ紨銆?,
      AIFunction.review => '浣犳槸涓€浣嶄笓涓氱殑灏忚缂栬緫锛岃浠庝竴鑷存€с€侀€昏緫鍜岃妭濂忕淮搴﹀鏌ュ唴瀹广€?,
      AIFunction.extraction => '浣犳槸涓€浣嶄笓涓氱殑璁惧畾鎻愬彇鍔╂墜锛岃鎻愬彇瑙掕壊銆佸湴鐐广€佺墿鍝佺瓑淇℃伅銆?,
      AIFunction.consistencyCheck => '浣犳槸涓€浣嶄笓涓氱殑涓€鑷存€ф鏌ュ姪鎵嬶紝璇锋鏌ュ唴瀹逛腑鐨勮瀹氬啿绐併€?,
      AIFunction.timelineExtract => '浣犳槸涓€浣嶄笓涓氱殑鏃堕棿绾挎彁鍙栧姪鎵嬶紝璇锋彁鍙栦簨浠堕『搴忋€?,
      AIFunction.oocDetection => '浣犳槸涓€浣嶄笓涓氱殑瑙掕壊 OOC 妫€娴嬪姪鎵嬶紝璇锋鏌ヨ鑹茶涓烘槸鍚︾鍚堣瀹氥€?,
      AIFunction.aiStyleDetection => '浣犳槸涓€浣嶄笓涓氱殑 AI 鏂囬妫€娴嬪姪鎵嬶紝璇疯瘑鍒槑鏄剧殑 AI 鐥曡抗銆?,
      AIFunction.perspectiveCheck => '浣犳槸涓€浣嶄笓涓氱殑瑙嗚妫€娴嬪姪鎵嬶紝璇锋鏌ュ彊浜嬭瑙掓槸鍚︿竴鑷淬€?,
      AIFunction.pacingAnalysis => '浣犳槸涓€浣嶄笓涓氱殑鑺傚鍒嗘瀽鍔╂墜锛岃鍒嗘瀽鍙欎簨鑺傚鏄惁鍚堢悊銆?,
      AIFunction.povGeneration => '浣犳槸涓€浣嶄笓涓氱殑瑙嗚鐢熸垚鍔╂墜锛岃浠庢寚瀹氳鑹茶瑙掗噸鍐欏唴瀹广€?,
    };
  }

  String _buildUserPrompt(String prompt, AIRequestConfig config) {
    var result = prompt;
    final variables = config.variables;
    if (variables != null) {
      variables.forEach((key, value) {
        result = result.replaceAll('{$key}', value.toString());
      });
    }
    return result;
  }

  void clearCache() {
    _cacheManager.clear();
  }

  CacheStats get cacheStats => _cacheManager.stats;

  Future<void> _recordAIUsage({
    required String functionType,
    required String modelId,
    required String tier,
    required String status,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    String? errorMessage,
    String? requestId,
    required bool fromCache,
    String? workId,
    Map<String, dynamic>? metadata,
  }) async {
    final record = AIUsageRecordsCompanion.insert(
      id: _uuid.v4(),
      workId: Value(workId),
      functionType: functionType,
      modelId: modelId,
      tier: tier,
      status: status,
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      totalTokens: Value(inputTokens + outputTokens),
      responseTimeMs: Value(responseTimeMs),
      errorMessage: Value(errorMessage),
      requestId: Value(requestId),
      fromCache: Value(fromCache),
      metadata: Value(metadata?.toString()),
      createdAt: DateTime.now(),
    );

    await _db.into(_db.aIUsageRecords).insert(record);

    await _updateDailySummary(
      functionType: functionType,
      modelId: modelId,
      tier: tier,
      status: status,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      responseTimeMs: responseTimeMs,
      fromCache: fromCache,
      workId: workId,
    );
  }

  Future<void> _updateDailySummary({
    required String functionType,
    required String modelId,
    required String tier,
    required String status,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    required bool fromCache,
    String? workId,
  }) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final existing =
        await (_db.select(_db.aIUsageSummaries)
              ..where(
                (table) =>
                    table.workId.equalsNullable(workId) &
                    table.modelId.equals(modelId) &
                    table.functionType.equalsNullable(functionType) &
                    table.date.equals(today),
              )
              ..limit(1))
            .get();

    if (existing.isNotEmpty) {
      final summary = existing.first;
      await (_db.update(
        _db.aIUsageSummaries,
      )..where((table) => table.id.equals(summary.id))).write(
        AIUsageSummariesCompanion(
          requestCount: Value(summary.requestCount + 1),
          successCount: Value(
            status == 'success'
                ? summary.successCount + 1
                : summary.successCount,
          ),
          errorCount: Value(
            status == 'error' ? summary.errorCount + 1 : summary.errorCount,
          ),
          cachedCount: Value(
            fromCache ? summary.cachedCount + 1 : summary.cachedCount,
          ),
          totalInputTokens: Value(summary.totalInputTokens + inputTokens),
          totalOutputTokens: Value(summary.totalOutputTokens + outputTokens),
          totalTokens: Value(summary.totalTokens + inputTokens + outputTokens),
          totalResponseTimeMs: Value(
            summary.totalResponseTimeMs + responseTimeMs,
          ),
          avgResponseTimeMs: Value(
            (summary.totalResponseTimeMs + responseTimeMs) ~/
                (summary.requestCount + 1),
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await _db
        .into(_db.aIUsageSummaries)
        .insert(
          AIUsageSummariesCompanion.insert(
            id: _uuid.v4(),
            workId: Value(workId),
            modelId: modelId,
            tier: tier,
            functionType: Value(functionType),
            date: today,
            requestCount: const Value(1),
            successCount: Value(status == 'success' ? 1 : 0),
            errorCount: Value(status == 'error' ? 1 : 0),
            cachedCount: Value(fromCache ? 1 : 0),
            totalInputTokens: Value(inputTokens),
            totalOutputTokens: Value(outputTokens),
            totalTokens: Value(inputTokens + outputTokens),
            totalResponseTimeMs: Value(responseTimeMs),
            avgResponseTimeMs: Value(responseTimeMs),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<AIUsageRecord>> getAIUsageStatistics({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? functionType,
    int limit = 100,
  }) async {
    final query = _db.select(_db.aIUsageRecords);

    if (workId != null) {
      query.where((table) => table.workId.equals(workId));
    }
    if (startDate != null) {
      query.where((table) => table.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((table) => table.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (functionType != null) {
      query.where((table) => table.functionType.equals(functionType));
    }

    query
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
      ..limit(limit);

    return query.get();
  }

  Future<List<AIUsageSummary>> getAIUsageSummaries({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? modelId,
  }) async {
    final query = _db.select(_db.aIUsageSummaries);

    if (workId != null) {
      query.where((table) => table.workId.equals(workId));
    }
    if (startDate != null) {
      query.where((table) => table.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((table) => table.date.isSmallerOrEqualValue(endDate));
    }
    if (modelId != null) {
      query.where((table) => table.modelId.equals(modelId));
    }

    query.orderBy([(table) => OrderingTerm.desc(table.date)]);
    return query.get();
  }

  Future<Map<String, dynamic>> getModelUsageStats({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final summaries = await getAIUsageSummaries(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
    );

    final result = <String, Map<String, dynamic>>{};
    for (final summary in summaries) {
      result.putIfAbsent(summary.modelId, () {
        return <String, dynamic>{
          'totalTokens': 0,
          'totalRequests': 0,
          'totalCost': 0.0,
          'avgResponseTime': 0,
          'tier': summary.tier,
        };
      });

      final entry = result[summary.modelId]!;
      entry['totalTokens'] += summary.totalTokens;
      entry['totalRequests'] += summary.requestCount;
      entry['totalCost'] += summary.estimatedCost;
      entry['avgResponseTime'] =
          ((entry['avgResponseTime'] as int) + summary.avgResponseTimeMs) ~/ 2;
    }

    return result;
  }

  feature_config.ModelTier _toFeatureTier(ModelTier tier) {
    return switch (tier) {
      ModelTier.thinking => feature_config.ModelTier.thinking,
      ModelTier.middle => feature_config.ModelTier.middle,
      ModelTier.fast => feature_config.ModelTier.fast,
    };
  }
}

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/providers/ai_provider.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/providers/openai_provider.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/providers/anthropic_provider.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/providers/azure_openai_provider.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/providers/ollama_provider.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/providers/custom_provider.dart' in C:\Users\changw98\dev\writing_assistant
 succeeded in 153ms:
import 'dart:async';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';

/// AI 渚涘簲鍟嗘娊璞℃帴鍙?abstract class AIProvider {
  /// 渚涘簲鍟嗙被鍨?  AIProviderType get type;

  /// 楠岃瘉杩炴帴
  Future<bool> validateConnection(ProviderConfig config);

  /// 鎵ц璇锋眰
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  });

  /// 浼扮畻 Token 鏁伴噺
  Future<int> countTokens(String text, String modelName);

  /// 鑾峰彇鍙敤妯″瀷鍒楄〃锛堝鏋滀緵搴斿晢鏀寔锛?  Future<List<String>> getAvailableModels(ProviderConfig config);
}

/// AI 渚涘簲鍟嗘敞鍐岃〃
class AIProviderRegistry {
  static final AIProviderRegistry _instance = AIProviderRegistry._();
  factory AIProviderRegistry() => _instance;
  AIProviderRegistry._();

  final Map<AIProviderType, AIProvider> _providers = {};

  void register(AIProvider provider) {
    _providers[provider.type] = provider;
  }

  AIProvider? get(AIProviderType type) => _providers[type];

  List<AIProviderType> get availableTypes => _providers.keys.toList();
}

 succeeded in 160ms:
import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

/// OpenAI 渚涘簲鍟嗗疄鐜?class OpenAIProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.openai;

  final Dio _dio;

  OpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<bool> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            ...config.headers,
          },
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  }) async {
    final stopwatch = Stopwatch()..start();

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final requestBody = {
      'model': model.modelName,
      'messages': messages,
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
      'top_p': model.topP,
      'frequency_penalty': model.frequencyPenalty,
      'presence_penalty': model.presencePenalty,
      'stream': stream,
    };

    try {
      if (stream && onStreamChunk != null) {
        return await _streamComplete(
          config: config,
          requestBody: requestBody,
          model: model,
          stopwatch: stopwatch,
          onStreamChunk: onStreamChunk,
        );
      }

      final response = await _dio.post(
        '${config.effectiveEndpoint}/chat/completions',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            ...config.headers,
          },
        ),
      );

      stopwatch.stop();

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List;
      final content = choices.first['message']['content'] as String;
      final usage = data['usage'] as Map<String, dynamic>;

      return AIResponse(
        content: content,
        inputTokens: usage['prompt_tokens'] as int,
        outputTokens: usage['completion_tokens'] as int,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
      );
    } on DioException catch (e) {
      throw AIException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<AIResponse> _streamComplete({
    required ProviderConfig config,
    required Map<String, dynamic> requestBody,
    required ModelConfig model,
    required Stopwatch stopwatch,
    required void Function(String) onStreamChunk,
  }) async {
    final response = await _dio.post(
      '${config.effectiveEndpoint}/chat/completions',
      data: requestBody,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
          ...config.headers,
        },
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();
    int inputTokens = 0;
    int outputTokens = 0;
    String? requestId;

    await for (final chunk in stream) {
      final text = utf8.decode(chunk);
      final lines = text.split('\n');

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') continue;

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            requestId ??= json['id'] as String?;

            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null) {
                buffer.write(content);
                onStreamChunk(content);
              }
            }
          } catch (_) {
            // 蹇界暐瑙ｆ瀽閿欒
          }
        }
      }
    }

    stopwatch.stop();

    // 浼扮畻 token锛堟祦寮忓搷搴旈€氬父涓嶈繑鍥?usage锛?    inputTokens = await countTokens(requestBody['messages'].toString(), model.modelName);
    outputTokens = await countTokens(buffer.toString(), model.modelName);

    return AIResponse(
      content: buffer.toString(),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: requestId,
    );
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    // 绠€鍖栦及绠楋細涓枃绾?1.5 瀛楃/token锛岃嫳鏂囩害 4 瀛楃/token
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final otherCount = text.length - chineseCount;
    return (chineseCount * 0.67 + otherCount * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            ...config.headers,
          },
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List;
      return models.map((m) => m['id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['error'] != null) {
        return data['error']['message'] ?? 'Unknown error';
      }
    }
    return e.message ?? 'Request failed';
  }
}

 succeeded in 146ms:
import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class AzureOpenAIProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.azure;

  final Dio _dio;

  AzureOpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<bool> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.post(
        _chatUrl(config, 'gpt-4.1-mini'),
        data: {
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
          'max_tokens': 1,
        },
        options: Options(headers: _headers(config)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  }) async {
    final stopwatch = Stopwatch()..start();
    final response = await _dio.post(
      _chatUrl(config, model.modelName),
      data: {
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature ?? model.temperature,
        'max_tokens': maxTokens ?? model.maxOutputTokens,
      },
      options: Options(headers: _headers(config)),
    );
    stopwatch.stop();

    final data = response.data as Map<String, dynamic>;
    final first = ((data['choices'] as List).first as Map<String, dynamic>);
    final message = first['message'] as Map<String, dynamic>;
    final usage = data['usage'] as Map<String, dynamic>?;

    return AIResponse(
      content: message['content'] as String? ?? '',
      inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: data['id'] as String?,
    );
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    return const [];
  }

  Map<String, String> _headers(ProviderConfig config) {
    return {
      'api-key': config.apiKey ?? '',
      'Content-Type': 'application/json',
      ...config.headers,
    };
  }

  String _chatUrl(ProviderConfig config, String deploymentName) {
    final base = config.effectiveEndpoint;
    final suffix = base.contains('?') ? '&' : '?';
    return '$base/openai/deployments/$deploymentName/chat/completions${suffix}api-version=2024-02-15-preview';
  }
}

 succeeded in 147ms:
import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class CustomProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.custom;

  final Dio _dio;

  CustomProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<bool> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(headers: _headers(config)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  }) async {
    final stopwatch = Stopwatch()..start();
    final response = await _dio.post(
      '${config.effectiveEndpoint}/chat/completions',
      data: {
        'model': model.modelName,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature ?? model.temperature,
        'max_tokens': maxTokens ?? model.maxOutputTokens,
        'stream': false,
      },
      options: Options(headers: _headers(config)),
    );
    stopwatch.stop();

    final data = response.data as Map<String, dynamic>;
    final content = ((data['choices'] as List).first as Map<String, dynamic>);
    final message = content['message'] as Map<String, dynamic>;
    final usage = data['usage'] as Map<String, dynamic>?;

    return AIResponse(
      content: message['content'] as String? ?? '',
      inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: data['id'] as String?,
    );
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    try {
      final response = await _dio.get(
        '${config.effectiveEndpoint}/models',
        options: Options(headers: _headers(config)),
      );
      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>? ?? const [];
      return models
          .whereType<Map<String, dynamic>>()
          .map((model) => model['id'])
          .whereType<String>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> _headers(ProviderConfig config) {
    return {
      if (config.apiKey != null && config.apiKey!.isNotEmpty)
        'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
      ...config.headers,
    };
  }
}

 succeeded in 148ms:
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class OllamaProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.ollama;

  final Dio _dio;

  OllamaProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<bool> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.get('${config.effectiveEndpoint}/tags');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  }) async {
    final stopwatch = Stopwatch()..start();
    final body = {
      'model': model.modelName,
      'stream': stream,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'options': {
        'temperature': temperature ?? model.temperature,
        'num_predict': maxTokens ?? model.maxOutputTokens,
      },
    };

    try {
      if (stream && onStreamChunk != null) {
        return await _streamComplete(
          config: config,
          body: body,
          model: model,
          stopwatch: stopwatch,
          onStreamChunk: onStreamChunk,
        );
      }

      final response = await _dio.post(
        '${config.effectiveEndpoint}/chat',
        data: body,
      );
      stopwatch.stop();

      final data = response.data as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>? ?? const {};
      final content = message['content'] as String? ?? '';

      return AIResponse(
        content: content,
        inputTokens: await countTokens(userPrompt, model.modelName),
        outputTokens: await countTokens(content, model.modelName),
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
      );
    } on DioException catch (e) {
      throw AIException(
        e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<AIResponse> _streamComplete({
    required ProviderConfig config,
    required Map<String, dynamic> body,
    required ModelConfig model,
    required Stopwatch stopwatch,
    required void Function(String) onStreamChunk,
  }) async {
    final response = await _dio.post(
      '${config.effectiveEndpoint}/chat',
      data: body,
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      final text = utf8.decode(chunk);
      for (final line in const LineSplitter().convert(text)) {
        if (line.trim().isEmpty) {
          continue;
        }
        try {
          final data = jsonDecode(line) as Map<String, dynamic>;
          final message = data['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            buffer.write(content);
            onStreamChunk(content);
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
    }

    stopwatch.stop();

    return AIResponse(
      content: buffer.toString(),
      inputTokens: await countTokens(body['messages'].toString(), model.modelName),
      outputTokens: await countTokens(buffer.toString(), model.modelName),
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
    );
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    try {
      final response = await _dio.get('${config.effectiveEndpoint}/tags');
      final data = response.data as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>? ?? const [];
      return models
          .whereType<Map<String, dynamic>>()
          .map((model) => model['name'])
          .whereType<String>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

 succeeded in 152ms:
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../ai_service.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'ai_provider.dart';

class AnthropicProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.anthropic;

  final Dio _dio;

  AnthropicProvider({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<bool> validateConnection(ProviderConfig config) async {
    try {
      final response = await _dio.post(
        '${config.effectiveEndpoint}/messages',
        data: {
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 16,
          'messages': [
            {'role': 'user', 'content': 'ping'},
          ],
        },
        options: Options(
          headers: _headers(config),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AIResponse> complete({
    required ProviderConfig config,
    required ModelConfig model,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
    bool stream = false,
    void Function(String)? onStreamChunk,
  }) async {
    final stopwatch = Stopwatch()..start();

    final body = {
      'model': model.modelName,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature ?? model.temperature,
      'max_tokens': maxTokens ?? model.maxOutputTokens,
      'stream': stream,
    };

    try {
      if (stream && onStreamChunk != null) {
        return await _streamComplete(
          config: config,
          body: body,
          model: model,
          stopwatch: stopwatch,
          onStreamChunk: onStreamChunk,
        );
      }

      final response = await _dio.post(
        '${config.effectiveEndpoint}/messages',
        data: body,
        options: Options(headers: _headers(config)),
      );

      stopwatch.stop();
      final data = response.data as Map<String, dynamic>;
      final content = _extractContent(data);
      final usage = data['usage'] as Map<String, dynamic>?;

      return AIResponse(
        content: content,
        inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
        outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
        modelId: model.id,
        responseTime: stopwatch.elapsed,
        fromCache: false,
        requestId: data['id'] as String?,
      );
    } on DioException catch (e) {
      throw AIException(
        _extractErrorMessage(e),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
    }
  }

  Future<AIResponse> _streamComplete({
    required ProviderConfig config,
    required Map<String, dynamic> body,
    required ModelConfig model,
    required Stopwatch stopwatch,
    required void Function(String) onStreamChunk,
  }) async {
    final response = await _dio.post(
      '${config.effectiveEndpoint}/messages',
      data: body,
      options: Options(
        headers: _headers(config),
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();
    String? requestId;

    await for (final chunk in stream) {
      final text = utf8.decode(chunk);
      for (final line in text.split('\n')) {
        if (!line.startsWith('data: ')) {
          continue;
        }
        final payload = line.substring(6);
        if (payload == '[DONE]' || payload.isEmpty) {
          continue;
        }
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          requestId ??= data['id'] as String?;
          final type = data['type'] as String?;
          if (type == 'content_block_delta') {
            final delta = data['delta'] as Map<String, dynamic>?;
            final textChunk = delta?['text'] as String?;
            if (textChunk != null && textChunk.isNotEmpty) {
              buffer.write(textChunk);
              onStreamChunk(textChunk);
            }
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
    }

    stopwatch.stop();

    return AIResponse(
      content: buffer.toString(),
      inputTokens: await countTokens(userPromptFromBody(body), model.modelName),
      outputTokens: await countTokens(buffer.toString(), model.modelName),
      modelId: model.id,
      responseTime: stopwatch.elapsed,
      fromCache: false,
      requestId: requestId,
    );
  }

  @override
  Future<int> countTokens(String text, String modelName) async {
    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final other = text.length - chinese;
    return (chinese * 0.67 + other * 0.25).ceil();
  }

  @override
  Future<List<String>> getAvailableModels(ProviderConfig config) async {
    return const [
      'claude-3-5-sonnet-20241022',
      'claude-3-5-haiku-20241022',
      'claude-3-opus-20240229',
    ];
  }

  Map<String, String> _headers(ProviderConfig config) {
    return {
      'x-api-key': config.apiKey ?? '',
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
      ...config.headers,
    };
  }

  String _extractContent(Map<String, dynamic> data) {
    final content = data['content'] as List<dynamic>? ?? const [];
    return content
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['text'])
        .whereType<String>()
        .join();
  }

  String userPromptFromBody(Map<String, dynamic> body) {
    final messages = body['messages'] as List<dynamic>? ?? const [];
    return messages
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['content'])
        .whereType<String>()
        .join('\n');
  }

  String _extractErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['message']?.toString() ?? 'Request failed';
    }
    return e.message ?? 'Request failed';
  }
}

codex
I’ve confirmed the current code has the full provider set, so the older memory note is stale and I’m treating it as history only. Next pass is the exact config model, endpoint normalization, and the database schema for `AIUsageRecords`, because those decide most of the SSRF, privacy, and cost-control answers.
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/models/model_config.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/models/provider_config.dart' in C:\Users\changw98\dev\writing_assistant
 succeeded in 133ms:
import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_config.dart';
import 'model_tier.dart';

part 'provider_config.freezed.dart';
part 'provider_config.g.dart';

/// 渚涘簲鍟嗛厤缃?/// 瀛樺偍姣忎釜 AI 渚涘簲鍟嗙殑 API 鍑瘉鍜岃缃?@freezed
class ProviderConfig with _$ProviderConfig {
  const ProviderConfig._();

  const factory ProviderConfig({
    required String id,
    required AIProviderType type,
    required String name,
    String? apiKey,          // 鍔犲瘑瀛樺偍
    String? apiEndpoint,     // 鑷畾涔夌鐐?    @Default({}) Map<String, String> headers,  // 鑷畾涔夎姹傚ご
    @Default(30) int timeoutSeconds,
    @Default(3) int maxRetries,
    @Default(true) bool isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ProviderConfig;

  factory ProviderConfig.fromJson(Map<String, dynamic> json) =>
      _$ProviderConfigFromJson(json);

  /// 鑾峰彇瀹屾暣鐨?API 绔偣
  String get effectiveEndpoint {
    if (apiEndpoint != null && apiEndpoint!.isNotEmpty) {
      return apiEndpoint!;
    }
    return type.defaultEndpoint;
  }
}

/// 鍔熻兘-妯″瀷鏄犲皠閰嶇疆
@freezed
class FunctionMapping with _$FunctionMapping {
  const FunctionMapping._();

  const factory FunctionMapping({
    required String functionKey,  // 浣跨敤 key 鑰岄潪鏋氫妇
    String? overrideModelId,      // 瑕嗙洊榛樿灞傜骇锛屼娇鐢ㄦ寚瀹氭ā鍨?    @Default(false) bool useOverride, // 鏄惁浣跨敤瑕嗙洊
  }) = _FunctionMapping;

  factory FunctionMapping.fromJson(Map<String, dynamic> json) =>
      _$FunctionMappingFromJson(json);

  /// 鑾峰彇瀵瑰簲鐨?AIFunction
  AIFunction? get function => AIFunction.fromKey(functionKey);

  /// 榛樿鏄犲皠
  static List<FunctionMapping> defaults() =>
      AIFunction.values.map((f) => FunctionMapping(functionKey: f.key)).toList();
}

 succeeded in 134ms:
import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_tier.dart';

part 'model_config.freezed.dart';
part 'model_config.g.dart';

/// 妯″瀷閰嶇疆
/// 鐢ㄦ埛鍙嚜瀹氫箟姣忎釜灞傜骇鐨勬ā鍨?@freezed
class ModelConfig with _$ModelConfig {
  const ModelConfig._();

  const factory ModelConfig({
    required String id,
    required ModelTier tier,
    required String displayName,
    required String providerType,
    required String modelName,
    String? apiEndpoint,
    @Default(0.7) double temperature,
    @Default(4096) int maxOutputTokens,
    @Default(1.0) double topP,
    @Default(0.0) double frequencyPenalty,
    @Default(0.0) double presencePenalty,
    @Default(true) bool isEnabled,
    DateTime? lastValidatedAt,
    @Default(false) bool isValid,
  }) = _ModelConfig;

  factory ModelConfig.fromJson(Map<String, dynamic> json) =>
      _$ModelConfigFromJson(json);

  /// 榛樿閰嶇疆妯℃澘
  static List<ModelConfig> defaultConfigs() => [
        ModelConfig(
          id: 'thinking_default',
          tier: ModelTier.thinking,
          displayName: 'Thinking (榛樿)',
          providerType: 'openai',
          modelName: 'gpt-4-turbo',
          temperature: 0.7,
          maxOutputTokens: 4096,
        ),
        ModelConfig(
          id: 'middle_default',
          tier: ModelTier.middle,
          displayName: 'Middle (榛樿)',
          providerType: 'openai',
          modelName: 'gpt-3.5-turbo',
          temperature: 0.7,
          maxOutputTokens: 2048,
        ),
        ModelConfig(
          id: 'fast_default',
          tier: ModelTier.fast,
          displayName: 'Fast (榛樿)',
          providerType: 'openai',
          modelName: 'gpt-3.5-turbo',
          temperature: 0.8,
          maxOutputTokens: 1024,
        ),
      ];
}

/// 渚涘簲鍟嗙被鍨?enum AIProviderType {
  openai('OpenAI', 'https://api.openai.com/v1'),
  anthropic('Claude', 'https://api.anthropic.com/v1'),
  ollama('Ollama', 'http://localhost:11434/api'),
  azure('Azure OpenAI', ''),
  custom('Custom', '');

  const AIProviderType(this.displayName, this.defaultEndpoint);

  final String displayName;
  final String defaultEndpoint;
}

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/models/model_tier.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'rg -n "AIUsageRecords|AIUsageSummaries|estimatedCost|retry|maxRetries|timeout|backoff|rate limit|cost" lib' in C:\Users\changw98\dev\writing_assistant
 succeeded in 133ms:
/// AI 妯″瀷灞傜骇鏋氫妇
/// 涓夊眰妯″瀷浣撶郴锛歍hinking/Middle/Fast
enum ModelTier {
  /// 鎬濊€冨眰 - 澶嶆潅鎺ㄧ悊銆佹繁搴﹀垎鏋愩€佽鑹叉帹婕?  thinking(
    name: 'Thinking',
    description: '澶嶆潅鎺ㄧ悊銆佹繁搴﹀垎鏋愩€佽鑹叉帹婕?,
    priority: 0,
  ),

  /// 涓棿灞?- 骞宠　鎬ц兘涓庢垚鏈?  middle(
    name: 'Middle',
    description: '绔犺妭瀹℃煡銆佽瀹氭彁鍙栥€佷竴鑷存€ф鏌?,
    priority: 1,
  ),

  /// 蹇€熷眰 - 蹇€熷搷搴斻€佷綆鎴愭湰
  fast(
    name: 'Fast',
    description: '缁啓銆佸璇濈敓鎴愩€佺畝鍗曚换鍔?,
    priority: 2,
  );

  const ModelTier({
    required this.name,
    required this.description,
    required this.priority,
  });

  final String name;
  final String description;
  final int priority;

  /// 浠庡瓧绗︿覆瑙ｆ瀽
  static ModelTier? fromString(String value) {
    return switch (value.toLowerCase()) {
      'thinking' => ModelTier.thinking,
      'middle' => ModelTier.middle,
      'fast' => ModelTier.fast,
      _ => null,
    };
  }
}

/// AI 鍔熻兘绫诲瀷
/// 鐢ㄤ簬鑷姩鏄犲皠鍒板搴旂殑妯″瀷灞傜骇
enum AIFunction {
  /// 缁啓 鈫?Fast
  continuation('continuation', ModelTier.fast),

  /// 瀵硅瘽鐢熸垚 鈫?Fast
  dialogue('dialogue', ModelTier.fast),

  /// 瑙掕壊鎺ㄦ紨 鈫?Thinking
  characterSimulation('character_simulation', ModelTier.thinking),

  /// 绔犺妭瀹℃煡 鈫?Middle
  review('review', ModelTier.middle),

  /// 璁惧畾鎻愬彇 鈫?Middle
  extraction('extraction', ModelTier.middle),

  /// 涓€鑷存€ф鏌?鈫?Middle
  consistencyCheck('consistency_check', ModelTier.middle),

  /// 鏃堕棿绾挎彁鍙?鈫?Middle
  timelineExtract('timeline_extract', ModelTier.middle),

  /// OOC妫€娴?鈫?Middle
  oocDetection('ooc_detection', ModelTier.middle),

  /// AI鍙ｅ惢妫€娴?鈫?Middle
  aiStyleDetection('ai_style_detection', ModelTier.middle),

  /// 瑙嗚妫€娴?鈫?Middle
  perspectiveCheck('perspective_check', ModelTier.middle),

  /// 鑺傚鍒嗘瀽 鈫?Middle
  pacingAnalysis('pacing_analysis', ModelTier.middle),

  /// 閰嶈瑙嗚鐢熸垚 鈫?Thinking
  povGeneration('pov_generation', ModelTier.thinking);

  const AIFunction(this.key, this.defaultTier);

  final String key;
  final ModelTier defaultTier;

  static AIFunction? fromKey(String key) {
    return values.cast<AIFunction?>().firstWhere(
          (f) => f?.key == key,
          orElse: () => null,
        );
  }
}

 succeeded in 190ms:
lib\l10n\app_zh.arb:362:  "povResult_retry": "重试",
lib\l10n\app_zh.arb:394:  "reader_retry": "重试",
lib\l10n\app_zh.arb:467:  "reading_retry": "重试",
lib\l10n\app_zh.arb:480:  "retry": "重试",
lib\l10n\app_zh.arb:1089:  "work_retry": "重试",
lib\l10n\app_localizations_zh.dart:1132:  String get povResult_retry => '重试';
lib\l10n\app_localizations_zh.dart:1236:  String get reader_retry => '重试';
lib\l10n\app_localizations_zh.dart:1479:  String get reading_retry => '重试';
lib\l10n\app_localizations_zh.dart:1520:  String get retry => '重试';
lib\l10n\app_localizations_zh.dart:3468:  String get work_retry => '重试';
lib\l10n\app_localizations_en.dart:1147:  String get povResult_retry => '重试';
lib\l10n\app_localizations_en.dart:1251:  String get reader_retry => '重试';
lib\l10n\app_localizations_en.dart:1494:  String get reading_retry => '重试';
lib\l10n\app_localizations_en.dart:1535:  String get retry => '重试';
lib\l10n\app_localizations_en.dart:3483:  String get work_retry => '重试';
lib\l10n\app_localizations.dart:2254:  /// No description provided for @povResult_retry.
lib\l10n\app_localizations.dart:2258:  String get povResult_retry;
lib\l10n\app_localizations.dart:2446:  /// No description provided for @reader_retry.
lib\l10n\app_localizations.dart:2450:  String get reader_retry;
lib\l10n\app_localizations.dart:2884:  /// No description provided for @reading_retry.
lib\l10n\app_localizations.dart:2888:  String get reading_retry;
lib\l10n\app_localizations.dart:2962:  /// No description provided for @retry.
lib\l10n\app_localizations.dart:2966:  String get retry;
lib\l10n\app_localizations.dart:6616:  /// No description provided for @work_retry.
lib\l10n\app_localizations.dart:6620:  String get work_retry;
lib\features\ai_config\data\ai_config_repository.dart:390:          estimatedCost: 1.35,
lib\features\ai_config\data\ai_config_repository.dart:395:          estimatedCost: 0.50,
lib\features\ai_config\data\ai_config_repository.dart:400:          estimatedCost: 2.75,
lib\l10n\app_en.arb:362:  "povResult_retry": "重试",
lib\l10n\app_en.arb:394:  "reader_retry": "重试",
lib\l10n\app_en.arb:467:  "reading_retry": "重试",
lib\l10n\app_en.arb:480:  "retry": "重试",
lib\l10n\app_en.arb:1089:  "work_retry": "重试",
lib\features\ai_config\presentation\pages\usage_stats_page.dart:339:      final summaries = await aiService.getAIUsageSummaries(
lib\features\ai_config\domain\model_config.dart:181:  final double estimatedCost;
lib\features\ai_config\domain\model_config.dart:186:    required this.estimatedCost,
lib\core\services\workflow_service.dart:164:  final int? retryNodeIndex;
lib\core\services\workflow_service.dart:172:    this.retryNodeIndex,
lib\features\reading_mode\presentation\pages\reader_page.dart:275:        actionLabel: s.retry,
lib\features\reading_mode\presentation\pages\reader_page.dart:728:                actionLabel: S.of(context)!.retry,
lib\features\workflow\data\workflow_repository.dart:109:  Future<void> retryTask(String taskId) async {
lib\features\workflow\data\workflow_repository.dart:141:        'action': 'retry',
lib\core\database\tables\ai_usage.dart:5:class AIUsageRecords extends Table {
lib\core\database\tables\ai_usage.dart:33:class AIUsageSummaries extends Table {
lib\core\database\tables\ai_usage.dart:49:  RealColumn get estimatedCost => real().withDefault(const Constant(0))(); // 预估成本
lib\features\work\presentation\work_copy.dart:20:  String get work_retry => _isZh ? '重试' : 'Retry';
lib\core\database\database.g.dart:12149:class $AIUsageRecordsTable extends AIUsageRecords
lib\core\database\database.g.dart:12150:    with TableInfo<$AIUsageRecordsTable, AIUsageRecord> {
lib\core\database\database.g.dart:12154:  $AIUsageRecordsTable(this.attachedDatabase, [this._alias]);
lib\core\database\database.g.dart:12411:  $AIUsageRecordsTable createAlias(String alias) {
lib\core\database\database.g.dart:12412:    return $AIUsageRecordsTable(attachedDatabase, alias);
lib\core\database\database.g.dart:12477:  AIUsageRecordsCompanion toCompanion(bool nullToAbsent) {
lib\core\database\database.g.dart:12478:    return AIUsageRecordsCompanion(
lib\core\database\database.g.dart:12581:  AIUsageRecord copyWithCompanion(AIUsageRecordsCompanion data) {
lib\core\database\database.g.dart:12671:class AIUsageRecordsCompanion extends UpdateCompanion<AIUsageRecord> {
lib\core\database\database.g.dart:12688:  const AIUsageRecordsCompanion({
lib\core\database\database.g.dart:12706:  AIUsageRecordsCompanion.insert({
lib\core\database\database.g.dart:12767:  AIUsageRecordsCompanion copyWith(
lib\core\database\database.g.dart:12784:    return AIUsageRecordsCompanion(
lib\core\database\database.g.dart:12860:    return (StringBuffer('AIUsageRecordsCompanion(')
lib\core\database\database.g.dart:12882:class $AIUsageSummariesTable extends AIUsageSummaries
lib\core\database\database.g.dart:12883:    with TableInfo<$AIUsageSummariesTable, AIUsageSummary> {
lib\core\database\database.g.dart:12887:  $AIUsageSummariesTable(this.attachedDatabase, [this._alias]);
lib\core\database\database.g.dart:12992:  static const VerificationMeta _estimatedCostMeta =
lib\core\database\database.g.dart:12993:      const VerificationMeta('estimatedCost');
lib\core\database\database.g.dart:12995:  late final GeneratedColumn<double> estimatedCost = GeneratedColumn<double>(
lib\core\database\database.g.dart:12996:      'estimated_cost', aliasedName, false,
lib\core\database\database.g.dart:13029:        estimatedCost,
lib\core\database\database.g.dart:13130:    if (data.containsKey('estimated_cost')) {
lib\core\database\database.g.dart:13132:          _estimatedCostMeta,
lib\core\database\database.g.dart:13133:          estimatedCost.isAcceptableOrUnknown(
lib\core\database\database.g.dart:13134:              data['estimated_cost']!, _estimatedCostMeta));
lib\core\database\database.g.dart:13191:      estimatedCost: attachedDatabase.typeMapping
lib\core\database\database.g.dart:13192:          .read(DriftSqlType.double, data['${effectivePrefix}estimated_cost'])!,
lib\core\database\database.g.dart:13201:  $AIUsageSummariesTable createAlias(String alias) {
lib\core\database\database.g.dart:13202:    return $AIUsageSummariesTable(attachedDatabase, alias);
lib\core\database\database.g.dart:13222:  final double estimatedCost;
lib\core\database\database.g.dart:13241:      required this.estimatedCost,
lib\core\database\database.g.dart:13266:    map['estimated_cost'] = Variable<double>(estimatedCost);
lib\core\database\database.g.dart:13272:  AIUsageSummariesCompanion toCompanion(bool nullToAbsent) {
lib\core\database\database.g.dart:13273:    return AIUsageSummariesCompanion(
lib\core\database\database.g.dart:13292:      estimatedCost: Value(estimatedCost),
lib\core\database\database.g.dart:13318:      estimatedCost: serializer.fromJson<double>(json['estimatedCost']),
lib\core\database\database.g.dart:13342:      'estimatedCost': serializer.toJson<double>(estimatedCost),
lib\core\database\database.g.dart:13364:          double? estimatedCost,
lib\core\database\database.g.dart:13384:        estimatedCost: estimatedCost ?? this.estimatedCost,
lib\core\database\database.g.dart:13388:  AIUsageSummary copyWithCompanion(AIUsageSummariesCompanion data) {
lib\core\database\database.g.dart:13422:      estimatedCost: data.estimatedCost.present
lib\core\database\database.g.dart:13423:          ? data.estimatedCost.value
lib\core\database\database.g.dart:13424:          : this.estimatedCost,
lib\core\database\database.g.dart:13448:          ..write('estimatedCost: $estimatedCost, ')
lib\core\database\database.g.dart:13472:      estimatedCost,
lib\core\database\database.g.dart:13494:          other.estimatedCost == this.estimatedCost &&
lib\core\database\database.g.dart:13499:class AIUsageSummariesCompanion extends UpdateCompanion<AIUsageSummary> {
lib\core\database\database.g.dart:13515:  final Value<double> estimatedCost;
lib\core\database\database.g.dart:13519:  const AIUsageSummariesCompanion({
lib\core\database\database.g.dart:13535:    this.estimatedCost = const Value.absent(),
lib\core\database\database.g.dart:13540:  AIUsageSummariesCompanion.insert({
lib\core\database\database.g.dart:13556:    this.estimatedCost = const Value.absent(),
lib\core\database\database.g.dart:13582:    Expression<double>? estimatedCost,
lib\core\database\database.g.dart:13604:      if (estimatedCost != null) 'estimated_cost': estimatedCost,
lib\core\database\database.g.dart:13611:  AIUsageSummariesCompanion copyWith(
lib\core\database\database.g.dart:13627:      Value<double>? estimatedCost,
lib\core\database\database.g.dart:13631:    return AIUsageSummariesCompanion(
lib\core\database\database.g.dart:13647:      estimatedCost: estimatedCost ?? this.estimatedCost,
lib\core\database\database.g.dart:13702:    if (estimatedCost.present) {
lib\core\database\database.g.dart:13703:      map['estimated_cost'] = Variable<double>(estimatedCost.value);
lib\core\database\database.g.dart:13719:    return (StringBuffer('AIUsageSummariesCompanion(')
lib\core\database\database.g.dart:13735:          ..write('estimatedCost: $estimatedCost, ')
lib\core\database\database.g.dart:14717:  late final $AIUsageRecordsTable aIUsageRecords = $AIUsageRecordsTable(this);
lib\core\database\database.g.dart:14718:  late final $AIUsageSummariesTable aIUsageSummaries =
lib\core\database\database.g.dart:14719:      $AIUsageSummariesTable(this);
lib\core\database\database.g.dart:23323:typedef $$AIUsageRecordsTableCreateCompanionBuilder = AIUsageRecordsCompanion
lib\core\database\database.g.dart:23342:typedef $$AIUsageRecordsTableUpdateCompanionBuilder = AIUsageRecordsCompanion
lib\core\database\database.g.dart:23362:class $$AIUsageRecordsTableFilterComposer
lib\core\database\database.g.dart:23363:    extends Composer<_$AppDatabase, $AIUsageRecordsTable> {
lib\core\database\database.g.dart:23364:  $$AIUsageRecordsTableFilterComposer({
lib\core\database\database.g.dart:23418:class $$AIUsageRecordsTableOrderingComposer
lib\core\database\database.g.dart:23419:    extends Composer<_$AppDatabase, $AIUsageRecordsTable> {
lib\core\database\database.g.dart:23420:  $$AIUsageRecordsTableOrderingComposer({
lib\core\database\database.g.dart:23477:class $$AIUsageRecordsTableAnnotationComposer
lib\core\database\database.g.dart:23478:    extends Composer<_$AppDatabase, $AIUsageRecordsTable> {
lib\core\database\database.g.dart:23479:  $$AIUsageRecordsTableAnnotationComposer({
lib\core\database\database.g.dart:23532:class $$AIUsageRecordsTableTableManager extends RootTableManager<
lib\core\database\database.g.dart:23534:    $AIUsageRecordsTable,
lib\core\database\database.g.dart:23536:    $$AIUsageRecordsTableFilterComposer,
lib\core\database\database.g.dart:23537:    $$AIUsageRecordsTableOrderingComposer,
lib\core\database\database.g.dart:23538:    $$AIUsageRecordsTableAnnotationComposer,
lib\core\database\database.g.dart:23539:    $$AIUsageRecordsTableCreateCompanionBuilder,
lib\core\database\database.g.dart:23540:    $$AIUsageRecordsTableUpdateCompanionBuilder,
lib\core\database\database.g.dart:23543:      BaseReferences<_$AppDatabase, $AIUsageRecordsTable, AIUsageRecord>
lib\core\database\database.g.dart:23547:  $$AIUsageRecordsTableTableManager(
lib\core\database\database.g.dart:23548:      _$AppDatabase db, $AIUsageRecordsTable table)
lib\core\database\database.g.dart:23553:              $$AIUsageRecordsTableFilterComposer($db: db, $table: table),
lib\core\database\database.g.dart:23555:              $$AIUsageRecordsTableOrderingComposer($db: db, $table: table),
lib\core\database\database.g.dart:23557:              $$AIUsageRecordsTableAnnotationComposer($db: db, $table: table),
lib\core\database\database.g.dart:23576:              AIUsageRecordsCompanion(
lib\core\database\database.g.dart:23612:              AIUsageRecordsCompanion.insert(
lib\core\database\database.g.dart:23637:typedef $$AIUsageRecordsTableProcessedTableManager = ProcessedTableManager<
lib\core\database\database.g.dart:23639:    $AIUsageRecordsTable,
lib\core\database\database.g.dart:23641:    $$AIUsageRecordsTableFilterComposer,
lib\core\database\database.g.dart:23642:    $$AIUsageRecordsTableOrderingComposer,
lib\core\database\database.g.dart:23643:    $$AIUsageRecordsTableAnnotationComposer,
lib\core\database\database.g.dart:23644:    $$AIUsageRecordsTableCreateCompanionBuilder,
lib\core\database\database.g.dart:23645:    $$AIUsageRecordsTableUpdateCompanionBuilder,
lib\core\database\database.g.dart:23648:      BaseReferences<_$AppDatabase, $AIUsageRecordsTable, AIUsageRecord>
lib\core\database\database.g.dart:23652:typedef $$AIUsageSummariesTableCreateCompanionBuilder
lib\core\database\database.g.dart:23653:    = AIUsageSummariesCompanion Function({
lib\core\database\database.g.dart:23669:  Value<double> estimatedCost,
lib\core\database\database.g.dart:23674:typedef $$AIUsageSummariesTableUpdateCompanionBuilder
lib\core\database\database.g.dart:23675:    = AIUsageSummariesCompanion Function({
lib\core\database\database.g.dart:23691:  Value<double> estimatedCost,
lib\core\database\database.g.dart:23697:class $$AIUsageSummariesTableFilterComposer
lib\core\database\database.g.dart:23698:    extends Composer<_$AppDatabase, $AIUsageSummariesTable> {
lib\core\database\database.g.dart:23699:  $$AIUsageSummariesTableFilterComposer({
lib\core\database\database.g.dart:23755:  ColumnFilters<double> get estimatedCost => $composableBuilder(
lib\core\database\database.g.dart:23756:      column: $table.estimatedCost, builder: (column) => ColumnFilters(column));
lib\core\database\database.g.dart:23765:class $$AIUsageSummariesTableOrderingComposer
lib\core\database\database.g.dart:23766:    extends Composer<_$AppDatabase, $AIUsageSummariesTable> {
lib\core\database\database.g.dart:23767:  $$AIUsageSummariesTableOrderingComposer({
lib\core\database\database.g.dart:23826:  ColumnOrderings<double> get estimatedCost => $composableBuilder(
lib\core\database\database.g.dart:23827:      column: $table.estimatedCost,
lib\core\database\database.g.dart:23837:class $$AIUsageSummariesTableAnnotationComposer
lib\core\database\database.g.dart:23838:    extends Composer<_$AppDatabase, $AIUsageSummariesTable> {
lib\core\database\database.g.dart:23839:  $$AIUsageSummariesTableAnnotationComposer({
lib\core\database\database.g.dart:23891:  GeneratedColumn<double> get estimatedCost => $composableBuilder(
lib\core\database\database.g.dart:23892:      column: $table.estimatedCost, builder: (column) => column);
lib\core\database\database.g.dart:23901:class $$AIUsageSummariesTableTableManager extends RootTableManager<
lib\core\database\database.g.dart:23903:    $AIUsageSummariesTable,
lib\core\database\database.g.dart:23905:    $$AIUsageSummariesTableFilterComposer,
lib\core\database\database.g.dart:23906:    $$AIUsageSummariesTableOrderingComposer,
lib\core\database\database.g.dart:23907:    $$AIUsageSummariesTableAnnotationComposer,
lib\core\database\database.g.dart:23908:    $$AIUsageSummariesTableCreateCompanionBuilder,
lib\core\database\database.g.dart:23909:    $$AIUsageSummariesTableUpdateCompanionBuilder,
lib\core\database\database.g.dart:23912:      BaseReferences<_$AppDatabase, $AIUsageSummariesTable, AIUsageSummary>
lib\core\database\database.g.dart:23916:  $$AIUsageSummariesTableTableManager(
lib\core\database\database.g.dart:23917:      _$AppDatabase db, $AIUsageSummariesTable table)
lib\core\database\database.g.dart:23922:              $$AIUsageSummariesTableFilterComposer($db: db, $table: table),
lib\core\database\database.g.dart:23924:              $$AIUsageSummariesTableOrderingComposer($db: db, $table: table),
lib\core\database\database.g.dart:23926:              $$AIUsageSummariesTableAnnotationComposer($db: db, $table: table),
lib\core\database\database.g.dart:23943:            Value<double> estimatedCost = const Value.absent(),
lib\core\database\database.g.dart:23948:              AIUsageSummariesCompanion(
lib\core\database\database.g.dart:23964:            estimatedCost: estimatedCost,
lib\core\database\database.g.dart:23985:            Value<double> estimatedCost = const Value.absent(),
lib\core\database\database.g.dart:23990:              AIUsageSummariesCompanion.insert(
lib\core\database\database.g.dart:24006:            estimatedCost: estimatedCost,
lib\core\database\database.g.dart:24018:typedef $$AIUsageSummariesTableProcessedTableManager = ProcessedTableManager<
lib\core\database\database.g.dart:24020:    $AIUsageSummariesTable,
lib\core\database\database.g.dart:24022:    $$AIUsageSummariesTableFilterComposer,
lib\core\database\database.g.dart:24023:    $$AIUsageSummariesTableOrderingComposer,
lib\core\database\database.g.dart:24024:    $$AIUsageSummariesTableAnnotationComposer,
lib\core\database\database.g.dart:24025:    $$AIUsageSummariesTableCreateCompanionBuilder,
lib\core\database\database.g.dart:24026:    $$AIUsageSummariesTableUpdateCompanionBuilder,
lib\core\database\database.g.dart:24029:      BaseReferences<_$AppDatabase, $AIUsageSummariesTable, AIUsageSummary>
lib\core\database\database.g.dart:24484:  $$AIUsageRecordsTableTableManager get aIUsageRecords =>
lib\core\database\database.g.dart:24485:      $$AIUsageRecordsTableTableManager(_db, _db.aIUsageRecords);
lib\core\database\database.g.dart:24486:  $$AIUsageSummariesTableTableManager get aIUsageSummaries =>
lib\core\database\database.g.dart:24487:      $$AIUsageSummariesTableTableManager(_db, _db.aIUsageSummaries);
lib\core\database\database.dart:46:    AIUsageRecords,
lib\core\database\database.dart:47:    AIUsageSummaries,
lib\core\services\ai\models\provider_config.g.dart:20:      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 30,
lib\core\services\ai\models\provider_config.g.dart:21:      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
lib\core\services\ai\models\provider_config.g.dart:40:      'timeoutSeconds': instance.timeoutSeconds,
lib\core\services\ai\models\provider_config.g.dart:41:      'maxRetries': instance.maxRetries,
lib\core\services\ai\models\provider_config.freezed.dart:30:  int get timeoutSeconds => throw _privateConstructorUsedError;
lib\core\services\ai\models\provider_config.freezed.dart:31:  int get maxRetries => throw _privateConstructorUsedError;
lib\core\services\ai\models\provider_config.freezed.dart:55:      int timeoutSeconds,
lib\core\services\ai\models\provider_config.freezed.dart:56:      int maxRetries,
lib\core\services\ai\models\provider_config.freezed.dart:81:    Object? timeoutSeconds = null,
lib\core\services\ai\models\provider_config.freezed.dart:82:    Object? maxRetries = null,
lib\core\services\ai\models\provider_config.freezed.dart:112:      timeoutSeconds: null == timeoutSeconds
lib\core\services\ai\models\provider_config.freezed.dart:113:          ? _value.timeoutSeconds
lib\core\services\ai\models\provider_config.freezed.dart:114:          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\models\provider_config.freezed.dart:116:      maxRetries: null == maxRetries
lib\core\services\ai\models\provider_config.freezed.dart:117:          ? _value.maxRetries
lib\core\services\ai\models\provider_config.freezed.dart:118:          : maxRetries // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\models\provider_config.freezed.dart:151:      int timeoutSeconds,
lib\core\services\ai\models\provider_config.freezed.dart:152:      int maxRetries,
lib\core\services\ai\models\provider_config.freezed.dart:175:    Object? timeoutSeconds = null,
lib\core\services\ai\models\provider_config.freezed.dart:176:    Object? maxRetries = null,
lib\core\services\ai\models\provider_config.freezed.dart:206:      timeoutSeconds: null == timeoutSeconds
lib\core\services\ai\models\provider_config.freezed.dart:207:          ? _value.timeoutSeconds
lib\core\services\ai\models\provider_config.freezed.dart:208:          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\models\provider_config.freezed.dart:210:      maxRetries: null == maxRetries
lib\core\services\ai\models\provider_config.freezed.dart:211:          ? _value.maxRetries
lib\core\services\ai\models\provider_config.freezed.dart:212:          : maxRetries // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\models\provider_config.freezed.dart:240:      this.timeoutSeconds = 30,
lib\core\services\ai\models\provider_config.freezed.dart:241:      this.maxRetries = 3,
lib\core\services\ai\models\provider_config.freezed.dart:276:  final int timeoutSeconds;
lib\core\services\ai\models\provider_config.freezed.dart:279:  final int maxRetries;
lib\core\services\ai\models\provider_config.freezed.dart:290:    return 'ProviderConfig(id: $id, type: $type, name: $name, apiKey: $apiKey, apiEndpoint: $apiEndpoint, headers: $headers, timeoutSeconds: $timeoutSeconds, maxRetries: $maxRetries, isEnabled: $isEnabled, createdAt: $createdAt, updatedAt: $updatedAt)';
lib\core\services\ai\models\provider_config.freezed.dart:305:            (identical(other.timeoutSeconds, timeoutSeconds) ||
lib\core\services\ai\models\provider_config.freezed.dart:306:                other.timeoutSeconds == timeoutSeconds) &&
lib\core\services\ai\models\provider_config.freezed.dart:307:            (identical(other.maxRetries, maxRetries) ||
lib\core\services\ai\models\provider_config.freezed.dart:308:                other.maxRetries == maxRetries) &&
lib\core\services\ai\models\provider_config.freezed.dart:327:      timeoutSeconds,
lib\core\services\ai\models\provider_config.freezed.dart:328:      maxRetries,
lib\core\services\ai\models\provider_config.freezed.dart:356:      final int timeoutSeconds,
lib\core\services\ai\models\provider_config.freezed.dart:357:      final int maxRetries,
lib\core\services\ai\models\provider_config.freezed.dart:379:  int get timeoutSeconds;
lib\core\services\ai\models\provider_config.freezed.dart:381:  int get maxRetries;
lib\core\services\ai\models\provider_config.dart:22:    @Default(30) int timeoutSeconds,
lib\core\services\ai\models\provider_config.dart:23:    @Default(3) int maxRetries,
lib\features\work\presentation\pages\work_list_page.dart:172:                child: Text(s.work_retry),
lib\core\services\ai\cache\cache_manager.dart:204:        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
lib\core\services\ai\cache\cache_manager.dart:208:          prev[j - 1] + cost,
lib\core\services\ai\ai_service.dart:416:    final record = AIUsageRecordsCompanion.insert(
lib\core\services\ai\ai_service.dart:483:        AIUsageSummariesCompanion(
lib\core\services\ai\ai_service.dart:515:          AIUsageSummariesCompanion.insert(
lib\core\services\ai\ai_service.dart:566:  Future<List<AIUsageSummary>> getAIUsageSummaries({
lib\core\services\ai\ai_service.dart:596:    final summaries = await getAIUsageSummaries(
lib\core\services\ai\ai_service.dart:617:      entry['totalCost'] += summary.estimatedCost;
lib\features\work\presentation\pages\search_page.dart:239:                child: Text(s.work_retry),
lib\features\statistics\data\statistics_service.dart:668:    final summaries = await aiService.getAIUsageSummaries(
lib\features\statistics\data\statistics_service.dart:676:      'date,modelId,tier,functionType,requestCount,successCount,errorCount,cachedCount,totalTokens,avgResponseTimeMs,estimatedCost',
lib\features\statistics\data\statistics_service.dart:680:        '${summary.date.toIso8601String()},${_csvValue(summary.modelId)},${_csvValue(summary.tier)},${_csvValue(summary.functionType ?? 'all')},${summary.requestCount},${summary.successCount},${summary.errorCount},${summary.cachedCount},${summary.totalTokens},${summary.avgResponseTimeMs},${summary.estimatedCost.toStringAsFixed(4)}',
lib\core\models\value_objects\token_usage.dart:38:    required double estimatedCost,
lib\core\models\value_objects\token_usage.freezed.dart:203:  double get estimatedCost => throw _privateConstructorUsedError;
lib\core\models\value_objects\token_usage.freezed.dart:222:      double estimatedCost,
lib\core\models\value_objects\token_usage.freezed.dart:243:    Object? estimatedCost = null,
lib\core\models\value_objects\token_usage.freezed.dart:260:      estimatedCost: null == estimatedCost
lib\core\models\value_objects\token_usage.freezed.dart:261:          ? _value.estimatedCost
lib\core\models\value_objects\token_usage.freezed.dart:262:          : estimatedCost // ignore: cast_nullable_to_non_nullable
lib\core\models\value_objects\token_usage.freezed.dart:288:      double estimatedCost,
lib\core\models\value_objects\token_usage.freezed.dart:307:    Object? estimatedCost = null,
lib\core\models\value_objects\token_usage.freezed.dart:324:      estimatedCost: null == estimatedCost
lib\core\models\value_objects\token_usage.freezed.dart:325:          ? _value.estimatedCost
lib\core\models\value_objects\token_usage.freezed.dart:326:          : estimatedCost // ignore: cast_nullable_to_non_nullable
lib\core\models\value_objects\token_usage.freezed.dart:347:      required this.estimatedCost,
lib\core\models\value_objects\token_usage.freezed.dart:360:  final double estimatedCost;
lib\core\models\value_objects\token_usage.freezed.dart:379:    return 'TokenUsageStats(totalInputTokens: $totalInputTokens, totalOutputTokens: $totalOutputTokens, requestCount: $requestCount, estimatedCost: $estimatedCost, byFunction: $byFunction, byModel: $byModel)';
lib\core\models\value_objects\token_usage.freezed.dart:393:            (identical(other.estimatedCost, estimatedCost) ||
lib\core\models\value_objects\token_usage.freezed.dart:394:                other.estimatedCost == estimatedCost) &&
lib\core\models\value_objects\token_usage.freezed.dart:406:      estimatedCost,
lib\core\models\value_objects\token_usage.freezed.dart:423:      required final double estimatedCost,
lib\core\models\value_objects\token_usage.freezed.dart:434:  double get estimatedCost;

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "rg -n \"timeoutSeconds|maxRetries|effectiveEndpoint|replaceAll\\(|onStreamChunk|generateStream\\(|complete\\(\" lib/core/services/ai lib/features/ai_config" in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/database/tables/ai_usage.dart' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'rg -n "getAIUsageStatistics|getApiCallHistory|getConfigChangeHistory|logApiCall|logConfigChange|saveModelConfig|testConnection" lib/features/ai_config lib/core/services/ai' in C:\Users\changw98\dev\writing_assistant
 succeeded in 133ms:
import 'package:drift/drift.dart';

/// AI浣跨敤缁熻琛?@DataClassName('AIUsageRecord')
class AIUsageRecords extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable()(); // 鍏宠仈浣滃搧ID锛屽彲鑳戒负绌?  TextColumn get functionType => text()(); // AI鍔熻兘绫诲瀷
  TextColumn get modelId => text()(); // 浣跨敤鐨勬ā鍨婭D
  TextColumn get tier => text()(); // 妯″瀷灞傜骇 thinking/middle/fast
  TextColumn get status => text()(); // success/error/cached
  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
  IntColumn get responseTimeMs => integer().withDefault(const Constant(0))(); // 鍝嶅簲鏃堕棿锛堟绉掞級
  TextColumn get errorMessage => text().nullable()(); // 閿欒淇℃伅
  TextColumn get requestId => text().nullable()(); // 璇锋眰ID锛堢敤浜庤拷韪級
  BoolColumn get fromCache => boolean().withDefault(const Constant(false))();
  TextColumn get metadata => text().nullable()(); // JSON鍏冩暟鎹?  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {requestId}, // requestId搴旇鏄敮涓€鐨?      ];
}

/// AI浣跨敤缁熻姹囨€昏〃锛堟寜鏃ユ湡鍜屾ā鍨嬫眹鎬伙級
@DataClassName('AIUsageSummary')
class AIUsageSummaries extends Table {
  TextColumn get id => text()();
  TextColumn get workId => text().nullable()();
  TextColumn get modelId => text()();
  TextColumn get tier => text()();
  TextColumn get functionType => text().nullable()(); // 涓簄ull琛ㄧず鎵€鏈夊姛鑳?  DateTimeColumn get date => dateTime()(); // 缁熻鏃ユ湡
  IntColumn get requestCount => integer().withDefault(const Constant(0))();
  IntColumn get successCount => integer().withDefault(const Constant(0))();
  IntColumn get errorCount => integer().withDefault(const Constant(0))();
  IntColumn get cachedCount => integer().withDefault(const Constant(0))();
  IntColumn get totalInputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalOutputTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
  IntColumn get totalResponseTimeMs => integer().withDefault(const Constant(0))();
  IntColumn get avgResponseTimeMs => integer().withDefault(const Constant(0))();
  RealColumn get estimatedCost => real().withDefault(const Constant(0))(); // 棰勪及鎴愭湰
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>>? get uniqueKeys => [
        {workId, modelId, functionType, date}, // 纭繚姣忓ぉ姣忎釜妯″瀷鍙湁涓€涓眹鎬昏褰?      ];
}

 succeeded in 186ms:
lib/core/services/ai\providers\ai_provider.dart:16:  Future<AIResponse> complete({
lib/core/services/ai\providers\ai_provider.dart:24:    void Function(String)? onStreamChunk,
lib/core/services/ai\providers\anthropic_provider.dart:23:        '${config.effectiveEndpoint}/messages',
lib/core/services/ai\providers\anthropic_provider.dart:42:  Future<AIResponse> complete({
lib/core/services/ai\providers\anthropic_provider.dart:50:    void Function(String)? onStreamChunk,
lib/core/services/ai\providers\anthropic_provider.dart:66:      if (stream && onStreamChunk != null) {
lib/core/services/ai\providers\anthropic_provider.dart:72:          onStreamChunk: onStreamChunk,
lib/core/services/ai\providers\anthropic_provider.dart:77:        '${config.effectiveEndpoint}/messages',
lib/core/services/ai\providers\anthropic_provider.dart:110:    required void Function(String) onStreamChunk,
lib/core/services/ai\providers\anthropic_provider.dart:113:      '${config.effectiveEndpoint}/messages',
lib/core/services/ai\providers\anthropic_provider.dart:144:              onStreamChunk(textChunk);
lib/core/services/ai\ai_service.dart:64:    void Function(String)? onStreamChunk,
lib/core/services/ai\ai_service.dart:197:      final response = await provider.complete(
lib/core/services/ai\ai_service.dart:251:  Stream<String> generateStream({
lib/core/services/ai\ai_service.dart:286:            .complete(
lib/core/services/ai\ai_service.dart:294:              onStreamChunk: (chunk) {
lib/core/services/ai\ai_service.dart:296:                config.onStreamChunk?.call(chunk);
lib/core/services/ai\ai_service.dart:390:        result = result.replaceAll('{$key}', value.toString());
lib/core/services/ai\providers\azure_openai_provider.dart:36:  Future<AIResponse> complete({
lib/core/services/ai\providers\azure_openai_provider.dart:44:    void Function(String)? onStreamChunk,
lib/core/services/ai\providers\azure_openai_provider.dart:98:    final base = config.effectiveEndpoint;
lib/core/services/ai\providers\custom_provider.dart:20:        '${config.effectiveEndpoint}/models',
lib/core/services/ai\providers\custom_provider.dart:30:  Future<AIResponse> complete({
lib/core/services/ai\providers\custom_provider.dart:38:    void Function(String)? onStreamChunk,
lib/core/services/ai\providers\custom_provider.dart:42:      '${config.effectiveEndpoint}/chat/completions',
lib/core/services/ai\providers\custom_provider.dart:84:        '${config.effectiveEndpoint}/models',
lib/core/services/ai\ai_service.freezed.dart:312:  void Function(String)? get onStreamChunk =>
lib/core/services/ai\ai_service.freezed.dart:337:      void Function(String)? onStreamChunk});
lib/core/services/ai\ai_service.freezed.dart:363:    Object? onStreamChunk = freezed,
lib/core/services/ai\ai_service.freezed.dart:406:      onStreamChunk: freezed == onStreamChunk
lib/core/services/ai\ai_service.freezed.dart:407:          ? _value.onStreamChunk
lib/core/services/ai\ai_service.freezed.dart:408:          : onStreamChunk // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\ai_service.freezed.dart:433:      void Function(String)? onStreamChunk});
lib/core/services/ai\ai_service.freezed.dart:457:    Object? onStreamChunk = freezed,
lib/core/services/ai\ai_service.freezed.dart:500:      onStreamChunk: freezed == onStreamChunk
lib/core/services/ai\ai_service.freezed.dart:501:          ? _value.onStreamChunk
lib/core/services/ai\ai_service.freezed.dart:502:          : onStreamChunk // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\ai_service.freezed.dart:522:      this.onStreamChunk})
lib/core/services/ai\ai_service.freezed.dart:557:  final void Function(String)? onStreamChunk;
lib/core/services/ai\ai_service.freezed.dart:561:    return 'AIRequestConfig(function: $function, systemPrompt: $systemPrompt, userPrompt: $userPrompt, variables: $variables, overrideTier: $overrideTier, overrideModelId: $overrideModelId, useCache: $useCache, stream: $stream, temperature: $temperature, maxTokens: $maxTokens, onStreamChunk: $onStreamChunk)';
lib/core/services/ai\ai_service.freezed.dart:588:            (identical(other.onStreamChunk, onStreamChunk) ||
lib/core/services/ai\ai_service.freezed.dart:589:                other.onStreamChunk == onStreamChunk));
lib/core/services/ai\ai_service.freezed.dart:605:      onStreamChunk);
lib/core/services/ai\ai_service.freezed.dart:627:      final void Function(String)? onStreamChunk}) = _$AIRequestConfigImpl;
lib/core/services/ai\ai_service.freezed.dart:650:  void Function(String)? get onStreamChunk;
lib/core/services/ai\providers\ollama_provider.dart:22:      final response = await _dio.get('${config.effectiveEndpoint}/tags');
lib/core/services/ai\providers\ollama_provider.dart:30:  Future<AIResponse> complete({
lib/core/services/ai\providers\ollama_provider.dart:38:    void Function(String)? onStreamChunk,
lib/core/services/ai\providers\ollama_provider.dart:55:      if (stream && onStreamChunk != null) {
lib/core/services/ai\providers\ollama_provider.dart:61:          onStreamChunk: onStreamChunk,
lib/core/services/ai\providers\ollama_provider.dart:66:        '${config.effectiveEndpoint}/chat',
lib/core/services/ai\providers\ollama_provider.dart:97:    required void Function(String) onStreamChunk,
lib/core/services/ai\providers\ollama_provider.dart:100:      '${config.effectiveEndpoint}/chat',
lib/core/services/ai\providers\ollama_provider.dart:120:            onStreamChunk(content);
lib/core/services/ai\providers\ollama_provider.dart:150:      final response = await _dio.get('${config.effectiveEndpoint}/tags');
lib/core/services/ai\providers\openai_provider.dart:24:        '${config.effectiveEndpoint}/models',
lib/core/services/ai\providers\openai_provider.dart:39:  Future<AIResponse> complete({
lib/core/services/ai\providers\openai_provider.dart:47:    void Function(String)? onStreamChunk,
lib/core/services/ai\providers\openai_provider.dart:68:      if (stream && onStreamChunk != null) {
lib/core/services/ai\providers\openai_provider.dart:74:          onStreamChunk: onStreamChunk,
lib/core/services/ai\providers\openai_provider.dart:79:        '${config.effectiveEndpoint}/chat/completions',
lib/core/services/ai\providers\openai_provider.dart:120:    required void Function(String) onStreamChunk,
lib/core/services/ai\providers\openai_provider.dart:123:      '${config.effectiveEndpoint}/chat/completions',
lib/core/services/ai\providers\openai_provider.dart:160:                onStreamChunk(content);
lib/core/services/ai\providers\openai_provider.dart:199:        '${config.effectiveEndpoint}/models',
lib/core/services/ai\models\prompt_template.dart:34:      result = result.replaceAll('{{${entry.key}}}', entry.value.toString());
lib/core/services/ai\models\provider_config.dart:22:    @Default(30) int timeoutSeconds,
lib/core/services/ai\models\provider_config.dart:23:    @Default(3) int maxRetries,
lib/core/services/ai\models\provider_config.dart:33:  String get effectiveEndpoint {
lib/core/services/ai\models\provider_config.g.dart:20:      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 30,
lib/core/services/ai\models\provider_config.g.dart:21:      maxRetries: (json['maxRetries'] as num?)?.toInt() ?? 3,
lib/core/services/ai\models\provider_config.g.dart:40:      'timeoutSeconds': instance.timeoutSeconds,
lib/core/services/ai\models\provider_config.g.dart:41:      'maxRetries': instance.maxRetries,
lib/core/services/ai\models\provider_config.freezed.dart:30:  int get timeoutSeconds => throw _privateConstructorUsedError;
lib/core/services/ai\models\provider_config.freezed.dart:31:  int get maxRetries => throw _privateConstructorUsedError;
lib/core/services/ai\models\provider_config.freezed.dart:55:      int timeoutSeconds,
lib/core/services/ai\models\provider_config.freezed.dart:56:      int maxRetries,
lib/core/services/ai\models\provider_config.freezed.dart:81:    Object? timeoutSeconds = null,
lib/core/services/ai\models\provider_config.freezed.dart:82:    Object? maxRetries = null,
lib/core/services/ai\models\provider_config.freezed.dart:112:      timeoutSeconds: null == timeoutSeconds
lib/core/services/ai\models\provider_config.freezed.dart:113:          ? _value.timeoutSeconds
lib/core/services/ai\models\provider_config.freezed.dart:114:          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\models\provider_config.freezed.dart:116:      maxRetries: null == maxRetries
lib/core/services/ai\models\provider_config.freezed.dart:117:          ? _value.maxRetries
lib/core/services/ai\models\provider_config.freezed.dart:118:          : maxRetries // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\models\provider_config.freezed.dart:151:      int timeoutSeconds,
lib/core/services/ai\models\provider_config.freezed.dart:152:      int maxRetries,
lib/core/services/ai\models\provider_config.freezed.dart:175:    Object? timeoutSeconds = null,
lib/core/services/ai\models\provider_config.freezed.dart:176:    Object? maxRetries = null,
lib/core/services/ai\models\provider_config.freezed.dart:206:      timeoutSeconds: null == timeoutSeconds
lib/core/services/ai\models\provider_config.freezed.dart:207:          ? _value.timeoutSeconds
lib/core/services/ai\models\provider_config.freezed.dart:208:          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\models\provider_config.freezed.dart:210:      maxRetries: null == maxRetries
lib/core/services/ai\models\provider_config.freezed.dart:211:          ? _value.maxRetries
lib/core/services/ai\models\provider_config.freezed.dart:212:          : maxRetries // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\models\provider_config.freezed.dart:240:      this.timeoutSeconds = 30,
lib/core/services/ai\models\provider_config.freezed.dart:241:      this.maxRetries = 3,
lib/core/services/ai\models\provider_config.freezed.dart:276:  final int timeoutSeconds;
lib/core/services/ai\models\provider_config.freezed.dart:279:  final int maxRetries;
lib/core/services/ai\models\provider_config.freezed.dart:290:    return 'ProviderConfig(id: $id, type: $type, name: $name, apiKey: $apiKey, apiEndpoint: $apiEndpoint, headers: $headers, timeoutSeconds: $timeoutSeconds, maxRetries: $maxRetries, isEnabled: $isEnabled, createdAt: $createdAt, updatedAt: $updatedAt)';
lib/core/services/ai\models\provider_config.freezed.dart:305:            (identical(other.timeoutSeconds, timeoutSeconds) ||
lib/core/services/ai\models\provider_config.freezed.dart:306:                other.timeoutSeconds == timeoutSeconds) &&
lib/core/services/ai\models\provider_config.freezed.dart:307:            (identical(other.maxRetries, maxRetries) ||
lib/core/services/ai\models\provider_config.freezed.dart:308:                other.maxRetries == maxRetries) &&
lib/core/services/ai\models\provider_config.freezed.dart:327:      timeoutSeconds,
lib/core/services/ai\models\provider_config.freezed.dart:328:      maxRetries,
lib/core/services/ai\models\provider_config.freezed.dart:356:      final int timeoutSeconds,
lib/core/services/ai\models\provider_config.freezed.dart:357:      final int maxRetries,
lib/core/services/ai\models\provider_config.freezed.dart:379:  int get timeoutSeconds;
lib/core/services/ai\models\provider_config.freezed.dart:381:  int get maxRetries;

 succeeded in 173ms:
lib/core/services/ai\ai_service.dart:537:  Future<List<AIUsageRecord>> getAIUsageStatistics({
lib/features/ai_config\data\ai_config_repository.dart:84:  Future<void> saveModelConfig({
lib/features/ai_config\data\ai_config_repository.dart:112:  Future<bool> testConnection(ModelTier tier) async {
lib/features/ai_config\data\ai_config_repository.dart:414:  Future<void> logApiCall({
lib/features/ai_config\data\ai_config_repository.dart:445:  Future<void> logConfigChange({
lib/features/ai_config\data\ai_config_repository.dart:473:  Future<List<Map<String, dynamic>>> getApiCallHistory({
lib/features/ai_config\data\ai_config_repository.dart:486:  Future<List<Map<String, dynamic>>> getConfigChangeHistory({
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:50:                  onPressed: () => _testConnection(context),
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:64:  Future<void> _testConnection(BuildContext context) async {
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:82:      final result = await repository.testConnection(tier);
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:228:    await repository.saveModelConfig(
lib/features/ai_config\presentation\pages\usage_stats_page.dart:124:      final records = await aiService.getAIUsageStatistics(
lib/features/ai_config\presentation\pages\usage_stats_page.dart:539:      final records = await aiService.getAIUsageStatistics(

2026-04-06T04:55:43.000762Z ERROR codex_core::tools::router: error=Exit code: 1
Wall time: 0.2 seconds
Output:
lib/features/ai_config/data/ai_config_repository.dart:23:  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
lib/features/ai_config/data/ai_config_repository.dart:24:    aOptions: AndroidOptions(encryptedSharedPreferences: true),
lib/features/ai_config/data/ai_config_repository.dart:30:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:35:    final apiEndpoint = prefs.getString('${key}_endpoint');
lib/features/ai_config/data/ai_config_repository.dart:93:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:96:    // 保存配置到 SharedPreferences
lib/features/ai_config/data/ai_config_repository.dart:100:      await prefs.setString('${key}_endpoint', apiEndpoint);
lib/features/ai_config/data/ai_config_repository.dart:307:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:353:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:421:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:451:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:476:    final prefs = await SharedPreferences.getInstance();
lib/features/ai_config/data/ai_config_repository.dart:489:    final prefs = await SharedPreferences.getInstance();
lib/core/services/ai/cache/cache_manager.dart:12:  final double _semanticSimilarityThreshold;
lib/core/services/ai/cache/cache_manager.dart:17:    double semanticSimilarityThreshold = 0.95,
lib/core/services/ai/cache/cache_manager.dart:20:        _semanticSimilarityThreshold = semanticSimilarityThreshold;
lib/core/services/ai/cache/cache_manager.dart:29:  final List<SemanticCacheEntry> _semanticCache = [];
lib/core/services/ai/cache/cache_manager.dart:40:    return md5.convert(utf8.encode(content)).toString();
lib/core/services/ai/cache/cache_manager.dart:113:    for (final entry in _semanticCache) {
lib/core/services/ai/cache/cache_manager.dart:115:          entry.similarity(prompt) >= _semanticSimilarityThreshold &&
lib/core/services/ai/cache/cache_manager.dart:127:    _semanticCache.removeWhere((entry) => entry.entry.isExpired);
lib/core/services/ai/cache/cache_manager.dart:134:    _semanticCache.clear();
lib/core/services/ai/cache/cache_manager.dart:148:        l3Count: _semanticCache.length,
lib/core/services/ai/cache/cache_manager.dart:187:    // 使用 Levenshtein 距离的简化版本
lib/core/services/ai/ai_service.dart:11:import 'cache/cache_manager.dart';
lib/core/services/ai/ai_service.dart:61:    @Default(true) bool stream,
lib/core/services/ai/ai_service.dart:112:class AIService extends getx.GetxController {
lib/core/services/ai/ai_service.dart:113:  final PromptCacheManager _cacheManager;
lib/core/services/ai/ai_service.dart:119:    : _cacheManager = PromptCacheManager(),
lib/core/services/ai/ai_service.dart:127:    _providerRegistry.register(OpenAIProvider());
lib/core/services/ai/ai_service.dart:128:    _providerRegistry.register(AnthropicProvider());
lib/core/services/ai/ai_service.dart:129:    _providerRegistry.register(OllamaProvider());
lib/core/services/ai/ai_service.dart:130:    _providerRegistry.register(AzureOpenAIProvider());
lib/core/services/ai/ai_service.dart:131:    _providerRegistry.register(CustomProvider());
lib/core/services/ai/ai_service.dart:145:      final cached = _cacheManager.find(
lib/core/services/ai/ai_service.dart:153:      if (cached != null) {
lib/core/services/ai/ai_service.dart:155:        await _recordAIUsage(
lib/core/services/ai/ai_service.dart:160:          inputTokens: cached.inputTokens ?? 0,
lib/core/services/ai/ai_service.dart:161:          outputTokens: cached.outputTokens ?? 0,
lib/core/services/ai/ai_service.dart:166:          content: cached.response,
lib/core/services/ai/ai_service.dart:167:          inputTokens: cached.inputTokens ?? 0,
lib/core/services/ai/ai_service.dart:168:          outputTokens: cached.outputTokens ?? 0,
lib/core/services/ai/ai_service.dart:183:    final provider = _providerRegistry.get(
lib/core/services/ai/ai_service.dart:197:      final response = await provider.complete(
lib/core/services/ai/ai_service.dart:204:        stream: false,
lib/core/services/ai/ai_service.dart:208:        _cacheManager.store(
lib/core/services/ai/ai_service.dart:221:      await _recordAIUsage(
lib/core/services/ai/ai_service.dart:236:      await _recordAIUsage(
lib/core/services/ai/ai_service.dart:267:    final provider = _providerRegistry.get(
lib/core/services/ai/ai_service.dart:286:            .complete(
lib/core/services/ai/ai_service.dart:293:              stream: true,
lib/core/services/ai/ai_service.dart:302:              final tokens = await provider.countTokens(
lib/core/services/ai/ai_service.dart:307:                _cacheManager.store(
lib/core/services/ai/ai_service.dart:319:              await _recordAIUsage(
lib/core/services/ai/ai_service.dart:332:              await _recordAIUsage(
lib/core/services/ai/ai_service.dart:348:      yield* controller.stream;
lib/core/services/ai/ai_service.dart:390:        result = result.replaceAll('{$key}', value.toString());
lib/core/services/ai/ai_service.dart:397:    _cacheManager.clear();
lib/core/services/ai/ai_service.dart:400:  CacheStats get cacheStats => _cacheManager.stats;
lib/core/services/ai/ai_service.dart:402:  Future<void> _recordAIUsage({
lib/core/services/ai/ai_service.dart:416:    final record = AIUsageRecordsCompanion.insert(
lib/core/services/ai/ai_service.dart:476:            .get();
lib/core/services/ai/ai_service.dart:483:        AIUsageSummariesCompanion(
lib/core/services/ai/ai_service.dart:493:          cachedCount: Value(
lib/core/services/ai/ai_service.dart:494:            fromCache ? summary.cachedCount + 1 : summary.cachedCount,
lib/core/services/ai/ai_service.dart:515:          AIUsageSummariesCompanion.insert(
lib/core/services/ai/ai_service.dart:525:            cachedCount: Value(fromCache ? 1 : 0),
lib/core/services/ai/ai_service.dart:537:  Future<List<AIUsageRecord>> getAIUsageStatistics({
lib/core/services/ai/ai_service.dart:563:    return query.get();
lib/core/services/ai/ai_service.dart:566:  Future<List<AIUsageSummary>> getAIUsageSummaries({
lib/core/services/ai/ai_service.dart:588:    return query.get();
lib/core/services/ai/ai_service.dart:596:    final summaries = await getAIUsageSummaries(
lib/core/database\database.dart:15:import 'tables/ai_usage.dart';
lib/core/database\database.dart:46:    AIUsageRecords,
lib/core/database\database.dart:47:    AIUsageSummaries,
lib/core/database\tables\ai_usage.dart:4:@DataClassName('AIUsageRecord')
lib/core/database\tables\ai_usage.dart:5:class AIUsageRecords extends Table {
lib/core/database\tables\ai_usage.dart:11:  TextColumn get status => text()(); // success/error/cached
lib/core/database\tables\ai_usage.dart:32:@DataClassName('AIUsageSummary')
lib/core/database\tables\ai_usage.dart:33:class AIUsageSummaries extends Table {
lib/core/database\tables\ai_usage.dart:43:  IntColumn get cachedCount => integer().withDefault(const Constant(0))();
rg: lib/core/services/ai/providers/*.dart: 文件名、目录名或卷标语法不正确。 (os error 123)

codex
I’m checking one more branch before I write findings: whether the UI/repository validates user-entered endpoints at all, and whether any config/history paths can end up persisting secrets or raw error payloads locally. Those two details separate “theoretical risk” from “actually reachable risk” in this app.
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "rg -n \"endpoint|apiKey|apikey|oldValue|newValue|errorMessage|metadata|requestId|saveModelConfig\\(|logConfigChange\\(|logApiCall\\(\" lib/features/ai_config lib/core/services/ai lib/features/statistics" in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/features/ai_config/presentation/widgets/ai_config_page_sections.dart' in C:\Users\changw98\dev\writing_assistant
 succeeded in 165ms:
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../data/ai_config_repository.dart';
import '../../domain/model_config.dart';
import 'ai_config_form_sections.dart';

class AITierConfigCard extends StatelessWidget {
  final ModelTier tier;

  const AITierConfigCard({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AIConfigCopy.of(context);

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: tier.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(tier.icon, color: tier.color),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(tier.description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _testConnection(context),
                  icon: Icon(Icons.wifi_find, size: 18.sp),
                  label: Text(s.aiConfig_test),
                ),
              ],
            ),
            const Divider(height: 24),
            AIModelConfigForm(tier: tier),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection(BuildContext context) async {
    final s = AIConfigCopy.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            SizedBox(width: 16.w),
            Text(s.aiConfig_testingConnection),
          ],
        ),
      ),
    );

    try {
      final repository = Get.find<AIConfigRepository>();
      final result = await repository.testConnection(tier);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result
                  ? s.aiConfig_connectionSuccess
                  : s.aiConfig_connectionFailed,
            ),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.aiConfig_testFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class AIModelConfigForm extends StatefulWidget {
  final ModelTier tier;

  const AIModelConfigForm({super.key, required this.tier});

  @override
  State<AIModelConfigForm> createState() => _AIModelConfigFormState();
}

class _AIModelConfigFormState extends State<AIModelConfigForm> {
  late TextEditingController _modelController;
  late TextEditingController _endpointController;
  late TextEditingController _apiKeyController;
  late double _temperature;
  late int _maxTokens;

  String _providerType = 'openai';

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _temperature = 0.7;
    _maxTokens = 4096;
    _loadConfig();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final repository = Get.find<AIConfigRepository>();
    final config = await repository.getModelConfig(widget.tier);
    if (config != null && mounted) {
      setState(() {
        _providerType = config.providerType;
        _modelController.text = config.modelName;
        _endpointController.text = config.apiEndpoint ?? '';
        _temperature = config.temperature;
        _maxTokens = config.maxOutputTokens;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProviderTypeDropdown(
          value: _providerType,
          onChanged: (value) {
            setState(() {
              _providerType = value ?? 'openai';
              if (value == 'openai') {
                _endpointController.text = 'https://api.openai.com/v1';
              } else if (value == 'anthropic') {
                _endpointController.text = 'https://api.anthropic.com/v1';
              } else if (value == 'ollama') {
                _endpointController.text = 'http://localhost:11434/api';
              }
            });
          },
        ),
        SizedBox(height: 16.h),
        ConfigTextField(
          controller: _endpointController,
          labelText: s.aiConfig_apiEndpoint,
          hintText: 'https://api.openai.com/v1',
        ),
        SizedBox(height: 16.h),
        ConfigTextField(
          controller: _apiKeyController,
          labelText: s.aiConfig_apiKey,
          obscureText: true,
          suffixIcon: const Icon(Icons.visibility_off),
        ),
        SizedBox(height: 16.h),
        ConfigTextField(
          controller: _modelController,
          labelText: s.aiConfig_modelName,
          hintText: 'gpt-4 / claude-3-opus / qwen2.5:14b',
        ),
        SizedBox(height: 16.h),
        AdvancedParamsSection(
          temperature: _temperature,
          maxTokens: _maxTokens,
          onTemperatureChanged: (value) {
            setState(() => _temperature = value);
          },
          onMaxTokensChanged: (value) {
            setState(() => _maxTokens = value);
          },
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
            label: Text(s.aiConfig_saveConfig),
          ),
        ),
      ],
    );
  }

  Future<void> _saveConfig() async {
    final repository = Get.find<AIConfigRepository>();
    await repository.saveModelConfig(
      tier: widget.tier,
      providerType: _providerType,
      modelName: _modelController.text,
      apiEndpoint: _endpointController.text,
      apiKey: _apiKeyController.text,
      temperature: _temperature,
      maxOutputTokens: _maxTokens,
    );

    if (mounted) {
      final s = AIConfigCopy.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.aiConfig_configSaved)));
    }
  }
}

class AIFunctionMappingCard extends StatelessWidget {
  final AIFunction function;
  final FunctionMapping mapping;

  const AIFunctionMappingCard({
    super.key,
    required this.function,
    required this.mapping,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(function.icon),
        title: Text(function.label),
        subtitle: Text(function.description),
        trailing: DropdownButton<ModelTier>(
          value: mapping.useOverride && mapping.overrideTier != null
              ? mapping.overrideTier
              : function.defaultTier,
          items: ModelTier.values.map((tier) {
            return DropdownMenuItem(
              value: tier,
              child: Row(
                children: [
                  Icon(tier.icon, size: 16.sp, color: tier.color),
                  SizedBox(width: 8.w),
                  Text(tier.displayName),
                ],
              ),
            );
          }).toList(),
          onChanged: (tier) {
            if (tier != null) {
              _updateMapping(tier);
            }
          },
        ),
      ),
    );
  }

  void _updateMapping(ModelTier tier) {
    final repository = Get.find<AIConfigRepository>();
    repository.updateFunctionMapping(functionKey: function.key, tier: tier);
  }
}

class AIPromptTemplateCard extends StatelessWidget {
  final PromptTemplate template;

  const AIPromptTemplateCard({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ExpansionTile(
        leading: Icon(template.icon),
        title: Text(template.name),
        subtitle: Text(template.description),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.aiConfig_systemPrompt,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    template.systemPrompt,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 16.h),
                PromptTemplateActions(onEdit: () {}, onCopy: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AIUsageStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AIUsageStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class AIPromptTemplateEditorDialog extends StatefulWidget {
  const AIPromptTemplateEditorDialog({super.key});

  @override
  State<AIPromptTemplateEditorDialog> createState() =>
      _AIPromptTemplateEditorDialogState();
}

class _AIPromptTemplateEditorDialogState
    extends State<AIPromptTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _userPromptController = TextEditingController();
  String _selectedIcon = 'edit_note';

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    _userPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    final availableIcons = <Map<String, dynamic>>[
      {
        'name': 'edit_note',
        'icon': Icons.edit_note,
        'label': s.aiConfig_icon_edit,
      },
      {'name': 'chat', 'icon': Icons.chat, 'label': s.aiConfig_icon_chat},
      {'name': 'person', 'icon': Icons.person, 'label': s.aiConfig_icon_person},
      {
        'name': 'rate_review',
        'icon': Icons.rate_review,
        'label': s.aiConfig_icon_review,
      },
      {
        'name': 'extract',
        'icon': Icons.input,
        'label': s.aiConfig_icon_extract,
      },
      {
        'name': 'check_circle',
        'icon': Icons.check_circle,
        'label': s.aiConfig_icon_check,
      },
      {
        'name': 'timeline',
        'icon': Icons.timeline,
        'label': s.aiConfig_icon_timeline,
      },
      {
        'name': 'warning',
        'icon': Icons.warning,
        'label': s.aiConfig_icon_warning,
      },
      {
        'name': 'summarize',
        'icon': Icons.summarize,
        'label': s.aiConfig_icon_summarize,
      },
      {
        'name': 'visibility',
        'icon': Icons.visibility,
        'label': s.aiConfig_icon_visibility,
      },
    ];

    return AlertDialog(
      title: Text(s.aiConfig_newPromptTemplate),
      content: SizedBox(
        width: 600.w,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: s.aiConfig_templateId,
                    hintText: s.aiConfig_templateIdHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true
                      ? s.aiConfig_error_validation_templateId
                      : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: s.aiConfig_templateName,
                    hintText: s.aiConfig_templateNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true
                      ? s.aiConfig_error_validation_templateName
                      : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: s.aiConfig_description,
                    hintText: s.aiConfig_descriptionHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 16.h),
                DropdownButtonFormField<String>(
                  initialValue: _selectedIcon,
                  decoration: InputDecoration(
                    labelText: s.aiConfig_icon,
                    border: const OutlineInputBorder(),
                  ),
                  items: availableIcons.map((iconData) {
                    return DropdownMenuItem(
                      value: iconData['name'] as String,
                      child: Row(
                        children: [
                          Icon(iconData['icon'] as IconData),
                          SizedBox(width: 8.w),
                          Text(iconData['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedIcon = value);
                    }
                  },
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _systemPromptController,
                  decoration: InputDecoration(
                    labelText: s.aiConfig_systemPromptLabel,
                    hintText: s.aiConfig_systemPromptHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  validator: (value) => value?.isEmpty ?? true
                      ? s.aiConfig_error_validation_systemPrompt
                      : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _userPromptController,
                  decoration: InputDecoration(
                    labelText: s.aiConfig_userPromptTemplate,
                    hintText: s.aiConfig_userPromptTemplateHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.aiConfig_cancel),
        ),
        FilledButton(onPressed: _saveTemplate, child: Text(s.aiConfig_save)),
      ],
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final template = PromptTemplate(
      id: _idController.text,
      name: _nameController.text,
      description: _descriptionController.text,
      systemPrompt: _systemPromptController.text,
      userPromptTemplate: _userPromptController.text.isEmpty
          ? null
          : _userPromptController.text,
      iconName: _selectedIcon,
      createdAt: DateTime.now(),
    );

    final repository = Get.find<AIConfigRepository>();
    await repository.savePromptTemplate(template);

    if (mounted) {
      final s = AIConfigCopy.of(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.aiConfig_templateSaved)));
    }
  }
}

 succeeded in 194ms:
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:122:  late TextEditingController _endpointController;
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:123:  late TextEditingController _apiKeyController;
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:133:    _endpointController = TextEditingController();
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:134:    _apiKeyController = TextEditingController();
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:143:    _endpointController.dispose();
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:144:    _apiKeyController.dispose();
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:155:        _endpointController.text = config.apiEndpoint ?? '';
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:174:                _endpointController.text = 'https://api.openai.com/v1';
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:176:                _endpointController.text = 'https://api.anthropic.com/v1';
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:178:                _endpointController.text = 'http://localhost:11434/api';
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:185:          controller: _endpointController,
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:191:          controller: _apiKeyController,
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:192:          labelText: s.aiConfig_apiKey,
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:228:    await repository.saveModelConfig(
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:232:      apiEndpoint: _endpointController.text,
lib/features/ai_config\presentation\widgets\ai_config_page_sections.dart:233:      apiKey: _apiKeyController.text,
lib/features/ai_config\presentation\widgets\ai_config_form_sections.dart:26:      : 'Configure models, endpoints, and parameters for each capability tier.';
lib/features/ai_config\presentation\widgets\ai_config_form_sections.dart:52:  String get aiConfig_apiKey => 'API Key';
lib/core/services/ai\providers\openai_provider.dart:27:            'Authorization': 'Bearer ${config.apiKey}',
lib/core/services/ai\providers\openai_provider.dart:83:            'Authorization': 'Bearer ${config.apiKey}',
lib/core/services/ai\providers\openai_provider.dart:104:        requestId: data['id'] as String?,
lib/core/services/ai\providers\openai_provider.dart:127:          'Authorization': 'Bearer ${config.apiKey}',
lib/core/services/ai\providers\openai_provider.dart:139:    String? requestId;
lib/core/services/ai\providers\openai_provider.dart:152:            requestId ??= json['id'] as String?;
lib/core/services/ai\providers\openai_provider.dart:183:      requestId: requestId,
lib/core/services/ai\providers\openai_provider.dart:202:            'Authorization': 'Bearer ${config.apiKey}',
lib/core/services/ai\providers\custom_provider.dart:69:      requestId: data['id'] as String?,
lib/core/services/ai\providers\custom_provider.dart:101:      if (config.apiKey != null && config.apiKey!.isNotEmpty)
lib/core/services/ai\providers\custom_provider.dart:102:        'Authorization': 'Bearer ${config.apiKey}',
lib/core/services/ai\ai_service.freezed.dart:25:  String? get requestId => throw _privateConstructorUsedError;
lib/core/services/ai\ai_service.freezed.dart:26:  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
lib/core/services/ai\ai_service.freezed.dart:46:      String? requestId,
lib/core/services/ai\ai_service.freezed.dart:47:      Map<String, dynamic>? metadata});
lib/core/services/ai\ai_service.freezed.dart:69:    Object? requestId = freezed,
lib/core/services/ai\ai_service.freezed.dart:70:    Object? metadata = freezed,
lib/core/services/ai\ai_service.freezed.dart:97:      requestId: freezed == requestId
lib/core/services/ai\ai_service.freezed.dart:98:          ? _value.requestId
lib/core/services/ai\ai_service.freezed.dart:99:          : requestId // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\ai_service.freezed.dart:101:      metadata: freezed == metadata
lib/core/services/ai\ai_service.freezed.dart:102:          ? _value.metadata
lib/core/services/ai\ai_service.freezed.dart:103:          : metadata // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\ai_service.freezed.dart:124:      String? requestId,
lib/core/services/ai\ai_service.freezed.dart:125:      Map<String, dynamic>? metadata});
lib/core/services/ai\ai_service.freezed.dart:145:    Object? requestId = freezed,
lib/core/services/ai\ai_service.freezed.dart:146:    Object? metadata = freezed,
lib/core/services/ai\ai_service.freezed.dart:173:      requestId: freezed == requestId
lib/core/services/ai\ai_service.freezed.dart:174:          ? _value.requestId
lib/core/services/ai\ai_service.freezed.dart:175:          : requestId // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\ai_service.freezed.dart:177:      metadata: freezed == metadata
lib/core/services/ai\ai_service.freezed.dart:178:          ? _value._metadata
lib/core/services/ai\ai_service.freezed.dart:179:          : metadata // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\ai_service.freezed.dart:195:      this.requestId,
lib/core/services/ai\ai_service.freezed.dart:196:      final Map<String, dynamic>? metadata})
lib/core/services/ai\ai_service.freezed.dart:197:      : _metadata = metadata;
lib/core/services/ai\ai_service.freezed.dart:212:  final String? requestId;
lib/core/services/ai\ai_service.freezed.dart:213:  final Map<String, dynamic>? _metadata;
lib/core/services/ai\ai_service.freezed.dart:215:  Map<String, dynamic>? get metadata {
lib/core/services/ai\ai_service.freezed.dart:216:    final value = _metadata;
lib/core/services/ai\ai_service.freezed.dart:218:    if (_metadata is EqualUnmodifiableMapView) return _metadata;
lib/core/services/ai\ai_service.freezed.dart:225:    return 'AIResponse(content: $content, inputTokens: $inputTokens, outputTokens: $outputTokens, modelId: $modelId, responseTime: $responseTime, fromCache: $fromCache, requestId: $requestId, metadata: $metadata)';
lib/core/services/ai\ai_service.freezed.dart:243:            (identical(other.requestId, requestId) ||
lib/core/services/ai\ai_service.freezed.dart:244:                other.requestId == requestId) &&
lib/core/services/ai\ai_service.freezed.dart:245:            const DeepCollectionEquality().equals(other._metadata, _metadata));
lib/core/services/ai\ai_service.freezed.dart:257:      requestId,
lib/core/services/ai\ai_service.freezed.dart:258:      const DeepCollectionEquality().hash(_metadata));
lib/core/services/ai\ai_service.freezed.dart:275:      final String? requestId,
lib/core/services/ai\ai_service.freezed.dart:276:      final Map<String, dynamic>? metadata}) = _$AIResponseImpl;
lib/core/services/ai\ai_service.freezed.dart:291:  String? get requestId;
lib/core/services/ai\ai_service.freezed.dart:293:  Map<String, dynamic>? get metadata;
lib/core/services/ai\providers\azure_openai_provider.dart:73:      requestId: data['id'] as String?,
lib/core/services/ai\providers\azure_openai_provider.dart:91:      'api-key': config.apiKey ?? '',
lib/core/services/ai\ai_service.dart:46:    String? requestId,
lib/core/services/ai\ai_service.dart:47:    Map<String, dynamic>? metadata,
lib/core/services/ai\ai_service.dart:229:        requestId: response.requestId,
lib/core/services/ai\ai_service.dart:231:        metadata: response.metadata,
lib/core/services/ai\ai_service.dart:244:        errorMessage: error.toString(),
lib/core/services/ai\ai_service.dart:340:                errorMessage: error.toString(),
lib/core/services/ai\ai_service.dart:410:    String? errorMessage,
lib/core/services/ai\ai_service.dart:411:    String? requestId,
lib/core/services/ai\ai_service.dart:414:    Map<String, dynamic>? metadata,
lib/core/services/ai\ai_service.dart:427:      errorMessage: Value(errorMessage),
lib/core/services/ai\ai_service.dart:428:      requestId: Value(requestId),
lib/core/services/ai\ai_service.dart:430:      metadata: Value(metadata?.toString()),
lib/core/services/ai\providers\anthropic_provider.dart:94:        requestId: data['id'] as String?,
lib/core/services/ai\providers\anthropic_provider.dart:123:    String? requestId;
lib/core/services/ai\providers\anthropic_provider.dart:137:          requestId ??= data['id'] as String?;
lib/core/services/ai\providers\anthropic_provider.dart:162:      requestId: requestId,
lib/core/services/ai\providers\anthropic_provider.dart:184:      'x-api-key': config.apiKey ?? '',
lib/core/services/ai\models\provider_config.dart:19:    String? apiKey,          // 加密存储
lib/core/services/ai\models\provider_config.freezed.dart:26:  String? get apiKey => throw _privateConstructorUsedError; // 加密存储
lib/core/services/ai\models\provider_config.freezed.dart:52:      String? apiKey,
lib/core/services/ai\models\provider_config.freezed.dart:78:    Object? apiKey = freezed,
lib/core/services/ai\models\provider_config.freezed.dart:100:      apiKey: freezed == apiKey
lib/core/services/ai\models\provider_config.freezed.dart:101:          ? _value.apiKey
lib/core/services/ai\models\provider_config.freezed.dart:102:          : apiKey // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\models\provider_config.freezed.dart:148:      String? apiKey,
lib/core/services/ai\models\provider_config.freezed.dart:172:    Object? apiKey = freezed,
lib/core/services/ai\models\provider_config.freezed.dart:194:      apiKey: freezed == apiKey
lib/core/services/ai\models\provider_config.freezed.dart:195:          ? _value.apiKey
lib/core/services/ai\models\provider_config.freezed.dart:196:          : apiKey // ignore: cast_nullable_to_non_nullable
lib/core/services/ai\models\provider_config.freezed.dart:237:      this.apiKey,
lib/core/services/ai\models\provider_config.freezed.dart:258:  final String? apiKey;
lib/core/services/ai\models\provider_config.freezed.dart:290:    return 'ProviderConfig(id: $id, type: $type, name: $name, apiKey: $apiKey, apiEndpoint: $apiEndpoint, headers: $headers, timeoutSeconds: $timeoutSeconds, maxRetries: $maxRetries, isEnabled: $isEnabled, createdAt: $createdAt, updatedAt: $updatedAt)';
lib/core/services/ai\models\provider_config.freezed.dart:301:            (identical(other.apiKey, apiKey) || other.apiKey == apiKey) &&
lib/core/services/ai\models\provider_config.freezed.dart:324:      apiKey,
lib/core/services/ai\models\provider_config.freezed.dart:353:      final String? apiKey,
lib/core/services/ai\models\provider_config.freezed.dart:373:  String? get apiKey;
lib/features/ai_config\data\ai_config_repository.dart:35:    final apiEndpoint = prefs.getString('${key}_endpoint');
lib/features/ai_config\data\ai_config_repository.dart:84:  Future<void> saveModelConfig({
lib/features/ai_config\data\ai_config_repository.dart:89:    String? apiKey,
lib/features/ai_config\data\ai_config_repository.dart:100:      await prefs.setString('${key}_endpoint', apiEndpoint);
lib/features/ai_config\data\ai_config_repository.dart:106:    if (apiKey != null && apiKey.isNotEmpty) {
lib/features/ai_config\data\ai_config_repository.dart:107:      await _secureStorage.write(key: '${key}_apikey', value: apiKey);
lib/features/ai_config\data\ai_config_repository.dart:121:      final apiKey = await _getApiKey(tier);
lib/features/ai_config\data\ai_config_repository.dart:125:      if (requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
lib/features/ai_config\data\ai_config_repository.dart:132:          return await _testOpenAIConnection(apiKey ?? '', config);
lib/features/ai_config\data\ai_config_repository.dart:134:          return await _testAnthropicConnection(apiKey ?? '', config);
lib/features/ai_config\data\ai_config_repository.dart:136:          return await _testAzureConnection(apiKey ?? '', config);
lib/features/ai_config\data\ai_config_repository.dart:140:          return await _testCustomConnection(apiKey ?? '', config);
lib/features/ai_config\data\ai_config_repository.dart:153:      return await _secureStorage.read(key: '${key}_apikey');
lib/features/ai_config\data\ai_config_repository.dart:160:  Future<bool> _testOpenAIConnection(String apiKey, ModelConfig config) async {
lib/features/ai_config\data\ai_config_repository.dart:165:          apiKey: apiKey,
lib/features/ai_config\data\ai_config_repository.dart:177:    String apiKey,
lib/features/ai_config\data\ai_config_repository.dart:184:          apiKey: apiKey,
lib/features/ai_config\data\ai_config_repository.dart:195:  Future<bool> _testAzureConnection(String apiKey, ModelConfig config) async {
lib/features/ai_config\data\ai_config_repository.dart:200:          apiKey: apiKey,
lib/features/ai_config\data\ai_config_repository.dart:216:          apiKey: '',
lib/features/ai_config\data\ai_config_repository.dart:227:  Future<bool> _testCustomConnection(String apiKey, ModelConfig config) async {
lib/features/ai_config\data\ai_config_repository.dart:232:          apiKey: apiKey,
lib/features/ai_config\data\ai_config_repository.dart:286:    final apiKey = await _getApiKey(tier);
lib/features/ai_config\data\ai_config_repository.dart:288:      apiKey: apiKey ?? '',
lib/features/ai_config\data\ai_config_repository.dart:414:  Future<void> logApiCall({
lib/features/ai_config\data\ai_config_repository.dart:445:  Future<void> logConfigChange({
lib/features/ai_config\data\ai_config_repository.dart:448:    required Map<String, dynamic> oldValue,
lib/features/ai_config\data\ai_config_repository.dart:449:    required Map<String, dynamic> newValue,
lib/features/ai_config\data\ai_config_repository.dart:458:      'oldValue': oldValue,
lib/features/ai_config\data\ai_config_repository.dart:459:      'newValue': newValue,
lib/features/ai_config\data\ai_config_repository.dart:499:    required String apiKey,
lib/features/ai_config\data\ai_config_repository.dart:507:      apiKey: apiKey,
lib/core/services/ai\models\provider_config.g.dart:14:      apiKey: json['apiKey'] as String?,
lib/core/services/ai\models\provider_config.g.dart:37:      'apiKey': instance.apiKey,

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "rg -n \"overrideModelId|getFunctionMappings\\(|updateFunctionMapping\\(|mapping_\" lib" in C:\Users\changw98\dev\writing_assistant
 succeeded in 174ms:
lib\features\ai_config\presentation\widgets\ai_config_page_sections.dart:293:    repository.updateFunctionMapping(functionKey: function.key, tier: tier);
lib\features\ai_config\presentation\pages\ai_config_page.dart:156:      final mappings = await repository.getFunctionMappings();
lib\features\ai_config\data\ai_config_repository.dart:295:  Future<List<FunctionMapping>> getFunctionMappings() async {
lib\features\ai_config\data\ai_config_repository.dart:303:  Future<void> updateFunctionMapping({
lib\features\ai_config\data\ai_config_repository.dart:308:    final key = '${_keyPrefix}mapping_$functionKey';
lib\core\services\ai\ai_service.dart:59:    String? overrideModelId,
lib\core\services\ai\ai_service.freezed.dart:307:  String? get overrideModelId => throw _privateConstructorUsedError;
lib\core\services\ai\ai_service.freezed.dart:332:      String? overrideModelId,
lib\core\services\ai\ai_service.freezed.dart:358:    Object? overrideModelId = freezed,
lib\core\services\ai\ai_service.freezed.dart:386:      overrideModelId: freezed == overrideModelId
lib\core\services\ai\ai_service.freezed.dart:387:          ? _value.overrideModelId
lib\core\services\ai\ai_service.freezed.dart:388:          : overrideModelId // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\ai_service.freezed.dart:428:      String? overrideModelId,
lib\core\services\ai\ai_service.freezed.dart:452:    Object? overrideModelId = freezed,
lib\core\services\ai\ai_service.freezed.dart:480:      overrideModelId: freezed == overrideModelId
lib\core\services\ai\ai_service.freezed.dart:481:          ? _value.overrideModelId
lib\core\services\ai\ai_service.freezed.dart:482:          : overrideModelId // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\ai_service.freezed.dart:517:      this.overrideModelId,
lib\core\services\ai\ai_service.freezed.dart:544:  final String? overrideModelId;
lib\core\services\ai\ai_service.freezed.dart:561:    return 'AIRequestConfig(function: $function, systemPrompt: $systemPrompt, userPrompt: $userPrompt, variables: $variables, overrideTier: $overrideTier, overrideModelId: $overrideModelId, useCache: $useCache, stream: $stream, temperature: $temperature, maxTokens: $maxTokens, onStreamChunk: $onStreamChunk)';
lib\core\services\ai\ai_service.freezed.dart:579:            (identical(other.overrideModelId, overrideModelId) ||
lib\core\services\ai\ai_service.freezed.dart:580:                other.overrideModelId == overrideModelId) &&
lib\core\services\ai\ai_service.freezed.dart:600:      overrideModelId,
lib\core\services\ai\ai_service.freezed.dart:622:      final String? overrideModelId,
lib\core\services\ai\ai_service.freezed.dart:640:  String? get overrideModelId;
lib\core\services\ai\models\provider_config.dart:48:    String? overrideModelId,      // 覆盖默认层级，使用指定模型
lib\core\services\ai\models\provider_config.freezed.dart:401:  String? get overrideModelId =>
lib\core\services\ai\models\provider_config.freezed.dart:417:  $Res call({String functionKey, String? overrideModelId, bool useOverride});
lib\core\services\ai\models\provider_config.freezed.dart:434:    Object? overrideModelId = freezed,
lib\core\services\ai\models\provider_config.freezed.dart:442:      overrideModelId: freezed == overrideModelId
lib\core\services\ai\models\provider_config.freezed.dart:443:          ? _value.overrideModelId
lib\core\services\ai\models\provider_config.freezed.dart:444:          : overrideModelId // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\models\provider_config.freezed.dart:462:  $Res call({String functionKey, String? overrideModelId, bool useOverride});
lib\core\services\ai\models\provider_config.freezed.dart:477:    Object? overrideModelId = freezed,
lib\core\services\ai\models\provider_config.freezed.dart:485:      overrideModelId: freezed == overrideModelId
lib\core\services\ai\models\provider_config.freezed.dart:486:          ? _value.overrideModelId
lib\core\services\ai\models\provider_config.freezed.dart:487:          : overrideModelId // ignore: cast_nullable_to_non_nullable
lib\core\services\ai\models\provider_config.freezed.dart:502:      this.overrideModelId,
lib\core\services\ai\models\provider_config.freezed.dart:513:  final String? overrideModelId;
lib\core\services\ai\models\provider_config.freezed.dart:521:    return 'FunctionMapping(functionKey: $functionKey, overrideModelId: $overrideModelId, useOverride: $useOverride)';
lib\core\services\ai\models\provider_config.freezed.dart:531:            (identical(other.overrideModelId, overrideModelId) ||
lib\core\services\ai\models\provider_config.freezed.dart:532:                other.overrideModelId == overrideModelId) &&
lib\core\services\ai\models\provider_config.freezed.dart:540:      Object.hash(runtimeType, functionKey, overrideModelId, useOverride);
lib\core\services\ai\models\provider_config.freezed.dart:560:      final String? overrideModelId,
lib\core\services\ai\models\provider_config.freezed.dart:570:  String? get overrideModelId;
lib\core\services\ai\models\provider_config.g.dart:59:      overrideModelId: json['overrideModelId'] as String?,
lib\core\services\ai\models\provider_config.g.dart:67:      'overrideModelId': instance.overrideModelId,

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command "rg -n \"Dio\\(|BaseOptions|connectTimeout|receiveTimeout|sendTimeout|InterceptorsWrapper|QueuedInterceptorsWrapper|retry\" lib/core/services/ai lib/features/ai_config" in C:\Users\changw98\dev\writing_assistant
 succeeded in 191ms:
lib/core/services/ai\providers\openai_provider.dart:18:  OpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();
lib/core/services/ai\providers\anthropic_provider.dart:17:  AnthropicProvider({Dio? dio}) : _dio = dio ?? Dio();
lib/core/services/ai\providers\ollama_provider.dart:17:  OllamaProvider({Dio? dio}) : _dio = dio ?? Dio();
lib/core/services/ai\providers\azure_openai_provider.dart:14:  AzureOpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();
lib/core/services/ai\providers\custom_provider.dart:14:  CustomProvider({Dio? dio}) : _dio = dio ?? Dio();
lib/features/ai_config\data\ai_config_repository.dart:162:      final provider = OpenAIProvider(dio: Dio());
lib/features/ai_config\data\ai_config_repository.dart:181:      final provider = AnthropicProvider(dio: Dio());
lib/features/ai_config\data\ai_config_repository.dart:197:      final provider = AzureOpenAIProvider(dio: Dio());
lib/features/ai_config\data\ai_config_repository.dart:213:      final provider = OllamaProvider(dio: Dio());
lib/features/ai_config\data\ai_config_repository.dart:229:      final provider = CustomProvider(dio: Dio());

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command 'Get-Content lib/core/services/ai/models/prompt_template.dart' in C:\Users\changw98\dev\writing_assistant
 succeeded in 134ms:
import 'package:freezed_annotation/freezed_annotation.dart';

part 'prompt_template.freezed.dart';
part 'prompt_template.g.dart';

/// Prompt 妯℃澘
/// 鏀寔鐢ㄦ埛鑷畾涔夊悇鍔熻兘鐨?Prompt
@freezed
class PromptTemplate with _$PromptTemplate {
  const PromptTemplate._();

  const factory PromptTemplate({
    required String id,
    required String functionType,   // 瀵瑰簲 AIFunction.key
    required String name,
    required String systemPrompt,
    required String userPromptTemplate,
    String? description,
    @Default([]) List<String> variables,  // 妯℃澘鍙橀噺鍒楄〃
    @Default(1) int version,
    @Default(false) bool isDefault,
    @Default(false) bool isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _PromptTemplate;

  factory PromptTemplate.fromJson(Map<String, dynamic> json) =>
      _$PromptTemplateFromJson(json);

  /// 娓叉煋妯℃澘
  String render(Map<String, dynamic> variables) {
    var result = userPromptTemplate;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value.toString());
    }
    return result;
  }

  /// 楠岃瘉妯℃澘鍙橀噺
  List<String> validateVariables(Map<String, dynamic> provided) {
    final missing = <String>[];
    for (final v in variables) {
      if (!provided.containsKey(v) || provided[v] == null) {
        missing.add(v);
      }
    }
    return missing;
  }
}

/// 瑙掕壊鎵紨 Prompt 鐢熸垚鍣?class CharacterPromptBuilder {
  /// 浠庤鑹叉。妗堢敓鎴愯鑹叉壆婕?Prompt
  static String buildCharacterPrompt({
    required String characterName,
    required String tier,
    String? mbti,
    Map<String, dynamic>? personality,
    String? speechStyle,
    String? coreValues,
    String? fears,
    String? desires,
    List<String>? behaviorPatterns,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('浣犵幇鍦ㄨ鎵紨瑙掕壊"$characterName"銆?);
    buffer.writeln();
    buffer.writeln('## 瑙掕壊鍩烘湰淇℃伅');
    buffer.writeln('- 瑙掕壊绛夌骇锛?tier');
    if (mbti != null) buffer.writeln('- MBTI浜烘牸锛?mbti');
    buffer.writeln();

    if (personality != null && personality.isNotEmpty) {
      buffer.writeln('## 鎬ф牸鐗硅川');
      if (personality['keywords'] != null) {
        buffer.writeln('- 鏍稿績鎬ф牸锛?{(personality['keywords'] as List).join('銆?)}');
      }
      if (coreValues != null) buffer.writeln('- 鏍稿績浠峰€艰锛?coreValues');
      if (fears != null) buffer.writeln('- 鎭愭儳锛?fears');
      if (desires != null) buffer.writeln('- 娓存湜锛?desires');
      buffer.writeln();
    }

    if (speechStyle != null) {
      buffer.writeln('## 璇磋瘽椋庢牸');
      buffer.writeln(speechStyle);
      buffer.writeln();
    }

    if (behaviorPatterns != null && behaviorPatterns.isNotEmpty) {
      buffer.writeln('## 琛屼负涔犳儻');
      for (final pattern in behaviorPatterns) {
        buffer.writeln('- $pattern');
      }
      buffer.writeln();
    }

    buffer.writeln('## 閲嶈瑙勫垯');
    buffer.writeln('1. 浣犲繀椤诲畬鍏ㄤ唬鍏ヨ繖涓鑹诧紝鐢ㄨ鑹茬殑瑙嗚鎬濊€冨拰鍥炲簲');
    buffer.writeln('2. 浣犵殑瑷€琛屽繀椤荤鍚堣鑹茬殑鎬ф牸銆佷环鍊艰鍜岃鐭ヨ寖鍥?);
    buffer.writeln('3. 涓嶈浣跨敤"浣滀负瑙掕壊X锛屾垜璁や负..."杩欑鍏冨彊浜嬭〃杈?);
    buffer.writeln('4. 涓嶈閫忛湶浣犳槸涓€涓狝I鎴栨鍦ㄦ壆婕旇鑹?);

    return buffer.toString();
  }
}

2026-04-06T04:56:26.585919Z ERROR codex_core::tools::router: error=Exit code: 1
Wall time: 0.7 seconds
Output:
Could not find a command named "-".

Usage: dart <command|dart-file> [arguments]

Global options:
-v, --verbose               Show additional command output.
    --version               Print the Dart SDK version.
    --enable-analytics      Enable analytics.
    --disable-analytics     Disable analytics.
    --suppress-analytics    Disallow analytics for this `dart *` run without changing the analytics configuration.
-h, --help                  Print this usage information.

Available commands:

Global
  install     Install or upgrade a Dart CLI tool for global use.
  installed   List globally installed Dart CLI tools.
  uninstall   Remove a globally installed Dart CLI tool.

Project
  build       Build a Dart application including code assets.
  compile     Compile Dart to various formats.
  create      Create a new Dart project.
  pub         Work with packages.
  run         Run a Dart program from a file or a local package.
  test        Run tests for a project.

Source code
  analyze     Analyze Dart code in a directory.
  doc         Generate API documentation for Dart projects.
  fix         Apply automated fixes to Dart source code.
  format      Idiomatically format Dart source code.

Tools
  devtools    Open DevTools (optionally connecting to an existing application).
  info        Show diagnostic information about the installed tooling.

Run "dart help <command>" for more information about a command.
See https://dart.dev/tools/dart-tool for detailed documentation.

codex
The main risk pattern is emerging pretty clearly: endpoint and provider settings are modeled as configurable, but the transport layer never actually consumes the timeout/retry controls and accepts raw endpoints. I’m pulling numbered snippets now so the review can point to exact failure sites instead of broad “could be improved” statements.
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/providers/ai_provider.dart'; "'$lines=Get-Content $path; for($i=1;$i -le $lines.Length;$i++){ '"'{0}:{1}' -f "'$i,$lines[$i-1] }' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/ai_service.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=100;e=170},@{s=180;e=245},@{s=250;e=350},@{s=385;e=450},@{s=596;e=620})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/models/provider_config.dart'; "'$lines=Get-Content $path; for($i=1;$i -le $lines.Length;$i++){ '"'{0}:{1}' -f "'$i,$lines[$i-1] }' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/features/ai_config/data/ai_config_repository.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=15;e=35},@{s=80;e=155},@{s=286;e=310},@{s=414;e=486},@{s=495;e=509})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
 succeeded in 155ms:
1:import 'dart:async';
2:
3:import '../ai_service.dart';
4:import '../models/model_config.dart';
5:import '../models/provider_config.dart';
6:
7:/// AI 渚涘簲鍟嗘娊璞℃帴鍙?abstract class AIProvider {
8:  /// 渚涘簲鍟嗙被鍨?  AIProviderType get type;
9:
10:  /// 楠岃瘉杩炴帴
11:  Future<bool> validateConnection(ProviderConfig config);
12:
13:  /// 鎵ц璇锋眰
14:  Future<AIResponse> complete({
15:    required ProviderConfig config,
16:    required ModelConfig model,
17:    required String systemPrompt,
18:    required String userPrompt,
19:    double? temperature,
20:    int? maxTokens,
21:    bool stream = false,
22:    void Function(String)? onStreamChunk,
23:  });
24:
25:  /// 浼扮畻 Token 鏁伴噺
26:  Future<int> countTokens(String text, String modelName);
27:
28:  /// 鑾峰彇鍙敤妯″瀷鍒楄〃锛堝鏋滀緵搴斿晢鏀寔锛?  Future<List<String>> getAvailableModels(ProviderConfig config);
29:}
30:
31:/// AI 渚涘簲鍟嗘敞鍐岃〃
32:class AIProviderRegistry {
33:  static final AIProviderRegistry _instance = AIProviderRegistry._();
34:  factory AIProviderRegistry() => _instance;
35:  AIProviderRegistry._();
36:
37:  final Map<AIProviderType, AIProvider> _providers = {};
38:
39:  void register(AIProvider provider) {
40:    _providers[provider.type] = provider;
41:  }
42:
43:  AIProvider? get(AIProviderType type) => _providers[type];
44:
45:  List<AIProviderType> get availableTypes => _providers.keys.toList();
46:}

 succeeded in 180ms:
100:  @override
101:  String toString() => 'AIException: $message';
102:}
103:
104:class TokenCountException extends AIException {
105:  const TokenCountException(int current, int max)
106:    : super(
107:        'Token count exceeds limit: $current > $max',
108:        code: 'TOKEN_LIMIT_EXCEEDED',
109:      );
110:}
111:
112:class AIService extends getx.GetxController {
113:  final PromptCacheManager _cacheManager;
114:  final AIProviderRegistry _providerRegistry;
115:  final AppDatabase _db;
116:  final Uuid _uuid;
117:
118:  AIService()
119:    : _cacheManager = PromptCacheManager(),
120:      _providerRegistry = AIProviderRegistry(),
121:      _db = getx.Get.find<AppDatabase>(),
122:      _uuid = const Uuid() {
123:    _registerDefaultProviders();
124:  }
125:
126:  void _registerDefaultProviders() {
127:    _providerRegistry.register(OpenAIProvider());
128:    _providerRegistry.register(AnthropicProvider());
129:    _providerRegistry.register(OllamaProvider());
130:    _providerRegistry.register(AzureOpenAIProvider());
131:    _providerRegistry.register(CustomProvider());
132:  }
133:
134:  Future<AIResponse> generate({
135:    required String prompt,
136:    required AIRequestConfig config,
137:  }) async {
138:    final stopwatch = Stopwatch()..start();
139:    final modelConfig = await _getModelConfig(config);
140:    if (modelConfig == null) {
141:      throw AIException('No model configured for ${config.function.key}');
142:    }
143:
144:    if (config.useCache) {
145:      final cached = _cacheManager.find(
146:        prompt,
147:        modelConfig.id,
148:        params: {
149:          'temperature': config.temperature,
150:          'maxTokens': config.maxTokens,
151:        },
152:      );
153:      if (cached != null) {
154:        stopwatch.stop();
155:        await _recordAIUsage(
156:          functionType: config.function.key,
157:          modelId: modelConfig.id,
158:          tier: modelConfig.tier.name,
159:          status: 'success',
160:          inputTokens: cached.inputTokens ?? 0,
161:          outputTokens: cached.outputTokens ?? 0,
162:          responseTimeMs: stopwatch.elapsed.inMilliseconds,
163:          fromCache: true,
164:        );
165:        return AIResponse(
166:          content: cached.response,
167:          inputTokens: cached.inputTokens ?? 0,
168:          outputTokens: cached.outputTokens ?? 0,
169:          modelId: modelConfig.id,
170:          responseTime: stopwatch.elapsed,
---
180:      );
181:    }
182:
183:    final provider = _providerRegistry.get(
184:      modelConfig.providerType.toProviderType(),
185:    );
186:    if (provider == null) {
187:      throw AIException(
188:        'No provider registered for ${modelConfig.providerType}',
189:      );
190:    }
191:
192:    final systemPrompt =
193:        config.systemPrompt ?? _getDefaultSystemPrompt(config.function);
194:    final userPrompt = _buildUserPrompt(prompt, config);
195:
196:    try {
197:      final response = await provider.complete(
198:        config: providerConfig,
199:        model: modelConfig,
200:        systemPrompt: systemPrompt,
201:        userPrompt: userPrompt,
202:        temperature: config.temperature,
203:        maxTokens: config.maxTokens,
204:        stream: false,
205:      );
206:
207:      if (config.useCache) {
208:        _cacheManager.store(
209:          prompt,
210:          modelConfig.id,
211:          response.content,
212:          params: {
213:            'temperature': config.temperature,
214:            'maxTokens': config.maxTokens,
215:          },
216:          inputTokens: response.inputTokens,
217:          outputTokens: response.outputTokens,
218:        );
219:      }
220:
221:      await _recordAIUsage(
222:        functionType: config.function.key,
223:        modelId: modelConfig.id,
224:        tier: modelConfig.tier.name,
225:        status: 'success',
226:        inputTokens: response.inputTokens,
227:        outputTokens: response.outputTokens,
228:        responseTimeMs: response.responseTime.inMilliseconds,
229:        requestId: response.requestId,
230:        fromCache: false,
231:        metadata: response.metadata,
232:      );
233:
234:      return response;
235:    } catch (error) {
236:      await _recordAIUsage(
237:        functionType: config.function.key,
238:        modelId: modelConfig.id,
239:        tier: modelConfig.tier.name,
240:        status: 'error',
241:        inputTokens: 0,
242:        outputTokens: 0,
243:        responseTimeMs: stopwatch.elapsed.inMilliseconds,
244:        errorMessage: error.toString(),
245:        fromCache: false,
---
250:
251:  Stream<String> generateStream({
252:    required String prompt,
253:    required AIRequestConfig config,
254:  }) async* {
255:    final modelConfig = await _getModelConfig(config);
256:    if (modelConfig == null) {
257:      throw AIException('No model configured for ${config.function.key}');
258:    }
259:
260:    final providerConfig = await _getProviderConfig(modelConfig);
261:    if (providerConfig == null) {
262:      throw AIException(
263:        'No provider config found for ${modelConfig.providerType}',
264:      );
265:    }
266:
267:    final provider = _providerRegistry.get(
268:      modelConfig.providerType.toProviderType(),
269:    );
270:    if (provider == null) {
271:      throw AIException(
272:        'No provider registered for ${modelConfig.providerType}',
273:      );
274:    }
275:
276:    final systemPrompt =
277:        config.systemPrompt ?? _getDefaultSystemPrompt(config.function);
278:    final userPrompt = _buildUserPrompt(prompt, config);
279:    final controller = StreamController<String>();
280:    final buffer = StringBuffer();
281:    final stopwatch = Stopwatch()..start();
282:
283:    try {
284:      unawaited(
285:        provider
286:            .complete(
287:              config: providerConfig,
288:              model: modelConfig,
289:              systemPrompt: systemPrompt,
290:              userPrompt: userPrompt,
291:              temperature: config.temperature,
292:              maxTokens: config.maxTokens,
293:              stream: true,
294:              onStreamChunk: (chunk) {
295:                buffer.write(chunk);
296:                config.onStreamChunk?.call(chunk);
297:                controller.add(chunk);
298:              },
299:            )
300:            .then((_) async {
301:              stopwatch.stop();
302:              final tokens = await provider.countTokens(
303:                buffer.toString(),
304:                modelConfig.modelName,
305:              );
306:              if (config.useCache) {
307:                _cacheManager.store(
308:                  prompt,
309:                  modelConfig.id,
310:                  buffer.toString(),
311:                  params: {
312:                    'temperature': config.temperature,
313:                    'maxTokens': config.maxTokens,
314:                  },
315:                  inputTokens: tokens,
316:                  outputTokens: tokens,
317:                );
318:              }
319:              await _recordAIUsage(
320:                functionType: config.function.key,
321:                modelId: modelConfig.id,
322:                tier: modelConfig.tier.name,
323:                status: 'success',
324:                inputTokens: tokens,
325:                outputTokens: tokens,
326:                responseTimeMs: stopwatch.elapsed.inMilliseconds,
327:                fromCache: false,
328:              );
329:              await controller.close();
330:            })
331:            .catchError((error) async {
332:              await _recordAIUsage(
333:                functionType: config.function.key,
334:                modelId: modelConfig.id,
335:                tier: modelConfig.tier.name,
336:                status: 'error',
337:                inputTokens: 0,
338:                outputTokens: 0,
339:                responseTimeMs: stopwatch.elapsed.inMilliseconds,
340:                errorMessage: error.toString(),
341:                fromCache: false,
342:              );
343:              controller.addError(error);
344:              controller.close();
345:            }),
346:      );
347:
348:      yield* controller.stream;
349:    } finally {
350:      await controller.close();
---
385:  String _buildUserPrompt(String prompt, AIRequestConfig config) {
386:    var result = prompt;
387:    final variables = config.variables;
388:    if (variables != null) {
389:      variables.forEach((key, value) {
390:        result = result.replaceAll('{$key}', value.toString());
391:      });
392:    }
393:    return result;
394:  }
395:
396:  void clearCache() {
397:    _cacheManager.clear();
398:  }
399:
400:  CacheStats get cacheStats => _cacheManager.stats;
401:
402:  Future<void> _recordAIUsage({
403:    required String functionType,
404:    required String modelId,
405:    required String tier,
406:    required String status,
407:    required int inputTokens,
408:    required int outputTokens,
409:    required int responseTimeMs,
410:    String? errorMessage,
411:    String? requestId,
412:    required bool fromCache,
413:    String? workId,
414:    Map<String, dynamic>? metadata,
415:  }) async {
416:    final record = AIUsageRecordsCompanion.insert(
417:      id: _uuid.v4(),
418:      workId: Value(workId),
419:      functionType: functionType,
420:      modelId: modelId,
421:      tier: tier,
422:      status: status,
423:      inputTokens: Value(inputTokens),
424:      outputTokens: Value(outputTokens),
425:      totalTokens: Value(inputTokens + outputTokens),
426:      responseTimeMs: Value(responseTimeMs),
427:      errorMessage: Value(errorMessage),
428:      requestId: Value(requestId),
429:      fromCache: Value(fromCache),
430:      metadata: Value(metadata?.toString()),
431:      createdAt: DateTime.now(),
432:    );
433:
434:    await _db.into(_db.aIUsageRecords).insert(record);
435:
436:    await _updateDailySummary(
437:      functionType: functionType,
438:      modelId: modelId,
439:      tier: tier,
440:      status: status,
441:      inputTokens: inputTokens,
442:      outputTokens: outputTokens,
443:      responseTimeMs: responseTimeMs,
444:      fromCache: fromCache,
445:      workId: workId,
446:    );
447:  }
448:
449:  Future<void> _updateDailySummary({
450:    required String functionType,
---
596:    final summaries = await getAIUsageSummaries(
597:      workId: workId,
598:      startDate: startDate,
599:      endDate: endDate,
600:    );
601:
602:    final result = <String, Map<String, dynamic>>{};
603:    for (final summary in summaries) {
604:      result.putIfAbsent(summary.modelId, () {
605:        return <String, dynamic>{
606:          'totalTokens': 0,
607:          'totalRequests': 0,
608:          'totalCost': 0.0,
609:          'avgResponseTime': 0,
610:          'tier': summary.tier,
611:        };
612:      });
613:
614:      final entry = result[summary.modelId]!;
615:      entry['totalTokens'] += summary.totalTokens;
616:      entry['totalRequests'] += summary.requestCount;
617:      entry['totalCost'] += summary.estimatedCost;
618:      entry['avgResponseTime'] =
619:          ((entry['avgResponseTime'] as int) + summary.avgResponseTimeMs) ~/ 2;
620:    }
---

 succeeded in 151ms:
1:import 'package:freezed_annotation/freezed_annotation.dart';
2:
3:import 'model_config.dart';
4:import 'model_tier.dart';
5:
6:part 'provider_config.freezed.dart';
7:part 'provider_config.g.dart';
8:
9:/// 渚涘簲鍟嗛厤缃?/// 瀛樺偍姣忎釜 AI 渚涘簲鍟嗙殑 API 鍑瘉鍜岃缃?@freezed
10:class ProviderConfig with _$ProviderConfig {
11:  const ProviderConfig._();
12:
13:  const factory ProviderConfig({
14:    required String id,
15:    required AIProviderType type,
16:    required String name,
17:    String? apiKey,          // 鍔犲瘑瀛樺偍
18:    String? apiEndpoint,     // 鑷畾涔夌鐐?    @Default({}) Map<String, String> headers,  // 鑷畾涔夎姹傚ご
19:    @Default(30) int timeoutSeconds,
20:    @Default(3) int maxRetries,
21:    @Default(true) bool isEnabled,
22:    DateTime? createdAt,
23:    DateTime? updatedAt,
24:  }) = _ProviderConfig;
25:
26:  factory ProviderConfig.fromJson(Map<String, dynamic> json) =>
27:      _$ProviderConfigFromJson(json);
28:
29:  /// 鑾峰彇瀹屾暣鐨?API 绔偣
30:  String get effectiveEndpoint {
31:    if (apiEndpoint != null && apiEndpoint!.isNotEmpty) {
32:      return apiEndpoint!;
33:    }
34:    return type.defaultEndpoint;
35:  }
36:}
37:
38:/// 鍔熻兘-妯″瀷鏄犲皠閰嶇疆
39:@freezed
40:class FunctionMapping with _$FunctionMapping {
41:  const FunctionMapping._();
42:
43:  const factory FunctionMapping({
44:    required String functionKey,  // 浣跨敤 key 鑰岄潪鏋氫妇
45:    String? overrideModelId,      // 瑕嗙洊榛樿灞傜骇锛屼娇鐢ㄦ寚瀹氭ā鍨?    @Default(false) bool useOverride, // 鏄惁浣跨敤瑕嗙洊
46:  }) = _FunctionMapping;
47:
48:  factory FunctionMapping.fromJson(Map<String, dynamic> json) =>
49:      _$FunctionMappingFromJson(json);
50:
51:  /// 鑾峰彇瀵瑰簲鐨?AIFunction
52:  AIFunction? get function => AIFunction.fromKey(functionKey);
53:
54:  /// 榛樿鏄犲皠
55:  static List<FunctionMapping> defaults() =>
56:      AIFunction.values.map((f) => FunctionMapping(functionKey: f.key)).toList();
57:}

 succeeded in 164ms:
15:import '../domain/model_config.dart';
16:
17:/// AI 閰嶇疆浠撳簱
18:class AIConfigRepository {
19:  static const String _keyPrefix = 'ai_config_';
20:  static const String _defaultLocalProviderType = 'custom';
21:  static const String _defaultLocalModelName = 'google/gemma-4-26b-a4b';
22:  static const String _defaultLocalEndpoint = 'http://127.0.0.1:1234/v1';
23:  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
24:    aOptions: AndroidOptions(encryptedSharedPreferences: true),
25:    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
26:  );
27:
28:  /// 鑾峰彇妯″瀷閰嶇疆
29:  Future<ModelConfig?> getModelConfig(ModelTier tier) async {
30:    final prefs = await SharedPreferences.getInstance();
31:    final key = '${_keyPrefix}model_${tier.name}';
32:
33:    final providerType = prefs.getString('${key}_provider');
34:    final modelName = prefs.getString('${key}_model');
35:    final apiEndpoint = prefs.getString('${key}_endpoint');
---
80:    );
81:  }
82:
83:  /// 淇濆瓨妯″瀷閰嶇疆
84:  Future<void> saveModelConfig({
85:    required ModelTier tier,
86:    required String providerType,
87:    required String modelName,
88:    String? apiEndpoint,
89:    String? apiKey,
90:    double temperature = 0.7,
91:    int maxOutputTokens = 4096,
92:  }) async {
93:    final prefs = await SharedPreferences.getInstance();
94:    final key = '${_keyPrefix}model_${tier.name}';
95:
96:    // 淇濆瓨閰嶇疆鍒?SharedPreferences
97:    await prefs.setString('${key}_provider', providerType);
98:    await prefs.setString('${key}_model', modelName);
99:    if (apiEndpoint != null) {
100:      await prefs.setString('${key}_endpoint', apiEndpoint);
101:    }
102:    await prefs.setDouble('${key}_temperature', temperature);
103:    await prefs.setInt('${key}_max_tokens', maxOutputTokens);
104:
105:    // API Key 浣跨敤 flutter_secure_storage 瀹夊叏瀛樺偍
106:    if (apiKey != null && apiKey.isNotEmpty) {
107:      await _secureStorage.write(key: '${key}_apikey', value: apiKey);
108:    }
109:  }
110:
111:  /// 娴嬭瘯杩炴帴
112:  Future<bool> testConnection(ModelTier tier) async {
113:    try {
114:      // 鑾峰彇璇ュ眰绾х殑閰嶇疆
115:      final config = await getModelConfig(tier);
116:      if (config == null) {
117:        return false;
118:      }
119:
120:      // 浠庡畨鍏ㄥ瓨鍌ㄤ腑璇诲彇 API Key
121:      final apiKey = await _getApiKey(tier);
122:      final providerType = config.providerType.toLowerCase();
123:      final requiresApiKey =
124:          providerType != 'ollama' && providerType != 'custom';
125:      if (requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
126:        return false;
127:      }
128:
129:      // 鏍规嵁鎻愪緵鍟嗙被鍨嬫祴璇曡繛鎺?      switch (config.providerType.toLowerCase()) {
130:        case 'openai':
131:          return await _testOpenAIConnection(apiKey ?? '', config);
132:        case 'anthropic':
133:          return await _testAnthropicConnection(apiKey ?? '', config);
134:        case 'azure':
135:          return await _testAzureConnection(apiKey ?? '', config);
136:        case 'ollama':
137:          return await _testOllamaConnection(config);
138:        case 'custom':
139:          return await _testCustomConnection(apiKey ?? '', config);
140:        default:
141:          return false;
142:      }
143:    } catch (_) {
144:      return false;
145:    }
146:  }
147:
148:  /// 浠庡畨鍏ㄥ瓨鍌ㄨ幏鍙?API Key
149:  Future<String?> _getApiKey(ModelTier tier) async {
150:    final key = '${_keyPrefix}model_${tier.name}';
151:    try {
152:      return await _secureStorage.read(key: '${key}_apikey');
153:    } catch (_) {
154:      return null;
155:    }
---
286:      config: config,
287:      type: _toCoreProviderType(config.providerType),
288:    );
289:  }
290:
291:  /// 鑾峰彇鍔熻兘鏄犲皠鍒楄〃
292:  Future<List<FunctionMapping>> getFunctionMappings() async {
293:    // 杩斿洖榛樿鏄犲皠
294:    return AIFunction.values
295:        .map((f) => FunctionMapping(functionKey: f.key))
296:        .toList();
297:  }
298:
299:  /// 鏇存柊鍔熻兘鏄犲皠
300:  Future<void> updateFunctionMapping({
301:    required String functionKey,
302:    required ModelTier tier,
303:  }) async {
304:    final prefs = await SharedPreferences.getInstance();
305:    final key = '${_keyPrefix}mapping_$functionKey';
306:    await prefs.setString(key, tier.name);
307:  }
308:
309:  /// 鑾峰彇 Prompt 妯℃澘鍒楄〃
310:  Future<List<PromptTemplate>> getPromptTemplates() async {
---
414:    required int inputTokens,
415:    required int outputTokens,
416:    required bool success,
417:  }) async {
418:    final prefs = await SharedPreferences.getInstance();
419:    final callHistory = prefs.getStringList('ai_api_call_history') ?? [];
420:
421:    final record = {
422:      'timestamp': DateTime.now().toIso8601String(),
423:      'tier': tier.name,
424:      'function': function.name,
425:      'inputTokens': inputTokens,
426:      'outputTokens': outputTokens,
427:      'totalTokens': inputTokens + outputTokens,
428:      'success': success,
429:    };
430:
431:    callHistory.add(jsonEncode(record));
432:
433:    // 鍙繚鐣欐渶杩?000鏉¤褰?    if (callHistory.length > 1000) {
434:      callHistory.removeRange(0, callHistory.length - 1000);
435:    }
436:
437:    await prefs.setStringList('ai_api_call_history', callHistory);
438:  }
439:
440:  /// 璁板綍AI閰嶇疆鍙樻洿
441:  Future<void> logConfigChange({
442:    required ModelTier tier,
443:    required String changeType,
444:    required Map<String, dynamic> oldValue,
445:    required Map<String, dynamic> newValue,
446:  }) async {
447:    final prefs = await SharedPreferences.getInstance();
448:    final configHistory = prefs.getStringList('ai_config_change_history') ?? [];
449:
450:    final record = {
451:      'timestamp': DateTime.now().toIso8601String(),
452:      'tier': tier.name,
453:      'changeType': changeType,
454:      'oldValue': oldValue,
455:      'newValue': newValue,
456:    };
457:
458:    configHistory.add(jsonEncode(record));
459:
460:    // 鍙繚鐣欐渶杩?00鏉￠厤缃彉鏇磋褰?    if (configHistory.length > 500) {
461:      configHistory.removeRange(0, configHistory.length - 500);
462:    }
463:
464:    await prefs.setStringList('ai_config_change_history', configHistory);
465:  }
466:
467:  /// 鑾峰彇API璋冪敤鍘嗗彶
468:  Future<List<Map<String, dynamic>>> getApiCallHistory({
469:    int limit = 100,
470:  }) async {
471:    final prefs = await SharedPreferences.getInstance();
472:    final callHistory = prefs.getStringList('ai_api_call_history') ?? [];
473:
474:    return callHistory
475:        .take(limit)
476:        .map((record) => jsonDecode(record) as Map<String, dynamic>)
477:        .toList();
478:  }
479:
480:  /// 鑾峰彇閰嶇疆鍙樻洿鍘嗗彶
481:  Future<List<Map<String, dynamic>>> getConfigChangeHistory({
482:    int limit = 100,
483:  }) async {
484:    final prefs = await SharedPreferences.getInstance();
485:    final configHistory = prefs.getStringList('ai_config_change_history') ?? [];
486:
---
495:    required ModelConfig config,
496:    required core_model.AIProviderType type,
497:  }) {
498:    return core_provider.ProviderConfig(
499:      id: 'ai_config_${config.tier.name}_${type.name}',
500:      type: type,
501:      name: type.displayName,
502:      apiKey: apiKey,
503:      apiEndpoint: config.apiEndpoint,
504:    );
505:  }
506:
507:  core_tier.ModelTier _toCoreTier(ModelTier tier) {
508:    return switch (tier) {
509:      ModelTier.thinking => core_tier.ModelTier.thinking,
---

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/providers/openai_provider.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=12;e=35},@{s=39;e=107},@{s=110;e=190})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/providers/anthropic_provider.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=12;e=30},@{s=33;e=96},@{s=98;e=173})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
 succeeded in 165ms:
12:  @override
13:  AIProviderType get type => AIProviderType.openai;
14:
15:  final Dio _dio;
16:
17:  OpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();
18:
19:  @override
20:  Future<bool> validateConnection(ProviderConfig config) async {
21:    try {
22:      final response = await _dio.get(
23:        '${config.effectiveEndpoint}/models',
24:        options: Options(
25:          headers: {
26:            'Authorization': 'Bearer ${config.apiKey}',
27:            ...config.headers,
28:          },
29:        ),
30:      );
31:      return response.statusCode == 200;
32:    } catch (e) {
33:      return false;
34:    }
35:  }
---
39:    required ProviderConfig config,
40:    required ModelConfig model,
41:    required String systemPrompt,
42:    required String userPrompt,
43:    double? temperature,
44:    int? maxTokens,
45:    bool stream = false,
46:    void Function(String)? onStreamChunk,
47:  }) async {
48:    final stopwatch = Stopwatch()..start();
49:
50:    final messages = [
51:      {'role': 'system', 'content': systemPrompt},
52:      {'role': 'user', 'content': userPrompt},
53:    ];
54:
55:    final requestBody = {
56:      'model': model.modelName,
57:      'messages': messages,
58:      'temperature': temperature ?? model.temperature,
59:      'max_tokens': maxTokens ?? model.maxOutputTokens,
60:      'top_p': model.topP,
61:      'frequency_penalty': model.frequencyPenalty,
62:      'presence_penalty': model.presencePenalty,
63:      'stream': stream,
64:    };
65:
66:    try {
67:      if (stream && onStreamChunk != null) {
68:        return await _streamComplete(
69:          config: config,
70:          requestBody: requestBody,
71:          model: model,
72:          stopwatch: stopwatch,
73:          onStreamChunk: onStreamChunk,
74:        );
75:      }
76:
77:      final response = await _dio.post(
78:        '${config.effectiveEndpoint}/chat/completions',
79:        data: requestBody,
80:        options: Options(
81:          headers: {
82:            'Authorization': 'Bearer ${config.apiKey}',
83:            'Content-Type': 'application/json',
84:            ...config.headers,
85:          },
86:        ),
87:      );
88:
89:      stopwatch.stop();
90:
91:      final data = response.data as Map<String, dynamic>;
92:      final choices = data['choices'] as List;
93:      final content = choices.first['message']['content'] as String;
94:      final usage = data['usage'] as Map<String, dynamic>;
95:
96:      return AIResponse(
97:        content: content,
98:        inputTokens: usage['prompt_tokens'] as int,
99:        outputTokens: usage['completion_tokens'] as int,
100:        modelId: model.id,
101:        responseTime: stopwatch.elapsed,
102:        fromCache: false,
103:        requestId: data['id'] as String?,
104:      );
105:    } on DioException catch (e) {
106:      throw AIException(
107:        _extractErrorMessage(e),
---
110:      );
111:    }
112:  }
113:
114:  Future<AIResponse> _streamComplete({
115:    required ProviderConfig config,
116:    required Map<String, dynamic> requestBody,
117:    required ModelConfig model,
118:    required Stopwatch stopwatch,
119:    required void Function(String) onStreamChunk,
120:  }) async {
121:    final response = await _dio.post(
122:      '${config.effectiveEndpoint}/chat/completions',
123:      data: requestBody,
124:      options: Options(
125:        headers: {
126:          'Authorization': 'Bearer ${config.apiKey}',
127:          'Content-Type': 'application/json',
128:          ...config.headers,
129:        },
130:        responseType: ResponseType.stream,
131:      ),
132:    );
133:
134:    final stream = response.data.stream as Stream<List<int>>;
135:    final buffer = StringBuffer();
136:    int inputTokens = 0;
137:    int outputTokens = 0;
138:    String? requestId;
139:
140:    await for (final chunk in stream) {
141:      final text = utf8.decode(chunk);
142:      final lines = text.split('\n');
143:
144:      for (final line in lines) {
145:        if (line.startsWith('data: ')) {
146:          final data = line.substring(6);
147:          if (data == '[DONE]') continue;
148:
149:          try {
150:            final json = jsonDecode(data) as Map<String, dynamic>;
151:            requestId ??= json['id'] as String?;
152:
153:            final choices = json['choices'] as List?;
154:            if (choices != null && choices.isNotEmpty) {
155:              final delta = choices.first['delta'] as Map<String, dynamic>?;
156:              final content = delta?['content'] as String?;
157:              if (content != null) {
158:                buffer.write(content);
159:                onStreamChunk(content);
160:              }
161:            }
162:          } catch (_) {
163:            // 蹇界暐瑙ｆ瀽閿欒
164:          }
165:        }
166:      }
167:    }
168:
169:    stopwatch.stop();
170:
171:    // 浼扮畻 token锛堟祦寮忓搷搴旈€氬父涓嶈繑鍥?usage锛?    inputTokens = await countTokens(requestBody['messages'].toString(), model.modelName);
172:    outputTokens = await countTokens(buffer.toString(), model.modelName);
173:
174:    return AIResponse(
175:      content: buffer.toString(),
176:      inputTokens: inputTokens,
177:      outputTokens: outputTokens,
178:      modelId: model.id,
179:      responseTime: stopwatch.elapsed,
180:      fromCache: false,
181:      requestId: requestId,
182:    );
183:  }
184:
185:  @override
186:  Future<int> countTokens(String text, String modelName) async {
187:    // 绠€鍖栦及绠楋細涓枃绾?1.5 瀛楃/token锛岃嫳鏂囩害 4 瀛楃/token
188:    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
189:    final otherCount = text.length - chineseCount;
190:    return (chineseCount * 0.67 + otherCount * 0.25).ceil();
---

 succeeded in 163ms:
12:  @override
13:  AIProviderType get type => AIProviderType.anthropic;
14:
15:  final Dio _dio;
16:
17:  AnthropicProvider({Dio? dio}) : _dio = dio ?? Dio();
18:
19:  @override
20:  Future<bool> validateConnection(ProviderConfig config) async {
21:    try {
22:      final response = await _dio.post(
23:        '${config.effectiveEndpoint}/messages',
24:        data: {
25:          'model': 'claude-3-haiku-20240307',
26:          'max_tokens': 16,
27:          'messages': [
28:            {'role': 'user', 'content': 'ping'},
29:          ],
30:        },
---
33:        ),
34:      );
35:      return response.statusCode == 200;
36:    } catch (_) {
37:      return false;
38:    }
39:  }
40:
41:  @override
42:  Future<AIResponse> complete({
43:    required ProviderConfig config,
44:    required ModelConfig model,
45:    required String systemPrompt,
46:    required String userPrompt,
47:    double? temperature,
48:    int? maxTokens,
49:    bool stream = false,
50:    void Function(String)? onStreamChunk,
51:  }) async {
52:    final stopwatch = Stopwatch()..start();
53:
54:    final body = {
55:      'model': model.modelName,
56:      'system': systemPrompt,
57:      'messages': [
58:        {'role': 'user', 'content': userPrompt},
59:      ],
60:      'temperature': temperature ?? model.temperature,
61:      'max_tokens': maxTokens ?? model.maxOutputTokens,
62:      'stream': stream,
63:    };
64:
65:    try {
66:      if (stream && onStreamChunk != null) {
67:        return await _streamComplete(
68:          config: config,
69:          body: body,
70:          model: model,
71:          stopwatch: stopwatch,
72:          onStreamChunk: onStreamChunk,
73:        );
74:      }
75:
76:      final response = await _dio.post(
77:        '${config.effectiveEndpoint}/messages',
78:        data: body,
79:        options: Options(headers: _headers(config)),
80:      );
81:
82:      stopwatch.stop();
83:      final data = response.data as Map<String, dynamic>;
84:      final content = _extractContent(data);
85:      final usage = data['usage'] as Map<String, dynamic>?;
86:
87:      return AIResponse(
88:        content: content,
89:        inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
90:        outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
91:        modelId: model.id,
92:        responseTime: stopwatch.elapsed,
93:        fromCache: false,
94:        requestId: data['id'] as String?,
95:      );
96:    } on DioException catch (e) {
---
98:        _extractErrorMessage(e),
99:        statusCode: e.response?.statusCode,
100:        originalError: e,
101:      );
102:    }
103:  }
104:
105:  Future<AIResponse> _streamComplete({
106:    required ProviderConfig config,
107:    required Map<String, dynamic> body,
108:    required ModelConfig model,
109:    required Stopwatch stopwatch,
110:    required void Function(String) onStreamChunk,
111:  }) async {
112:    final response = await _dio.post(
113:      '${config.effectiveEndpoint}/messages',
114:      data: body,
115:      options: Options(
116:        headers: _headers(config),
117:        responseType: ResponseType.stream,
118:      ),
119:    );
120:
121:    final stream = response.data.stream as Stream<List<int>>;
122:    final buffer = StringBuffer();
123:    String? requestId;
124:
125:    await for (final chunk in stream) {
126:      final text = utf8.decode(chunk);
127:      for (final line in text.split('\n')) {
128:        if (!line.startsWith('data: ')) {
129:          continue;
130:        }
131:        final payload = line.substring(6);
132:        if (payload == '[DONE]' || payload.isEmpty) {
133:          continue;
134:        }
135:        try {
136:          final data = jsonDecode(payload) as Map<String, dynamic>;
137:          requestId ??= data['id'] as String?;
138:          final type = data['type'] as String?;
139:          if (type == 'content_block_delta') {
140:            final delta = data['delta'] as Map<String, dynamic>?;
141:            final textChunk = delta?['text'] as String?;
142:            if (textChunk != null && textChunk.isNotEmpty) {
143:              buffer.write(textChunk);
144:              onStreamChunk(textChunk);
145:            }
146:          }
147:        } catch (_) {
148:          // ignore malformed chunk
149:        }
150:      }
151:    }
152:
153:    stopwatch.stop();
154:
155:    return AIResponse(
156:      content: buffer.toString(),
157:      inputTokens: await countTokens(userPromptFromBody(body), model.modelName),
158:      outputTokens: await countTokens(buffer.toString(), model.modelName),
159:      modelId: model.id,
160:      responseTime: stopwatch.elapsed,
161:      fromCache: false,
162:      requestId: requestId,
163:    );
164:  }
165:
166:  @override
167:  Future<int> countTokens(String text, String modelName) async {
168:    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
169:    final other = text.length - chinese;
170:    return (chinese * 0.67 + other * 0.25).ceil();
171:  }
172:
173:  @override
---

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/providers/ollama_provider.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=12;e=26},@{s=29;e=76},@{s=79;e=153})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/providers/azure_openai_provider.dart'; "'$lines=Get-Content $path; for($i=1;$i -le $lines.Length;$i++){ '"'{0}:{1}' -f "'$i,$lines[$i-1] }' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/providers/custom_provider.dart'; "'$lines=Get-Content $path; for($i=1;$i -le $lines.Length;$i++){ '"'{0}:{1}' -f "'$i,$lines[$i-1] }' in C:\Users\changw98\dev\writing_assistant
exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/cache/cache_manager.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=1;e=40},@{s=41;e=120},@{s=150;e=213})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
 succeeded in 181ms:
1:import 'package:dio/dio.dart';
2:
3:import '../ai_service.dart';
4:import '../models/model_config.dart';
5:import '../models/provider_config.dart';
6:import 'ai_provider.dart';
7:
8:class AzureOpenAIProvider implements AIProvider {
9:  @override
10:  AIProviderType get type => AIProviderType.azure;
11:
12:  final Dio _dio;
13:
14:  AzureOpenAIProvider({Dio? dio}) : _dio = dio ?? Dio();
15:
16:  @override
17:  Future<bool> validateConnection(ProviderConfig config) async {
18:    try {
19:      final response = await _dio.post(
20:        _chatUrl(config, 'gpt-4.1-mini'),
21:        data: {
22:          'messages': [
23:            {'role': 'user', 'content': 'ping'},
24:          ],
25:          'max_tokens': 1,
26:        },
27:        options: Options(headers: _headers(config)),
28:      );
29:      return response.statusCode == 200;
30:    } catch (_) {
31:      return false;
32:    }
33:  }
34:
35:  @override
36:  Future<AIResponse> complete({
37:    required ProviderConfig config,
38:    required ModelConfig model,
39:    required String systemPrompt,
40:    required String userPrompt,
41:    double? temperature,
42:    int? maxTokens,
43:    bool stream = false,
44:    void Function(String)? onStreamChunk,
45:  }) async {
46:    final stopwatch = Stopwatch()..start();
47:    final response = await _dio.post(
48:      _chatUrl(config, model.modelName),
49:      data: {
50:        'messages': [
51:          {'role': 'system', 'content': systemPrompt},
52:          {'role': 'user', 'content': userPrompt},
53:        ],
54:        'temperature': temperature ?? model.temperature,
55:        'max_tokens': maxTokens ?? model.maxOutputTokens,
56:      },
57:      options: Options(headers: _headers(config)),
58:    );
59:    stopwatch.stop();
60:
61:    final data = response.data as Map<String, dynamic>;
62:    final first = ((data['choices'] as List).first as Map<String, dynamic>);
63:    final message = first['message'] as Map<String, dynamic>;
64:    final usage = data['usage'] as Map<String, dynamic>?;
65:
66:    return AIResponse(
67:      content: message['content'] as String? ?? '',
68:      inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
69:      outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
70:      modelId: model.id,
71:      responseTime: stopwatch.elapsed,
72:      fromCache: false,
73:      requestId: data['id'] as String?,
74:    );
75:  }
76:
77:  @override
78:  Future<int> countTokens(String text, String modelName) async {
79:    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
80:    final other = text.length - chinese;
81:    return (chinese * 0.67 + other * 0.25).ceil();
82:  }
83:
84:  @override
85:  Future<List<String>> getAvailableModels(ProviderConfig config) async {
86:    return const [];
87:  }
88:
89:  Map<String, String> _headers(ProviderConfig config) {
90:    return {
91:      'api-key': config.apiKey ?? '',
92:      'Content-Type': 'application/json',
93:      ...config.headers,
94:    };
95:  }
96:
97:  String _chatUrl(ProviderConfig config, String deploymentName) {
98:    final base = config.effectiveEndpoint;
99:    final suffix = base.contains('?') ? '&' : '?';
100:    return '$base/openai/deployments/$deploymentName/chat/completions${suffix}api-version=2024-02-15-preview';
101:  }
102:}

 succeeded in 180ms:
1:import 'package:dio/dio.dart';
2:
3:import '../ai_service.dart';
4:import '../models/model_config.dart';
5:import '../models/provider_config.dart';
6:import 'ai_provider.dart';
7:
8:class CustomProvider implements AIProvider {
9:  @override
10:  AIProviderType get type => AIProviderType.custom;
11:
12:  final Dio _dio;
13:
14:  CustomProvider({Dio? dio}) : _dio = dio ?? Dio();
15:
16:  @override
17:  Future<bool> validateConnection(ProviderConfig config) async {
18:    try {
19:      final response = await _dio.get(
20:        '${config.effectiveEndpoint}/models',
21:        options: Options(headers: _headers(config)),
22:      );
23:      return response.statusCode == 200;
24:    } catch (_) {
25:      return false;
26:    }
27:  }
28:
29:  @override
30:  Future<AIResponse> complete({
31:    required ProviderConfig config,
32:    required ModelConfig model,
33:    required String systemPrompt,
34:    required String userPrompt,
35:    double? temperature,
36:    int? maxTokens,
37:    bool stream = false,
38:    void Function(String)? onStreamChunk,
39:  }) async {
40:    final stopwatch = Stopwatch()..start();
41:    final response = await _dio.post(
42:      '${config.effectiveEndpoint}/chat/completions',
43:      data: {
44:        'model': model.modelName,
45:        'messages': [
46:          {'role': 'system', 'content': systemPrompt},
47:          {'role': 'user', 'content': userPrompt},
48:        ],
49:        'temperature': temperature ?? model.temperature,
50:        'max_tokens': maxTokens ?? model.maxOutputTokens,
51:        'stream': false,
52:      },
53:      options: Options(headers: _headers(config)),
54:    );
55:    stopwatch.stop();
56:
57:    final data = response.data as Map<String, dynamic>;
58:    final content = ((data['choices'] as List).first as Map<String, dynamic>);
59:    final message = content['message'] as Map<String, dynamic>;
60:    final usage = data['usage'] as Map<String, dynamic>?;
61:
62:    return AIResponse(
63:      content: message['content'] as String? ?? '',
64:      inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
65:      outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
66:      modelId: model.id,
67:      responseTime: stopwatch.elapsed,
68:      fromCache: false,
69:      requestId: data['id'] as String?,
70:    );
71:  }
72:
73:  @override
74:  Future<int> countTokens(String text, String modelName) async {
75:    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
76:    final other = text.length - chinese;
77:    return (chinese * 0.67 + other * 0.25).ceil();
78:  }
79:
80:  @override
81:  Future<List<String>> getAvailableModels(ProviderConfig config) async {
82:    try {
83:      final response = await _dio.get(
84:        '${config.effectiveEndpoint}/models',
85:        options: Options(headers: _headers(config)),
86:      );
87:      final data = response.data as Map<String, dynamic>;
88:      final models = data['data'] as List<dynamic>? ?? const [];
89:      return models
90:          .whereType<Map<String, dynamic>>()
91:          .map((model) => model['id'])
92:          .whereType<String>()
93:          .toList();
94:    } catch (_) {
95:      return const [];
96:    }
97:  }
98:
99:  Map<String, String> _headers(ProviderConfig config) {
100:    return {
101:      if (config.apiKey != null && config.apiKey!.isNotEmpty)
102:        'Authorization': 'Bearer ${config.apiKey}',
103:      'Content-Type': 'application/json',
104:      ...config.headers,
105:    };
106:  }
107:}

 succeeded in 184ms:
12:  @override
13:  AIProviderType get type => AIProviderType.ollama;
14:
15:  final Dio _dio;
16:
17:  OllamaProvider({Dio? dio}) : _dio = dio ?? Dio();
18:
19:  @override
20:  Future<bool> validateConnection(ProviderConfig config) async {
21:    try {
22:      final response = await _dio.get('${config.effectiveEndpoint}/tags');
23:      return response.statusCode == 200;
24:    } catch (_) {
25:      return false;
26:    }
---
29:  @override
30:  Future<AIResponse> complete({
31:    required ProviderConfig config,
32:    required ModelConfig model,
33:    required String systemPrompt,
34:    required String userPrompt,
35:    double? temperature,
36:    int? maxTokens,
37:    bool stream = false,
38:    void Function(String)? onStreamChunk,
39:  }) async {
40:    final stopwatch = Stopwatch()..start();
41:    final body = {
42:      'model': model.modelName,
43:      'stream': stream,
44:      'messages': [
45:        {'role': 'system', 'content': systemPrompt},
46:        {'role': 'user', 'content': userPrompt},
47:      ],
48:      'options': {
49:        'temperature': temperature ?? model.temperature,
50:        'num_predict': maxTokens ?? model.maxOutputTokens,
51:      },
52:    };
53:
54:    try {
55:      if (stream && onStreamChunk != null) {
56:        return await _streamComplete(
57:          config: config,
58:          body: body,
59:          model: model,
60:          stopwatch: stopwatch,
61:          onStreamChunk: onStreamChunk,
62:        );
63:      }
64:
65:      final response = await _dio.post(
66:        '${config.effectiveEndpoint}/chat',
67:        data: body,
68:      );
69:      stopwatch.stop();
70:
71:      final data = response.data as Map<String, dynamic>;
72:      final message = data['message'] as Map<String, dynamic>? ?? const {};
73:      final content = message['content'] as String? ?? '';
74:
75:      return AIResponse(
76:        content: content,
---
79:        modelId: model.id,
80:        responseTime: stopwatch.elapsed,
81:        fromCache: false,
82:      );
83:    } on DioException catch (e) {
84:      throw AIException(
85:        e.message ?? 'Request failed',
86:        statusCode: e.response?.statusCode,
87:        originalError: e,
88:      );
89:    }
90:  }
91:
92:  Future<AIResponse> _streamComplete({
93:    required ProviderConfig config,
94:    required Map<String, dynamic> body,
95:    required ModelConfig model,
96:    required Stopwatch stopwatch,
97:    required void Function(String) onStreamChunk,
98:  }) async {
99:    final response = await _dio.post(
100:      '${config.effectiveEndpoint}/chat',
101:      data: body,
102:      options: Options(responseType: ResponseType.stream),
103:    );
104:
105:    final stream = response.data.stream as Stream<List<int>>;
106:    final buffer = StringBuffer();
107:
108:    await for (final chunk in stream) {
109:      final text = utf8.decode(chunk);
110:      for (final line in const LineSplitter().convert(text)) {
111:        if (line.trim().isEmpty) {
112:          continue;
113:        }
114:        try {
115:          final data = jsonDecode(line) as Map<String, dynamic>;
116:          final message = data['message'] as Map<String, dynamic>?;
117:          final content = message?['content'] as String?;
118:          if (content != null && content.isNotEmpty) {
119:            buffer.write(content);
120:            onStreamChunk(content);
121:          }
122:        } catch (_) {
123:          // ignore malformed chunk
124:        }
125:      }
126:    }
127:
128:    stopwatch.stop();
129:
130:    return AIResponse(
131:      content: buffer.toString(),
132:      inputTokens: await countTokens(body['messages'].toString(), model.modelName),
133:      outputTokens: await countTokens(buffer.toString(), model.modelName),
134:      modelId: model.id,
135:      responseTime: stopwatch.elapsed,
136:      fromCache: false,
137:    );
138:  }
139:
140:  @override
141:  Future<int> countTokens(String text, String modelName) async {
142:    final chinese = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
143:    final other = text.length - chinese;
144:    return (chinese * 0.67 + other * 0.25).ceil();
145:  }
146:
147:  @override
148:  Future<List<String>> getAvailableModels(ProviderConfig config) async {
149:    try {
150:      final response = await _dio.get('${config.effectiveEndpoint}/tags');
151:      final data = response.data as Map<String, dynamic>;
152:      final models = data['models'] as List<dynamic>? ?? const [];
153:      return models
---

 succeeded in 190ms:
1:import 'dart:convert';
2:import 'dart:collection';
3:
4:import 'package:crypto/crypto.dart';
5:import 'package:collection/collection.dart';
6:
7:/// Prompt 缂撳瓨绠＄悊鍣?/// 鏀寔 L1-L4 鍥涘眰缂撳瓨绛栫暐
8:class PromptCacheManager {
9:  final int _maxMemoryCacheSize;
10:  final Duration _exactCacheTTL;
11:  final double _semanticSimilarityThreshold;
12:
13:  PromptCacheManager({
14:    int maxMemoryCacheSize = 1000,
15:    Duration exactCacheTTL = const Duration(hours: 24),
16:    double semanticSimilarityThreshold = 0.95,
17:  })  : _maxMemoryCacheSize = maxMemoryCacheSize,
18:        _exactCacheTTL = exactCacheTTL,
19:        _semanticSimilarityThreshold = semanticSimilarityThreshold;
20:
21:  /// L1: 鍐呭瓨缂撳瓨锛堜細璇濆唴锛?  final LinkedHashMap<String, CacheEntry> _memoryCache = LinkedHashMap();
22:
23:  /// L2: 绮剧‘鍖归厤缂撳瓨锛堣法浼氳瘽锛?  final Map<String, CacheEntry> _exactCache = {};
24:
25:  /// L3: 璇箟缂撳瓨锛堢浉浼艰姹傦級
26:  final List<SemanticCacheEntry> _semanticCache = [];
27:
28:  /// 缂撳瓨灞傜骇寮€鍏?  bool enableL1 = true;
29:  bool enableL2 = true;
30:  bool enableL3 = false; // 榛樿鍏抽棴锛岄渶瑕佸悜閲忔敮鎸?  bool enableL4 = true;  // 渚涘簲鍟嗙骇缂撳瓨
31:
32:  /// 鐢熸垚缂撳瓨閿?  String _generateKey(String prompt, String modelId, {Map<String, dynamic>? params}) {
33:    final content = '$prompt|$modelId|${jsonEncode(params ?? {})}';
34:    return md5.convert(utf8.encode(content)).toString();
35:  }
36:
37:  /// 鏌ユ壘缂撳瓨
38:  CacheEntry? find(String prompt, String modelId, {Map<String, dynamic>? params}) {
39:    final key = _generateKey(prompt, modelId, params: params);
40:
---
41:    // L1: 鍐呭瓨缂撳瓨
42:    if (enableL1) {
43:      final entry = _memoryCache[key];
44:      if (entry != null && !entry.isExpired) {
45:        return entry;
46:      }
47:    }
48:
49:    // L2: 绮剧‘鍖归厤
50:    if (enableL2) {
51:      final entry = _exactCache[key];
52:      if (entry != null && !entry.isExpired) {
53:        // 鎻愬崌鍒?L1
54:        _memoryCache[key] = entry;
55:        _evictIfNeeded();
56:        return entry;
57:      }
58:    }
59:
60:    // L3: 璇箟缂撳瓨
61:    if (enableL3) {
62:      final entry = _findSemanticMatch(prompt, modelId);
63:      if (entry != null) {
64:        return entry.entry;
65:      }
66:    }
67:
68:    return null;
69:  }
70:
71:  /// 瀛樺偍鍒扮紦瀛?  void store(
72:    String prompt,
73:    String modelId,
74:    String response, {
75:    Map<String, dynamic>? params,
76:    int? inputTokens,
77:    int? outputTokens,
78:  }) {
79:    final key = _generateKey(prompt, modelId, params: params);
80:    final now = DateTime.now();
81:
82:    final entry = CacheEntry(
83:      key: key,
84:      response: response,
85:      createdAt: now,
86:      expiresAt: now.add(_exactCacheTTL),
87:      inputTokens: inputTokens,
88:      outputTokens: outputTokens,
89:    );
90:
91:    // L1
92:    if (enableL1) {
93:      _memoryCache[key] = entry;
94:      _evictIfNeeded();
95:    }
96:
97:    // L2
98:    if (enableL2) {
99:      _exactCache[key] = entry;
100:    }
101:  }
102:
103:  /// L3: 璇箟鍖归厤鏌ユ壘
104:  SemanticCacheEntry? _findSemanticMatch(String prompt, String modelId) {
105:    // 杩欓噷闇€瑕佸悜閲忕浉浼煎害璁＄畻锛岀畝鍖栧疄鐜颁娇鐢ㄧ紪杈戣窛绂?    for (final entry in _semanticCache) {
106:      if (entry.modelId == modelId &&
107:          entry.similarity(prompt) >= _semanticSimilarityThreshold &&
108:          !entry.entry.isExpired) {
109:        return entry;
110:      }
111:    }
112:    return null;
113:  }
114:
115:  /// 娓呯悊杩囨湡缂撳瓨
116:  void cleanup() {
117:    _memoryCache.removeWhere((_, entry) => entry.isExpired);
118:    _exactCache.removeWhere((_, entry) => entry.isExpired);
119:    _semanticCache.removeWhere((entry) => entry.entry.isExpired);
120:  }
---
150:
151:  CacheEntry({
152:    required this.key,
153:    required this.response,
154:    required this.createdAt,
155:    required this.expiresAt,
156:    this.inputTokens,
157:    this.outputTokens,
158:  });
159:
160:  bool get isExpired => DateTime.now().isAfter(expiresAt);
161:}
162:
163:/// 璇箟缂撳瓨鏉＄洰
164:class SemanticCacheEntry {
165:  final String prompt;
166:  final String modelId;
167:  final CacheEntry entry;
168:
169:  SemanticCacheEntry({
170:    required this.prompt,
171:    required this.modelId,
172:    required this.entry,
173:  });
174:
175:  /// 璁＄畻鐩镐技搴︼紙绠€鍖栫増锛屽疄闄呭簲浣跨敤鍚戦噺锛?  double similarity(String other) {
176:    // 浣跨敤 Levenshtein 璺濈鐨勭畝鍖栫増鏈?    final distance = _levenshteinDistance(prompt, other);
177:    final maxLen = prompt.length > other.length ? prompt.length : other.length;
178:    return 1.0 - (distance / maxLen);
179:  }
180:
181:  int _levenshteinDistance(String s1, String s2) {
182:    if (s1 == s2) return 0;
183:    if (s1.isEmpty) return s2.length;
184:    if (s2.isEmpty) return s1.length;
185:
186:    List<int> prev = List.generate(s2.length + 1, (i) => i);
187:    List<int> curr = List.filled(s2.length + 1, 0);
188:
189:    for (int i = 1; i <= s1.length; i++) {
190:      curr[0] = i;
191:      for (int j = 1; j <= s2.length; j++) {
192:        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
193:        curr[j] = [
194:          prev[j] + 1,
195:          curr[j - 1] + 1,
196:          prev[j - 1] + cost,
197:        ].min;
198:      }
199:      final temp = prev;
200:      prev = curr;
201:      curr = temp;
202:    }
203:
204:    return prev[s2.length];
205:  }
206:}
207:
208:/// 缂撳瓨缁熻
209:class CacheStats {
210:  final int l1Count;
211:  final int l2Count;
212:  final int l3Count;
213:
---

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/database/tables/ai_usage.dart'; "'$lines=Get-Content $path; for($i=1;$i -le $lines.Length;$i++){ '"'{0}:{1}' -f "'$i,$lines[$i-1] }' in C:\Users\changw98\dev\writing_assistant
 succeeded in 146ms:
1:import 'package:drift/drift.dart';
2:
3:/// AI浣跨敤缁熻琛?@DataClassName('AIUsageRecord')
4:class AIUsageRecords extends Table {
5:  TextColumn get id => text()();
6:  TextColumn get workId => text().nullable()(); // 鍏宠仈浣滃搧ID锛屽彲鑳戒负绌?  TextColumn get functionType => text()(); // AI鍔熻兘绫诲瀷
7:  TextColumn get modelId => text()(); // 浣跨敤鐨勬ā鍨婭D
8:  TextColumn get tier => text()(); // 妯″瀷灞傜骇 thinking/middle/fast
9:  TextColumn get status => text()(); // success/error/cached
10:  IntColumn get inputTokens => integer().withDefault(const Constant(0))();
11:  IntColumn get outputTokens => integer().withDefault(const Constant(0))();
12:  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
13:  IntColumn get responseTimeMs => integer().withDefault(const Constant(0))(); // 鍝嶅簲鏃堕棿锛堟绉掞級
14:  TextColumn get errorMessage => text().nullable()(); // 閿欒淇℃伅
15:  TextColumn get requestId => text().nullable()(); // 璇锋眰ID锛堢敤浜庤拷韪級
16:  BoolColumn get fromCache => boolean().withDefault(const Constant(false))();
17:  TextColumn get metadata => text().nullable()(); // JSON鍏冩暟鎹?  DateTimeColumn get createdAt => dateTime()();
18:
19:  @override
20:  Set<Column> get primaryKey => {id};
21:
22:  @override
23:  List<Set<Column>>? get uniqueKeys => [
24:        {requestId}, // requestId搴旇鏄敮涓€鐨?      ];
25:}
26:
27:/// AI浣跨敤缁熻姹囨€昏〃锛堟寜鏃ユ湡鍜屾ā鍨嬫眹鎬伙級
28:@DataClassName('AIUsageSummary')
29:class AIUsageSummaries extends Table {
30:  TextColumn get id => text()();
31:  TextColumn get workId => text().nullable()();
32:  TextColumn get modelId => text()();
33:  TextColumn get tier => text()();
34:  TextColumn get functionType => text().nullable()(); // 涓簄ull琛ㄧず鎵€鏈夊姛鑳?  DateTimeColumn get date => dateTime()(); // 缁熻鏃ユ湡
35:  IntColumn get requestCount => integer().withDefault(const Constant(0))();
36:  IntColumn get successCount => integer().withDefault(const Constant(0))();
37:  IntColumn get errorCount => integer().withDefault(const Constant(0))();
38:  IntColumn get cachedCount => integer().withDefault(const Constant(0))();
39:  IntColumn get totalInputTokens => integer().withDefault(const Constant(0))();
40:  IntColumn get totalOutputTokens => integer().withDefault(const Constant(0))();
41:  IntColumn get totalTokens => integer().withDefault(const Constant(0))();
42:  IntColumn get totalResponseTimeMs => integer().withDefault(const Constant(0))();
43:  IntColumn get avgResponseTimeMs => integer().withDefault(const Constant(0))();
44:  RealColumn get estimatedCost => real().withDefault(const Constant(0))(); // 棰勪及鎴愭湰
45:  DateTimeColumn get createdAt => dateTime()();
46:  DateTimeColumn get updatedAt => dateTime()();
47:
48:  @override
49:  Set<Column> get primaryKey => {id};
50:
51:  @override
52:  List<Set<Column>>? get uniqueKeys => [
53:        {workId, modelId, functionType, date}, // 纭繚姣忓ぉ姣忎釜妯″瀷鍙湁涓€涓眹鎬昏褰?      ];
54:}

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/features/ai_config/presentation/widgets/ai_config_page_sections.dart'; "'$lines=Get-Content $path; foreach($r in @(@{s=146;e=199},@{s=223;e=236})){ for($i=$r.s;$i -le $r.e;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }; '"'---' }" in C:\Users\changw98\dev\writing_assistant
 succeeded in 143ms:
146:  }
147:
148:  Future<void> _loadConfig() async {
149:    final repository = Get.find<AIConfigRepository>();
150:    final config = await repository.getModelConfig(widget.tier);
151:    if (config != null && mounted) {
152:      setState(() {
153:        _providerType = config.providerType;
154:        _modelController.text = config.modelName;
155:        _endpointController.text = config.apiEndpoint ?? '';
156:        _temperature = config.temperature;
157:        _maxTokens = config.maxOutputTokens;
158:      });
159:    }
160:  }
161:
162:  @override
163:  Widget build(BuildContext context) {
164:    final s = AIConfigCopy.of(context);
165:    return Column(
166:      crossAxisAlignment: CrossAxisAlignment.start,
167:      children: [
168:        ProviderTypeDropdown(
169:          value: _providerType,
170:          onChanged: (value) {
171:            setState(() {
172:              _providerType = value ?? 'openai';
173:              if (value == 'openai') {
174:                _endpointController.text = 'https://api.openai.com/v1';
175:              } else if (value == 'anthropic') {
176:                _endpointController.text = 'https://api.anthropic.com/v1';
177:              } else if (value == 'ollama') {
178:                _endpointController.text = 'http://localhost:11434/api';
179:              }
180:            });
181:          },
182:        ),
183:        SizedBox(height: 16.h),
184:        ConfigTextField(
185:          controller: _endpointController,
186:          labelText: s.aiConfig_apiEndpoint,
187:          hintText: 'https://api.openai.com/v1',
188:        ),
189:        SizedBox(height: 16.h),
190:        ConfigTextField(
191:          controller: _apiKeyController,
192:          labelText: s.aiConfig_apiKey,
193:          obscureText: true,
194:          suffixIcon: const Icon(Icons.visibility_off),
195:        ),
196:        SizedBox(height: 16.h),
197:        ConfigTextField(
198:          controller: _modelController,
199:          labelText: s.aiConfig_modelName,
---
223:    );
224:  }
225:
226:  Future<void> _saveConfig() async {
227:    final repository = Get.find<AIConfigRepository>();
228:    await repository.saveModelConfig(
229:      tier: widget.tier,
230:      providerType: _providerType,
231:      modelName: _modelController.text,
232:      apiEndpoint: _endpointController.text,
233:      apiKey: _apiKeyController.text,
234:      temperature: _temperature,
235:      maxOutputTokens: _maxTokens,
236:    );
---

exec
"C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -Command '$path='"'lib/core/services/ai/ai_service.dart'; "'$lines=Get-Content $path; for($i=352;$i -le 384;$i++){ if($i -le $lines.Length){ '"'{0}:{1}' -f "'$i,$lines[$i-1] } }' in C:\Users\changw98\dev\writing_assistant
 succeeded in 150ms:
352:  }
353:
354:  Future<ModelConfig?> _getModelConfig(AIRequestConfig config) async {
355:    final repo = getx.Get.find<AIConfigRepository>();
356:    final featureTier = _toFeatureTier(
357:      config.overrideTier ?? config.function.defaultTier,
358:    );
359:    return repo.getCoreModelConfig(featureTier);
360:  }
361:
362:  Future<ProviderConfig?> _getProviderConfig(ModelConfig modelConfig) async {
363:    final repo = getx.Get.find<AIConfigRepository>();
364:    final featureTier = _toFeatureTier(modelConfig.tier);
365:    return repo.getCoreProviderConfig(featureTier);
366:  }
367:
368:  String _getDefaultSystemPrompt(AIFunction function) {
369:    return switch (function) {
370:      AIFunction.continuation => '浣犳槸涓€浣嶄笓涓氱殑灏忚浣滃鍔╂墜锛岃鏍规嵁涓婁笅鏂囪嚜鐒剁画鍐欍€?,
371:      AIFunction.dialogue => '浣犳槸涓€浣嶄笓涓氱殑灏忚瀵硅瘽浣滃锛岃鐢熸垚绗﹀悎瑙掕壊璁惧畾鐨勫璇濄€?,
372:      AIFunction.characterSimulation => '浣犳槸涓€浣嶄笓涓氱殑瑙掕壊鎵紨鍔╂墜锛岃鏍规嵁瑙掕壊璁惧畾杩涜鎺ㄦ紨銆?,
373:      AIFunction.review => '浣犳槸涓€浣嶄笓涓氱殑灏忚缂栬緫锛岃浠庝竴鑷存€с€侀€昏緫鍜岃妭濂忕淮搴﹀鏌ュ唴瀹广€?,
374:      AIFunction.extraction => '浣犳槸涓€浣嶄笓涓氱殑璁惧畾鎻愬彇鍔╂墜锛岃鎻愬彇瑙掕壊銆佸湴鐐广€佺墿鍝佺瓑淇℃伅銆?,
375:      AIFunction.consistencyCheck => '浣犳槸涓€浣嶄笓涓氱殑涓€鑷存€ф鏌ュ姪鎵嬶紝璇锋鏌ュ唴瀹逛腑鐨勮瀹氬啿绐併€?,
376:      AIFunction.timelineExtract => '浣犳槸涓€浣嶄笓涓氱殑鏃堕棿绾挎彁鍙栧姪鎵嬶紝璇锋彁鍙栦簨浠堕『搴忋€?,
377:      AIFunction.oocDetection => '浣犳槸涓€浣嶄笓涓氱殑瑙掕壊 OOC 妫€娴嬪姪鎵嬶紝璇锋鏌ヨ鑹茶涓烘槸鍚︾鍚堣瀹氥€?,
378:      AIFunction.aiStyleDetection => '浣犳槸涓€浣嶄笓涓氱殑 AI 鏂囬妫€娴嬪姪鎵嬶紝璇疯瘑鍒槑鏄剧殑 AI 鐥曡抗銆?,
379:      AIFunction.perspectiveCheck => '浣犳槸涓€浣嶄笓涓氱殑瑙嗚妫€娴嬪姪鎵嬶紝璇锋鏌ュ彊浜嬭瑙掓槸鍚︿竴鑷淬€?,
380:      AIFunction.pacingAnalysis => '浣犳槸涓€浣嶄笓涓氱殑鑺傚鍒嗘瀽鍔╂墜锛岃鍒嗘瀽鍙欎簨鑺傚鏄惁鍚堢悊銆?,
381:      AIFunction.povGeneration => '浣犳槸涓€浣嶄笓涓氱殑瑙嗚鐢熸垚鍔╂墜锛岃浠庢寚瀹氳鑹茶瑙掗噸鍐欏唴瀹广€?,
382:    };
383:  }
384:

collab: Wait
2026-04-06T04:57:33.122388Z ERROR codex_core::tools::router: error=Exit code: 1
Wall time: 0.2 seconds
Output:

ERROR: You've hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at 2:14 PM.
ERROR: You've hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at 2:14 PM.
tokens used
96,839

```

## Concise summary

Provider command failed (exit 1): OpenAI Codex v0.118.0 (research preview)

## Action items

- Inspect the raw output error details.
- Fix CLI/auth/environment issues and rerun the command.
