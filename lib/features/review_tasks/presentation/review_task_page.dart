import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'review_task_panel.dart';

class ReviewTaskPage extends ConsumerStatefulWidget {
  const ReviewTaskPage({super.key});

  static const titleKey = ValueKey<String>('review-task-page-title');

  @override
  ConsumerState<ReviewTaskPage> createState() => _ReviewTaskPageState();
}

class _ReviewTaskPageState extends ConsumerState<ReviewTaskPage> {
  @override
  Widget build(BuildContext context) {
    final store = ref.watch(reviewTaskStoreProvider);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return DesktopShellFrame(
          header: const DesktopHeaderBar(
            titleKey: ReviewTaskPage.titleKey,
            title: '推演写作 · 修订清单',
            subtitle: '作者待处理的推演事项',
            showBackButton: true,
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
}
