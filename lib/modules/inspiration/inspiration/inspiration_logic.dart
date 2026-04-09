import 'package:get/get.dart';

import '../../../core/database/database.dart';
import '../../../features/inspiration/data/inspiration_repository.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'inspiration_state.dart';

/// Inspiration 业务逻辑
class InspirationLogic extends BaseController {
  final InspirationState state = InspirationState();

  final InspirationRepository _repo = Get.find<InspirationRepository>();

  @override
  void onInit() {
    super.onInit();
    loadData();

    // 当筛选条件变化时自动刷新
    ever(state.selectedCategory, (_) => loadData());
    ever(state.searchQuery, (_) => loadData());
  }

  void setSelectedCategory(String? category) {
    state.selectedCategory.value = category;
  }

  void setSearchQuery(String query) {
    state.searchQuery.value = query;
  }

  void clearSearch() {
    state.searchQuery.value = '';
  }

  Future<void> loadData() async {
    state.isLoading.value = true;
    try {
      final results = await _fetchInspirations();
      state.inspirations.assignAll(results);
    } catch (e) {
      showErrorSnackbar('加载失败：$e');
    } finally {
      state.isLoading.value = false;
    }
  }

  Future<List<Inspiration>> _fetchInspirations() async {
    if (state.searchQuery.value.isNotEmpty) {
      return _repo.searchAll(state.searchQuery.value);
    }
    if (state.selectedCategory.value != null) {
      return _repo.getByCategoryAll(state.selectedCategory.value!);
    }
    return _repo.getAll();
  }

  Future<void> deleteInspiration(String id) async {
    try {
      await _repo.delete(id);
      showSuccessSnackbar('素材已删除');
      await loadData();
    } catch (e) {
      showErrorSnackbar('删除失败：$e');
    }
  }

  Future<void> createInspiration({
    required String title,
    required String content,
    required String category,
    List<String>? tags,
    String? source,
  }) async {
    try {
      await _repo.create(
        title: title,
        content: content,
        category: category,
        tags: tags,
        source: source,
      );
      showSuccessSnackbar('素材已创建');
      await loadData();
    } catch (e) {
      showErrorSnackbar('创建失败：$e');
    }
  }
}
