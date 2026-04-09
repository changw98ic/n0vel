# Implementation Plan: Refactoring to Strict GetX Architecture

## Executive Summary

This plan migrates a Flutter writing assistant app from DDD+StatefulWidget to the flutter-schema GetX convention. The codebase currently has **23 StatefulWidget pages** across 16 feature modules, **231 setState() calls**, **159 mounted checks**, **47 Get.lazyPut registrations** in a single InitialBinding, and **19 files using TextEditingController**. The target is `lib/modules/` with per-page binding/logic/state/view quartets, a shared BaseController, and no direct repository access from views.

---

## Phase 0: Scaffolding and Shared Infrastructure (PR 1)

**Goal**: Create all base classes, directory structure, and routing infrastructure before touching any pages.

### 0.1 Create `shared/data/base_business/` Directory

**File: `lib/shared/data/base_business/base_controller.dart`**

```dart
abstract class BaseController extends GetxController {
  final _isLoading = false.obs;
  final _errorMessage = Rx<String?>(null);

  bool get isLoading => _isLoading.value;
  String? get errorMessage => _errorMessage.value;

  void setLoading(bool value) => _isLoading.value = value;
  void setError(String? msg) => _errorMessage.value = msg;

  /// Wraps an async operation with loading/error handling.
  /// Returns true on success, false on error.
  Future<bool> runWithLoading(Future<void> Function() action) async {
    try {
      setLoading(true);
      setError(null);
      await action();
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Shows a GetX snackbar for errors.
  void showErrorSnackbar(String message) {
    Get.snackbar('Error', message, snackPosition: SnackPosition.BOTTOM);
  }

  /// Shows a GetX snackbar for success.
  void showSuccessSnackbar(String message) {
    Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  void onClose() {
    // Dispose any TextEditingControllers registered via disposeOnClose()
    super.onClose();
  }
}
```

**Design Rationale**:
- `isLoading` / `errorMessage` cover the pattern seen in 100% of pages: `setState(() { _isLoading = true; _loadError = null; })` followed by try/catch
- `runWithLoading` eliminates the repeated try/catch/setState blocks (seen 23+ times)
- No BuildContext references -- Get.snackbar replaces ScaffoldMessenger.of(context)

**File: `lib/shared/data/base_business/base_page.dart`**

A mixin or utility that provides common page patterns:
```dart
/// Mixin for views that need standard loading/error/empty states.
/// Use with GetView<Controller> or GetX<Controller>.
mixin BasePage {
  Widget loadingIndicator() => const Center(child: CircularProgressIndicator());

  Widget errorState({
    required String title,
    required String description,
    required VoidCallback onRetry,
  }) {
    // Returns AppEmptyState with error icon + retry button
  }

  Widget emptyState({
    required IconData icon,
    required String title,
    required String description,
    Widget? action,
  }) {
    // Returns AppEmptyState
  }
}
```

### 0.2 Create `core/config/` Routing Infrastructure

**File: `lib/core/config/app_routes.dart`**

Extract all route name string literals into constants:
```dart
abstract class AppRoutes {
  static const home = '/';
  static const search = '/search';
  static const workDetail = '/work/:id';
  static const workSettings = '/work/:id/settings';
  static const workCharacters = '/work/:id/characters';
  static const characterNew = '/work/:id/characters/new';
  static const characterDetail = '/work/:workId/characters/:characterId';
  static const characterProfileEdit = '/work/:workId/characters/:characterId/profile';
  static const relationships = '/work/:id/relationships';
  static const items = '/work/:id/items';
  static const locations = '/work/:id/locations';
  static const factions = '/work/:id/factions';
  static const chapterEditor = '/work/:workId/chapter/:chapterId';
  static const review = '/work/:id/review';
  static const aiDetection = '/ai-detection';
  static const timeline = '/work/:id/timeline';
  static const povGeneration = '/work/:id/pov';
  static const statistics = '/work/:id/stats';
  static const readingMode = '/work/:id/read';
  static const aiConfig = '/ai-config';
  static const aiUsageStats = '/work/:id/ai-usage-stats';
  static const workEdit = '/work/:id/edit';
  static const workNew = '/work/new';
}
```

**File: `lib/core/config/app_pages.dart`**

Consolidated GetPage list. Initially identical to current `getx_routes.dart` but importing from the new module paths. This file grows incrementally as each module is migrated.

### 0.3 Create Module Directory Skeleton

Create `lib/modules/` with all module subdirectories:
```
lib/modules/
  work/
    work_list/
    work_detail/
    work_form/
    search/
    db/
    model/
    view/
  editor/
    chapter_editor/
    db/
    model/
    view/
  settings/
    character_list/
    character_detail/
    character_form/
    character_profile_edit/
    faction_list/
    item_list/
    location_list/
    relationship/
    settings_panel/
    db/
    model/
    view/
  ai_config/
    ai_config/
    usage_stats/
    db/
    model/
    view/
  ai_detection/
    ai_detection/
    model/
    view/
  review/
    review_center/
    db/
    model/
    view/
  timeline/
    timeline/
    db/
    model/
    view/
  pov/
    pov_generation/
    db/
    model/
    view/
  reading_mode/
    reader/
    db/
    model/
    view/
  statistics/
    statistics/
    db/
    model/
    view/
  workflow/
    db/
    model/
  story_arc/
    db/
    model/
  inspiration/
    inspiration/
    db/
  dashboard/
    dashboard/
```

### 0.4 Migration Strategy for Empty Modules

- **pov** (empty): DELETE entirely. Merge into `pov_generation` module.
- **reader** (empty): DELETE entirely. Merge into `reading_mode` module.
- **stats** (empty): DELETE entirely. Merge into `statistics` module.

---

## Phase 1: BaseController Pattern and Canonical Example (PR 2)

**Goal**: Establish the conversion pattern with one simple module (dashboard) and one medium module (work_list), then use them as templates.

### Canonical Conversion: DashboardPage

This is the simplest page (1 page, ~380 lines, FutureBuilder pattern, only uses WorkRepository).

#### Step 1: Create State Class

**File: `lib/modules/dashboard/dashboard/dashboard_state.dart`**

```dart
class DashboardState {
  final works = <Work>[].obs;
  // Derived values are computed, not stored as observables
}
```

Extract from the current `_DashboardPageState`:
- `late Future<List<Work>> _worksFuture` becomes `state.works`
- All helper functions (`_totalWords`, `_todayWords`, `_streak`, `_recentWorks`) move into logic

#### Step 2: Create Logic Class

**File: `lib/modules/dashboard/dashboard/dashboard_logic.dart`**

```dart
class DashboardLogic extends BaseController {
  final DashboardState state = DashboardState();
  final WorkRepository _workRepo = Get.find<WorkRepository>();

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    await runWithLoading(() async {
      final works = await _workRepo.getAllWorks();
      state.works.assignAll(works);
    });
  }

  // Business logic extracted from the old State
  int get totalWords => state.works.fold(0, (sum, w) => sum + w.currentWords);
  int get todayWords { /* same logic */ }
  int get streak { /* same logic */ }
  List<Work> get recentWorks { /* same logic */ }
  String todayLabel() { /* same logic */ }
  String formatNumber(int n) { /* same logic */ }
}
```

Key extraction rules:
- Every `setState(() { _variable = value })` becomes `state.variable.value = value` or `state.variable.assignAll(list)`
- Every `mounted` check is eliminated (GetX controllers have lifecycle management via `onClose`)
- Every `ScaffoldMessenger.of(context).showSnackBar(...)` becomes `Get.snackbar(...)`
- Repository `Get.find<XxxRepository>()` calls move from the build/initState into the controller constructor or `onInit`

#### Step 3: Create Binding

**File: `lib/modules/dashboard/dashboard/dashboard_binding.dart`**

```dart
class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardLogic>(() => DashboardLogic());
  }
}
```

Note: WorkRepository is already registered globally in InitialBinding. The binding only registers the page controller.

#### Step 4: Create View

**File: `lib/modules/dashboard/dashboard/dashboard_view.dart`**

```dart
class DashboardPage extends GetView<DashboardLogic> with BasePage {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace FutureBuilder with Obx reactive pattern
    return Obx(() {
      if (controller.isLoading) return loadingIndicator();
      if (controller.errorMessage != null) return errorState(
        title: 'Load Failed',
        description: 'Could not load work data.',
        onRetry: controller.loadData,
      );
      return _buildContent(context);
    });
  }

  Widget _buildContent(BuildContext context) {
    final works = controller.state.works;
    // All the build methods stay here, reading from controller
    // No setState, no FutureBuilder, no mounted checks
  }
}
```

### Canonical Conversion: WorkListPage

This is a medium-complexity page (~520 lines) with:
- Search with debounce
- Multiple lists (_works, _recentFocuses, _resumeFocuses)
- Dialog interactions (WorkFormDialog)
- Bottom sheets
- Multiple async operations

#### State Class

```dart
class WorkListState {
  var works = <Work>[].obs;
  var recentFocuses = <WorkChapterFocus>[].obs;
  var resumeFocuses = <WorkChapterFocus>[].obs;
  var searchQuery = Rx<String?>(null);
  var showArchived = false.obs;
}
```

#### Logic Class

```dart
class WorkListLogic extends BaseController {
  final WorkListState state = WorkListState();
  final WorkRepository _workRepo = Get.find<WorkRepository>();
  final ChapterRepository _chapterRepo = Get.find<ChapterRepository>();
  final ExportService _exportService = Get.find<ExportService>();

  @override
  void onInit() {
    super.onInit();
    loadWorks();
  }

  Future<void> loadWorks() async {
    await runWithLoading(() async {
      final works = await _workRepo.getAllWorks(includeArchived: true);
      final signals = await _loadChapterSignals(works);
      state.works.assignAll(works);
      state.recentFocuses.assignAll(signals.recent);
      state.resumeFocuses.assignAll(signals.resume);
    });
  }

  Future<void> togglePin(Work work) async { ... }
  Future<void> toggleArchive(Work work) async { ... }
  Future<void> exportWork(Work work) async { ... }
  Future<void> editWork(Work work) async { ... }
  Future<void> createNewWork() async { ... }

  void setSearchQuery(String? query) => state.searchQuery.value = query;
  void toggleShowArchived() => state.showArchived.toggle();
  List<Work> get visibleWorks { /* filtering logic */ }
}
```

#### View Class

The View retains all the UI building methods (`_buildContent`, `_buildWorkGrid`, `_buildSectionLabel`, etc.) but reads state from `controller.state.xxx` and calls methods on `controller.xxx()`.

**Special handling for WorkFormDialog**: This is a dialog that returns a result. It stays as a StatefulWidget because dialogs are ephemeral UI components with their own form state. The View calls `showDialog` and passes the result to `controller.handleFormResult(result)`.

---

## Phase 2: Systematic Page Conversion Order (PRs 3-10)

Pages are converted in order of complexity, starting with simplest and building up. Each PR converts one complete module.

### Priority Order

| PR | Module | Pages | Complexity | Notes |
|----|--------|-------|------------|-------|
| 3 | dashboard | 1 | Low | Single page, FutureBuilder only |
| 4 | work | 4 | Medium-High | Multiple pages, shared repos |
| 5 | settings | 9 | High | Most pages, most repos |
| 6 | editor | 1 | Very High | Complex state, timers, undo/redo |
| 7 | ai_config | 2 | Low-Medium | Form-heavy |
| 8 | review + ai_detection + timeline | 3 | Medium | One page each |
| 9 | pov_generation + reading_mode + statistics | 3 | Medium | One page each, merge empties |
| 10 | inspiration + story_arc + workflow | 1 active + 2 data-only | Low | Inspiration has 1 page |

### Per-Page Conversion Checklist (apply to every page)

For each page, follow this exact sequence:

1. **Identify state variables**: List all fields in the `_XxxPageState` class
2. **Create State class**: Move all mutable fields as `.obs` or `Rx<>` variables
3. **Create Logic class**:
   - Extend BaseController
   - Inject repositories via constructor or `Get.find` in `onInit`
   - Move all async methods (initState loaders, button handlers)
   - Replace `setState(() { ... })` with direct `.value = ` or `.assignAll()`
   - Remove all `mounted` checks
   - Replace `ScaffoldMessenger.of(context).showSnackBar(...)` with `Get.snackbar(...)`
   - Replace `Navigator.pop(context)` with `Get.back()`
   - Move business logic (filtering, sorting, computation) into getter methods
4. **Create Binding class**: Register only the Logic controller
5. **Create View class**:
   - Extend `GetView<XxxLogic>` for simple pages
   - Use `GetX<XxxLogic>` if you need `init` or need access to both controller and state
   - Wrap reactive sections in `Obx(() => ...)`
   - Replace `widget.paramName` with `controller.paramName` (route params via `Get.parameters`)
6. **Update route**: Change import in `app_pages.dart` to point to new view file, set new binding
7. **Delete old file**: Remove the old page file from `lib/features/`
8. **Verify**: Hot reload, navigate to page, test all interactions

---

## Phase 3: Complex Widget Handling

### 3.1 Toolbar Widgets (e.g., EditorToolbar)

The current `EditorToolbar` is already a StatelessWidget that takes callback functions. These stay as-is in `lib/modules/editor/view/editor_toolbar.dart`. No conversion needed -- they are pure presentational widgets.

### 3.2 Panel Widgets (e.g., AssistantPanel, StatisticsPanel)

These are currently StatefulWidgets with their own internal state. Two strategies:

**Strategy A: Absorb into parent Logic** (recommended for panels tightly coupled to one page)
- The panel's state moves into the parent page's State class
- The panel becomes a StatelessWidget that receives data and callbacks
- Example: `AssistantPanel` state (generation prompts, results) moves into `ChapterEditorLogic`

**Strategy B: Give panel its own mini-controller** (for panels reused across pages)
- Create a lightweight controller for the panel
- Register it in the parent page's Binding
- Panel uses `GetView<PanelLogic>`

For this codebase, **Strategy A** is appropriate for all panels since they are page-specific.

### 3.3 Dialog Widgets (e.g., WorkFormDialog, ReviewConfigDialog)

**Rule: Keep dialogs as StatefulWidgets.**

Dialogs are ephemeral UI with their own TextEditingController instances and form validation. They do NOT need GetX controllers. The pattern is:

```dart
// In the View (or Logic for complex cases):
final result = await showDialog<WorkFormResult>(
  context: Get.context!,  // or pass context from build method
  builder: (context) => const WorkFormDialog(),
);
if (result != null) {
  controller.handleFormResult(result);
}
```

Move dialog files to `lib/modules/{module}/view/` directory.

### 3.4 The Chapter Editor (Most Complex Page)

The editor has special challenges:
- Multiple TextEditingControllers (_textController, _titleController)
- Timer-based auto-save
- Undo/redo stack
- FocusNode management
- ScrollController

**Approach**: The editor Logic holds all non-UI state:
```dart
class ChapterEditorLogic extends BaseController {
  final ChapterEditorState state = ChapterEditorState();

  // TextEditingControllers stay in the View (they are UI controllers)
  // But the Logic manages the undo/redo stacks and save logic

  Timer? _autoSaveTimer;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  void onTextChanged(String currentText) {
    if (_undoStack.isEmpty || _undoStack.last != currentText) {
      _undoStack.add(currentText);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
    }
    _scheduleAutoSave();
  }

  void undo() { /* pop from undoStack, push to redoStack */ }
  void redo() { /* pop from redoStack, push to undoStack */ }

  Future<void> saveContent(String content) async { ... }
}
```

The View retains TextEditingControllers, FocusNode, ScrollController (these are Flutter UI primitives), but forwards all business logic to the controller:
```dart
class ChapterEditorPage extends StatefulWidget {
  // Still StatefulWidget because of TextEditingControllers
  // BUT all business logic is in the controller
}
```

**Important**: For the editor, we may use `GetBuilder` pattern instead of `Obx` because the text content changes too rapidly for reactive observations. The editor is a special case where StatefulWidget for the View is acceptable, with logic still extracted to the controller.

---

## Phase 4: Import Migration Strategy

### 4.1 Mapping Table (Old Path -> New Path)

| Old | New |
|-----|-----|
| `lib/features/{module}/presentation/pages/{page}.dart` | `lib/modules/{module}/{feature}/{feature}_view.dart` |
| `lib/features/{module}/data/{repo}.dart` | `lib/modules/{module}/db/{repo}.dart` |
| `lib/features/{module}/domain/{model}.dart` | `lib/modules/{module}/model/{model}.dart` |
| `lib/features/{module}/presentation/widgets/{widget}.dart` | `lib/modules/{module}/view/{widget}.dart` |
| `lib/features/{module}/bindings/{binding}.dart` | DELETED (new bindings in module) |
| `lib/core/bindings/initial_binding.dart` | STAYS (global DI) but gets lighter |
| `lib/app/getx_routes.dart` | `lib/core/config/app_pages.dart` |

### 4.2 Migration Order for Imports

1. First, move all `domain/` models to `modules/{module}/model/` (they have zero dependencies on presentation)
2. Then, move all `data/` repositories to `modules/{module}/db/` (they depend only on models and core/database)
3. Then, create the new binding/logic/state/view files alongside the old pages
4. Update `app_pages.dart` imports one module at a time
5. Delete old files only after the new files are verified working

### 4.3 What Stays in InitialBinding

The InitialBinding continues to register:
- AppDatabase
- All repositories (they are singletons shared across pages)
- Core services (AIService, SearchService, ExportService, etc.)

What gets REMOVED from InitialBinding:
- Nothing initially. The InitialBinding stays as-is for backward compatibility.

What gets ADDED to page-level Bindings:
- Page-specific controllers (Logic classes)

---

## Phase 5: Empty Module Merging

### 5.1 pov -> merge into pov_generation

- `lib/features/pov/` has empty data/domain/presentation directories
- DELETE the entire `pov` module
- `lib/features/pov_generation/` becomes `lib/modules/pov/`
- Route `/work/:id/pov` already points to POVGenerationPage -- no route changes needed

### 5.2 reader -> merge into reading_mode

- `lib/features/reader/` has empty directories
- DELETE the entire `reader` module
- `lib/features/reading_mode/` becomes `lib/modules/reading_mode/`

### 5.3 stats -> merge into statistics

- `lib/features/stats/` has empty directories
- DELETE the entire `stats` module
- `lib/features/statistics/` becomes `lib/modules/statistics/`

---

## Phase 6: Verification Steps

### Per-Module Verification (after each PR)

1. **Compile check**: `flutter analyze --no-fatal-infos` must pass
2. **Hot reload**: App starts, navigates to converted page
3. **State reactivity**: Change data in one view, navigate away and back, verify refresh
4. **Route params**: Pages receiving `Get.parameters['id']` correctly extract and use them
5. **Dialog flows**: All showDialog interactions work (create, edit, delete)
6. **Error handling**: Trigger a failure, verify error state displays
7. **Dispose**: Navigate to and away from a page, verify no memory leaks (no dangling timers, controllers)

### Full App Verification (after final PR)

1. `flutter analyze` with zero errors
2. Full navigation coverage: visit every route in the app
3. Data integrity: create a work, add chapters, edit, save, verify persistence
4. AI features: test AI config, POV generation, review, detection
5. Search: global and in-work search
6. Export: verify export still works
7. Backward compatibility: ensure all `Get.toNamed` routes still resolve
8. Performance: verify no unnecessary rebuilds (use Flutter DevTools)

---

## Appendix A: Complete File Inventory

### Pages to Convert (24 total)

| # | Current Path | New Path (view) |
|---|-------------|-----------------|
| 1 | `features/dashboard/presentation/pages/dashboard_page.dart` | `modules/dashboard/dashboard/dashboard_view.dart` |
| 2 | `features/work/presentation/pages/work_list_page.dart` | `modules/work/work_list/work_list_view.dart` |
| 3 | `features/work/presentation/pages/work_detail_page.dart` | `modules/work/work_detail/work_detail_view.dart` |
| 4 | `features/work/presentation/pages/work_form_page.dart` | `modules/work/work_form/work_form_view.dart` |
| 5 | `features/work/presentation/pages/search_page.dart` | `modules/work/search/search_view.dart` |
| 6 | `features/editor/presentation/pages/chapter_editor_page.dart` | `modules/editor/chapter_editor/chapter_editor_view.dart` |
| 7 | `features/settings/presentation/pages/character_list_page.dart` | `modules/settings/character_list/character_list_view.dart` |
| 8 | `features/settings/presentation/pages/character_detail_page.dart` | `modules/settings/character_detail/character_detail_view.dart` |
| 9 | `features/settings/presentation/pages/character_form_page.dart` | `modules/settings/character_form/character_form_view.dart` |
| 10 | `features/settings/presentation/pages/character_profile_edit_page.dart` | `modules/settings/character_profile_edit/character_profile_edit_view.dart` |
| 11 | `features/settings/presentation/pages/faction_list_page.dart` | `modules/settings/faction_list/faction_list_view.dart` |
| 12 | `features/settings/presentation/pages/item_list_page.dart` | `modules/settings/item_list/item_list_view.dart` |
| 13 | `features/settings/presentation/pages/location_list_page.dart` | `modules/settings/location_list/location_list_view.dart` |
| 14 | `features/settings/presentation/pages/relationship_page.dart` | `modules/settings/relationship/relationship_view.dart` |
| 15 | `features/settings/presentation/pages/settings_panel_page.dart` | `modules/settings/settings_panel/settings_panel_view.dart` |
| 16 | `features/ai_config/presentation/pages/ai_config_page.dart` | `modules/ai_config/ai_config/ai_config_view.dart` |
| 17 | `features/ai_config/presentation/pages/usage_stats_page.dart` | `modules/ai_config/usage_stats/usage_stats_view.dart` |
| 18 | `features/ai_detection/presentation/pages/ai_detection_page.dart` | `modules/ai_detection/ai_detection/ai_detection_view.dart` |
| 19 | `features/review/presentation/pages/review_center_page.dart` | `modules/review/review_center/review_center_view.dart` |
| 20 | `features/timeline/presentation/pages/timeline_page.dart` | `modules/timeline/timeline/timeline_view.dart` |
| 21 | `features/pov_generation/presentation/pages/pov_generation_page.dart` | `modules/pov/pov_generation/pov_generation_view.dart` |
| 22 | `features/reading_mode/presentation/pages/reader_page.dart` | `modules/reading_mode/reader/reader_view.dart` |
| 23 | `features/statistics/presentation/pages/statistics_page.dart` | `modules/statistics/statistics/statistics_view.dart` |
| 24 | `features/inspiration/presentation/pages/inspiration_page.dart` | `modules/inspiration/inspiration/inspiration_view.dart` |

### New Files Per Page (4 files each = 96 new files)

For each page above, create:
- `xxx_binding.dart` (~10-15 lines)
- `xxx_logic.dart` (~50-300 lines depending on complexity)
- `xxx_state.dart` (~10-50 lines)
- `xxx_view.dart` (existing build methods adapted)

### Data/Model Files to Move (no changes needed)

Move these files to their new `modules/{module}/db/` or `modules/{module}/model/` locations:
- All `*_repository.dart` files (12 files)
- All `*_service.dart` files in feature data layers (8 files)
- All domain model files (`*.dart` excluding `.freezed.dart` and `.g.dart`)

---

## Appendix B: Route Parameter Handling

Current pattern uses constructor parameters:
```dart
GetPage(
  name: '/work/:id',
  page: () => WorkDetailPage(workId: Get.parameters['id']!),
)
```

New pattern moves parameter extraction into the Logic's `onInit`:
```dart
// In binding:
class WorkDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WorkDetailLogic>(() => WorkDetailLogic());
  }
}

// In logic:
class WorkDetailLogic extends BaseController {
  late String workId;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id']!;
    loadData();
  }
}

// In view:
class WorkDetailPage extends GetView<WorkDetailLogic> {
  // No constructor parameters needed
  // Access workId via controller.workId
}

// In app_pages.dart:
GetPage(
  name: '/work/:id',
  page: () => const WorkDetailPage(),
  binding: WorkDetailBinding(),
)
```

This eliminates the need for `Get.parameters` in the view entirely.

---

## Appendix C: MainShellPage Handling

`MainShellPage` is a StatefulWidget that holds 4 tab pages as a `_pages` list with `_currentIndex`. This is a shell/container, not a business page. Two options:

**Option A (Recommended)**: Keep as StatefulWidget but reference new module imports:
```dart
import 'package:writing_assistant/modules/dashboard/dashboard/dashboard_view.dart';
import 'package:writing_assistant/modules/work/work_list/work_list_view.dart';
import 'package:writing_assistant/modules/inspiration/inspiration/inspiration_view.dart';
import 'package:writing_assistant/modules/ai_config/ai_config/ai_config_view.dart';
```

The shell itself does not need a GetX controller because its only state is `_currentIndex` (a purely UI concern).

**Option B**: Convert to GetX with a simple ShellLogic. This is over-engineering for a tab index.

Choose Option A.

---

## Summary: Estimated Effort

| Phase | Files Changed | Effort |
|-------|--------------|--------|
| Phase 0: Scaffolding | ~10 new files | Low |
| Phase 1: Dashboard + WorkList | ~12 new files, ~4 modified | Medium |
| Phase 2: All modules | ~80 new files, ~30 deletions | High |
| Phase 3: Complex widgets | ~10 files moved | Medium |
| Phase 4: Import migration | ~20 files modified | Medium |
| Phase 5: Empty module cleanup | ~12 directories deleted | Low |
| Phase 6: Verification | 0 files | Medium |
| **Total** | **~130 new files, ~50 modifications, ~40 deletions** | **Large** |
