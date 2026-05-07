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
            title: '改稿 · 修订清单',
            subtitle: '作者待处理的改稿事项',
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
                child: ReviewTaskPanel(store: store, title: '改稿清单'),
              ),
            ],
          ),
          statusBar: DesktopStatusStrip(
            leftText: '${store.openCount} 个待处理事项',
            rightText: '${store.tasks.length} 条修订记录',
          ),
        );
      },
    );
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return buildDesktopWorkspaceMenuItems(
      selected: DesktopWorkspaceSection.reviewTasks,
      onShelf: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onWorkbench: () => AppNavigator.push(context, AppRoutes.workbench),
      onWorkSettings: () =>
          AppNavigator.push(context, AppRoutes.workSettingsHub),
      onRevision: () {
        setState(() {
          _isDrawerOpen = false;
        });
      },
      onReading: () => AppNavigator.push(context, AppRoutes.scenes),
      onSettings: () => AppNavigator.push(context, AppRoutes.settings),
    );
  }
}
