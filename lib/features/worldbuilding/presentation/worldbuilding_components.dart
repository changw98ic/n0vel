import 'package:flutter/material.dart';

import '../../../app/widgets/desktop_shell.dart';

class WorldbuildingListButton extends StatelessWidget {
  const WorldbuildingListButton({
    this.buttonKey,
    required this.label,
    this.selected = false,
    required this.onPressed,
    super.key,
  });

  final Key? buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class WorldbuildingInfoBlock extends StatelessWidget {
  const WorldbuildingInfoBlock({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class WorldbuildingEditableTextField extends StatelessWidget {
  const WorldbuildingEditableTextField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    super.key,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class WorldbuildingStateCard extends StatelessWidget {
  const WorldbuildingStateCard({
    required this.title,
    required this.message,
    required this.accent,
    super.key,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: desktopPalette(context).subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: desktopPalette(context).borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class WorldbuildingCallToActionState extends StatelessWidget {
  const WorldbuildingCallToActionState({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class WorldbuildingCenteredPanelState extends StatelessWidget {
  const WorldbuildingCenteredPanelState({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class WorldbuildingDeleteOverlay extends StatelessWidget {
  const WorldbuildingDeleteOverlay({
    required this.nodeTitle,
    this.onCancel,
    this.onConfirm,
    super.key,
  });

  final String nodeTitle;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99F6F0E6),
      child: Center(
        child: Container(
          width: 760,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: desktopPalette(context).surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: desktopPalette(context).borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('删除关联节点？', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                '节点"$nodeTitle"仍被场景引用。删除该节点会导致相关场景失去世界观绑定。\n\n请选择先取消、或在未来版本中进入连带删除流程。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              WorldbuildingInfoBlock(title: '当前层级', message: '$nodeTitle\n规则摘要\n引用场景'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: onCancel, child: const Text('取消')),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: onConfirm, child: const Text('确认删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
