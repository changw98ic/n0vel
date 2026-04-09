import 'package:get/get.dart';
import '../../../../../shared/data/base_business/base_controller.dart';
import 'work_form_state.dart';
import '../../../../../features/work/data/work_repository.dart';
import '../../../../../features/work/domain/work.dart';

class WorkFormLogic extends BaseController {
  final WorkFormState state = WorkFormState();

  @override
  void onInit() {
    super.onInit();
    final workId = Get.parameters['id'];
    if (workId != null) {
      state.workId.value = workId;
      loadExistingWork(workId);
    }
  }

  Future<void> loadExistingWork(String workId) async {
    final repository = Get.find<WorkRepository>();
    final work = await repository.getWorkById(workId);
    state.existingWork.value = work;
  }

  bool get isEditing => state.existingWork.value != null;
}

class WorkFormResult {
  final Work work;
  final bool isEditing;

  const WorkFormResult({required this.work, required this.isEditing});
}
