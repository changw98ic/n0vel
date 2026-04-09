Task statement

Use team mode with 3 executor lanes to complete a high-value optimization pass in the writing_assistant workspace.

Desired outcome

- Improve review data parsing robustness and remove silent JSON failures.
- Reduce duplication in SearchService and add focused unit tests.
- Reduce risk and complexity in ChapterEditorPage with safer autosave/resource handling and smaller extracted helpers where practical.

Known facts and evidence

- `lib/features/review/data/review_repository.dart` has multiple `catch (_) {}` branches around JSON parsing and returns silent fallbacks.
- `lib/core/services/search_service.dart` contains repeated mapping/search methods for works, chapters, characters, items, locations, and factions.
- `lib/features/editor/presentation/pages/chapter_editor_page.dart` is a large stateful widget with autosave timer, undo/redo stacks, and multiple controllers.
- `test/unit/`, `test/integration/`, and `test/widget/` exist, but test coverage is effectively empty.

Constraints

- No new dependencies.
- Keep diffs small, reviewable, and reversible.
- Run verification after changes.
- Focus on the highest-value items from the previously identified optimization list rather than broad speculative cleanup.

Unknowns and open questions

- Exact unit-test seam quality for repositories/services without introducing broad mock frameworks.
- Whether ChapterEditorPage can be meaningfully split without cascading generated-code or routing changes.
- Whether Flutter analyze/test runs are clean in the current environment.

Likely codebase touchpoints

- `lib/features/review/data/review_repository.dart`
- `lib/core/services/search_service.dart`
- `lib/features/editor/presentation/pages/chapter_editor_page.dart`
- `test/unit/**`
