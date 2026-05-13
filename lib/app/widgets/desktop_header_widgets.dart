import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/app_providers.dart';
import '../navigation/app_navigator.dart';
import 'desktop_theme.dart';
import '../theme/app_design_tokens.dart';

/// Standard navigation tabs shared across main pages.
abstract final class AppNavTabs {
  static const labels = ['书架', '作品资料', '设定', '编辑'];

  /// Returns true if a project is currently open.
  static bool hasProject(WidgetRef ref) {
    final store = ref.read(appWorkspaceStoreProvider);
    return store.currentProjectId.isNotEmpty &&
        store.projectById(store.currentProjectId) != null;
  }

  static void navigateTo(WidgetRef ref, BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case 1:
        if (!hasProject(ref)) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        AppNavigator.push(context, AppRoutes.workSettingsHub);
      case 2:
        if (!hasProject(ref)) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        AppNavigator.push(context, AppRoutes.workSettingsHub);
      case 3:
        if (!hasProject(ref)) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        AppNavigator.push(context, AppRoutes.workbench);
    }
  }
}

class DesktopHeaderBar extends StatelessWidget {
  const DesktopHeaderBar({
    super.key,
    this.title,
    this.titleKey,
    this.subtitle,
    this.actions = const [],
    this.showBackButton = false,
    this.tabs = const [],
    this.activeTabIndex = 0,
    this.onTabChanged,
  });

  final String? title;
  final Key? titleKey;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;

  /// Navigation tabs shown in the center (e.g. ['书架', '最近编辑', '归档']).
  final List<String> tabs;
  final int activeTabIndex;
  final ValueChanged<int>? onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Semantics(
      header: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDesignTokens.radiusLarge),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            decoration: navBarDecoration(context),
            child: Row(
              children: [
                // Brand
                _BrandLogo(),
                const SizedBox(width: 28),
                // Center tabs or title
                if (tabs.isNotEmpty)
                  Expanded(
                    child: _NavTabs(
                      tabs: tabs,
                      activeIndex: activeTabIndex,
                      onChanged: onTabChanged,
                    ),
                  )
                else
                  Expanded(
                    child: Row(
                      children: [
                        if (showBackButton) ...[
                          BackButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: ButtonStyle(
                              foregroundColor: WidgetStatePropertyAll(
                                palette.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title ?? '',
                                key: titleKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: palette.navActive,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.navInactive,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Actions
                if (actions.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
              ],
            ),
          ),
        ),
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
    this.actions,
  });

  final String breadcrumb;
  final Key? barKey;
  final String? trailingText;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppDesignTokens.radiusLarge),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: barKey,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          decoration: navBarDecoration(context),
          child: Row(
            children: [
              _BrandLogo(),
              const SizedBox(width: 28),
              Expanded(
                child: Text(
                  breadcrumb,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.navActive,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.navInactive,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              for (final action in actions ?? const <Widget>[]) action,
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: const Image(
            image: AssetImage('assets/icons/app_icon.png'),
            width: 32,
            height: 32,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '文优写作',
          style: theme.textTheme.titleMedium?.copyWith(
            color: palette.navActive,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _NavTabs extends StatelessWidget {
  const _NavTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 28),
          _NavTabButton(
            label: tabs[i],
            isActive: i == activeIndex,
            activeColor: palette.navActive,
            inactiveColor: palette.navInactive,
            onTap: () => onChanged?.call(i),
            textStyle: const TextStyle(
              fontFamily: AppDesignTokens.fontCaption,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class _NavTabButton extends StatefulWidget {
  const _NavTabButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    required this.textStyle,
  });

  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  State<_NavTabButton> createState() => _NavTabButtonState();
}

class _NavTabButtonState extends State<_NavTabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? widget.activeColor
        : _hovered
        ? widget.activeColor
        : widget.inactiveColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: widget.textStyle?.copyWith(
            color: color,
            fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
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
      height: 40,
      child: TextField(
        key: fieldKey,
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.navInactive),
          prefixIcon: Icon(Icons.search, size: 16, color: palette.navInactive),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          filled: true,
          fillColor: palette.glassCard,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: BorderSide(color: palette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: BorderSide(color: palette.primary),
          ),
        ),
      ),
    );
  }
}
