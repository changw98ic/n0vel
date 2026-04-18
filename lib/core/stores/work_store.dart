import 'dart:async';

import 'package:get/get.dart';

import '../../features/work/data/work_repository.dart';
import '../../features/work/domain/work.dart';

/// 作品列表的统一响应式数据源
///
/// 通过 Drift 的 [watch] 自动监听 works 表变更，
/// 任何对 works 表的写入（含章节字数同步）都会自动推送到所有观察者，
/// 无需手动调用 [refresh]。
class WorkStore extends GetxController {
  final works = <Work>[].obs;
  late final WorkRepository _repo;
  StreamSubscription<List<Work>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _repo = Get.find<WorkRepository>();
    // 监听 works 表 — DB 写入自动触发 works.assignAll()
    _subscription = _repo.watchAllWorks(includeArchived: true).listen((data) {
      works.assignAll(data);
    });
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  /// 手动刷新（一般不需要，watch 已自动同步；仅作兜底）
  Future<void> refresh() async {
    final all = await _repo.getAllWorks(includeArchived: true);
    works.assignAll(all);
  }
}
