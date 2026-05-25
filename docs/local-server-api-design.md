# Local MCP-like Server API Design

> Plan ID: M7-04
> Related Issues: #71, #23
> Base branch: `feature/m7-03-bidirectional-sync`
> Target branch: `feature/m7-04-local-server-api-design`
> Status: Design

## 1. Purpose and Non-Goals

### 1.1 Purpose

Design a local HTTP server that exposes n0vel's core capabilities through a REST-like API, enabling:

1. **External agent integration** - Allow AI agents and tools to read and propose changes to novel projects without direct SQLite access
2. **Markdown mirror coordination** - Provide endpoints for Git-driven workflows where external edits flow through the pending overlay system
3. **Candidate proposal workflow** - External systems can generate candidate content (scenes, characters, prose) that requires explicit author confirmation before applying
4. **Run observation** - External monitoring of story generation runs for logging, analytics, and coordinated workflows

The server is **MCP-like** in spirit (Model Context Protocol - a local capability exposure pattern for AI agents) but does not implement the MCP wire protocol. Instead, it provides a simple HTTP/JSON API designed for coordination between n0vel and local tools (Git hooks, external LLM tools, custom scripts).

### 1.2 Non-Goals

1. **Remote access** - The server **only listens on loopback** (`127.0.0.1` or `::1`). It is not designed for LAN or internet exposure.
2. **Remote identity** - No cloud account, multi-user login, or third-party OAuth. Local capability tokens still gate every non-health endpoint.
3. **Direct database access** - All writes go through the app's existing stores and the pending overlay system.
4. **Real-time streaming** - No WebSocket or SSE. Run progress is polled via status endpoints.
5. **MCP wire protocol compatibility** - While inspired by MCP's capability model, this is a custom HTTP API, not an MCP server implementation.

## 2. Server Configuration

### 2.1 Default Behavior

- **Disabled by default** - The server does not start automatically. Users must explicitly enable it via settings or command-line flag.
- **Loopback binding** - Binds to `127.0.0.1` by default. Configurable port (default: `3727`, "N0V" in T9).
- **Project-scoped capabilities** - All operations are scoped to a specific project ID passed via request header or URL path.

### 2.2 Startup Settings

```dart
class LocalServerConfig {
  final bool enabled;
  final String host; // Default: "127.0.0.1"
  final int port; // Default: 3727
  final bool requireCapabilityToken; // Default: true
  final List<ServerCapability> allowedCapabilities;
}
```

## 3. Endpoint Summary

| Method | Path | Scope | Purpose |
|--------|------|-------|---------|
| GET | `/health` | - | Server health check |
| GET | `/projects` | `project:read` | List all projects |
| GET | `/projects/:id` | `project:read` | Get project metadata |
| POST | `/projects` | `project:write` | Create project (confirmation-gated) |
| PUT | `/projects/:id` | `project:write` | Update project (confirmation-gated) |
| DELETE | `/projects/:id` | `project:delete` | Delete project (confirmation-gated) |
| GET | `/projects/:id/scenes` | `scene:read` | List project scenes |
| GET | `/projects/:id/scenes/:sceneId` | `scene:read` | Get scene details |
| POST | `/projects/:id/scenes` | `scene:write` | Create scene (confirmation-gated) |
| PUT | `/projects/:id/scenes/:sceneId` | `scene:write` | Update scene (confirmation-gated) |
| DELETE | `/projects/:id/scenes/:sceneId` | `scene:delete` | Delete scene (confirmation-gated) |
| GET | `/projects/:id/characters` | `character:read` | List characters |
| GET | `/projects/:id/characters/:charId` | `character:read` | Get character details |
| POST | `/projects/:id/characters` | `character:write` | Create character (confirmation-gated) |
| PUT | `/projects/:id/characters/:charId` | `character:write` | Update character (confirmation-gated) |
| DELETE | `/projects/:id/characters/:charId` | `character:delete` | Delete character (confirmation-gated) |
| GET | `/projects/:id/world` | `world:read` | List world nodes |
| GET | `/projects/:id/world/:nodeId` | `world:read` | Get world node details |
| POST | `/projects/:id/world` | `world:write` | Create world node (confirmation-gated) |
| PUT | `/projects/:id/world/:nodeId` | `world:write` | Update world node (confirmation-gated) |
| DELETE | `/projects/:id/world/:nodeId` | `world:delete` | Delete world node (confirmation-gated) |
| POST | `/projects/:id/scenes/:sceneId/generate` | `generate:trigger` | Trigger scene generation |
| GET | `/runs` | `run:read` | List all runs |
| GET | `/runs/:runId` | `run:read` | Get run status and snapshot |
| GET | `/runs/:runId/candidates` | `run:read` | Get run candidate content |
| POST | `/runs/:runId/candidates/:candidateId/adopt` | `candidate:adopt` | Adopt candidate (confirmation-gated) |
| POST | `/projects/:id/writeback/preview` | `memory:preview` | Preview memory/Bible writeback candidates |
| POST | `/projects/:id/writeback/commit` | `memory:commit` | Commit approved memory/Bible writeback (confirmation-gated) |
| GET | `/projects/:id/export/plan` | `export:read` | Get Markdown export plan |
| POST | `/projects/:id/export/apply` | `export:write` | Apply export (confirmation-gated) |
| GET | `/projects/:id/import/plan` | `import:read` | Get Markdown import plan |
| POST | `/projects/:id/import/apply` | `import:write` | Apply import (confirmation-gated) |
| GET | `/projects/:id/git/status` | `git:read` | Get Git mirror status |
| POST | `/projects/:id/git/import-plan` | `git:read`, `import:read` | Scan Git mirror and return an import plan |

## 4. Capability Model

### 4.1 Capability Scopes

Capabilities are granular permissions that control what operations a caller can perform. Each scope requires explicit user consent before being granted to a caller.

| Scope | Grants | Requires Confirmation |
|-------|--------|----------------------|
| `project:read` | Read project metadata | No |
| `project:write` | Modify project metadata (non-destructive) | Yes |
| `project:delete` | Delete projects | Yes |
| `scene:read` | Read scenes | No |
| `scene:write` | Create/modify scenes | Yes |
| `scene:delete` | Delete scenes | Yes |
| `character:read` | Read characters | No |
| `character:write` | Create/modify characters | Yes |
| `character:delete` | Delete characters | Yes |
| `world:read` | Read world nodes | No |
| `world:write` | Create/modify world nodes | Yes |
| `world:delete` | Delete world nodes | Yes |
| `generate:trigger` | Trigger scene generation | No |
| `run:read` | Read run status and snapshots | No |
| `candidate:adopt` | Adopt candidate content | Yes |
| `memory:preview` | Preview extracted memory/Bible writeback candidates | No |
| `memory:commit` | Commit approved memory/Bible writeback facts | Yes |
| `export:read` | Read export plans | No |
| `export:write` | Apply exports | Yes |
| `import:read` | Read import plans | No |
| `import:write` | Apply imports | Yes |
| `git:read` | Read Git status | No |
| `git:write` | Reserved for future Git push/pull operations | Yes |

### 4.2 Capability Token Shape

A capability token is a local bearer token passed via the `Authorization: Bearer` header. M7-06 may implement it as an opaque random token with a server-side grant record or as a signed token; the decoded grant shape is:

```json
{
  "iss": "n0vel-local-server",
  "iat": 1716652800,
  "exp": 1716739200,
  "nbf": 1716652800,
  "sub": "external-agent",
  "aud": "n0vel-api",
  "scope": ["project:read", "scene:read", "generate:trigger"],
  "projectId": "project-123",
  "txn": "txn-abc-123"
}
```

Fields:
- `iss`: Issuer (fixed: "n0vel-local-server")
- `iat`: Issued at (Unix timestamp)
- `exp`: Expiration time (Unix timestamp, max 24 hours from issuance)
- `nbf`: Not before (Unix timestamp)
- `sub`: Subject identifier for the caller (e.g., "git-hook", "external-script")
- `aud`: Audience (fixed: "n0vel-api")
- `scope`: Array of granted capability scopes
- `projectId`: Bound project ID (operations on other projects are rejected)
- `txn`: Optional transaction ID for audit logging

### 4.3 Token Lifecycle

1. **Issuance** - Tokens are issued in response to an explicit user grant action in the UI. The user selects which scopes to grant, and the server generates a signed token.
2. **Expiration** - Tokens have a configurable TTL (default: 1 hour, max: 24 hours). Expired tokens are rejected.
3. **Revocation** - Users can revoke tokens via UI. Revoked tokens are added to a denylist.
4. **Audit logging** - All operations using a capability token are logged with the token's `sub` and `txn` fields.

### 4.4 Project Binding

All capability tokens are bound to a specific `projectId`. Operations targeting other projects are rejected with `403 Forbidden` even if the token has the required scopes.

### 4.5 Confirmation Gates

Destructive or high-impact operations require explicit user confirmation:

**Always require confirmation:**
- `memory.commit` - Persisting approved memory, character-state, or Bible writeback facts
- Project deletion
- Scene/character/world deletion
- Candidate adoption
- Mirror import apply
- Destructive project writes (overwrites, mass deletions)

**Confirmation flow:**
1. Caller POSTs to a confirmation-gated endpoint with `prefer: asynchronous` header
2. Server returns `202 Accepted` with a `Confirmation-Id` header
3. Server prompts user in UI: "External agent 'script-name' wants to [action]. Allow?"
4. If user accepts, server processes the request
5. If user denies, request is cancelled with `403 Forbidden`
6. Result is available via status endpoint referenced by `Location` header

## 5. API Endpoints

### 5.1 Health Check

```
GET /health
```

Response (200 OK):
```json
{
  "status": "ok",
  "version": "0.4.0",
  "uptime": 3600
}
```

### 5.2 Project Endpoints

#### List Projects

```
GET /projects
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "projects": [
    {
      "id": "project-123",
      "title": "月潮档案",
      "genre": "悬疑推理",
      "summary": "一起失踪案引发的连锁反应...",
      "createdAt": "2025-01-15T08:00:00Z",
      "updatedAt": "2025-01-20T14:30:00Z"
    }
  ]
}
```

#### Get Project

```
GET /projects/:id
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "id": "project-123",
  "title": "月潮档案",
  "genre": "悬疑推理",
  "summary": "一起失踪案引发的连锁反应...",
  "sceneCount": 12,
  "characterCount": 8,
  "worldNodeCount": 15,
  "createdAt": "2025-01-15T08:00:00Z",
  "updatedAt": "2025-01-20T14:30:00Z"
}
```

#### Create Project (Confirmation-Gated)

```
POST /projects
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "title": "新项目",
  "genre": "都市异能",
  "summary": "一个关于隐秘世界的故事..."
}
```

Response (202 Accepted):
```http
HTTP/1.1 202 Accepted
Confirmation-Id: confirm-abc-123
Location: /confirmations/confirm-abc-123
```

### 5.3 Scene Endpoints

#### List Scenes

```
GET /projects/:id/scenes
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "scenes": [
    {
      "id": "scene-001",
      "chapterLabel": "第 1 章",
      "title": "雨夜来客",
      "summary": "一个神秘的访者在雨夜敲响了门...",
      "wordCount": 0,
      "status": "pending"
    }
  ]
}
```

#### Get Scene

```
GET /projects/:id/scenes/:sceneId
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "id": "scene-001",
  "chapterLabel": "第 1 章",
  "title": "雨夜来客",
  "summary": "一个神秘的访者在雨夜敲响了门...",
  "goal": "建立主角和访者的首次接触",
  "conflict": "访者的身份不明，主角保持警惕",
  "constraint": "场景限在公寓内，时间一晚",
  "draftText": "",
  "characters": ["char-001", "char-002"],
  "worldNodes": ["world-001"]
}
```

#### Create Scene (Confirmation-Gated)

```
POST /projects/:id/scenes
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "chapterLabel": "第 2 章",
  "title": "新场景",
  "summary": "场景摘要..."
}
```

#### Update Scene (Confirmation-Gated)

```
PUT /projects/:id/scenes/:sceneId
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "title": "更新后的标题",
  "summary": "更新后的摘要..."
}
```

### 5.4 Scene Generation Trigger

```
POST /projects/:id/scenes/:sceneId/generate
Authorization: Bearer <token>
```

Request body (optional):
```json
{
  "revisionRequests": [
    "加强悬疑氛围",
    "增加环境描写"
  ]
}
```

Response (202 Accepted):
```http
HTTP/1.1 202 Accepted
Location: /runs/run-abc-123
```

The generation runs asynchronously. Status is polled via the `/runs/:runId` endpoint.

### 5.5 Run Status Endpoints

#### List Runs

```
GET /runs
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "runs": [
    {
      "id": "run-abc-123",
      "projectId": "project-123",
      "sceneId": "scene-001",
      "sceneLabel": "第 1 章 / 场景 01",
      "status": "running",
      "phase": "draft",
      "headline": "AI 正在准备本章",
      "summary": "正在整理章节目标、出场人物和改稿检查",
      "startedAt": "2025-01-20T15:00:00Z",
      "updatedAt": "2025-01-20T15:02:30Z"
    }
  ]
}
```

#### Get Run Status

```
GET /runs/:runId
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "id": "run-abc-123",
  "projectId": "project-123",
  "sceneId": "scene-001",
  "sceneLabel": "第 1 章 / 场景 01",
  "status": "completed",
  "phase": "candidate",
  "headline": "候选稿已生成",
  "summary": "共 3 个段落，约 1200 字",
  "startedAt": "2025-01-20T15:00:00Z",
  "completedAt": "2025-01-20T15:05:00Z",
  "messages": [
    {
      "kind": "status",
      "title": "完成",
      "body": "候选稿生成完成，请审阅"
    }
  ],
  "stageTimeline": [
    {
      "stageId": "scenePlanning",
      "status": "completed",
      "startedAt": "2025-01-20T15:00:00Z",
      "completedAt": "2025-01-20T15:01:00Z"
    },
    {
      "stageId": "proseGeneration",
      "status": "completed",
      "startedAt": "2025-01-20T15:01:00Z",
      "completedAt": "2025-01-20T15:04:00Z"
    }
  ]
}
```

Run status values: `pending`, `running`, `completed`, `failed`, `cancelled`.
Run phase values: `idle`, `draft`, `context`, `generation`, `candidate`, `review`, `fail`, `cancel`.

#### Get Run Candidates

```
GET /runs/:runId/candidates
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "runId": "run-abc-123",
  "candidates": [
    {
      "id": "candidate-001",
      "kind": "prose",
      "sectionIndex": 0,
      "content": "窗外雨声淅沥，李明正在书桌前整理笔记...",
      "wordCount": 156,
      "metadata": {
        "style": "narrative",
        "pov": "third-person"
      }
    },
    {
      "id": "candidate-002",
      "kind": "prose",
      "sectionIndex": 1,
      "content": "敲门声响起时，已经是深夜十一点...",
      "wordCount": 203,
      "metadata": {
        "style": "narrative",
        "pov": "third-person"
      }
    }
  ]
}
```

### 5.6 Candidate Adoption (Confirmation-Gated)

```
POST /runs/:runId/candidates/:candidateId/adopt
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "targetSection": 0
}
```

This operation requires user confirmation because it modifies the working draft (a destructive write).

Response (202 Accepted):
```http
HTTP/1.1 202 Accepted
Confirmation-Id: confirm-xyz-789
Location: /confirmations/confirm-xyz-789
```

After user approval, the candidate content is applied through the same candidate adoption path as the Workbench review flow, with a version anchor before the draft changes.

### 5.7 Memory Writeback Preview

```
POST /projects/:id/writeback/preview
Authorization: Bearer <token>
```

Request body:
```json
{
  "sourceRunId": "run-abc-123",
  "candidateId": "candidate-001",
  "facts": [
    {
      "kind": "characterState",
      "targetId": "char-001",
      "proposedText": "李明已经知道访者与旧案有关。",
      "evidence": "候选稿第 2 段"
    }
  ]
}
```

Response (200 OK):
```json
{
  "projectId": "project-123",
  "previewId": "writeback-preview-001",
  "facts": [
    {
      "id": "fact-001",
      "kind": "characterState",
      "targetId": "char-001",
      "status": "needsReview",
      "proposedText": "李明已经知道访者与旧案有关。",
      "conflicts": []
    }
  ]
}
```

This endpoint is read-only. It lets external tools ask n0vel to normalize proposed memory/Bible updates before any durable writeback.

### 5.8 Memory Writeback Commit (Confirmation-Gated)

```
POST /projects/:id/writeback/commit
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "previewId": "writeback-preview-001",
  "acceptedFactIds": ["fact-001"]
}
```

Response (202 Accepted):
```http
HTTP/1.1 202 Accepted
Confirmation-Id: confirm-writeback-123
Location: /confirmations/confirm-writeback-123
```

After user approval, the accepted facts are written to the appropriate memory, character-state, or Bible stores. This endpoint must never apply prose directly to the draft.

### 5.9 Markdown Export Plan

```
GET /projects/:id/export/plan
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "projectId": "project-123",
  "direction": "sqliteToMarkdown",
  "entries": [
    {
      "id": "entry-project-123",
      "targetRef": {
        "kind": "project",
        "id": "project-123"
      },
      "status": "unchanged",
      "sourceSummary": {
        "kind": "project",
        "title": "月潮档案",
        "detail": "悬疑推理"
      }
    },
    {
      "id": "entry-scene-001",
      "targetRef": {
        "kind": "scene",
        "id": "scene-001"
      },
      "status": "pending",
      "sourceSummary": {
        "kind": "scene",
        "title": "雨夜来客",
        "detail": "一个神秘的访者在雨夜..."
      },
      "changedFields": ["summary", "goal"]
    }
  ],
  "totalCount": 25,
  "pendingCount": 3,
  "conflictCount": 0
}
```

### 5.10 Markdown Export Apply (Confirmation-Gated)

```
POST /projects/:id/export/apply
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "decisions": [
    {
      "entryId": "entry-scene-001",
      "decision": "keepSource"
    }
  ]
}
```

Response (202 Accepted):
```http
HTTP/1.1 202 Accepted
Confirmation-Id: confirm-export-123
Location: /confirmations/confirm-export-123
```

### 5.11 Markdown Import Plan

```
GET /projects/:id/import/plan
Authorization: Bearer <token>
```

This endpoint triggers a scan of the project's Git mirror directory and returns the import plan from `PendingOverlayStore.buildMarkdownImportPlan()`.

Response (200 OK):
```json
{
  "projectId": "project-123",
  "direction": "markdownToSqlite",
  "entries": [
    {
      "id": "entry-scene-002",
      "targetRef": {
        "kind": "scene",
        "id": "scene-002"
      },
      "status": "pending",
      "pendingSummary": {
        "kind": "scene",
        "title": "新增场景",
        "detail": "新增的场景内容"
      },
      "changedFields": ["added"]
    }
  ],
  "blockingIssues": [],
  "totalCount": 26,
  "pendingCount": 1,
  "conflictCount": 0
}
```

### 5.12 Markdown Import Apply (Confirmation-Gated)

```
POST /projects/:id/import/apply
Authorization: Bearer <token>
Prefer: asynchronous
```

Request body:
```json
{
  "decisions": [
    {
      "entryId": "entry-scene-002",
      "decision": "keepPending"
    }
  ]
}
```

Response (202 Accepted):
```http
HTTP/1.1 202 Accepted
Confirmation-Id: confirm-import-456
Location: /confirmations/confirm-import-456
```

After user approval, the import is applied via `PendingOverlayStore.resolve()` and changes are written to SQLite behind a version anchor. Import plans with blocking issues cannot be applied.

### 5.13 Git Status

```
GET /projects/:id/git/status
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "projectId": "project-123",
  "isGitWorktree": true,
  "hasUncommittedChanges": true,
  "status": "dirty",
  "changedFiles": [
    "chapters/ch01/scene-001.md",
    "bible/characters/001-li-ming.md"
  ],
  "issues": []
}
```

### 5.14 Git Mirror Import Plan

```
POST /projects/:id/git/import-plan
Authorization: Bearer <token>
```

Response (200 OK):
```json
{
  "projectId": "project-123",
  "gitStatus": "dirty",
  "importPlanLocation": "/projects/project-123/import/plan"
}
```

This triggers the read-only `GitCoordinator.syncImport()` scan and produces an import plan for review. It must not run Git pull/push or write to SQLite.

## 6. Error Model

### 6.1 Error Response Format

All errors return JSON with consistent structure:

```json
{
  "error": {
    "code": "capability_insufficient",
    "message": "Token lacks required scope: scene:write",
    "details": {
      "requiredScope": "scene:write",
      "tokenScopes": ["project:read", "scene:read"]
    },
    "requestId": "req-xyz-789"
  }
}
```

### 6.2 HTTP Status Codes

| Status | Usage |
|--------|-------|
| 200 | Success |
| 202 | Accepted, confirmation required |
| 400 | Invalid request body or parameters |
| 401 | Missing or invalid token |
| 403 | Insufficient capabilities or project mismatch |
| 404 | Resource not found |
| 409 | Conflict (e.g., import conflict) |
| 500 | Internal server error |

### 6.3 Error Codes

| Code | Description |
|------|-------------|
| `invalid_token` | Token is malformed, expired, or revoked |
| `capability_insufficient` | Token lacks required scope |
| `project_mismatch` | Token is bound to a different project |
| `confirmation_required` | Operation requires user confirmation |
| `confirmation_denied` | User denied the confirmation request |
| `invalid_request_body` | Request body validation failed |
| `resource_not_found` | Requested resource does not exist |
| `import_conflict` | Import has blocking issues |
| `run_not_found` | Run ID does not exist |
| `generation_failed` | Scene generation failed |
| `server_busy` | Server is at capacity (rate-limited) |

### 6.4 Error Examples

#### Invalid Token
```json
{
  "error": {
    "code": "invalid_token",
    "message": "Token expired at 2025-01-20T16:00:00Z",
    "details": {
      "expiredAt": "2025-01-20T16:00:00Z"
    },
    "requestId": "req-abc-123"
  }
}
```

#### Capability Insufficient
```json
{
  "error": {
    "code": "capability_insufficient",
    "message": "Token lacks required scope: scene:write",
    "details": {
      "requiredScope": "scene:write",
      "tokenScopes": ["scene:read"]
    },
    "requestId": "req-def-456"
  }
}
```

#### Confirmation Required
```json
{
  "error": {
    "code": "confirmation_required",
    "message": "Operation requires user confirmation",
    "details": {
      "confirmationId": "confirm-ghi-789",
      "confirmationUrl": "/confirmations/confirm-ghi-789",
      "prompt": "External agent 'git-hook' wants to update scene '雨夜来客'. Allow?"
    },
    "requestId": "req-ghi-789"
  }
}
```

## 7. Security Model

All endpoints except `GET /health` require a valid capability token. Loopback
binding reduces exposure, but it is not treated as authorization by itself.

### 7.1 Loopback-Only Binding

The server binds exclusively to loopback addresses:
- IPv4: `127.0.0.1`
- IPv6: `::1`

Firewall rules should reject external connections. The server rejects non-loopback connections even if the firewall is misconfigured.

### 7.2 Audit Logging

All operations using capability tokens are logged with:
- Timestamp
- Token subject (`sub`)
- Transaction ID (`txn` if present)
- Operation performed
- Target resource
- Result (success/failure)

Audit logs are stored locally and can be exported for review.

### 7.3 Version Anchor

All destructive operations (confirmation-gated) create a version anchor:
- A snapshot of the affected entity is stored before modification
- The anchor ID is returned in the response
- Users can revert to the anchor via UI (feature for M7-06)

## 8. Implementation Phases

### Phase 1 (M7-05): Server Foundation

- [ ] Server lifecycle (start/stop) with loopback binding
- [ ] Health check endpoint
- [ ] Capability token issuance in UI
- [ ] Token validation middleware
- [ ] Project read endpoints
- [ ] Scene/character/world read endpoints
- [ ] Basic error handling

### Phase 2 (M7-06): Write Operations

- [ ] Confirmation-gated endpoint pattern
- [ ] Confirmation UI in app
- [ ] Project/scene/character/world write endpoints
- [ ] Scene generation trigger
- [ ] Run status endpoints
- [ ] Candidate adoption endpoint
- [ ] Memory writeback preview/commit endpoints
- [ ] Audit logging

### Phase 3 (M7-06): Mirror Integration

- [ ] Export plan endpoint
- [ ] Export apply endpoint
- [ ] Import plan endpoint
- [ ] Import apply endpoint
- [ ] Git status endpoint
- [ ] Git mirror import-plan endpoint
- [ ] Version anchoring

### Phase 4 (Post-M7): Enhanced Features

- [ ] WebSocket/SSE for run progress streaming
- [ ] MCP wire protocol compatibility layer
- [ ] Rate limiting
- [ ] Token management UI
- [ ] Audit log export
- [ ] External tool registration

## 9. Appendix: Run Status Mapping

The run status endpoints map directly to `StoryGenerationRunStore` concepts:

| API Field | Store Source |
|-----------|--------------|
| `status` | `StoryGenerationRunSnapshot.status` |
| `phase` | `StoryGenerationRunSnapshot.phase` |
| `headline` | `StoryGenerationRunSnapshot.headline` |
| `summary` | `StoryGenerationRunSnapshot.summary` |
| `stageTimeline` | `StoryGenerationRunSnapshot.stageTimeline` |
| `messages` | `StoryGenerationRunSnapshot.messages` |
| `participants` | `StoryGenerationRunSnapshot.participants` |

Run IDs are constructed from scene scope IDs: `{projectId}::{sceneId}`.
