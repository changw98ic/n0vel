import 'package:flutter/widgets.dart';

import 'app/app.dart';

export 'app/app.dart';
export 'app/navigation/reading_route_data.dart';
export 'app/state/app_ai_history_store.dart';
export 'features/sandbox/presentation/sandbox_monitor_page.dart';
export 'features/reading/presentation/reading_mode_page.dart';
export 'features/review_tasks/presentation/review_task_page.dart';
export 'features/audit/presentation/audit_center_page.dart';
export 'features/characters/presentation/character_library_page.dart';
export 'features/import_export/presentation/project_import_export_page.dart';
export 'features/production_board/presentation/production_board_page.dart';
export 'features/projects/presentation/project_list_page.dart';
export 'features/settings/presentation/settings_shell_page.dart';
export 'features/scenes/presentation/scene_management_page.dart';
export 'features/style/presentation/style_panel_page.dart';
export 'features/story_bible/presentation/story_bible_page.dart';
export 'features/versions/presentation/version_history_page.dart';
export 'features/workbench/presentation/workbench_shell_page.dart';
export 'features/worldbuilding/presentation/worldbuilding_page.dart';

void main() {
  runApp(const NovelWriterApp());
}
