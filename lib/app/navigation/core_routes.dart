import '../../features/projects/presentation/project_list_page.dart';
import '../../features/settings/presentation/settings_shell_page.dart';
import '../../features/workbench/presentation/workbench_shell_page.dart';
import 'app_navigator.dart';

void registerCoreRoutes() {
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
}
