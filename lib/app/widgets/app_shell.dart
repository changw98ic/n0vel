import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme.dart';
import 'package:get/get.dart';

class AppPageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottom;
  final bool constrainWidth;
  final EdgeInsetsGeometry bodyPadding;
  final double maxWidth;

  AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.floatingActionButton,
    this.bottom,
    this.constrainWidth = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    this.maxWidth = 1440,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: leading ?? _defaultBackButton(context),
        titleSpacing: 24.w,
        toolbarHeight: subtitle == null ? 78.h : 92.h,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            if (subtitle != null)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(subtitle!, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
        actions: actions,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainerLowest.withValues(
                  alpha: 0.98,
                ),
                theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
                theme.colorScheme.surface.withValues(alpha: 0.94),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        bottom: bottom == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(74),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 16.h),
                  child: bottom,
                ),
              ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AppPageBackground(),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constrainWidth ? maxWidth : double.infinity,
                ),
                child: Padding(padding: bodyPadding, child: child),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  /// 当 leading 为 null 且可以返回时，自动显示返回按钮
  static Widget? _defaultBackButton(BuildContext context) {
    // 主 shell（root 路由）不需要返回按钮
    final canPop = Navigator.of(context).canPop();
    if (!canPop) return null;
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Get.back(),
    );
  }
}

class AppHeroPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> meta;
  final List<Widget> actions;
  final Widget? aside;

  const AppHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.meta = const [],
    this.actions = const [],
    this.aside,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.6),
            colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
            colorScheme.tertiaryContainer.withValues(alpha: 0.4),

          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980 && aside != null;
            final primaryContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(title, style: theme.textTheme.displayMedium),
                SizedBox(height: 14.h),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(description, style: theme.textTheme.bodyLarge),
                ),
                if (meta.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Wrap(spacing: 10.w, runSpacing: 10.h, children: meta),
                ],
                if (actions.isNotEmpty) ...[
                  SizedBox(height: 24.h),
                  Wrap(spacing: 12.w, runSpacing: 12.h, children: actions),
                ],
              ],
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  primaryContent,
                  if (aside != null) ...[SizedBox(height: 24.h), aside!],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: primaryContent),
                SizedBox(width: 24.w),
                Expanded(flex: 2, child: aside!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          if (subtitle != null) ...[
                            SizedBox(height: 4.h),
                            Text(subtitle!, style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[SizedBox(width: 16.w), trailing!],
                  ],
                ),
                SizedBox(height: 2.h),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color? accent;

  const AppStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = accent ?? colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36.w,
                height: 36.h,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Icon(icon, color: tone, size: 20.sp),
              ),
              SizedBox(height: 12.h),
              Text(label, style: theme.textTheme.bodySmall),
              SizedBox(height: 4.h),
              Text(value, style: theme.textTheme.headlineSmall),
              SizedBox(height: 4.h),
              Text(hint, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class AppTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const AppTag({super.key, required this.label, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = color ?? colorScheme.secondary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: tone.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16.sp, color: tone),
            SizedBox(width: 8.w),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class AppActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final Color? accent;

  const AppActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = accent ?? colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            hoverColor: colorScheme.primaryContainer.withValues(alpha: 0.08),
            child: Ink(
              padding: EdgeInsets.all(16.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Icon(icon, color: tone, size: 20.sp),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        SizedBox(height: 2.h),
                        Text(description, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 18.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              child: Icon(icon, size: 36.sp, color: colorScheme.primary),
            ),
            SizedBox(height: 16.h),
            Text(title, style: theme.textTheme.titleMedium),
            SizedBox(height: 6.h),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[SizedBox(height: 2.h), action!],
          ],
        ),
      ),
    );
  }
}

class _AppPageBackground extends StatelessWidget {
  const _AppPageBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerLow,
            colorScheme.surfaceContainer,
          ],
        ),
      ),
    );
  }
}
