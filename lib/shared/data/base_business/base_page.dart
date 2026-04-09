import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
/// GetX View 层通用 UI 辅助方法
///
/// 为 GetView / GetX 提供统一的 loading、error、empty 状态渲染。
/// 使用方式：with BasePage 或直接调用静态方法。
mixin BasePage {
  Widget loadingIndicator() => Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.h),
          child: const CircularProgressIndicator(),
        ),
      );

  Widget errorState(String message, {VoidCallback? onRetry}) => Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48.w, color: Colors.red.shade300),
              SizedBox(height: 16.h),
              Text(
                message,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget emptyState({
    IconData icon = Icons.inbox_outlined,
    String message = '暂无数据',
    Widget? action,
  }) =>
      Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56.w, color: Colors.grey.shade400),
              SizedBox(height: 16.h),
              Text(
                message,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade500),
              ),
              if (action != null) ...[
                SizedBox(height: 16.h),
                action,
              ],
            ],
          ),
        ),
      );
}
