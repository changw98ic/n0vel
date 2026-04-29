import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../data/review_task_store.dart';
import 'review_task_panel.dart';

class ReviewTaskPage extends StatefulWidget {
  const ReviewTaskPage({super.key});

  static const titleKey = ValueKey<String>('review-task-page-title');

  @override
  State<ReviewTaskPage> createState() => _ReviewTaskPageState();
}

class _ReviewTaskPageState extends State<ReviewTaskPage> {
  bool _isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final store = ReviewTaskScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return DesktopShellFrame(
          header: const DesktopHeaderBar(
            titleKey: ReviewTaskPage.titleKey,
            title: 'Review Tasks',
            subtitle: '审查发现、修订任务和处理状态',
            showBackButton: true,
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopMenuDrawerRegion(
                isOpen: _isDrawerOpen,
                onHandleTap: () {
                  setState(() {
                    _isDrawerOpen = !_isDrawerOpen;
                  });
                },
                items: _menuItems(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ReviewTaskPanel(store: store, title: '审查任务队列'),
              ),
            ],
          ),
          statusBar: DesktopStatusStrip(
            leftText: '${store.openCount} 个活跃任务',
            rightText: '${store.tasks.length} 个任务已记录',
          ),
        );
      },
    );
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return buildDesktopWorkspaceMenuItems(
      selected: DesktopWorkspaceSection.reviewTasks,
      onShelf: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onProductionBoard: () =>
          AppNavigator.push(context, AppRoutes.productionBoard),
      onWorkbench: () => AppNavigator.push(context, AppRoutes.workbench),
      onReviewTasks: () {
        setState(() {
          _isDrawerOpen = false;
        });
      },
      onStyle: () => AppNavigator.push(context, AppRoutes.style),
      onScenes: () => AppNavigator.push(context, AppRoutes.scenes),
      onCharacters: () => AppNavigator.push(context, AppRoutes.characters),
      onWorldbuilding: () =>
          AppNavigator.push(context, AppRoutes.worldbuilding),
      onStoryBible: () => AppNavigator.push(context, AppRoutes.storyBible),
      onAudit: () => AppNavigator.push(context, AppRoutes.audit),
      onSettings: () => AppNavigator.push(context, AppRoutes.settings),
    );
  }
}
