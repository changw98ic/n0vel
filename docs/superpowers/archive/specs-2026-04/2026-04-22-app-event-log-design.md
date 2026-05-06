# App Event Log Design

Date: 2026-04-22
Status: Draft approved for spec review
Scope: Add a local structured logging system that is strong enough to analyze AI, settings, persistence, import/export, and key UI interaction failures.

## Problem

The current app has diagnostic snippets and state persistence, but it does not have a unified event log.
That makes it hard to answer questions such as:

- Which UI action triggered a failure?
- Which AI request used which provider, model, endpoint, and timeout?
- Did the request fail before transport, during transport, or after response parsing?
- Did the user accept or reject a generated result?
- Did persistence fail before or after a write retry?
- Did import/export partially mutate local state before a package was rejected?

We need a local-first logging system that is useful for debugging and analysis without making the app dependent on external telemetry services.

## Goals

- Capture structured local events for key product flows.
- Persist the same event stream to both SQLite and JSONL.
- Make writes best-effort so logging failure never breaks user workflows.
- Record enough context to correlate AI, settings, persistence, and UI actions.
- Avoid storing secrets such as full API keys.
- Keep the design small enough to land incrementally.

## Non-Goals

- No remote telemetry upload.
- No analytics dashboard in this change.
- No full-text search UI in this change.
- No complete “log every widget rebuild” style tracing.
- No full draft-body snapshots by default.

## Approaches

### Approach A: JSONL-only

Write newline-delimited JSON files under the app support directory.

Pros:
- Fast to implement
- Easy to inspect with shell tools
- Easy to export and share

Cons:
- Weak for filtering and joining
- Harder to bound retention cleanly
- Hard to power future in-app inspection

### Approach B: SQLite-only

Write structured rows into a dedicated local database.

Pros:
- Strong querying and filtering
- Easy future in-app log browser
- Good retention and indexing story

Cons:
- Harder to tail live
- Slightly more ceremony for external inspection

### Approach C: SQLite primary + JSONL mirror

Write one canonical event object, then persist it to SQLite and JSONL in the same logging pipeline.

Pros:
- Best future queryability
- Best ad-hoc shell inspection
- One event model, two useful storage surfaces

Cons:
- More implementation than either single-store option
- Must handle partial sink failure carefully

Recommendation: Approach C.
It gives us both analysis modes while staying local-first. The app already uses SQLite successfully, so adding a dedicated telemetry database fits the existing architecture.

## Design

### Event Model

Introduce a unified event object, tentatively `AppEventLogEntry`, with these fields:

- `eventId`: globally unique id for the event
- `timestampMs`: event timestamp in milliseconds
- `level`: `debug | info | warn | error`
- `category`: `app | settings | ai | persistence | import_export | ui | simulation`
- `action`: short event name such as `settings.save`, `ai.chat.request`, `ai.chat.failure`, `project.import.start`
- `status`: `started | succeeded | failed | cancelled | warning`
- `sessionId`: local app session identifier
- `correlationId`: identifier shared across related events in one flow
- `projectId`: optional
- `sceneId`: optional
- `message`: short human-readable summary
- `errorCode`: optional machine-friendly error kind
- `errorDetail`: optional detail text
- `metadata`: structured JSON object with event-specific fields

The same logical event object is serialized to SQLite and JSONL.

### Storage Layout

Add a dedicated telemetry path resolver alongside the existing authoring path helpers.

Files:
- SQLite: `telemetry.db`
- JSONL directory: `logs/`

Suggested macOS paths:
- `~/Library/Application Support/NovelWriter/telemetry.db`
- `~/Library/Application Support/NovelWriter/logs/YYYY-MM-DD.jsonl`

Fallback when `HOME` is unavailable:
- `./telemetry.db`
- `./logs/YYYY-MM-DD.jsonl`

Keep telemetry storage separate from authoring data to reduce accidental coupling and migration risk.

### SQLite Schema

Create table `app_event_log_entries` with columns:

- `event_id TEXT PRIMARY KEY`
- `timestamp_ms INTEGER NOT NULL`
- `level TEXT NOT NULL`
- `category TEXT NOT NULL`
- `action TEXT NOT NULL`
- `status TEXT NOT NULL`
- `session_id TEXT NOT NULL`
- `correlation_id TEXT`
- `project_id TEXT`
- `scene_id TEXT`
- `message TEXT NOT NULL`
- `error_code TEXT`
- `error_detail TEXT`
- `metadata_json TEXT NOT NULL`

Indexes:
- `(timestamp_ms DESC)`
- `(category, action, timestamp_ms DESC)`
- `(correlation_id)`
- `(project_id, scene_id, timestamp_ms DESC)`

### JSONL Format

Each line is a full JSON encoding of the same event object.

Example:

```json
{"eventId":"evt-123","timestampMs":1776854400000,"level":"info","category":"ai","action":"ai.chat.request","status":"started","sessionId":"session-1","correlationId":"corr-1","projectId":"project-yuechao","sceneId":"scene-05-witness-room","message":"Started manual AI request.","errorCode":null,"errorDetail":null,"metadata":{"provider":"OpenAI compatible","model":"gpt-5.4","endpoint":"https://api.example.com/v1/chat/completions","timeoutMs":30000,"promptLength":84,"promptPreview":"请给我一句建议"}}
```

JSONL is append-only and should roll daily by filename.

### Logging Service

Add a small service layer:

- `AppEventLog`
- `AppEventLogStorage`
- `SqliteAppEventLogStorage`
- `JsonlAppEventLogMirror`

One write call accepts an event object and attempts:

1. SQLite insert
2. JSONL append

Rules:
- Event creation is synchronous and lightweight.
- Sink writes are async.
- Failure in either sink must not throw into user-facing flows.
- If one sink fails, optionally emit a best-effort fallback `debugPrint` in debug mode only, but do not recurse into logging the logging failure forever.

### Session and Correlation

Generate one app session id at app boot.

Generate per-flow correlation ids for:
- settings save
- connection test
- AI generate request
- AI replay request
- import package
- export package
- simulation run

This lets us reconstruct a full user flow from multiple events.

## Initial Integration Points

### Settings

Log:
- `settings.save.started`
- `settings.save.succeeded`
- `settings.save.failed`
- `settings.connection_test.started`
- `settings.connection_test.succeeded`
- `settings.connection_test.failed`
- `settings.retry_secure_store.started`
- `settings.retry_secure_store.succeeded`
- `settings.retry_secure_store.failed`

Metadata examples:
- provider
- baseUrl host
- model
- timeoutMs
- hasApiKey
- validation outcome
- persistence issue

### AI Client

Log around `AppLlmClient` use, not deep inside unrelated widgets.

Events:
- `ai.chat.request`
- `ai.chat.success`
- `ai.chat.failure`

Metadata:
- provider summary
- endpoint
- model
- timeoutMs
- message count
- prompt length
- prompt preview
- response length
- response preview
- latencyMs
- failure kind
- status code

Privacy:
- never store full API key
- default to truncated prompt/response previews
- do not store full draft unless explicitly requested later

### Workbench UI

Log key user actions:
- `ui.ai.generate_clicked`
- `ui.ai.review.opened`
- `ui.ai.review.accepted`
- `ui.ai.review.rejected`
- `ui.ai.history.replayed`
- `ui.scene.created`
- `ui.scene.renamed`
- `ui.scene.deleted`
- `ui.simulation.started`
- `ui.simulation.failed`
- `ui.simulation.completed`

These should carry project and scene identifiers when available.

### Import / Export

Log:
- `project.export.started`
- `project.export.succeeded`
- `project.export.failed`
- `project.import.started`
- `project.import.inspect_warning`
- `project.import.overwrite_confirmed`
- `project.import.succeeded`
- `project.import.failed`

Metadata:
- package path
- schema version
- manifest project id
- current local project id
- overwrite mode
- failure reason

## Privacy and Data Minimization

Default rules:
- Never log API keys.
- Never log full settings snapshots.
- Log only preview snippets for prompts and responses.
- Limit previews to a fixed max length.
- Keep metadata JSON structured and redactable.

Future extension can add an explicit “verbose debug session” toggle, but not in this first cut.

## Failure Semantics

Logging must be best-effort:

- App flow succeeds even if logging fails.
- Logging writes should not participate in business transactions.
- Telemetry failure must never roll back draft persistence, AI review accept, or import/export.

This is intentional because observability must not become a new source of user-visible failure.

## Testing

Add module-level tests for:

- SQLite event insert and query shape
- JSONL append format
- best-effort behavior when one sink fails
- path resolution fallback when `HOME` is missing
- redaction rules for API key and prompt preview length

Add integration tests for:

- settings save emits started/succeeded or failed events
- connection test emits request/result events
- AI client call emits request/success/failure events
- workbench AI accept/reject emits UI events

## Rollout Plan

Phase 1:
- event model
- dual sink storage
- app session id
- settings + AI client logging

Phase 2:
- workbench UI event hooks
- import/export event hooks
- simulation event hooks

Phase 3:
- optional in-app log viewer or export action

## Risks

- Over-logging noisy UI events can make analysis worse.
- Logging full text by accident creates privacy risk.
- Dual-sink writes can drift if event generation is duplicated instead of centralized.

Mitigation:
- one shared event builder
- strict redaction helpers
- start with high-signal events only

## Self-Review

- Placeholder scan: no `TODO`, `TBD`, or unresolved sections remain.
- Internal consistency: SQLite is the query source of truth; JSONL is an append-only mirror; both use one event model.
- Scope check: this is implementable as a single focused feature with incremental integration phases.
- Ambiguity check: event fields, sink behavior, and privacy rules are explicit enough to plan implementation without reinterpreting the design.

## Notes

- The brainstorming workflow normally asks to commit the spec, but this workspace currently has no Git metadata, so no commit was created.
