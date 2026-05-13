import 'package:flutter/material.dart';

class WorkbenchEditorReturnAnchor {
  const WorkbenchEditorReturnAnchor({
    required this.sceneId,
    required this.selection,
    required this.scrollOffset,
    required this.expectedText,
  });

  final String sceneId;
  final TextSelection selection;
  final double scrollOffset;
  final String expectedText;
}

TextSelection clampWorkbenchEditorSelection(
  TextSelection selection,
  int textLength,
) {
  final start = selection.start.clamp(0, textLength).toInt();
  final end = selection.end.clamp(0, textLength).toInt();
  return TextSelection(baseOffset: start, extentOffset: end);
}

TextSelection? normalizedWorkbenchEditorSelection({
  required TextSelection selection,
  required String text,
}) {
  final clampedSelection = clampWorkbenchEditorSelection(
    selection,
    text.length,
  );
  if (!clampedSelection.isValid || clampedSelection.isCollapsed) {
    return null;
  }
  return TextSelection(
    baseOffset: clampedSelection.start,
    extentOffset: clampedSelection.end,
  );
}

bool resourceBelongsToWorkbenchScene({
  required List<String> linkedSceneIds,
  required String currentSceneId,
  required String resourceName,
  required String syncedSummary,
}) {
  if (linkedSceneIds.contains(currentSceneId)) {
    return true;
  }
  if (linkedSceneIds.isNotEmpty) {
    return false;
  }
  return syncedSummary.contains(resourceName);
}

bool hasUsableWorkbenchSceneContext(String value, String expectedPrefix) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.contains('等待同步') ||
      normalized.contains('暂无') ||
      normalized.contains('还没有')) {
    return false;
  }
  if (!normalized.startsWith(expectedPrefix)) {
    return true;
  }
  return normalized
      .substring(expectedPrefix.length)
      .replaceFirst('：', '')
      .trim()
      .isNotEmpty;
}

List<String> workbenchResourceNamesForConfirmation({
  required List<String> linked,
  required List<String> fallback,
}) {
  final source = linked.isNotEmpty ? linked : fallback;
  return [
    for (final name in source)
      if (name.trim().isNotEmpty) name.trim(),
  ];
}
