# RAG And Thought Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full novel-specialized RAG system that supports pre-generation context retrieval, long-form consistency, Thought-Retriever-style memory growth, state-aware review, and inspectable evidence.

**Architecture:** Build a local-first memory layer around the existing story-generation pipeline. Raw project materials become source records and chunks; generated scenes and reviews produce higher-level thought atoms; retrieval returns compact context capsules with source traces instead of dumping raw text into prompts.

**Tech Stack:** Flutter/Dart, existing `sqlite3` persistence style, existing OpenAI-compatible LLM gateway, existing scene orchestration files under `lib/features/story_generation/data`, optional provider embeddings added behind an interface after lexical retrieval works.

---

## Current Fit

The repository already contains the right insertion points:

- `AgentTurnController` already supports controller-managed tool-like retrieval loops.
- `KnowledgeToolRegistry` already returns `ContextCapsule` objects for role agents.
- `ContextCapsuleStore` already has turn-local TTL and capacity behavior.
- `SceneStateResolver` already turns role output into accepted scene facts.
- `SceneReviewCoordinator` already separates judge, consistency, reader-flow, and lexicon review.

The RAG work should extend these seams rather than introduce a separate chat-style RAG subsystem.

---

## Delivery Strategy

Implement the system in five milestones. Each milestone must leave the app in a working state.

1. **Canonical Memory Store:** Persist source documents, chunks, retrieval traces, and thought atoms.
2. **Local Retrieval MVP:** Retrieve useful project memory without adding a heavy vector dependency.
3. **Generation Integration:** Feed retrieved capsules into scene planning, role turns, prose, and review.
4. **Thought Memory Loop:** Extract, filter, dedupe, and store reusable thoughts after accepted scenes.
5. **Audit And Tuning Surfaces:** Make retrieval inspectable and prepare for optional embedding/vector upgrades.

---

## File Map

### New Files

- `lib/features/story_generation/data/story_memory_models.dart`
  - Defines source documents, memory chunks, memory queries, retrieval hits, retrieval packs, thought atoms, and source traces.
- `lib/features/story_generation/data/story_memory_storage.dart`
  - Abstract storage contract for local-first memory persistence.
- `lib/features/story_generation/data/story_memory_storage_io.dart`
  - SQLite implementation using the project storage style already used elsewhere.
- `lib/features/story_generation/data/story_memory_storage_stub.dart`
  - In-memory implementation for tests and non-IO contexts.
- `lib/features/story_generation/data/story_memory_indexer.dart`
  - Converts project records, outline data, scene context, generated scenes, and reviews into memory chunks.
- `lib/features/story_generation/data/story_memory_retriever.dart`
  - Runs lexical scoring first, then optional semantic scoring later, and returns compact retrieval packs.
- `lib/features/story_generation/data/story_memory_dedupe.dart`
  - Similarity and redundancy guard for chunks and thoughts.
- `lib/features/story_generation/data/thought_memory_updater.dart`
  - Extracts Thought-Retriever-style thought atoms after scene acceptance.
- `test/story_memory_models_test.dart`
- `test/story_memory_storage_io_test.dart`
- `test/story_memory_retriever_test.dart`
- `test/thought_memory_updater_test.dart`
- `test/story_generation_rag_pipeline_test.dart`

### Modified Files

- `lib/features/story_generation/data/scene_context_models.dart`
  - Keep existing scene-facing models stable; move broader memory-specific types into `story_memory_models.dart`.
- `lib/features/story_generation/data/agentic_rag.dart`
  - Replace current atom-only ranking with memory retrieval packs.
- `lib/features/story_generation/data/knowledge_tool_registry.dart`
  - Add tools for plot memory, persona memory, foreshadowing, state ledger, and thought memory.
- `lib/features/story_generation/data/context_capsule_store.dart`
  - Add source trace and thought priority handling without changing role-agent prompt shape.
- `lib/features/story_generation/data/scene_context_assembler.dart`
  - Index current project material and attach scene-level retrieval requirements.
- `lib/features/story_generation/data/agent_turn_controller.dart`
  - Allow role agents to request memory tools and receive evidence-backed capsules.
- `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
  - Run pre-scene retrieval, pass retrieval packs through the scene pipeline, and trigger thought updates after accepted scenes.
- `lib/features/story_generation/data/scene_review_coordinator.dart`
  - Add evidence-grounded consistency checks and review-to-retrieval repair queries.
- `lib/app/state/story_generation_store.dart`
  - Persist memory fingerprints and scene invalidation edges.
- `lib/features/import_export/data/project_transfer_service.dart`
  - Include memory store records in project export/import after storage is stable.

---

## Milestone 1: Canonical Memory Store

**Purpose:** Give the project a durable memory substrate before adding retrieval behavior.

### Task 1: Define Memory Models

**Files:**
- Create: `lib/features/story_generation/data/story_memory_models.dart`
- Test: `test/story_memory_models_test.dart`

- [ ] **Step 1: Write tests for stable JSON round trips**

Create tests that cover:

```dart
test('thought atom preserves source trace and confidence', () {
  final atom = ThoughtAtom(
    id: 'thought-1',
    projectId: 'project-a',
    scopeId: 'scene-1',
    thoughtType: ThoughtType.persona,
    content: 'Liu Xi hides fear by asking procedural questions.',
    confidence: 0.86,
    abstractionLevel: 2.0,
    sourceRefs: const [
      MemorySourceRef(sourceId: 'scene-1', sourceType: 'scene'),
    ],
    rootSourceIds: const ['scene-1:beat-2'],
    tags: const ['char-liuxi', 'persona'],
    priority: 3,
    tokenCostEstimate: 18,
    createdAtMs: 1777046400000,
  );

  final restored = ThoughtAtom.fromJson(atom.toJson());

  expect(restored.id, atom.id);
  expect(restored.thoughtType, ThoughtType.persona);
  expect(restored.sourceRefs.single.sourceId, 'scene-1');
  expect(restored.rootSourceIds, contains('scene-1:beat-2'));
  expect(restored.confidence, 0.86);
});
```

- [ ] **Step 2: Implement minimal immutable models**

Define:

- `MemorySourceKind`
- `ThoughtType`
- `MemorySourceRef`
- `StoryMemorySource`
- `StoryMemoryChunk`
- `ThoughtAtom`
- `StoryMemoryQuery`
- `StoryMemoryHit`
- `StoryRetrievalPack`

Required fields:

- `projectId`
- `scopeId`
- `sourceRefs`
- `rootSourceIds`
- `visibility`
- `tags`
- `priority`
- `tokenCostEstimate`
- `createdAtMs`

- [ ] **Step 3: Run model tests**

Run:

```bash
flutter test test/story_memory_models_test.dart
```

Expected: all tests pass.

### Task 2: Add Memory Storage Contract And Stub

**Files:**
- Create: `lib/features/story_generation/data/story_memory_storage.dart`
- Create: `lib/features/story_generation/data/story_memory_storage_stub.dart`
- Test: `test/story_memory_storage_io_test.dart`

- [ ] **Step 1: Write storage contract tests against the stub**

Cover:

- save/load sources by project
- save/load chunks by project and scope
- save/load thoughts by project
- clear memory by project
- preserve source traces

- [ ] **Step 2: Implement `StoryMemoryStorage`**

Expose:

```dart
abstract interface class StoryMemoryStorage {
  Future<void> saveSources(String projectId, List<StoryMemorySource> sources);
  Future<List<StoryMemorySource>> loadSources(String projectId);
  Future<void> saveChunks(String projectId, List<StoryMemoryChunk> chunks);
  Future<List<StoryMemoryChunk>> loadChunks(String projectId);
  Future<void> saveThoughts(String projectId, List<ThoughtAtom> thoughts);
  Future<List<ThoughtAtom>> loadThoughts(String projectId);
  Future<void> clearProject(String projectId);
}
```

- [ ] **Step 3: Implement the stub with deterministic ordering**

Sort loaded records by `createdAtMs`, then `id`, so tests and retrieval behavior are stable.

- [ ] **Step 4: Run stub storage tests**

Run:

```bash
flutter test test/story_memory_storage_io_test.dart --plain-name "stub"
```

Expected: stub tests pass.

### Task 3: Add SQLite Memory Storage

**Files:**
- Create: `lib/features/story_generation/data/story_memory_storage_io.dart`
- Modify: `test/story_memory_storage_io_test.dart`

- [ ] **Step 1: Write SQLite persistence tests**

Cover:

- records survive store reconstruction
- different projects are isolated
- thoughts keep `rootSourceIds`
- clearing one project does not clear another

- [ ] **Step 2: Implement SQLite tables**

Use three tables:

- `story_memory_sources`
- `story_memory_chunks`
- `story_thought_atoms`

Store complex fields as JSON strings, following the existing storage style in the repo.

- [ ] **Step 3: Run storage tests**

Run:

```bash
flutter test test/story_memory_storage_io_test.dart
```

Expected: all storage tests pass.

---

## Milestone 2: Local Retrieval MVP

**Purpose:** Make retrieval useful before adding embeddings or external vector stores.

### Task 4: Index Project Material Into Memory Chunks

**Files:**
- Create: `lib/features/story_generation/data/story_memory_indexer.dart`
- Test: `test/story_memory_retriever_test.dart`

- [ ] **Step 1: Write indexer tests**

Verify that the indexer creates chunk types for:

- `world_fact`
- `character_profile`
- `relationship_hint`
- `outline_beat`
- `scene_summary`
- `accepted_state`
- `review_finding`

- [ ] **Step 2: Implement chunk normalization**

Rules:

- trim empty content
- preserve source identity
- assign tags from character ids, scene ids, chapter ids, and world node ids
- estimate token cost with a simple character-based heuristic
- assign `KnowledgeVisibility.publicObservable` for shared story facts and `agentPrivate` for role-scoped persona facts

- [ ] **Step 3: Run retriever tests**

Run:

```bash
flutter test test/story_memory_retriever_test.dart --plain-name "indexer"
```

Expected: indexer tests pass.

### Task 5: Implement Lexical Hybrid Retrieval

**Files:**
- Create: `lib/features/story_generation/data/story_memory_retriever.dart`
- Create: `lib/features/story_generation/data/story_memory_dedupe.dart`
- Test: `test/story_memory_retriever_test.dart`

- [ ] **Step 1: Write retrieval ranking tests**

Cover:

- exact tag match outranks loose text match
- recent accepted scene state outranks old low-priority chunks
- persona query retrieves persona chunks
- plot query retrieves outline and accepted state chunks
- visibility prevents private facts from leaking to the wrong role

- [ ] **Step 2: Implement scoring**

Initial score:

```text
score =
  keywordOverlap * 4
  + tagOverlap * 6
  + priority * 2
  + recencyBoost
  - tokenPenalty
```

Do not add embeddings yet. Keep the scoring deterministic and easy to test.

- [ ] **Step 3: Implement retrieval pack compaction**

Return `StoryRetrievalPack` with:

- `query`
- `hits`
- `sourceRefs`
- `summary`
- `tokenBudget`
- `spentTokenEstimate`
- `deferredHitCount`

- [ ] **Step 4: Run retriever tests**

Run:

```bash
flutter test test/story_memory_retriever_test.dart
```

Expected: all retrieval tests pass.

---

## Milestone 3: Generation Integration

**Purpose:** Use RAG in the real generation flow without destabilizing the current scene pipeline.

### Task 6: Add Memory Retrieval Tools

**Files:**
- Modify: `lib/features/story_generation/data/knowledge_tool_registry.dart`
- Modify: `lib/features/story_generation/data/agentic_rag.dart`
- Test: `test/story_generation_rag_pipeline_test.dart`

- [ ] **Step 1: Write tool tests**

Add tests for tools:

- `get_plot_memory`
- `get_persona_memory`
- `get_foreshadowing_memory`
- `get_state_ledger`
- `get_thought_memory`

Each test should assert:

- returned capsule is compact
- source refs are preserved
- viewer visibility is enforced
- raw unrelated chunks are not injected

- [ ] **Step 2: Register memory tools**

Extend `KnowledgeToolRegistry.availableTools` and route each tool into `StoryMemoryRetriever`.

- [ ] **Step 3: Convert retrieval packs to context capsules**

Capsule requirements:

- `summary` is short and prompt-ready
- `salientFacts` contains the top facts
- `uncertainties` includes deferred hit count and missing evidence
- `visibilityScopes` mirrors the query viewer

- [ ] **Step 4: Run RAG pipeline tests**

Run:

```bash
flutter test test/story_generation_rag_pipeline_test.dart --plain-name "tools"
```

Expected: memory tools produce evidence-backed capsules.

### Task 7: Add Pre-Scene Retrieval

**Files:**
- Modify: `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
- Modify: `lib/features/story_generation/data/scene_context_assembler.dart`
- Test: `test/story_generation_rag_pipeline_test.dart`

- [ ] **Step 1: Write pre-scene retrieval test**

Build a fixture where:

- chapter 1 establishes a lost key
- chapter 2 asks a character to use that key
- retrieval must surface the previous key state before prose generation

- [ ] **Step 2: Run memory indexing before scene execution**

Before director planning, index:

- current world nodes
- current character records
- current outline
- current scene context
- previously accepted scene states
- previously stored thoughts

- [ ] **Step 3: Attach retrieval pack to scene metadata**

Store compact retrieval metadata under `SceneBrief.metadata['retrievalPack']` with JSON-safe values.

- [ ] **Step 4: Run pre-scene retrieval tests**

Run:

```bash
flutter test test/story_generation_rag_pipeline_test.dart --plain-name "pre-scene"
```

Expected: the relevant prior state appears before director planning.

### Task 8: Make Review Evidence-Grounded

**Files:**
- Modify: `lib/features/story_generation/data/scene_review_coordinator.dart`
- Test: `test/story_generation_rag_pipeline_test.dart`

- [ ] **Step 1: Write consistency review tests**

Cover:

- prose contradicting accepted state returns `REWRITE_PROSE`
- missing evidence is reported as uncertainty, not a hard contradiction
- review includes source ids for hard contradictions

- [ ] **Step 2: Add evidence pack to consistency prompt**

Pass:

- accepted facts
- retrieval pack summary
- root source ids
- relevant thought atoms

- [ ] **Step 3: Add repair query generation**

When consistency review fails, create a deterministic `StoryMemoryQuery` from the failure reason and re-run retrieval once before deciding whether to replan.

- [ ] **Step 4: Run review tests**

Run:

```bash
flutter test test/story_generation_rag_pipeline_test.dart --plain-name "review"
```

Expected: contradictions are grounded in retrieved evidence.

---

## Milestone 4: Thought Memory Loop

**Purpose:** Add Thought-Retriever-style self-improving memory after scenes are accepted.

### Task 9: Extract Thought Atoms After Accepted Scenes

**Files:**
- Create: `lib/features/story_generation/data/thought_memory_updater.dart`
- Modify: `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
- Test: `test/thought_memory_updater_test.dart`

- [ ] **Step 1: Write local extraction tests**

Use deterministic local extraction for tests. Given accepted beats and final prose, expect thoughts like:

- persona thought
- plot causality thought
- state thought
- foreshadowing thought

- [ ] **Step 2: Implement local extractor**

The local extractor should work without an LLM by summarizing:

- accepted state changes
- open threats
- role turn withheld info
- review pass results

- [ ] **Step 3: Add optional LLM refinement path**

When real LLM mode is enabled, ask the model for JSON thoughts with:

- `thoughtType`
- `content`
- `confidence`
- `sourceIds`
- `rootSourceIds`
- `tags`

If parsing fails, fall back to local extraction.

- [ ] **Step 4: Run thought updater tests**

Run:

```bash
flutter test test/thought_memory_updater_test.dart
```

Expected: thoughts are extracted with stable source traces.

### Task 10: Add Confidence And Dedup Filtering

**Files:**
- Modify: `lib/features/story_generation/data/thought_memory_updater.dart`
- Modify: `lib/features/story_generation/data/story_memory_dedupe.dart`
- Test: `test/thought_memory_updater_test.dart`

- [ ] **Step 1: Write filtering tests**

Cover:

- confidence below threshold is rejected
- near-duplicate thought is rejected
- thought with no source trace is rejected
- higher-abstraction thought can coexist with its raw source if content is meaningfully different

- [ ] **Step 2: Implement confidence gate**

Default threshold:

```dart
const double defaultThoughtConfidenceThreshold = 0.72;
```

- [ ] **Step 3: Implement deterministic similarity fallback**

Until embeddings exist, use normalized token overlap. Reject when overlap is high and thought type matches.

- [ ] **Step 4: Run thought filtering tests**

Run:

```bash
flutter test test/thought_memory_updater_test.dart --plain-name "filter"
```

Expected: low-quality and redundant thoughts are discarded.

### Task 11: Store And Retrieve Thoughts

**Files:**
- Modify: `lib/features/story_generation/data/story_memory_storage_io.dart`
- Modify: `lib/features/story_generation/data/story_memory_retriever.dart`
- Test: `test/story_generation_rag_pipeline_test.dart`

- [ ] **Step 1: Write thought retrieval tests**

Cover:

- abstract question retrieves thought atoms before raw chunks
- concrete fact query retrieves raw chunks before thought atoms
- thought source trace maps back to raw scene evidence

- [ ] **Step 2: Add abstraction-aware ranking**

Query types:

- `concreteFact`
- `sceneContinuity`
- `persona`
- `causality`
- `foreshadowing`
- `style`

Concrete queries prefer low abstraction. Causality and foreshadowing queries prefer higher abstraction.

- [ ] **Step 3: Run full RAG tests**

Run:

```bash
flutter test test/story_generation_rag_pipeline_test.dart
```

Expected: raw memory and thought memory both contribute to retrieval.

---

## Milestone 5: Audit, Import/Export, And Upgrade Path

**Purpose:** Make the system inspectable, portable, and ready for embeddings.

### Task 12: Add Retrieval Audit Records

**Files:**
- Modify: `lib/app/logging/app_event_log_types.dart`
- Modify: `lib/features/story_generation/data/chapter_generation_orchestrator.dart`
- Test: `test/story_generation_rag_pipeline_test.dart`

- [ ] **Step 1: Write audit event tests**

Assert that scene generation logs:

- memory indexing count
- retrieval query
- selected hit count
- deferred hit count
- thought creation count
- rejected thought count

- [ ] **Step 2: Emit compact retrieval events**

Do not log raw long text. Log ids, counts, source refs, and compact summaries.

- [ ] **Step 3: Run audit tests**

Run:

```bash
flutter test test/story_generation_rag_pipeline_test.dart --plain-name "audit"
```

Expected: retrieval is visible in event logs.

### Task 13: Include Memory In Import/Export

**Files:**
- Modify: `lib/features/import_export/data/project_transfer_service.dart`
- Test: `test/project_transfer_service_test.dart`

- [ ] **Step 1: Write import/export tests**

Export a project with:

- sources
- chunks
- thoughts
- retrieval traces

Import into a clean store and verify all records are present.

- [ ] **Step 2: Add memory payload section**

Add a `storyMemory` section to the project transfer payload. Preserve backward compatibility when the section is absent.

- [ ] **Step 3: Run transfer tests**

Run:

```bash
flutter test test/project_transfer_service_test.dart
```

Expected: projects move with their memory state.

### Task 14: Add Embedding Provider Interface

**Files:**
- Create: `lib/features/story_generation/data/story_embedding_provider.dart`
- Modify: `lib/features/story_generation/data/story_memory_retriever.dart`
- Test: `test/story_memory_retriever_test.dart`

- [ ] **Step 1: Write interface tests with fake embeddings**

Use a fake provider that returns deterministic vectors for:

- character names
- object names
- plot terms

- [ ] **Step 2: Add provider interface**

Expose:

```dart
abstract interface class StoryEmbeddingProvider {
  Future<List<double>> embedText(String text);
  Future<List<List<double>>> embedBatch(List<String> texts);
}
```

- [ ] **Step 3: Add optional semantic score**

Only use semantic score when embeddings are present. Lexical retrieval remains the default and test baseline.

- [ ] **Step 4: Run retriever tests**

Run:

```bash
flutter test test/story_memory_retriever_test.dart --plain-name "embedding"
```

Expected: semantic ranking improves matches without breaking deterministic lexical fallback.

---

## Acceptance Criteria

The first full implementation is complete when:

- A scene can retrieve relevant world, character, outline, prior-scene, state, and thought memory before generation.
- Role agents can request memory by tool intent and receive compact source-backed capsules.
- Consistency review can cite retrieved evidence when rejecting prose.
- Accepted scenes create thought atoms with confidence, dedupe, and source traces.
- Import/export preserves memory records.
- Tests pass for storage, retrieval, thought update, and generation integration.
- The app still supports local fallback mode when no embedding provider or external vector service exists.

---

## Verification Commands

Run after each milestone:

```bash
flutter test test/story_memory_models_test.dart
flutter test test/story_memory_storage_io_test.dart
flutter test test/story_memory_retriever_test.dart
flutter test test/thought_memory_updater_test.dart
flutter test test/story_generation_rag_pipeline_test.dart
```

Run before declaring the whole RAG feature complete:

```bash
flutter test
```

---

## Risks And Controls

- **Risk:** Prompt bloat returns through large retrieval packs.
  - **Control:** Retrieval packs carry token budgets and deferred counts; only compact capsules enter prompts.
- **Risk:** Thought memory stores hallucinated conclusions.
  - **Control:** Reject thoughts without confidence, source traces, or sufficient novelty.
- **Risk:** Private character knowledge leaks across agents.
  - **Control:** Enforce `KnowledgeVisibility` and viewer scopes in retrieval, not only in prompt construction.
- **Risk:** Embedding dependency slows delivery.
  - **Control:** Ship lexical retrieval first; add embeddings behind an optional provider interface.
- **Risk:** Import/export breaks older projects.
  - **Control:** Treat missing `storyMemory` as empty memory during import.

---

## Recommended Execution Order

Build in this order:

1. Milestone 1: storage and models.
2. Milestone 2: deterministic local retrieval.
3. Milestone 3: generation integration.
4. Milestone 4: Thought Memory.
5. Milestone 5: audit, import/export, embeddings.

Do not start embeddings before lexical retrieval and thought storage are passing tests.
