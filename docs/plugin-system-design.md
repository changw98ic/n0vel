# Plugin System Design

> Plan ID: M8-01
> Related Issues: #74, #23
> Base branch: `feature/m7-06-capability-auth`
> Target branch: `feature/m8-01-plugin-system-design`
> Status: Design

## 1. Purpose and Non-Goals

### 1.1 Purpose

The plugin system extends n0vel without weakening the local-first authoring
model. It should let trusted local extensions add commands, import/export
adapters, templates, review tools, and production automations while preserving:

1. **Author-in-the-loop writes** - plugins may propose changes, but destructive
   writes still flow through candidate overlays, confirmation gates, version
   anchors, or existing store commands.
2. **Local capability boundaries** - plugin permissions align with the M7 local
   server capability model instead of inventing a parallel authorization system.
3. **Open storage compatibility** - plugins can read Markdown mirror artifacts
   and project metadata, but they must not bypass SQLite/source-of-truth stores.
4. **Reviewable installation** - manifest permissions, hooks, and sandbox mode
   are visible before activation.
5. **Small implementation steps** - M8-02 can implement a local plugin manager
   from this design without adding a remote marketplace or runtime dependency.

### 1.2 Non-Goals

1. **No remote plugin marketplace in M8-01/M8-02** - catalog distribution is a
   later layer. M8 starts with local plugin bundles.
2. **No arbitrary in-process Dart execution** - plugins do not run inside the
   app isolate with direct access to app internals.
3. **No direct SQLite writes** - all mutation goes through app-level commands,
   candidate adoption, mirror import plans, or future local server endpoints.
4. **No cloud identity or OAuth** - plugin permissions are local grants.
5. **No guarantee of MCP wire compatibility** - plugins may call the local
   HTTP API, but the plugin system itself is not an MCP server.

## 2. System Shape

```text
Local plugin bundle
  plugin.n0vel.json
  README.md
  entrypoint files
  assets/
  templates/
        |
        v
PluginInstaller
  parse manifest
  verify signature/hash
  show permission diff
  copy into local plugin store
        |
        v
PluginRegistry
  installed / enabled / disabled
  hook index
  capability grants
        |
        v
PluginRuntime
  sandbox launch
  JSON envelopes
  local capability token
        |
        v
n0vel App Services
  command palette
  import/export
  template application
  local server API
  candidate overlays
```

The core app owns the registry and all app state. A plugin is a constrained
worker that receives explicit inputs and returns structured envelopes. The app
decides whether to apply any result.

## 3. Plugin Bundle Layout

```text
my-plugin/
  plugin.n0vel.json
  README.md
  LICENSE
  bin/
    plugin.wasm
  assets/
    icon.png
  templates/
    mystery-basic/
      template.n0vel.json
      project.n0vel.json
      bible/
```

Required files:

- `plugin.n0vel.json` - manifest.
- `README.md` - user-visible purpose, permissions explanation, and support
  contact.

Optional files:

- `LICENSE` - shown in installer.
- `bin/` - executable entrypoints.
- `assets/` - icons and local static assets.
- `templates/` - project/template bundles consumed by M8-03.

The installer must reject bundles with files outside the plugin root after path
normalization. Symlinks are not followed during installation.

## 4. Manifest Schema

```json
{
  "schemaVersion": 1,
  "pluginId": "com.example.timeline-exporter",
  "displayName": "Timeline Exporter",
  "version": "0.1.0",
  "publisher": {
    "name": "Example Studio",
    "url": "https://example.invalid"
  },
  "description": "Exports scene timelines from the current project.",
  "runtime": {
    "kind": "wasi",
    "entrypoint": "bin/plugin.wasm"
  },
  "permissions": [
    "project:read",
    "scene:read",
    "export:write"
  ],
  "hooks": [
    {
      "id": "timeline.export",
      "type": "command.palette",
      "title": "Export Timeline",
      "command": "timeline.export"
    }
  ],
  "templates": [
    {
      "templateId": "mystery-basic",
      "path": "templates/mystery-basic/template.n0vel.json"
    }
  ],
  "capabilities": {
    "requiresNetwork": false,
    "requiresProjectWrite": false,
    "confirmationRequired": ["export:write"]
  },
  "integrity": {
    "algorithm": "sha256",
    "digest": "base64:..."
  },
  "signature": {
    "algorithm": "ed25519",
    "keyId": "publisher-key-1",
    "value": "base64:..."
  },
  "minimumAppVersion": "0.9.0"
}
```

### 4.1 Required Fields

| Field | Rule |
|-------|------|
| `schemaVersion` | Integer. M8 starts at `1`. Unknown major versions are rejected. |
| `pluginId` | Reverse-DNS style stable identifier. Lowercase ASCII plus dots and hyphens. |
| `displayName` | Human-readable name. |
| `version` | SemVer string. |
| `runtime.kind` | One of `wasi`, `process`, `templateOnly`. |
| `permissions` | List of M7-aligned capability scopes. Empty is allowed. |
| `hooks` | Hook declarations. Empty is allowed only for template-only bundles. |
| `minimumAppVersion` | Minimum app version required to load the plugin. |

### 4.2 Permission Vocabulary

M8 reuses the local server scope names where possible:

| Scope | Meaning |
|-------|---------|
| `project:read` | Read project metadata. |
| `project:write` | Propose or request project metadata changes. |
| `scene:read` | Read scene metadata and accepted scene text. |
| `scene:write` | Propose scene changes through candidates or import plans. |
| `character:read` | Read character cards and relationships. |
| `character:write` | Propose character or Bible changes. |
| `world:read` | Read worldbuilding nodes. |
| `world:write` | Propose worldbuilding changes. |
| `run:read` | Read run status and generated candidates. |
| `generate:trigger` | Request scene generation. |
| `candidate:adopt` | Request candidate adoption; always confirmation-gated. |
| `memory:preview` | Preview memory/Bible writeback candidates. |
| `memory:commit` | Commit memory/Bible writeback; always confirmation-gated. |
| `export:read` | Read export plans. |
| `export:write` | Write export artifacts. |
| `import:read` | Read import plans. |
| `import:write` | Apply imports; always confirmation-gated. |
| `git:read` | Read Git mirror status. |

`git:write`, unrestricted filesystem access, and unrestricted network access
are explicitly reserved. They must not ship in the first implementation.

## 5. Extension Points

| Hook Type | Purpose | First Implementation |
|-----------|---------|----------------------|
| `command.palette` | Add a command visible in the command palette or plugin menu. | M8-02 |
| `project.export` | Contribute an export action or format. | M8-02/M8-05 |
| `project.importPlan` | Propose import-plan analysis for a mirror or bundle. | M8-05 |
| `template.catalog` | Contribute local templates. | M8-03 |
| `review.package` | Contribute review-package exporters/importers. | M8-05 |
| `production.metric` | Contribute read-only metrics to Production. | Later M8 |

Hooks are declarative. A disabled plugin contributes no hooks. A plugin may
only receive invocation payloads for hooks declared in its manifest.

## 6. Plugin API Contract

Plugins communicate with n0vel using newline-delimited JSON envelopes over the
sandbox runtime stdin/stdout boundary. The app sends one request envelope and
expects one response envelope per command invocation.

### 6.1 Request Envelope

```json
{
  "jsonrpc": "2.0",
  "id": "req-123",
  "method": "command.invoke",
  "params": {
    "command": "timeline.export",
    "projectId": "project-123",
    "capabilityToken": "opaque-local-token",
    "input": {
      "format": "markdown"
    }
  }
}
```

### 6.2 Response Envelope

```json
{
  "jsonrpc": "2.0",
  "id": "req-123",
  "result": {
    "kind": "exportResult",
    "artifacts": [
      {
        "path": "exports/timeline.md",
        "mimeType": "text/markdown"
      }
    ],
    "proposedChanges": []
  }
}
```

### 6.3 Error Envelope

```json
{
  "jsonrpc": "2.0",
  "id": "req-123",
  "error": {
    "code": "permission_denied",
    "message": "Plugin lacks scene:read permission"
  }
}
```

The API is intentionally narrow. Complex project reads should go through the
local server using a project-scoped token; plugin stdout must not contain raw
API keys, bearer tokens, or full prompt logs.

## 7. Lifecycle

### 7.1 Install

1. User chooses a local plugin bundle.
2. Installer normalizes the path and reads `plugin.n0vel.json`.
3. Installer validates schema, plugin ID, version, runtime kind, hook types,
   permission names, file references, and minimum app version.
4. Installer computes bundle digests and verifies signature when present.
5. UI shows permission diff and sandbox summary.
6. User confirms install.
7. App copies bundle into the local plugin store and records installed state.

### 7.2 Enable

1. User enables the plugin.
2. App creates or refreshes local capability grants scoped to the selected
   project and declared permissions.
3. Hook registry indexes the plugin's hooks.
4. Plugin becomes visible in command surfaces.

### 7.3 Invoke

1. User or app invokes a declared hook.
2. PluginRuntime starts a sandbox process or reuses a warm process if allowed.
3. App sends a JSON request envelope.
4. Plugin returns a JSON response envelope.
5. App validates response shape.
6. Any proposed writes are converted to candidate overlays, import plans, or
   confirmation-gated commands before application.

### 7.4 Disable

1. User disables the plugin.
2. App removes hook registry entries.
3. App revokes active capability grants.
4. Warm runtime processes are stopped.
5. Installed files remain on disk.

### 7.5 Uninstall

1. User requests uninstall.
2. App disables the plugin if needed.
3. App deletes the copied bundle from the plugin store.
4. App retains audit history and optional user data tombstones.

## 8. Sandbox Model

### 8.1 Runtime Kinds

| Runtime | Description | M8 Status |
|---------|-------------|-----------|
| `templateOnly` | No executable code; contributes templates only. | M8-03 |
| `wasi` | Preferred executable plugin runtime. No ambient filesystem/network. | Design target |
| `process` | Local subprocess for developer-mode plugins. Disabled by default. | Developer mode only |

### 8.2 Filesystem Access

Plugins get a virtual workspace:

```text
/plugin/       read-only plugin bundle
/work/         temporary scratch directory
/out/          output artifacts returned to app
```

They do not receive direct access to the user's project directory, SQLite DB,
home directory, shell, or arbitrary filesystem paths. Project reads happen via
explicit API calls and capability tokens.

### 8.3 Network Access

Network access is denied by default. A future `network:request` permission may
allow host allowlists, but M8-02 must not implement broad network access.

### 8.4 Resource Limits

The runtime enforces:

- command timeout;
- stdout/stderr byte limits;
- output artifact size limits;
- one invocation cancellation token;
- maximum concurrent invocations per plugin.

Timeouts and cancellations produce structured errors and audit events.

## 9. Security Model

### 9.1 Trust Boundary

Plugins are untrusted input. A signed plugin is only a publisher integrity
signal; it is not allowed to bypass sandbox or confirmation rules.

### 9.2 Permission Review

Before install or enable, the UI displays:

- requested permissions;
- hooks that will appear in the app;
- runtime kind;
- whether confirmation-gated operations are requested;
- signature status;
- local files the bundle will install.

Permission changes on upgrade require a new confirmation.

### 9.3 Capability Alignment

Plugin invocations receive local capability tokens generated from the plugin's
enabled grants. Tokens inherit M7 rules:

- project binding;
- expiration;
- revocation on disable/uninstall;
- audit logging by subject and transaction ID;
- confirmation gates for destructive operations.

The plugin system should use a `sub` value like
`plugin:<pluginId>@<version>` so server audit logs identify the caller.

### 9.4 Write Safety

Plugins cannot directly mutate accepted project content. Writes must become one
of:

1. candidate patches;
2. pending overlay entries;
3. import plans;
4. memory writeback previews;
5. confirmation-gated local server requests.

The app creates a version anchor before applying any accepted plugin write.

### 9.5 Logging and Redaction

Audit logs record:

- plugin ID and version;
- hook ID;
- project ID;
- granted permission used;
- decision/result;
- timestamp;
- error code when failed.

Logs must not record raw bearer tokens, API keys, prompt bodies by default, or
full manuscript text unless the user explicitly exports a review package.

## 10. Persistence Model

M8-02 can start with a JSON store under the app support directory:

```json
{
  "installed": [
    {
      "pluginId": "com.example.timeline-exporter",
      "version": "0.1.0",
      "installedAt": "2026-05-25T16:45:00Z",
      "enabled": true,
      "bundlePath": "...",
      "manifestDigest": "sha256:...",
      "grantedPermissions": ["project:read", "scene:read"]
    }
  ]
}
```

SQLite integration can be added later if plugin state needs querying in
Production dashboards. The first implementation should keep plugin state
separate from authoring content so disabling the feature is reversible.

## 11. Template Integration

Template bundles may be standalone or shipped inside plugins. M8-03 should
consume the same manifest validation rules but may use `runtime.kind:
"templateOnly"` and no executable entrypoint.

Template application is still an app-owned operation:

1. validate template manifest;
2. preview project files and Bible starter data;
3. create a project initialization version anchor;
4. write through existing project creation/import flows.

Templates cannot run code during project creation unless the user explicitly
enables an executable plugin.

## 12. Failure Modes

| Failure | Result |
|---------|--------|
| Invalid manifest | Install rejected with validation errors. |
| Unknown permission | Install rejected. |
| Signature missing | Allowed only when user accepts unsigned local plugin policy. |
| Signature invalid | Install rejected. |
| Runtime timeout | Invocation fails, process is killed, audit event recorded. |
| Malformed response | Invocation fails, no writes applied. |
| Permission denied | Invocation fails with `permission_denied`; audit event recorded. |
| User denies confirmation | Request cancelled; no writes applied. |

## 13. M8-02 Implementation Handoff

Recommended first implementation slices:

1. `lib/app/plugin/plugin_manifest.dart`
   - Manifest model and validation.
   - Permission and hook enums.
   - Runtime kind validation.
2. `lib/app/plugin/plugin_registry.dart`
   - Installed/enabled plugin records.
   - Hook index projection.
3. `lib/app/plugin/plugin_installer.dart`
   - Local bundle validation.
   - Path normalization and digest computation.
   - No remote marketplace.
4. `test/plugin_manifest_test.dart`
   - Valid manifest parsing.
   - Unknown permissions rejected.
   - Invalid file references rejected.
   - Permission diff detection.

Runtime execution can be a later M8-02 follow-up if needed; it should remain
behind a feature flag until sandbox behavior is verified.

## 14. Acceptance Checklist

- [x] Plugin API is defined with request/response/error envelopes.
- [x] Manifest schema and extension points are defined.
- [x] Lifecycle covers install, enable, invoke, disable, and uninstall.
- [x] Sandbox mechanism is defined without adding dependencies.
- [x] Security model aligns with M7 capability auth.
- [x] Out-of-scope boundaries are explicit for M8-02/M8-03.
