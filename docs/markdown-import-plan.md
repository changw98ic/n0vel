# Markdown Import Plan

> Version: 1.0
> Created: 2026-05-25
> Status: Design (M3-03)
> Implementation Target: M7

## Scope and Non-Goals

### In Scope (M3-03 Design)

This document defines the technical design for importing Markdown mirror projects back into n0vel. The design addresses:

- Directory scanning and file discovery
- Frontmatter and body parsing
- Identity mapping between Markdown files and SQLite entities
- Fingerprint computation for change detection
- Import plan states and conflict resolution rules
- Safety model and rollback expectations
- Edge case handling
- Test strategy and implementation phases

The output is a design handoff for M7 implementation, not runtime code.

### Out of Scope (M3-03)

- **No import runtime implementation** — M3-03 produces a design document only
- **No filesystem watching** — Git-based change detection is M7 scope
- **No SQLite mutations** — Actual import execution is M7 scope
- **No UI components** — Import UI is M7 scope
- **No Git integration** — Git coordinator is M7 scope

### Out of Scope (Future M7 Implementation)

- Incremental import (only full-tree import is planned)
- Live sync/merge while editing
- Conflict-free replicated data types
- Multi-writer scenarios
- Cross-project import

## Supported Markdown Mirror Inputs

The importer reads the exact tree structure emitted by M3-01 `MarkdownExporter`:

```
<root>/
├── project.n0vel.json          # Project metadata and full dump
├── README.md                    # Human-readable project overview
├── chapters/
│   ├── ch01/
│   │   ├── scene-001.md
│   │   ├── scene-002-title-slug.md
│   │   └── scene-003-id.md     # Collision-handled names
│   └── ch02/
│       └── ...
└── bible/
    ├── characters/
    │   ├── 001-character-name.md
    │   └── 002-another-name.md
    └── world/
        ├── 001-location.md
        └── 002-rule.md
```

### File-by-File Specifications

#### `project.n0vel.json`

```json
{
  "project": { /* ProjectRecord */ },
  "characters": [ /* CharacterRecord[] */ ],
  "scenes": [ /* SceneRecord[] */ ],
  "worldNodes": [ /* WorldNodeRecord[] */ ],
  "draft": "/* Full draft text if exported */"
}
```

This file serves as the authoritative source of truth for:
- All entity IDs
- Base fingerprints for overlay comparison
- Complete data snapshot

**Import rule**: This file MUST exist. Import fails without it.

#### `README.md`

Human-readable project overview. Parsed for display but not used for entity reconstruction.

**Import rule**: Optional. Missing README is a warning, not an error.

#### `chapters/chNN/scene-*.md`

Scene files with frontmatter:

```yaml
---
id: scene-uuid
chapter: Chapter Label
---
# Scene Title

## 摘要

Scene summary content...
```

**Import rules**:
- Frontmatter `id` is REQUIRED
- Frontmatter `chapter` is REQUIRED
- Body content is stored in `scene.summary`

#### `bible/characters/*.md`

Character files:

```yaml
---
id: character-uuid
role: Protagonist
---
# Character Name

**角色**: Protagonist

## 简介

Summary content...

## 核心需求

Need text...

## 备注

Notes...
```

**Import rules**:
- Frontmatter `id` is REQUIRED
- Frontmatter `role` is optional

#### `bible/world/*.md`

World node files:

```yaml
---
id: world-uuid
type: Location
location: Eastern Palace
---
# Node Title

**类型**: Location
**位置**: Eastern Palace

## 概要

Summary...

## 规则

Rules...

## 详情

Detail...
```

**Import rules**:
- Frontmatter `id` is REQUIRED
- Frontmatter `type` and `location` are optional

#### `.n0vel/pending/*.json` (Future Overlay Sidecars)

Pending overlay entries stored as sidecar files alongside the mirror. Each file contains an `OverlayEntry` serialized to JSON.

**Import rule** (M7): If present, load and merge into import plan as pre-resolved decisions. If absent, import proceeds without pre-resolved state.

## Directory Scanning and Deterministic Ordering

### Scan Algorithm

1. **Root validation**: Check for `project.n0vel.json`. Abort if missing.
2. **Load base dump**: Parse `project.n0vel.json` to get expected entity IDs.
3. **Scan chapters**: Recursively walk `chapters/` directory
   - Ignore non-`.md` files
   - Require `chXX` directory pattern (case-sensitive)
   - Sort directories lexicographically: `ch01`, `ch02`, ..., `ch10`, `ch11`, ...
4. **Scan bible**: Walk `bible/characters/` and `bible/world/`
   - Require `.md` extension
   - Sort files lexicographically
5. **Scan pending**: Check for `.n0vel/pending/` directory
   - Load all `.json` files as overlay entries

### Deterministic Ordering

To ensure reproducible import plans across runs:

1. **Chapter directories**: Sort by directory name (lexicographic `ch01`, `ch02`, etc.)
2. **Scene files within chapter**: Sort by filename
3. **Character files**: Sort by filename
4. **World files**: Sort by filename
5. **Pending entries**: Sort by entry ID

### Chapter Ordering Resolution

Chapter labels in scene frontmatter may not match directory names. Resolution priority:

1. Use directory name as primary sort key (`ch01` < `ch02`)
2. Use scene frontmatter `chapter` field for display
3. If directory name doesn't parse to a number, preserve lexicographic order

## Frontmatter/Body Parsing Strategy

### Parser Specification

| Component | Strategy |
|-----------|----------|
| **Frontmatter detection** | Look for `---` delimiter at line start. Must have opening `---`, content, closing `---`. |
| **Frontmatter parsing** | Simple constrained parser: detect `---` delimiters, extract `key: value` lines, split on first colon, trim whitespace. No nested YAML. Fail gracefully to empty map on parse error. |
| **Body extraction** | Everything after closing `---` delimiter. Trim leading/trailing whitespace. |
| **Encoding detection** | Assume UTF-8. Detect BOM and strip if present. |
| **Line ending normalization** | Normalize `\r\n` and `\r` to `\n` before parsing. |

### Unsafe/Missing Metadata Handling

| Scenario | Handling |
|----------|----------|
| **Missing frontmatter** | Treat entire file as body. Mark entry as `needs_review` with reason "missing_frontmatter". |
| **Invalid YAML** | Log warning, treat frontmatter as empty map. Continue import. Mark as `needs_review`. |
| **Missing required field** | Mark as `needs_review`. Use placeholder value if needed for reconstruction. |
| **Empty body** | Allow. Empty summary/content is valid. |
| **Duplicate frontmatter keys** | Last value wins (standard YAML behavior). |
| **Malformed UTF-8** | Mark file as `unsupported`. Skip import. |

### CJK/UTF-8 Handling

- **Encoding**: Assume UTF-8 without BOM. If BOM present (`﻿`), strip it.
- **Normalization**: Do NOT apply NFKC/NFD normalization. Preserve user's exact Unicode choice.
- **String length**: Use Dart `String.length` (code units, not code points).
- **Slug comparison**: For filename-based identity, use exact byte comparison after normalization.

## Identity Mapping Rules

Identity mapping determines which Markdown file corresponds to which SQLite entity.

### Primary Identity: File ID Field

Each entity type uses its `id` field from frontmatter as the primary identity:

| Entity Type | Identity Source |
|-------------|-----------------|
| Project | `project.n0vel.json` → `project.id` |
| Scene | Frontmatter `id` field |
| Character | Frontmatter `id` field |
| World Node | Frontmatter `id` field |
| Draft | `project.n0vel.json` → `draft` field |

### Fallback Identity: Filename-Based

When frontmatter `id` is missing or malformed:

1. **Scenes**: Extract scene number from filename pattern `scene-NNN-*.md`
   - Generate provisional ID: `scene-provisional-<chapter>-<number>`
   - Mark as `needs_review`

2. **Characters**: Extract index from filename pattern `NNN-slug.md`
   - Generate provisional ID: `char-provisional-<number>-<slug-hash>`
   - Mark as `needs_review`

3. **World Nodes**: Extract index from filename pattern `NNN-slug.md`
   - Generate provisional ID: `world-provisional-<number>-<slug-hash>`
   - Mark as `needs_review`

### Duplicate ID Resolution

If two files claim the same `id`:

1. **Both in Markdown**: Mark both as `conflict_keep_both`. Generate provisional IDs for the second occurrence.
2. **One in Markdown, one in SQLite**: Create `conflict` entry requiring user decision.

### Deleted Entity Detection

An entity present in SQLite but not in Markdown is treated as "deleted-in-pending":

- Import plan includes entry with `changedFields: ['deleted']`
- Status: `needs_review`
- Default resolution: Omit from final import unless user explicitly `keepSource`

## Fingerprint/Base-Hash Strategy

### Composition with M3-02 PendingOverlayStore

The importer reuses `OverlayFingerprint.fromCanonicalJson()` for consistency.

### Base Hash Computation

For each Markdown file:

1. **Parse frontmatter + body** into structured data
2. **Normalize** to canonical JSON representation
3. **Compute fingerprint** via `OverlayFingerprint`

### Comparison Strategy

During import:

| Scenario | Fingerprint Comparison | Result |
|----------|------------------------|--------|
| **File matches `project.n0vel.json`** | File fingerprint == JSON fingerprint | `unchanged` |
| **File differs from JSON** | File fingerprint != JSON fingerprint | `needs_review` |
| **File not in JSON** | No base fingerprint available | `needs_review` (added) |
| **File in JSON, missing on disk** | Base fingerprint exists, no file fingerprint | `needs_review` (deleted) |

### Fingerprint Storage

- **M3-01 export behavior**: The current `MarkdownExporter` writes `project.n0vel.json` with `project`, `characters`, `scenes`, `worldNodes`, and `draft` fields. It does NOT write a `_fingerprints` map today.
- **M7 import base fingerprint computation**: Compute base fingerprints directly from the canonical records already present in `project.n0vel.json` using `OverlayFingerprint.fromCanonicalJson()`. A future explicit `_fingerprints` map may be added through a separate compatibility decision if needed for performance or explicit fingerprint storage.
- **Overlay composition**: Pass both base and file fingerprints to `PendingOverlayStore.buildPlan()`

### Rollback Use

Fingerprints enable pre-apply validation:

- Before any SQLite mutation, compute expected fingerprints
- Compare against current SQLite state
- If mismatch detected, abort import and show error

## Import Plan States

The importer produces an `ImportPlan` containing one `ImportEntry` per entity.

### Entry States

| State | Meaning | User Action Required |
|-------|---------|---------------------|
| `safe_apply` | Fingerprint matches base | None. Auto-apply. |
| `needs_review` | Content changed or new | Review changes before apply. |
| `conflict_keep_both` | Duplicate ID detected | Choose which to keep or rename. |
| `unsupported` | Parsing failed (e.g., bad UTF-8) | Fix file and re-import. |
| `rejected` | User explicitly rejected | Exclude from import. |

### State Transitions

```
[Initial Scan]
       |
       v
[safe_apply] <--fingerprint match-- [Parsing Complete]
       |
       +--fingerprint mismatch--> [needs_review]
       |
       +--duplicate ID----------> [conflict_keep_both]
       |
       +--parse error-----------> [unsupported]

[needs_review] --user rejects--> [rejected]
[needs_review] --user accepts--> [safe_apply]
```

### Entry Model

```dart
class ImportEntry {
  final String id;
  final ImportTargetKind kind;  // project, scene, character, worldNode, draft
  final ImportState state;
  final OverlayFingerprint? baseFingerprint;
  final OverlayFingerprint fileFingerprint;
  final String? reason;  // Human-readable explanation
  final String? filePath;  // Relative path from root
  final Map<String, Object?> parsedData;
}
```

## Conflict Resolution Rules

### Conflict Types

| Type | Detection | Default Resolution |
|------|-----------|-------------------|
| **Duplicate ID** | Two files with same `id` | Mark both as `conflict_keep_both`. Generate new ID for second. |
| **ID collision with SQLite** | File `id` exists in database | Create `needs_review` entry. User chooses: keepSource, keepPending, or keepBoth. |
| **Deleted-in-pending** | Entity in SQLite but not in Markdown | Default: omit from import. User can explicitly `keepSource`. |
| **Fingerprint mismatch** | File differs from `project.n0vel.json` | Mark as `needs_review`. Show diff. |
| **Orphan file** | File doesn't match expected structure | Mark as `unsupported`. Skip. |

### Deleted-in-Pending Semantics

An entity in SQLite but absent from Markdown means "deleted in the mirror":

- **Import plan includes**: Entry with `deleted` flag
- **Default behavior**: Do NOT include in final import (i.e., deletion is propagated)
- **User override**: Can explicitly `keepSource` to preserve SQLite entity
- **Safety check**: Warn if deletion would lose data without confirmation

### Source Preservation

When `keepSource` is chosen on a deleted-in-pending entry:

- SQLite entity is preserved
- Does NOT create corresponding Markdown file (no reverse sync in M7)
- File remains absent from mirror

### Conflict Resolution Table

| Scenario | SQLite State | Markdown State | Resolution Options |
|----------|--------------|----------------|-------------------|
| Unchanged | Exists | Same fingerprint | Auto-apply (`safe_apply`) |
| Modified | Exists | Different fingerprint | `keepSource` / `keepPending` |
| Added | Missing | Exists | `keepPending` (auto-add) |
| Deleted | Exists | Missing | `keepSource` (preserve) / omit (delete) |
| Duplicate | N/A | Two files claim same ID | `keepBoth` with new ID / choose one |

## Safety and Rollback Model

### Planning Before Apply

The import process is strictly divided into two phases:

1. **Plan Phase** (read-only, no mutations):
   - Scan all files
   - Parse frontmatter and bodies
   - Compute fingerprints
   - Build `ImportPlan` with all entries and states
   - **DO NOT touch SQLite**

2. **Apply Phase** (with user confirmation):
   - User reviews plan
   - User makes decisions on `needs_review` entries
   - On user "Apply Import":
     - Begin SQLite transaction
     - Apply all `safe_apply` entries
     - Apply resolved `needs_review` entries
     - Commit transaction

### No Direct SQLite Mutation During Scan

**Critical invariant**: During the plan phase, the importer MUST NOT:

- Open SQLite write transactions
- Modify any store
- Write to `authoring.db`
- Modify `project.n0vel.json`

### Version and Audit Expectations

For M7 implementation, the import should:

1. **Create a version snapshot** before applying import
2. **Log import event** to event log with:
   - Timestamp
   - Source path
   - Entry counts by state
   - Commit hash (if from Git)
3. **Write import receipt** to `.n0vel/import-receipt-<timestamp>.json`:
   ```json
   {
     "timestamp": "2026-05-25T10:00:00Z",
     "sourcePath": "/path/to/mirror",
     "entriesApplied": 42,
     "entriesRejected": 3,
     "versionBefore": "version-id-123",
     "versionAfter": "version-id-124"
   }
   ```

### Rollback Strategy

If import fails or user cancels:

1. **SQLite transaction rollback** is automatic if commit not reached
2. **Version snapshot** allows manual rollback to pre-import state
3. **Import receipt** enables audit trail

## Edge Cases

### Duplicate Filenames

**Scenario**: Two scene files named `scene-001.md` in same chapter directory.

**Handling**:
- First file processed normally
- Second file marked as `conflict_keep_both`
- Generate new ID: `scene-001-dup-<hash>`
- Include both in import plan for user decision

### Duplicate Entity IDs

**Scenario**: Two files with frontmatter `id: scene-abc-123`.

**Handling**:
- Mark both as `conflict_keep_both`
- Generate provisional ID for second: `scene-abc-123-dup-<hash>`
- User must resolve: keep one, keep both (with rename), or reject both

### Missing Frontmatter

**Scenario**: Markdown file without `---` delimiters.

**Handling**:
- Treat entire file as body content
- Generate missing frontmatter fields with placeholders:
  - `id`: provisional from filename
  - `chapter`: extracted from directory path or "unsorted"
- Mark as `needs_review` with reason "missing_frontmatter"

### Malformed Frontmatter

**Scenario**: YAML parsing throws error.

**Handling**:
- Log warning with file path
- Use empty frontmatter map
- Proceed with body parsing
- Mark as `needs_review` with reason "malformed_frontmatter"

### Orphan Files

**Scenario**: File in unexpected location or name pattern.

**Handling**:
- Examples of orphans:
  - `chapters/notes.txt` (wrong extension)
  - `bible/characters/README.md` (doesn't match pattern)
  - `loose-file.md` at root
- Mark as `unsupported`
- Skip during import
- Log warning with count of orphan files

### Renamed Scenes or Chapters

**Scenario**: Scene `id` matches but file moved to different chapter directory.

**Handling**:
- Detect via directory path vs frontmatter `chapter` mismatch
- Mark as `needs_review` with reason "chapter_mismatch"
- Show both old and new locations
- User chooses: trust frontmatter or trust directory structure

### CJK Filenames/Content

**Scenario**: Files or content with Chinese/Japanese/Korean characters.

**Handling**:
- Filenames: Preserve exactly as-is (no slugification needed for import)
- Content: Parse as UTF-8, preserve exact Unicode (no normalization)
- Slug comparison: Use exact byte comparison, preserve user's Unicode choice
- No special handling required beyond UTF-8 validation

### Line Ending Normalization

**Scenario**: Files with `\r\n` (Windows) or `\r` (old Mac) line endings.

**Handling**:
- Normalize to `\n` before parsing
- Do NOT preserve original line endings in SQLite
- Export back with platform-appropriate line endings

### Empty Sections

**Scenario**: Frontmatter field present but empty (`id: ""`).

**Handling**:
- Empty required field → Treat as missing, generate provisional ID
- Empty optional field → Valid, use `""` as value
- Empty body → Valid, use empty string

### Pending Overlay Entries with Mismatched Base Hash

**Scenario**: `.n0vel/pending/entry.json` exists but its `sourceFingerprint` doesn't match current SQLite.

**Handling**:
- Mark entry as `needs_review` with reason "pending_base_mismatch"
- Show: expected fingerprint vs actual SQLite fingerprint
- User chooses: update pending, discard pending, or override anyway

## Test Strategy

### Unit Tests

| Component | Test Coverage |
|-----------|---------------|
| **Directory scanner** | Empty directory, missing `project.n0vel.json`, nested chapters, orphans |
| **Frontmatter parser** | Valid YAML, missing delimiters, malformed YAML, CJK content, empty fields |
| **Identity mapper** | Duplicate IDs, missing IDs, filename fallbacks |
| **Fingerprint computer** | Matching content, mismatched content, CJK stability |
| **Import plan builder** | All state transitions, entry counts, sorting |
| **Conflict resolver** | Each conflict type, user decisions |

### Integration Tests

| Scenario | Verification |
|----------|--------------|
| **Full valid import** | All `safe_apply`, clean apply |
| **Mixed states** | Combination of `safe_apply`, `needs_review`, `conflict` |
| **Large project** | 100+ scenes, 50+ characters, performance check |
| **CJK-heavy project** | All filenames and content in Chinese |
| **Corrupted mirror** | Malformed JSON, missing files, orphan files |

### Golden Tests

Create golden fixture sets:

```
test/golden/markdown_import/
├── simple_project/
│   ├── project.n0vel.json
│   └── ...
├── cjk_project/
│   ├── project.n0vel.json
│   └── ...
├── with_conflicts/
│   ├── project.n0vel.json
│   └── ...
└── pending_overlay/
    ├── project.n0vel.json
    └── .n0vel/pending/
```

Expected output: `ImportPlan` serialized to JSON for comparison.

### Property-Based Tests

Using `test` package with `property` generator:

- **Fingerprint stability**: Same content → same fingerprint across 1000 runs
- **Deterministic ordering**: Same file set → same entry order across 100 runs
- **ID uniqueness**: Generate 1000 random IDs → zero collisions

## Phased Implementation Checklist (M7)

### Phase 1: Core Parser (2-3 days)

- [ ] Implement `MarkdownImporter` class
- [ ] Implement directory scanner
- [ ] Implement frontmatter parser with YAML
- [ ] Implement body parser with UTF-8 handling
- [ ] Implement line ending normalization
- [ ] Add unit tests for parser

### Phase 2: Identity and Fingerprinting (2-3 days)

- [ ] Implement identity mapper (ID field + filename fallback)
- [ ] Implement duplicate ID detection
- [ ] Implement fingerprint computation
- [ ] Add base fingerprint loading from `project.n0vel.json`
- [ ] Add unit tests for identity mapping

### Phase 3: Import Planning (3-4 days)

- [ ] Implement `ImportEntry` model
- [ ] Implement `ImportPlan` model
- [ ] Implement state determination logic
- [ ] Implement conflict detection
- [ ] Implement orphan file handling
- [ ] Add unit tests for plan building

### Phase 4: SQLite Integration (3-4 days)

- [ ] Implement import apply logic
- [ ] Implement version snapshot before import
- [ ] Implement import receipt writing
- [ ] Implement transaction rollback on error
- [ ] Add integration tests with in-memory SQLite

### Phase 5: Pending Overlay Integration (2-3 days)

- [ ] Load `.n0vel/pending/*.json` sidecars
- [ ] Merge with `PendingOverlayStore`
- [ ] Handle mismatched base hashes
- [ ] Add tests for pending integration

### Phase 6: UI and Error Handling (3-4 days)

- [ ] Design import plan review UI
- [ ] Implement conflict resolution UI
- [ ] Implement error display and recovery
- [ ] Add progress reporting for large projects

### Phase 7: Testing and Documentation (2-3 days)

- [ ] Complete golden test coverage
- [ ] Add integration tests
- [ ] Write user-facing documentation
- [ ] Write error recovery guide

### Total Estimate: 17-23 days

## References

- M3-01: `lib/features/import_export/data/markdown_exporter.dart`
- M3-02: `lib/app/state/pending_overlay_store.dart`
- M7 Task: `docs/execution-roadmap.md` → TASK-M7-01
- GitHub Issue: #39 (M3-03), #23 (Roadmap parent)
