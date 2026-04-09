# AGENTS.md

## Commands

```bash
flutter pub get                                    # Install deps
dart run build_runner build --delete-conflicting-outputs  # Codegen (required after model/db/provider changes)
flutter run                                        # Run app
flutter test                                       # Run tests
flutter analyze                                    # Lint
```

## Code Generation

Run `build_runner` after any change to:
- Drift tables (`lib/core/database/tables/*.dart`)
- `@riverpod` providers (adds `.g.dart`)
- `freezed` models (adds `.freezed.dart` and `.g.dart`)
- `json_serializable` models (adds `.g.dart`)

Files with generated parts must declare: `part 'foo.g.dart';` and/or `part 'foo.freezed.dart';`

## Architecture

**Entry**: `lib/main.dart` → `lib/app/app.dart` (`WritingAssistantApp`)

**Features** (`lib/features/`): 14 feature modules using data/domain/presentation layering:
- `work` → `volume` → `chapter` hierarchy
- `editor`, `reader`, `reading_mode` - writing/reading surfaces
- `ai_config`, `ai_detection` - AI provider setup and detection
- `pov`, `pov_generation`, `workflow` - POV and workflow automation
- `review`, `settings`, `statistics`/`stats`, `timeline`

**Core** (`lib/core/`):
- `database/` - Drift ORM with SQLite, FTS5 search, tables in `tables/`
- `services/ai/` - AI provider registry (OpenAI, Anthropic, Ollama, Azure, custom)
- `services/workflow_service.dart` - Workflow nodes (AI, condition, parallel, review)

**Stack**: Riverpod (generated), Drift, freezed, go_router, dio

## Testing

Test dirs exist (`test/unit/`, `test/widget/`, `test/integration/`) but are mostly empty. Only `widget_test.dart` has content. Run `flutter test` for all tests.

## Notes

- No CI workflows, pre-commit hooks, or Makefile
- SDK constraint: Dart ^3.11.4
- Assets: `assets/images/`, `assets/templates/`
- L10n: `lib/l10n/` directory present
- See `CLAUDE.md` for detailed architecture and database schema
