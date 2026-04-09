import 'package:get/get.dart';

import '../../../features/settings/data/relationship_repository.dart';
import '../../../features/settings/domain/relationship.dart' as domain;
import '../../../shared/data/base_business/base_controller.dart';
import 'relationship_state.dart';

/// 关系管理页业务逻辑
class RelationshipLogic extends BaseController {
  final RelationshipState state = RelationshipState();
  final _repo = Get.find<RelationshipRepository>();

  String get workId => Get.parameters['id']!;

  @override
  void onInit() {
    super.onInit();
    loadRelationships();
  }

  Future<void> loadRelationships() async {
    await runWithLoading(() async {
      final relationships = await _repo.getRelationshipsByWorkId(workId);
      state.relationships.assignAll(relationships);
    });
  }

  void setFilter(String? typeName) {
    state.selectedType.value = typeName;
  }

  List<domain.RelationshipHead> get filteredRelationships {
    final selected = state.selectedType.value;
    if (selected == null) return state.relationships;
    return state.relationships
        .where((r) => r.relationType.name == selected)
        .toList();
  }

  Future<void> deleteRelationship(domain.RelationshipHead relationship) async {
    try {
      await _repo.deleteRelationship(relationship.id);
      showSuccessSnackbar('关系已删除');
      await loadRelationships();
    } catch (e) {
      showErrorSnackbar('删除失败：$e');
    }
  }
}
