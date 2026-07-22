import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../domain/production_board_models.dart';
import 'production_board_components.dart';

class ProductionBoardPage extends ConsumerStatefulWidget {
  const ProductionBoardPage({super.key});

  static const titleKey = ValueKey<String>('production-board-title');
  static const progressKey = ValueKey<String>('production-board-progress');
  static const lanesKey = ValueKey<String>('production-board-lanes');
  static const recentRunKey = ValueKey<String>('production-board-recent-run');

  @override
  ConsumerState<ProductionBoardPage> createState() =>
      _ProductionBoardPageState();
}

class _ProductionBoardPageState extends ConsumerState<ProductionBoardPage> {
  final ProductionBoardSnapshotBuilder _builder =
      const ProductionBoardSnapshotBuilder();

  @override
  Widget build(BuildContext context) {
    final workspaceStore = ref.watch(appWorkspaceStoreProvider);
    final outlineStore = ref.watch(storyOutlineStoreProvider);
    final generationStore = ref.watch(storyGenerationStoreProvider);
    final runStore = ref.watch(storyGenerationRunStoreProvider);
    final authorFeedbackStore = ref.watch(authorFeedbackStoreProvider);
    final reviewTaskStore = ref.watch(reviewTaskStoreProvider);

    final outline =
        outlineStore.snapshot.projectId == workspaceStore.currentProjectId
        ? outlineStore.snapshot
        : StoryOutlineSnapshot.empty(workspaceStore.currentProjectId);
    final generation =
        generationStore.snapshot.projectId == workspaceStore.currentProjectId
        ? generationStore.snapshot
        : StoryGenerationSnapshot.empty(workspaceStore.currentProjectId);
    final snapshot = _builder.build(
      project: workspaceStore.currentProject,
      workspaceScenes: workspaceStore.scenes,
      outline: outline,
      generation: generation,
      run: runStore.snapshot,
    );

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        titleKey: ProductionBoardPage.titleKey,
        title: '写作进度',
        subtitle: '${snapshot.projectTitle} · 草稿、改稿与导出',
        showBackButton: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          final main = ProductionBoardMain(
            snapshot: snapshot,
            scrollable: !compact,
            onOpenWorkbench: () =>
                AppNavigator.push(context, AppRoutes.workbench),
            onOpenExport: () =>
                AppNavigator.push(context, AppRoutes.importExport),
            onOpenReviewTasks: () =>
                AppNavigator.push(context, AppRoutes.reviewTasks),
            activeFeedbackCount: authorFeedbackStore.items
                .where((item) => item.isActive)
                .length,
            activeReviewTaskCount: reviewTaskStore.openCount,
          );
          final side = ProductionBoardSide(
            snapshot: snapshot,
            compact: compact,
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: AppDesignTokens.space16),
              if (compact)
                Expanded(
                  child: ListView(
                    children: [
                      main,
                      const SizedBox(height: AppDesignTokens.space16),
                      side,
                    ],
                  ),
                )
              else ...[
                Expanded(child: main),
                const SizedBox(width: AppDesignTokens.space16),
                SizedBox(width: 340, child: side),
              ],
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        leftText: '进度 ${snapshot.completedScenes}/${snapshot.totalScenes} 章节',
        rightText: '最近写作：${snapshot.recentRun.statusLabel}',
      ),
    );
  }
}
