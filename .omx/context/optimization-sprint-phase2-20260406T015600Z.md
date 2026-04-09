Task statement

Continue optimization in team mode after phase 1 completed search/review/editor risk reduction.

Desired outcome

- Reduce complexity in `ai_config_page.dart` by extracting coherent sub-widgets or helper structures.
- Reduce complexity and lifecycle risk in `reader_page.dart`, especially around progress/session saving.
- Audit stateful resource disposal across the repo and patch obvious leaks or missing cleanup in high-signal files.

Known facts and evidence

- `lib/features/ai_config/presentation/pages/ai_config_page.dart` is still a very large page with multiple tabs and form controllers.
- `lib/features/reading_mode/presentation/pages/reader_page.dart` uses `ScrollController`, `Timer`, and reading-session persistence paths with silent catches.
- Earlier optimization already tightened `chapter_editor_page.dart` autosave lifecycle.
- Previous review highlighted broad concern around controller/timer disposal across the repo.

Constraints

- No new dependencies.
- Keep diffs reviewable and local.
- Prefer extraction over architectural rewrite.
- Run targeted verification after changes.

Unknowns and open questions

- Which files outside `ai_config_page.dart` and `reader_page.dart` have the highest-value cleanup opportunities.
- Whether `reader_page.dart` has existing stale-save or dispose-order bugs beyond the obvious timer handling.
- How much widget extraction can be done without forcing route/binding changes.

Likely codebase touchpoints

- `lib/features/ai_config/presentation/pages/ai_config_page.dart`
- `lib/features/reading_mode/presentation/pages/reader_page.dart`
- high-signal `StatefulWidget` files found by controller/timer/dispose audit
