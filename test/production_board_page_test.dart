import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/main.dart';

void main() {
  setUp(() {
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
    AuthorFeedbackStore.debugStorageOverride = InMemoryAuthorFeedbackStorage();
    ReviewTaskStore.debugStorageOverride = InMemoryReviewTaskStorage();
    StoryGenerationStore.debugStorageOverride =
        InMemoryStoryGenerationStorage();
    StoryGenerationRunStore.debugStorageOverride =
        InMemoryStoryGenerationRunStorage();
    StoryOutlineStore.debugStorageOverride = InMemoryStoryOutlineStorage();
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
    AuthorFeedbackStore.debugStorageOverride = null;
    ReviewTaskStore.debugStorageOverride = null;
    StoryGenerationStore.debugStorageOverride = null;
    StoryGenerationRunStore.debugStorageOverride = null;
    StoryOutlineStore.debugStorageOverride = null;
  });

  testWidgets('production board renders progress, lanes, run, and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NovelWriterApp(home: ProductionBoardPage()));
    await tester.pump();

    expect(find.byKey(ProductionBoardPage.titleKey), findsOneWidget);
    expect(find.byKey(ProductionBoardPage.progressKey), findsOneWidget);
    expect(find.byKey(ProductionBoardPage.recentRunKey), findsOneWidget);
    expect(find.text('继续生成'), findsOneWidget);
    expect(find.text('打开工作台'), findsAtLeastNWidgets(1));
    expect(find.text('Review Tasks'), findsOneWidget);
    expect(find.text('打开审查任务'), findsOneWidget);
    expect(find.text('作品圣经'), findsOneWidget);
    expect(find.text('导出'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.byKey(ProductionBoardPage.lanesKey),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(ProductionBoardPage.lanesKey), findsOneWidget);
  });
}
