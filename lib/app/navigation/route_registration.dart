import '../../features/audit/presentation/audit_center_page.dart';
import '../../features/characters/presentation/character_library_page.dart';
import '../../features/import_export/presentation/project_import_export_page.dart';
import '../../features/production_board/presentation/production_board_page.dart';
import '../../features/projects/presentation/project_list_page.dart';
import '../../features/reading/presentation/reading_mode_page.dart';
import '../../features/review_tasks/presentation/review_task_page.dart';
import '../../features/sandbox/presentation/sandbox_monitor_page.dart';
import '../../features/scenes/presentation/scene_management_page.dart';
import '../../features/settings/presentation/settings_shell_page.dart';
import '../../features/style/presentation/style_panel_page.dart';
import '../../features/story_bible/presentation/story_bible_page.dart';
import '../../features/versions/presentation/version_history_page.dart';
import '../../features/workbench/presentation/workbench_shell_page.dart';
import '../../features/worldbuilding/presentation/worldbuilding_page.dart';
import 'app_navigator.dart';
import 'reading_route_data.dart';

void registerAppRoutes() {
  AppNavigator.register(
    AppRoutes.shelf,
    (context, _) => const ProjectListPage(),
  );
  AppNavigator.register(
    AppRoutes.workbench,
    (context, _) => const WorkbenchShellPage(),
  );
  AppNavigator.register(
    AppRoutes.settings,
    (context, _) => const SettingsShellPage(),
  );
  AppNavigator.register(
    AppRoutes.characters,
    (context, _) => const CharacterLibraryPage(),
  );
  AppNavigator.register(
    AppRoutes.worldbuilding,
    (context, _) => const WorldbuildingPage(),
  );
  AppNavigator.register(
    AppRoutes.scenes,
    (context, _) => const SceneManagementPage(),
  );
  AppNavigator.register(
    AppRoutes.style,
    (context, _) => const StylePanelPage(),
  );
  AppNavigator.register(
    AppRoutes.storyBible,
    (context, _) => const StoryBiblePage(),
  );
  AppNavigator.register(
    AppRoutes.audit,
    (context, _) => const AuditCenterPage(),
  );
  AppNavigator.register(
    AppRoutes.importExport,
    (context, _) => const ProjectImportExportPage(),
  );
  AppNavigator.register(
    AppRoutes.productionBoard,
    (context, _) => const ProductionBoardPage(),
  );
  AppNavigator.register(
    AppRoutes.reviewTasks,
    (context, _) => const ReviewTaskPage(),
  );
  AppNavigator.register(
    AppRoutes.versions,
    (context, _) => const VersionHistoryPage(),
  );
  AppNavigator.register(AppRoutes.reading, (context, args) {
    return ReadingModePage(session: args as ReadingSessionData?);
  });
  AppNavigator.register(AppRoutes.sandbox, (context, args) {
    final params = args as SandboxRouteArgs?;
    return SandboxMonitorPage(
      failureMode: params?.failureMode ?? false,
      previewStatus: params?.previewStatus,
    );
  });
}
