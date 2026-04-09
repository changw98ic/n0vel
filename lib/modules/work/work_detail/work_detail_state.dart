import 'package:get/get.dart';
import '../../../../../features/work/domain/work.dart';
import '../../../../../features/work/domain/volume.dart';
import '../../../../../features/editor/domain/chapter.dart';

enum WorkDetailPanel { chapters, world, studio, insight }

class WorkDetailState {
  final work = Rx<Work?>(null);
  final volumes = RxList<Volume>([]);
  final chaptersByVolume = RxMap<String, List<Chapter>>({});
  final isLoading = RxBool(true);
  final selectedPanel = Rx<WorkDetailPanel>(WorkDetailPanel.chapters);
}
