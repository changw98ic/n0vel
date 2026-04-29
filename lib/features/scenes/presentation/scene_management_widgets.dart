import 'package:flutter/material.dart';

import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/desktop_shell.dart';

class SceneListButton extends StatelessWidget {
  const SceneListButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final fill = selected ? palette.canvas : palette.surface;
    final border = selected ? palette.borderStrong : palette.border;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SceneDetailField extends StatelessWidget {
  const SceneDetailField({
    super.key,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
            maxLines: multiline ? null : 1,
            overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class SceneActionRow extends StatelessWidget {
  const SceneActionRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class SceneDialogField extends StatelessWidget {
  const SceneDialogField({
    super.key,
    required this.label,
    required this.child,
  });

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

class SceneChapterGroup {
  const SceneChapterGroup({
    required this.chapterLabel,
    required this.scenes,
  });

  final String chapterLabel;
  final List<SceneRecord> scenes;
}

