import 'package:get/get.dart';

import '../../../core/database/database.dart';

/// Inspiration 页面响应式状态
class InspirationState {
  final selectedCategory = Rx<String?>(null);
  final searchQuery = ''.obs;
  final inspirations = <Inspiration>[].obs;
  final isLoading = false.obs;
}
