import 'package:get/get.dart';

class SearchState {
  final workId = RxString('');
  final searchFuture = Rx<dynamic>(null);
  final recentSearches = RxList<String>([]);
  final selectedType = Rx<dynamic>(null);
}
