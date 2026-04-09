import 'package:get/get.dart';
import '../../../features/settings/domain/relationship.dart' as domain;

class RelationshipState {
  final selectedType = Rx<String?>(null);
  final relationships = <domain.RelationshipHead>[].obs;
  final isLoading = true.obs;
  final loadError = Rx<Object?>(null);
}
