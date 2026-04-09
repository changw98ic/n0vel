import 'package:get/get.dart';

import '../../../features/editor/domain/chapter.dart';
import '../../../features/settings/domain/character.dart' as domain;

/// ChapterEditor 页面响应式状态
class ChapterEditorState {
  final chapter = Rx<Chapter?>(null);
  final isPanelVisible = true.obs;
  final isSaving = false.obs;
  final lastSavedAt = Rx<DateTime?>(null);
  final characters = RxList<domain.Character>([]);

  // Undo/Redo stacks managed in controller
  final undoStack = <String>[].obs;
  final redoStack = <String>[].obs;
}
