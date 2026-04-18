part of 'app_shell.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _AppShellAppBar(
        title: title,
        subtitle: subtitle,
        actions: actions,
        leading: leading ?? _defaultBackButton(context),
        bottom: bottom,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AppPageBackground(),
          _AppShellBodyFrame(
            constrainWidth: constrainWidth,
            maxWidth: maxWidth,
            bodyPadding: bodyPadding,
            child: child,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  /// 当 leading 为 null 且可以返回时，自动显示返回按钮
  static Widget? _defaultBackButton(BuildContext context) {
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
            final primaryContent = _AppHeroPrimaryContent(
              eyebrow: eyebrow,
              title: title,
              description: description,
              meta: meta,
              actions: actions,
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  primaryContent,
                  if (aside != null) ...[
                    SizedBox(height: 24.h),
                    aside!,
                  ],
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

class _AppShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? bottom;

  const _AppShellAppBar({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.leading,
    required this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        (subtitle == null ? 78.h : 92.h) + (bottom == null ? 0 : 74),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      leading: leading,
      titleSpacing: 24.w,
      toolbarHeight: subtitle == null ? 78.h : 92.h,
      title: _AppShellTitleBlock(
        title: title,
        subtitle: subtitle,
      ),
      actions: actions,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.98),
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
    );
  }
}

class _AppShellTitleBlock extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _AppShellTitleBlock({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
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
    );
  }
}

class _AppShellBodyFrame extends StatelessWidget {
  final bool constrainWidth;
  final double maxWidth;
  final EdgeInsetsGeometry bodyPadding;
  final Widget child;

  const _AppShellBodyFrame({
    required this.constrainWidth,
    required this.maxWidth,
    required this.bodyPadding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constrainWidth ? maxWidth : double.infinity,
          ),
          child: Padding(
            padding: bodyPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _AppHeroPrimaryContent extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> meta;
  final List<Widget> actions;

  const _AppHeroPrimaryContent({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.meta,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
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
