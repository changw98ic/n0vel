import 'dart:io';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/story_generation/data/evaluation/agent_evaluation_sandbox_seal_verifier.dart';

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

export 'features/versions/presentation/version_history_page.dart';
export 'features/workbench/presentation/workbench_shell_page.dart';
export 'features/worldbuilding/presentation/worldbuilding_page.dart';

Future<void> main(List<String> arguments) async {
  final verifierExitCode = runAgentEvaluationSealVerifierCommand(arguments);
  if (verifierExitCode != null) {
    await stdout.flush();
    await stderr.flush();
    exit(verifierExitCode);
  }
  runApp(const NovelWriterApp());
}
