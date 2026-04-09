import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// GetX Controller 基类
///
/// 提供 loading/error 状态管理和通用 UI 反馈方法。
/// 所有模块的 Logic 类都应继承此基类。
abstract class BaseController extends GetxController {
  // ─── 响应式状态 ─────────────────────────────────────────────

  final isLoading = false.obs;
  final errorMessage = ''.obs;

  bool get hasError => errorMessage.value.isNotEmpty;

  // ─── 通用操作 ───────────────────────────────────────────────

  /// 包装异步操作，自动管理 loading/error 状态
  Future<void> runWithLoading(Future<void> Function() action) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await action();
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ─── UI 反馈 ────────────────────────────────────────────────

  void showErrorSnackbar(String message) {
    Get.snackbar(
      '错误',
      message,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  void showSuccessSnackbar(String message) {
    Get.snackbar(
      '成功',
      message,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  void showInfoSnackbar(String message) {
    Get.snackbar(
      '提示',
      message,
      margin: const EdgeInsets.all(16),
    );
  }
}
