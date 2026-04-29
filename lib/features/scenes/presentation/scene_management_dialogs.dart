import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_shell.dart';
import 'scene_management_widgets.dart';

Future<void> showSceneDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required ValueChanged<String> onConfirm,
  Key? fieldKey,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: title,
        description: '创建后会出现在当前项目的场景列表中，并立即可在工作台中继续写作。',
        body: SceneDialogField(
          label: '场景标题',
          child: TextField(
            key: fieldKey,
            controller: controller,
            decoration: const InputDecoration(hintText: '输入场景标题'),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  if (result == null || result.trim().isEmpty) {
    return;
  }
  onConfirm(result);
}

Future<void> showChapterDialog(
  BuildContext context, {
  required String initialValue,
  required ValueChanged<String> onConfirm,
  Key? fieldKey,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: '编辑章节标签',
        description: '章节标签会影响场景列表分组、工作台路径提示以及阅读模式的章节边界文案。',
        body: SceneDialogField(
          label: '章节标签',
          child: TextField(
            key: fieldKey,
            controller: controller,
            decoration: const InputDecoration(hintText: '例如：第 4 章 / 场景 01'),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  if (result == null || result.trim().isEmpty) {
    return;
  }
  onConfirm(result);
}

Future<void> showSummaryDialog(
  BuildContext context, {
  required String initialValue,
  required ValueChanged<String> onConfirm,
  Key? fieldKey,
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: '编辑场景摘要',
        description: '摘要会在场景管理、工作台资源面板和审计跳转提示中复用，应优先概括冲突、线索与当前目标。',
        width: 760,
        body: SceneDialogField(
          label: '场景摘要',
          child: TextField(
            key: fieldKey,
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '输入场景摘要'),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  if (result == null || result.trim().isEmpty) {
    return;
  }
  onConfirm(result);
}

Future<void> confirmDeleteScene(
  BuildContext context, {
  required String sceneTitle,
  required VoidCallback onConfirm,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: '删除场景',
        description: '删除后会从当前项目的场景列表中移除，工作台会自动切换到相邻场景，并同步刷新相关引用摘要。',
        body: SceneDialogField(
          label: '当前场景',
          child: Text(
            sceneTitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  if (shouldDelete == true) {
    onConfirm();
  }
}
