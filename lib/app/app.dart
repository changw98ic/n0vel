import 'package:flutter/material.dart';

import 'di/service_registration.dart';
import 'di/service_registry.dart';
import 'di/service_scope.dart';
import 'logging/app_event_log.dart';
import 'navigation/route_registration.dart';
import 'state/app_ai_history_store.dart';
import 'state/app_draft_store.dart';
import 'state/app_scene_context_store.dart';
import 'state/app_settings_store.dart';
import 'state/app_simulation_store.dart';
import 'state/app_version_store.dart';
import 'state/app_workspace_store.dart';
import '../features/projects/presentation/project_list_page.dart';
import '../features/author_feedback/data/author_feedback_store.dart';
import '../features/review_tasks/data/review_task_store.dart';
import 'theme/app_theme.dart';

class NovelWriterApp extends StatefulWidget {
  const NovelWriterApp({super.key, this.home});

  final Widget? home;

  @override
  State<NovelWriterApp> createState() => _NovelWriterAppState();
}

class _NovelWriterAppState extends State<NovelWriterApp> {
  late final ServiceRegistry _registry;

  @override
  void initState() {
    super.initState();
    registerAppRoutes();
    _registry = ServiceRegistry();
    registerAppServices(_registry);
  }

  @override
  void dispose() {
    _registry.disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventLog = _registry.resolve<AppEventLog>();
    final settingsStore = _registry.resolve<AppSettingsStore>();
    final workspaceStore = _registry.resolve<AppWorkspaceStore>();
    final aiHistoryStore = _registry.resolve<AppAiHistoryStore>();
    final sceneContextStore = _registry.resolve<AppSceneContextStore>();
    final simulationStore = _registry.resolve<AppSimulationStore>();
    final draftStore = _registry.resolve<AppDraftStore>();
    final versionStore = _registry.resolve<AppVersionStore>();
    final authorFeedbackStore = _registry.resolve<AuthorFeedbackStore>();
    final reviewTaskStore = _registry.resolve<ReviewTaskStore>();

    return ServiceScope(
      registry: _registry,
      child: AppEventLogScope(
        log: eventLog,
        child: AppDraftScope(
          store: draftStore,
          child: AppAiHistoryScope(
            store: aiHistoryStore,
            child: AppVersionScope(
              store: versionStore,
              child: AppSceneContextScope(
                store: sceneContextStore,
                child: AppSettingsScope(
                  store: settingsStore,
                  child: AuthorFeedbackScope(
                    store: authorFeedbackStore,
                    child: ReviewTaskScope(
                      store: reviewTaskStore,
                      child: AppSimulationScope(
                        store: simulationStore,
                        child: ListenableBuilder(
                          listenable: settingsStore,
                          builder: (context, child) {
                            return AppWorkspaceScope(
                              store: workspaceStore,
                              child: MaterialApp(
                                debugShowCheckedModeBanner: false,
                                title: '小说工作台',
                                theme: AppTheme.light(),
                                darkTheme: AppTheme.dark(),
                                themeMode: settingsStore.snapshot.themeMode,
                                home: widget.home ?? const ProjectListPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
