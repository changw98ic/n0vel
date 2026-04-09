import 'package:get/get.dart';

import '../../features/work/data/work_repository.dart';
import '../../features/work/domain/work.dart';
import '../../shared/data/base_business/base_controller.dart';
import 'dashboard_state.dart';

/// Dashboard 业务逻辑
class DashboardLogic extends BaseController {
  final DashboardState state = DashboardState();
  final _repository = Get.find<WorkRepository>();

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    await runWithLoading(() async {
      final works = await _repository.getAllWorks();
      state.works.assignAll(works);
    });
  }

  // ─── 计算属性 ───────────────────────────────────────────────

  String get todayLabel {
    final now = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.year}年${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  int get totalWords => state.works.fold(0, (sum, w) => sum + w.currentWords);

  int get todayWords {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return state.works
        .where((w) => w.updatedAt.isAfter(startOfDay))
        .fold(0, (sum, w) => sum + w.currentWords);
  }

  int get streak {
    if (state.works.isEmpty) return 0;
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      final hasActivity = state.works.any(
        (w) => w.updatedAt.isAfter(start) && w.updatedAt.isBefore(end),
      );
      if (hasActivity) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  List<Work> get recentWorks {
    final sorted = List<Work>.from(state.works)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(3).toList();
  }

  String formatNumber(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }
}
