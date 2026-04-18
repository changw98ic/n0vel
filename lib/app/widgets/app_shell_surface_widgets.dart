part of 'app_shell.dart';

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

    return _AppShellGlassCard(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppSectionHeader(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
            SizedBox(height: 2.h),
            child,
          ],
        ),
      ),
      color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.55),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
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

    return _AppShellGlassCard(
      color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.45),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AppShellIconBadge(
              icon: icon,
              tone: tone,
              size: 36,
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tone,
                ),
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

    return _AppShellGlassCard(
      color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.4),
      child: Material(
        color: Colors.transparent,
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
                _AppShellIconBadge(
                  icon: icon,
                  tone: tone,
                  size: 40,
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
            _AppShellIconBadge(
              icon: icon,
              tone: colorScheme.primary,
              size: 80,
              backgroundColor:
                  colorScheme.primaryContainer.withValues(alpha: 0.7),
              iconSize: 36,
              borderRadius: AppTokens.radiusLg,
            ),
            SizedBox(height: 16.h),
            Text(title, style: theme.textTheme.titleMedium),
            SizedBox(height: 6.h),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[
              SizedBox(height: 2.h),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _AppShellGlassCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;

  const _AppShellGlassCard({
    required this.child,
    required this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(
              color: borderColor ??
                  Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _AppSectionHeader({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4.h),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: 16.w),
          trailing!,
        ],
      ],
    );
  }
}

class _AppShellIconBadge extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final double size;
  final Color? backgroundColor;
  final double? iconSize;
  final double? borderRadius;

  const _AppShellIconBadge({
    required this.icon,
    required this.tone,
    required this.size,
    this.backgroundColor,
    this.iconSize,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.h,
      decoration: BoxDecoration(
        color: backgroundColor ?? tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius ?? AppTokens.radiusMd),
      ),
      child: Icon(
        icon,
        color: tone,
        size: (iconSize ?? 20).sp,
      ),
    );
  }
}
