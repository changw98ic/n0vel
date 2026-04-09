import 'package:get/get.dart';
import '../../../../../features/work/domain/work.dart';

class WorkFormState {
  final workId = RxString('');
  final existingWork = Rx<Work?>(null);
}
