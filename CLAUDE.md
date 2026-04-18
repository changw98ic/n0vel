# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-powered writing assistant (写作助手) for novel authors. Desktop-first Flutter app targeting Windows with `window_manager`. Locale is zh-CN only.

## Build Commands

```bash
flutter pub get                                                    # Get dependencies
dart run build_runner build --delete-conflicting-outputs           # Code gen (drift, freezed, json_serializable)
dart run build_runner watch --delete-conflicting-outputs           # Watch mode for code gen
flutter run                                                        # Run the app
flutter analyze                                                    # Analyze code

# Tests
flutter test                                                       # All tests
flutter test test/unit/                                            # Unit tests only
flutter test test/unit/features/editor/                            # Single feature's tests
flutter test test/integration/agent_integration_test.dart          # Single test file
flutter test --name "test pattern"                                 # By test name pattern
```

## Architecture

### Three-Layer GetX Structure (flutter-schema)
- **modules/** (top) — UI pages, each page = binding + logic + state + view
- **core/** (middle) — Config, routing, services, database, utils
- **shared/** (bottom) — BaseController, BasePage, reusable widgets

### `features/` vs `modules/` — Data vs UI Split
- `lib/features/{module}/data/` — Repositories (Drift-based, return Futures)
- `lib/features/{module}/domain/` — freezed models, domain types
- `lib/modules/{module}/` — GetX pages (binding + logic + state + view) consuming the data layer

Legacy `lib/modules/**/db/` and `lib/modules/**/model/` copies have been retired; keep repositories in `features/*/data` and models in `features/*/domain`

### Module Page Pattern
Each page under `lib/modules/{module}/{page}/` has 4 files:
- `xxx_binding.dart` — Dependency injection (registers Logic via `Get.lazyPut`)
- `xxx_logic.dart` — Business logic, extends `BaseController`, calls repositories
- `xxx_state.dart` — Reactive state class with `.obs` variables
- `xxx_view.dart` — UI, uses `GetView<XxxLogic>` with `Obx` for reactive sections

### Key GetX Patterns
- **DI**: Page-level Bindings + global `InitialBinding` (registers all repos and services). All registrations use `fenix: true` to allow re-creation after disposal.
- **Routing**: `GetMaterialApp` with routes in `core/config/app_pages.dart`, constants in `app_routes.dart`
- **State**: Reactive `.obs` variables observed via `Obx` widgets
- **Database**: Drift ORM with typed SQL, FTS5 full-text search for chapters

### Database Tables
`Works` → `Volumes` → `Chapters` (hierarchical), `Characters` with `CharacterProfiles`, `RelationshipHeads`/`Events`, `Items`/`Locations`, `Factions`/`Events`, `AiTasks`, `WorkflowNodeRuns`/`Checkpoints`, `AgentRuns`, `ChatTables`, `StoryArcs`, `Inspirations`, `WritingStats`, `POVTemplates`, `ReadingProgress`

### Core Services (`lib/core/services/`)
Key services registered in `InitialBinding`:
- `AIService` — AI provider abstraction with prompt caching, streaming, token tracking
- `AgentService` — ReAct (Reason-Act-Observe) loop for multi-step AI tasks, emits `AgentEvent` stream
- `ChatService` — AI chat with context compression and agent integration
- `WorkflowService` — DAG-based workflow engine (AI nodes, condition, parallel, review)
- `WritingAssistService` — Continuation, dialogue, scene description
- `CharacterSimulationService` — Behavior, dialogue, psychological reasoning
- `ExtractionService` / `EntityCreationService` — Extract and create entities from text

## AI Architecture

### Provider Registry
Abstract `AIProvider` interface with `AIProviderRegistry`. Supported providers: OpenAI, Anthropic, Ollama, Azure OpenAI, Custom (any OpenAI-compatible endpoint). Registered in `AIService._registerDefaultProviders()`.

### Model Tiers
Three-tier model system defined in `model_tier.dart`:
- **thinking** — Character simulation, POV generation, entity creation
- **middle** — Review, extraction, consistency/OOC/AI-style/timeline checks, pacing analysis
- **fast** — Continuation, dialogue, chat

Each `AIFunction` enum value maps to a default tier. Users can override via `ModelConfig`.

### Agent Service (ReAct Loop)
`AgentService.run()` executes a Reason-Act-Observe loop (max 10 iterations). It uses:
- `ToolRegistry` — 18 registered tools (search, generate, analyze, CRUD for works/volumes/chapters/characters/items/locations/factions/inspirations, extraction, consistency check)
- `ContextManager` — Context window compression
- Emits `Stream<AgentEvent>`: `AgentThinking`, `AgentAction`, `AgentObservation`, `AgentResponseChunk`, `AgentResponse`, `AgentError`

### AI Request Flow
`AIService.generate()` resolves model config → checks cache → calls provider → records usage → returns `AIResponse` with content, tokens, timing, and optional tool calls.

## Code Generation

This project relies heavily on code generation. After modifying:
- Drift tables (`database/tables/*.dart`): Run `dart run build_runner build`
- freezed models: Add `part 'file.freezed.dart';` and `part 'file.g.dart';`
- The generated files (`.freezed.dart`, `.g.dart`, `.drift.dart`) are committed but should be regenerated after model changes

## Test Structure
- `test/unit/` — Unit tests organized by `core/`, `features/`, `modules/`
- `test/integration/` — Integration tests (agent, full pipeline, real DB tests)
- `test/driver/` — Flutter driver tests for workflow E2E

## Flutter Rules

- **禁止使用 dart-mcp-server 进行代码校验或写入**：非调试模式下，不得使用 MCP（dart-mcp-server）工具对代码进行分析（`analyze_files`）、格式化（`dart_format`）或修改（`dart_fix`）。统一使用 `flutter analyze` 命令行工具。
