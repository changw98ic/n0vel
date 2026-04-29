import 'package:flutter/material.dart';

import 'desktop_shell.dart';

class AppDialogField extends StatelessWidget {
  const AppDialogField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? description,
  required Widget body,
  String cancelText = '取消',
  String confirmText = '确认',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: title,
        description: description,
        body: body,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  ).then((value) => value == true);
}

Future<String?> showAppTextInputDialog({
  required BuildContext context,
  required String title,
  String? description,
  required String hintText,
  String initialValue = '',
  int maxLines = 1,
  Key? fieldKey,
  String cancelText = '取消',
  String confirmText = '保存',
  double width = 720,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: title,
        description: description,
        width: width,
        body: TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}

Future<void> showAppMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
  String dismissText = '确定',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: title,
        body: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dismissText),
          ),
        ],
      );
    },
  );
}
