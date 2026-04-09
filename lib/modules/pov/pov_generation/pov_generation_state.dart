import 'package:get/get.dart';

import '../../../features/pov_generation/domain/pov_models.dart';
import '../../../features/settings/domain/character.dart';
import '../../../features/editor/domain/chapter.dart';

/// POVGeneration 页面响应式状态
class POVGenerationState {
  final selectedChapterId = Rx<String?>(null);
  final selectedCharacterId = Rx<String?>(null);
  final config = const POVConfig().obs;
  final currentTask = Rx<POVTask?>(null);
  final isGenerating = false.obs;

  // Loaded data
  final chapters = Rx<List<Chapter>?>(null);
  final characters = Rx<List<Character>?>(null);
  final templates = Rx<List<POVTemplate>?>(null);
  final chaptersError = Rx<Object?>(null);
  final charactersError = Rx<Object?>(null);
  final templatesError = Rx<Object?>(null);
}
