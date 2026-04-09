import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

/// 通用卡片列表组件
class CardList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(T) itemBuilder;
  final Widget? emptyWidget;
  final void Function(T)? onTap;
  final void Function(T)? onLongPress;

  const CardList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return emptyWidget ?? const _EmptyState();
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: onTap != null ? () => onTap!(item) : null,
          onLongPress: onLongPress != null ? () => onLongPress!(item) : null,
          child: itemBuilder(item),
        );
      },
    );
  }
}

/// 空状态组件
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64.sp,
            color: Theme.of(context).colorScheme.outline,
          ),
          SizedBox(height: 16.h),
          Text(
            s.shared_noContent,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
