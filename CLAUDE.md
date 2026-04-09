# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-powered writing assistant for novel authors built with Flutter. Supports character management, chapter editing with AI assistance, workflow automation, and AI detection features.

## Build Commands

```bash
# Get dependencies
flutter pub get

# Generate code (drift, freezed, json_serializable, riverpod)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation during development
dart run build_runner watch --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Architecture

### Three-Layer GetX Structure (flutter-schema)
- **modules/** (top) — Business pages, each page = binding + logic + state + view
- **core/** (middle) — Config, routing, services, database, utils
- **shared/** (bottom) — BaseController, BasePage, reusable widgets

### Module Page Pattern
Each page under `lib/modules/{module}/{page}/` has 4 files:
- `xxx_binding.dart` — Dependency injection (registers Logic via `Get.lazyPut`)
- `xxx_logic.dart` — Business logic, extends `BaseController`, calls repositories
- `xxx_state.dart` — Reactive state class with `.obs` variables
- `xxx_view.dart` — UI, uses `GetView<XxxLogic>` with `Obx` for reactive sections

### Core Modules (`lib/core/`)
- `config/` — Route constants (`app_routes.dart`), route table (`app_pages.dart`)
- `bindings/` — `InitialBinding` for global DI (database, all repositories, services)
- `database/` — Drift ORM with SQLite, table definitions in `tables/`
- `services/ai/` — AI provider abstraction, model configs, caching
- `services/workflow_service.dart` — Workflow nodes (AI, condition, parallel, review)
- `models/` — Base classes (Entity, Searchable, Exportable, Hierarchical)
- `utils/` — Debounce, text utils, slugify, duration formatter

### Shared Modules (`lib/shared/`)
- `data/base_business/base_controller.dart` — `BaseController` with loading/error state, snackbar helpers
- `data/base_business/base_page.dart` — `BasePage` mixin with loadingIndicator/errorState/emptyState
- `widgets/` — Generic list, filter bar

### Data Layer (still in `lib/features/`)
- `features/{module}/data/` — Repositories (Drift-based, return Futures)
- `features/{module}/domain/` — freezed models, domain types

### Key Patterns
- **State Management**: GetX with reactive `.obs` variables and `Obx` widgets
- **Routing**: GetX routing (`GetMaterialApp`), routes defined in `core/config/app_pages.dart`
- **DI**: Page-level Bindings + global `InitialBinding`
- **Database**: Drift ORM with typed SQL, FTS5 full-text search for chapters
- **Models**: freezed for immutable value objects and domain models
- **AI Providers**: Abstract `AIProvider` interface with registry pattern; supports OpenAI, Anthropic, Ollama, Azure, custom endpoints

### Database Tables
`Works` → `Volumes` → `Chapters` (hierarchical), `Characters` with `CharacterProfiles`, `RelationshipHeads`/`Events`, `Items`/`Locations`, `Factions`/`Events`, `AiTasks`, `WorkflowNodeRuns`/`Checkpoints`

### Model Tiers
AI models organized by tier: `thinking` (complex reasoning), `middle` (balanced), `fast` (quick responses). Configured via `ModelConfig` with function-to-model mapping.

## Code Generation

This project relies heavily on code generation. After modifying:
- Drift tables (`tables/*.dart`): Run `dart run build_runner build`
- freezed models: Add `part 'file.freezed.dart';` and `part 'file.g.dart';`
- Riverpod providers: Use `@riverpod` annotation, add `part 'file.g.dart';`
