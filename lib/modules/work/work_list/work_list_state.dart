import 'package:get/get.dart';

import '../../../features/work/domain/work.dart';

/// WorkList 页面响应式状态
class WorkListState {
  final works = <Work>[].obs;
  final showArchived = false.obs;
}
