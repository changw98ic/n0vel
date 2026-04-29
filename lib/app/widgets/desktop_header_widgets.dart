import 'package:flutter/material.dart';

import 'desktop_theme.dart';

class DesktopHeaderBar extends StatelessWidget {
  const DesktopHeaderBar({
    super.key,
    required this.title,
    this.titleKey,
    this.subtitle,
    this.actions = const [],
    this.showBackButton = false,
  });

  final String title;
  final Key? titleKey;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              constraints.maxWidth < DesktopLayoutTokens.narrowBreakpoint;
          final titleBlock = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, key: titleKey, style: theme.textTheme.titleMedium),
              if (subtitle != null)
                Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          );
          final actionsBlock = actions.isNotEmpty
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                )
              : null;

          if (narrow) {
            return Container(
              width: double.infinity,
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showBackButton) ...[
                        BackButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: titleBlock),
                    ],
                  ),
                  if (actionsBlock != null) ...[
                    const SizedBox(height: 8),
                    actionsBlock,
                  ],
                ],
              ),
            );
          }

          return Container(
            height: 56,
            width: double.infinity,
            decoration: appPanelDecoration(context),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (showBackButton) ...[
                  BackButton(onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 8),
                ],
                Expanded(child: titleBlock),
                if (actionsBlock != null) actionsBlock,
              ],
            ),
          );
        },
      ),
    );
  }
}

class DesktopBreadcrumbBar extends StatelessWidget {
  const DesktopBreadcrumbBar({
    super.key,
    required this.breadcrumb,
    this.barKey,
    this.trailingText,
  });

  final String breadcrumb;
  final Key? barKey;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: trailingText == null
          ? '导航路径: $breadcrumb'
          : '导航路径: $breadcrumb · $trailingText',
      child: ExcludeSemantics(
        child: Container(
          key: barKey,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: appPanelDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: Text(breadcrumb, style: theme.textTheme.bodyMedium),
              ),
              if (trailingText != null)
                Text(trailingText!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopSearchField extends StatelessWidget {
  const DesktopSearchField({
    super.key,
    this.width = 152,
    this.hintText = '搜索项目',
    this.fieldKey,
    this.controller,
    this.onChanged,
  });

  final double width;
  final String hintText;
  final Key? fieldKey;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    return SizedBox(
      width: width,
      height: 36,
      child: TextField(
        key: fieldKey,
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodySmall,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          filled: true,
          fillColor: palette.elevated,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: palette.primary),
          ),
        ),
      ),
    );
  }
}
