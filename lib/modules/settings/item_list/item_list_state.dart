import 'package:get/get.dart';

class ItemListState {
  final searchQuery = ''.obs;
  final filterType = Rx<String?>(null);
  final filterRarity = Rx<String?>(null);
}
