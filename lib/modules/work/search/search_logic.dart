import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../shared/data/base_business/base_controller.dart';
import 'search_state.dart';
import '../../../../../core/services/search_service.dart';
import '../../../../../core/utils/debounce.dart';

class SearchLogic extends BaseController {
  final SearchState state = SearchState();
  final Debounce searchDebounce = Debounce();

  static const _globalRecentSearchesKey = 'search.recent.global';
  static const _workRecentSearchesPrefix = 'search.recent.work.';

  @override
  void onInit() {
    super.onInit();
    state.workId.value = Get.parameters['workId'] ?? '';
    loadRecentSearches();
  }

  @override
  void onClose() {
    searchDebounce.dispose();
    super.onClose();
  }

  String get recentSearchesKeyForPage {
    return state.workId.isEmpty
        ? _globalRecentSearchesKey
        : '$_workRecentSearchesPrefix${state.workId.value}';
  }

  Future<void> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(recentSearchesKeyForPage) ?? const [];
    state.recentSearches.value = searches;
  }

  Future<void> persistRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final updated = [
      normalized,
      ...state.recentSearches.where((entry) => entry != normalized),
    ].take(6).toList();
    await prefs.setStringList(recentSearchesKeyForPage, updated);
    state.recentSearches.value = updated;
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(recentSearchesKeyForPage);
    state.recentSearches.value = const [];
  }

  void search(String query, {bool persist = false}) {
    if (query.trim().isEmpty) {
      state.searchFuture.value = null;
      state.selectedType.value = null;
      return;
    }

    if (persist) {
      persistRecentSearch(query);
    }

    final service = Get.find<SearchService>();
    state.searchFuture.value = service.searchAll(
      query: query,
      workId: state.workId.isEmpty ? null : state.workId.value,
    );
  }

  void selectType(dynamic type) {
    state.selectedType.value = type;
  }

  void openResult(dynamic item) {
    switch (item.type) {
      case 'work':
        Get.toNamed('/work/${item.id}');
        break;
      case 'chapter':
        final workId = item.workId ?? (state.workId.isEmpty ? null : state.workId.value);
        if (workId != null) {
          Get.toNamed('/work/$workId/chapter/${item.id}');
        }
        break;
      case 'character':
        final workId = item.workId ?? (state.workId.isEmpty ? null : state.workId.value);
        if (workId != null) {
          Get.toNamed('/work/$workId/characters/${item.id}');
        }
        break;
      case 'item':
        final workId = item.workId ?? (state.workId.isEmpty ? null : state.workId.value);
        if (workId != null) {
          Get.toNamed('/work/$workId/items');
        }
        break;
      case 'location':
        final workId = item.workId ?? (state.workId.isEmpty ? null : state.workId.value);
        if (workId != null) {
          Get.toNamed('/work/$workId/locations');
        }
        break;
      case 'faction':
        final workId = item.workId ?? (state.workId.isEmpty ? null : state.workId.value);
        if (workId != null) {
          Get.toNamed('/work/$workId/factions');
        }
        break;
    }
  }
}
