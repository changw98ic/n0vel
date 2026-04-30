import 'package:flutter/material.dart';

import '../../../app/logging/app_event_log.dart';
import '../../../app/di/service_scope.dart';
import '../../../app/llm/app_llm_client.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/navigation/reading_route_data.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../author_feedback/domain/author_feedback_models.dart';
import '../../author_feedback/presentation/author_feedback_panel.dart';
import '../../review_tasks/data/review_task_mapper.dart';
import '../../review_tasks/data/review_task_store.dart';
import '../../review_tasks/domain/review_task_models.dart';
import '../../review_tasks/presentation/review_task_panel.dart';
import '../../sandbox/presentation/sandbox_monitor_page.dart';

part 'workbench_shell_components.dart';

enum WorkbenchUiState {
  defaultHidden,
  menuDrawerOpen,
  apiKeyMissing,
  missingCharacterBinding,
  missingCharacterReference,
  missingWorldReference,
  noSimulationYet,
  contextSynced,
  simulationCompleted,
  simulationFailedSummary,
}

enum WorkbenchToolPanel { resources, ai, feedback, reviewTasks, settings }

enum AiToolMode { rewrite, continueWriting }

class _EditorReturnAnchor {
  const _EditorReturnAnchor({
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

class _AiSelectionDraft {
  const _AiSelectionDraft({
    required this.start,
    required this.end,
    required this.prompt,
  });

  final int start;
  final int end;
  final String prompt;

  int get length => end - start;

  _AiSelectionDraft copyWith({String? prompt}) {
    return _AiSelectionDraft(
      start: start,
      end: end,
      prompt: prompt ?? this.prompt,
    );
  }
}

class _AiReviewBlock {
  const _AiReviewBlock({
    required this.blockLabel,
    required this.previousText,
    required this.originalText,
    required this.nextText,
    required this.authorPrompt,
    required this.suggestionText,
    this.selection,
  });

  final String blockLabel;
  final String previousText;
  final String originalText;
  final String nextText;
  final String authorPrompt;
  final String suggestionText;
  final _AiSelectionDraft? selection;
}

class _AiRequestMetadata {
  const _AiRequestMetadata({
    required this.providerSummary,
    required this.endpointLabel,
    required this.styleSummary,
    required this.sceneSummary,
    required this.characterSummary,
    required this.worldSummary,
    required this.simulationSummary,
  });

  final String providerSummary;
  final String endpointLabel;
  final String styleSummary;
  final String sceneSummary;
  final String characterSummary;
  final String worldSummary;
  final String simulationSummary;
}

class _AiRequestException implements Exception {
  const _AiRequestException({required this.title, required this.message});

  final String title;
  final String message;
}

class WorkbenchShellPage extends StatefulWidget {
  const WorkbenchShellPage({
    super.key,
    this.uiState = WorkbenchUiState.defaultHidden,
  });

  static const menuDrawerHandleKey = ValueKey<String>(
    'workbench-menu-drawer-handle',
  );
  static const menuDrawerPanelKey = ValueKey<String>(
    'workbench-menu-drawer-panel',
  );
  static const breadcrumbKey = ValueKey<String>('workbench-breadcrumb');
  static const editorPaneKey = ValueKey<String>('workbench-editor-pane');
  static const editorSurfaceHeaderKey = ValueKey<String>(
    'workbench-editor-surface-header',
  );
  static const editorSurfaceMetaKey = ValueKey<String>(
    'workbench-editor-surface-meta',
  );
  static const editorTextFieldKey = ValueKey<String>(
    'workbench-editor-text-field',
  );
  static const toolRailKey = ValueKey<String>('workbench-tool-rail');
  static const toolWindowKey = ValueKey<String>('workbench-tool-window');
  static const statusBarKey = ValueKey<String>('workbench-status-bar');
  static const runSimulationButtonKey = ValueKey<String>(
    'workbench-run-simulation-button',
  );
  static const failSimulationButtonKey = ValueKey<String>(
    'workbench-fail-simulation-button',
  );
  static const cancelRunButtonKey = ValueKey<String>(
    'workbench-cancel-run-button',
  );
  static const runSnapshotPanelKey = ValueKey<String>(
    'workbench-run-snapshot-panel',
  );
  static const runSnapshotHeadlineKey = ValueKey<String>(
    'workbench-run-snapshot-headline',
  );
  static const runSnapshotStageKey = ValueKey<String>(
    'workbench-run-snapshot-stage',
  );
  static const saveVersionButtonKey = ValueKey<String>(
    'workbench-save-version-button',
  );
  static const openVersionsButtonKey = ValueKey<String>(
    'workbench-open-versions-button',
  );
  static const resourcesToolButtonKey = ValueKey<String>(
    'workbench-tool-button-resources',
  );
  static const createSceneButtonKey = ValueKey<String>(
    'workbench-create-scene-button',
  );
  static const renameSceneButtonKey = ValueKey<String>(
    'workbench-rename-scene-button',
  );
  static const deleteSceneButtonKey = ValueKey<String>(
    'workbench-delete-scene-button',
  );
  static const sceneTitleFieldKey = ValueKey<String>(
    'workbench-scene-title-field',
  );
  static const aiToolButtonKey = ValueKey<String>('workbench-tool-button-ai');
  static const feedbackToolButtonKey = ValueKey<String>(
    'workbench-tool-button-feedback',
  );
  static const reviewTasksToolButtonKey = ValueKey<String>(
    'workbench-tool-button-review-tasks',
  );
  static const mapReviewTasksButtonKey = ValueKey<String>(
    'workbench-map-review-tasks-button',
  );
  static const aiGenerateButtonKey = ValueKey<String>(
    'workbench-ai-generate-button',
  );
  static const aiPromptFieldKey = ValueKey<String>('workbench-ai-prompt-field');
  static const aiClearPromptButtonKey = ValueKey<String>(
    'workbench-ai-clear-prompt-button',
  );
  static const aiClearHistoryButtonKey = ValueKey<String>(
    'workbench-ai-clear-history-button',
  );
  static const aiRewriteModeButtonKey = ValueKey<String>(
    'workbench-ai-mode-rewrite',
  );
  static const aiContinueModeButtonKey = ValueKey<String>(
    'workbench-ai-mode-continue',
  );
  static const aiAddSelectionButtonKey = ValueKey<String>(
    'workbench-ai-add-selection-button',
  );
  static const aiSelectionListKey = ValueKey<String>(
    'workbench-ai-selection-list',
  );
  static const readingToolButtonKey = ValueKey<String>(
    'workbench-tool-button-reading',
  );
  static const settingsToolButtonKey = ValueKey<String>(
    'workbench-tool-button-settings',
  );
  static const aiRetrySecureStoreButtonKey = ValueKey<String>(
    'workbench-ai-retry-secure-store-button',
  );
  static const aiCopyDiagnosticButtonKey = ValueKey<String>(
    'workbench-ai-copy-diagnostic-button',
  );
  static const settingsRetrySecureStoreButtonKey = ValueKey<String>(
    'workbench-settings-retry-secure-store-button',
  );
  static const settingsCopyDiagnosticButtonKey = ValueKey<String>(
    'workbench-settings-copy-diagnostic-button',
  );

  static ValueKey<String> aiHistoryReplayButtonKey(int sequence) =>
      ValueKey<String>('workbench-ai-history-replay-$sequence');

  static ValueKey<String> aiHistoryDeleteButtonKey(int sequence) =>
      ValueKey<String>('workbench-ai-history-delete-$sequence');

  static ValueKey<String> aiHistoryPromptKey(int sequence) =>
      ValueKey<String>('workbench-ai-history-prompt-$sequence');

  static ValueKey<String> aiSelectionSummaryKey(int index) =>
      ValueKey<String>('workbench-ai-selection-summary-$index');

  static ValueKey<String> aiSelectionEditButtonKey(int index) =>
      ValueKey<String>('workbench-ai-selection-edit-$index');

  static ValueKey<String> aiSelectionRemoveButtonKey(int index) =>
      ValueKey<String>('workbench-ai-selection-remove-$index');

  final WorkbenchUiState uiState;

  @override
  State<WorkbenchShellPage> createState() => _WorkbenchShellPageState();
}

class _WorkbenchShellPageState extends State<WorkbenchShellPage> {
  late bool _isDrawerOpen;
  WorkbenchToolPanel? _activeToolPanel;
  AiToolMode _aiToolMode = AiToolMode.rewrite;
  bool _showContextSyncedBanner = false;
  bool _isGeneratingAi = false;
  final TextEditingController _aiPromptController = TextEditingController();
  final FocusNode _draftFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  TextEditingController? _draftController;
  AppDraftStore? _draftStore;
  final List<_AiSelectionDraft> _aiSelections = [];
  TextSelection _lastEditorSelection = const TextSelection.collapsed(offset: 0);
  String _lastDraftText = '';
  String? _activeDraftScopeId;
  _EditorReturnAnchor? _pendingReturnAnchor;

  bool get _isInteractiveDefault =>
      widget.uiState == WorkbenchUiState.defaultHidden;

  @override
  void initState() {
    super.initState();
    _isDrawerOpen = widget.uiState == WorkbenchUiState.menuDrawerOpen;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftController == null) {
      _draftStore = AppDraftScope.of(context);
      _draftController = TextEditingController(
        text: _draftStore!.snapshot.text,
      );
      _lastDraftText = _draftStore!.snapshot.text;
      _activeDraftScopeId = _draftStore!.activeProjectId;
      _draftController!.addListener(() {
        final next = _draftController!.text;
        if (_pendingReturnAnchor == null) {
          _lastEditorSelection = _draftController!.selection;
        }
        if (_lastDraftText != next) {
          _lastDraftText = next;
          if (_aiSelections.isNotEmpty) {
            setState(() {
              _aiSelections.clear();
            });
          }
        }
        if (_draftStore!.snapshot.text != next) {
          _draftStore!.updateText(next);
        }
      });
      _lastEditorSelection = _draftController!.selection;
    }
  }

  @override
  void didUpdateWidget(covariant WorkbenchShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uiState != widget.uiState && !_isInteractiveDefault) {
      _isDrawerOpen = widget.uiState == WorkbenchUiState.menuDrawerOpen;
    }
  }

  @override
  void dispose() {
    _aiPromptController.dispose();
    _draftFocusNode.dispose();
    _editorScrollController.dispose();
    _draftController?.dispose();
    super.dispose();
  }

  Future<void> _showSceneDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onConfirm,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: title,
          description: '创建后会出现在当前项目的场景列表中，并立即可在工作台中继续写作。',
          body: _WorkbenchDialogField(
            label: '场景标题',
            child: TextField(
              key: WorkbenchShellPage.sceneTitleFieldKey,
              controller: controller,
              decoration: const InputDecoration(hintText: '输入场景标题'),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (result == null || result.trim().isEmpty) {
      return;
    }
    onConfirm(result);
  }

  Future<void> _confirmDeleteScene(
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '删除场景',
          description: '删除后会从当前项目的场景列表中移除，工作台会自动切换到相邻场景，并同步刷新相关引用摘要。',
          body: _WorkbenchDialogField(
            label: '当前场景',
            child: Text(
              AppWorkspaceScope.of(context).currentScene.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true) {
      onConfirm();
    }
  }

  Future<void> _openSettingsAndRestoreAnchor({
    bool closeToolPanel = false,
  }) async {
    final anchor = _captureReturnAnchor();
    if (closeToolPanel) {
      setState(() {
        _activeToolPanel = null;
      });
    }
    await AppNavigator.push(context, AppRoutes.settings);
    if (!mounted) {
      return;
    }
    await _restoreReturnAnchor(anchor);
  }

  Future<void> _openReadingMode() async {
    final workspace = AppWorkspaceScope.of(context);
    final draftStore = AppDraftScope.of(context);
    final anchor = _captureReturnAnchor();
    final documents = <ReadingSceneDocument>[];
    for (final scene in workspace.scenes) {
      final scopeId = '${workspace.currentProject.id}::${scene.id}';
      final text = await draftStore.readTextForScope(scopeId);
      documents.add(
        ReadingSceneDocument(
          sceneId: scene.id,
          locationLabel: scene.displayLocation,
          text: text,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    await AppNavigator.push(
      context,
      AppRoutes.reading,
      arguments: ReadingSessionData(
        projectTitle: workspace.currentProject.title,
        initialSceneId: workspace.currentProject.sceneId,
        documents: documents,
      ),
    );
    if (!mounted) {
      return;
    }
    await _restoreReturnAnchor(anchor);
  }

  _EditorReturnAnchor _captureReturnAnchor() {
    final workspace = AppWorkspaceScope.of(context);
    final selection = _clampSelection(
      _draftController?.selection ?? _lastEditorSelection,
      _draftController?.text.length ?? 0,
    );
    final scrollOffset = _editorScrollController.hasClients
        ? _editorScrollController.offset
        : 0.0;
    return _EditorReturnAnchor(
      sceneId: workspace.currentProject.sceneId,
      selection: selection,
      scrollOffset: scrollOffset,
      expectedText: _draftController?.text ?? '',
    );
  }

  Future<void> _restoreReturnAnchor(_EditorReturnAnchor anchor) async {
    final workspace = AppWorkspaceScope.of(context);
    final draftStore = AppDraftScope.of(context);
    var pendingAnchor = anchor;
    if (workspace.currentProject.sceneId != anchor.sceneId) {
      final targetScene = workspace.scenes.where(
        (scene) => scene.id == anchor.sceneId,
      );
      if (targetScene.isNotEmpty) {
        final scene = targetScene.first;
        final targetScopeId = '${workspace.currentProject.id}::${scene.id}';
        pendingAnchor = _EditorReturnAnchor(
          sceneId: anchor.sceneId,
          selection: anchor.selection,
          scrollOffset: anchor.scrollOffset,
          expectedText: await draftStore.readTextForScope(targetScopeId),
        );
        workspace.updateCurrentScene(
          sceneId: scene.id,
          recentLocation: scene.displayLocation,
        );
      }
    }
    _pendingReturnAnchor = pendingAnchor;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeApplyPendingReturnAnchor(),
    );
  }

  void _maybeApplyPendingReturnAnchor() {
    final pendingAnchor = _pendingReturnAnchor;
    if (!mounted || _draftController == null || pendingAnchor == null) {
      return;
    }
    final workspace = AppWorkspaceScope.of(context);
    if (workspace.currentProject.sceneId != pendingAnchor.sceneId) {
      return;
    }
    final controller = _draftController!;
    if (controller.text != pendingAnchor.expectedText) {
      return;
    }
    final clampedSelection = _clampSelection(
      pendingAnchor.selection,
      controller.text.length,
    );
    controller.selection = clampedSelection;
    _lastEditorSelection = clampedSelection;
    if (_editorScrollController.hasClients) {
      final maxOffset = _editorScrollController.position.maxScrollExtent;
      final targetOffset = pendingAnchor.scrollOffset
          .clamp(0.0, maxOffset)
          .toDouble();
      _editorScrollController.jumpTo(targetOffset);
    }
    _draftFocusNode.requestFocus();
    _pendingReturnAnchor = null;
  }

  TextSelection _clampSelection(TextSelection selection, int textLength) {
    final start = selection.start.clamp(0, textLength).toInt();
    final end = selection.end.clamp(0, textLength).toInt();
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  TextSelection? _normalizedEditorSelection(String text) {
    final controller = _draftController;
    if (controller == null) {
      return null;
    }
    final selection = _clampSelection(controller.selection, text.length);
    if (!selection.isValid || selection.isCollapsed) {
      return null;
    }
    return TextSelection(
      baseOffset: selection.start,
      extentOffset: selection.end,
    );
  }

  String _selectionPreview(String text, TextSelection? selection) {
    if (selection == null || !selection.isValid || selection.isCollapsed) {
      return '尚未选择正文片段';
    }
    final excerpt = text.substring(selection.start, selection.end).trim();
    if (excerpt.isEmpty) {
      return '尚未选择正文片段';
    }
    if (excerpt.length <= 36) {
      return excerpt;
    }
    return '${excerpt.substring(0, 36)}...';
  }

  Future<void> _addCurrentSelectionFromEditor() async {
    final controller = _draftController;
    if (controller == null) {
      return;
    }
    final selection = _normalizedEditorSelection(controller.text);
    if (selection == null) {
      await _showMessageDialog(
        title: '请先选中正文片段',
        message: '在正文中框选一段内容后，再把它加入多处改写列表。',
      );
      return;
    }
    final prompt = _aiPromptController.text.trim().isEmpty
        ? '调整语气与节奏'
        : _aiPromptController.text.trim();
    setState(() {
      _aiSelections.add(
        _AiSelectionDraft(
          start: selection.start,
          end: selection.end,
          prompt: prompt,
        ),
      );
    });
    _aiPromptController.clear();
    _draftFocusNode.requestFocus();
  }

  Future<void> _editSelectionPrompt(int index) async {
    final current = _aiSelections[index];
    final controller = TextEditingController(text: current.prompt);
    final nextPrompt = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑该段修改意图'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: '输入这段的单独修改要求'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (nextPrompt == null || nextPrompt.isEmpty) {
      return;
    }
    setState(() {
      _aiSelections[index] = current.copyWith(prompt: nextPrompt);
    });
  }

  void _removeSelection(int index) {
    setState(() {
      _aiSelections.removeAt(index);
    });
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('返回正文'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOverlappingSelectionsDialog() async {
    await _showMessageDialog(
      title: '多处选区重叠',
      message: '当前请求未发出。请取消或合并重叠选区后再继续生成改写建议。',
    );
  }

  bool _hasOverlappingSelections(List<_AiSelectionDraft> selections) {
    if (selections.length < 2) {
      return false;
    }
    final sorted = List<_AiSelectionDraft>.from(selections)
      ..sort((left, right) => left.start.compareTo(right.start));
    for (var index = 1; index < sorted.length; index += 1) {
      if (sorted[index].start < sorted[index - 1].end) {
        return true;
      }
    }
    return false;
  }

  String _defaultAiIntent({required bool continueMode}) {
    return continueMode ? '补上一段自然衔接的正文。' : '调整语气与节奏';
  }

  Future<List<_AiReviewBlock>> _requestSelectionReviewBlocks(
    String original,
    List<_AiSelectionDraft> selections,
    _AiRequestMetadata metadata,
    String? correlationId,
  ) async {
    final sorted = List<_AiSelectionDraft>.from(selections)
      ..sort((left, right) => left.start.compareTo(right.start));
    final blocks = <_AiReviewBlock>[];
    for (var index = 0; index < sorted.length; index += 1) {
      final previousText = _contextWindow(
        original,
        end: sorted[index].start,
        backwards: true,
      );
      final originalText = original.substring(
        sorted[index].start,
        sorted[index].end,
      );
      final nextText = _contextWindow(original, start: sorted[index].end);
      final suggestionText = await _requestAiOutput(
        prompt: sorted[index].prompt,
        continueMode: false,
        metadata: metadata,
        originalText: originalText,
        previousText: previousText,
        nextText: nextText,
        taskType: '选区改写',
        correlationId: correlationId,
      );
      blocks.add(
        _AiReviewBlock(
          blockLabel: '修改块 ${index + 1}',
          previousText: previousText,
          originalText: originalText,
          nextText: nextText,
          authorPrompt: sorted[index].prompt,
          suggestionText: suggestionText,
          selection: sorted[index],
        ),
      );
    }
    return blocks;
  }

  Future<List<_AiReviewBlock>> _requestFallbackReviewBlocks({
    required String original,
    required String prompt,
    required bool continueMode,
    required _AiRequestMetadata metadata,
    String? correlationId,
  }) async {
    final effectivePrompt = prompt.isEmpty
        ? _defaultAiIntent(continueMode: continueMode)
        : prompt;
    final suggestionText = await _requestAiOutput(
      prompt: effectivePrompt,
      continueMode: continueMode,
      metadata: metadata,
      originalText: original,
      previousText: '夜雨还没有停。',
      nextText: '她听见码头深处传来金属回响。',
      taskType: continueMode ? '续写' : '整段改写',
      correlationId: correlationId,
    );
    return [
      _AiReviewBlock(
        blockLabel: continueMode ? '续写块 1' : '修改块 1',
        previousText: '上一段预览：夜雨还没有停。',
        originalText: original,
        nextText: '下一段预览：她听见码头深处传来金属回响。',
        authorPrompt: effectivePrompt,
        suggestionText: suggestionText,
      ),
    ];
  }

  _AiRequestMetadata _currentAiRequestMetadata() {
    final settings = AppSettingsScope.of(context).snapshot;
    final workspace = AppWorkspaceScope.of(context);
    final sceneContext = AppSceneContextScope.of(context).snapshot;
    final simulation = AppSimulationScope.of(context).snapshot;
    final endpoint =
        Uri.tryParse(settings.baseUrl.trim())?.host.isNotEmpty == true
        ? Uri.tryParse(settings.baseUrl.trim())!.host
        : settings.baseUrl.trim();
    final simulationSummary = switch (simulation.status) {
      SimulationStatus.none => '暂无模拟记录',
      SimulationStatus.running =>
        '${simulation.headline} · ${simulation.stageSummary}',
      SimulationStatus.completed =>
        '${simulation.headline} · ${simulation.summary}',
      SimulationStatus.failed =>
        '${simulation.headline} · ${simulation.summary}',
    };
    return _AiRequestMetadata(
      providerSummary: '${settings.providerName} · ${settings.model}',
      endpointLabel: endpoint,
      styleSummary:
          '${workspace.selectedStyleProfile?.name ?? '未绑定风格'} · ${workspace.styleIntensity}x',
      sceneSummary: sceneContext.sceneSummary,
      characterSummary: sceneContext.characterSummary,
      worldSummary: sceneContext.worldSummary,
      simulationSummary: simulationSummary,
    );
  }

  AppEventLog get _eventLog => AppEventLogScope.of(context);

  Future<void> _logWorkbenchEvent({
    required AppEventLogCategory category,
    required String action,
    required AppEventLogStatus status,
    required String message,
    String? correlationId,
    AppEventLogLevel level = AppEventLogLevel.info,
    String? errorCode,
    String? errorDetail,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final workspace = AppWorkspaceScope.of(context);
    return _eventLog.log(
      level: level,
      category: category,
      action: action,
      status: status,
      message: message,
      correlationId: correlationId,
      projectId: workspace.currentProject.id,
      sceneId: workspace.currentProject.sceneId,
      errorCode: errorCode,
      errorDetail: errorDetail,
      metadata: metadata,
    );
  }

  Map<String, Object?> _aiRequestLogMetadata({
    required _AiRequestMetadata metadata,
    required String prompt,
    required String taskType,
    String? response,
  }) {
    return {
      'provider': metadata.providerSummary,
      'endpoint': metadata.endpointLabel,
      'taskType': taskType,
      'promptLength': prompt.length,
      'promptPreview': _previewText(prompt, 160),
      if (response != null) 'responseLength': response.length,
      if (response != null) 'responsePreview': _previewText(response, 160),
    };
  }

  String _previewText(String text, int maxLength) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= maxLength) {
      return normalized;
    }
    if (maxLength <= 3) {
      return normalized.substring(0, maxLength);
    }
    return '${normalized.substring(0, maxLength - 3)}...';
  }

  Future<String> _requestAiOutput({
    required String prompt,
    required bool continueMode,
    required _AiRequestMetadata metadata,
    required String originalText,
    required String previousText,
    required String nextText,
    required String taskType,
    String? correlationId,
  }) async {
    final settingsStore = AppSettingsScope.of(context);
    final effectivePrompt = prompt.isEmpty
        ? _defaultAiIntent(continueMode: continueMode)
        : prompt;
    await _logWorkbenchEvent(
      category: AppEventLogCategory.ai,
      action: 'ai.chat.request.started',
      status: AppEventLogStatus.started,
      message: 'Started AI chat request.',
      correlationId: correlationId,
      metadata: _aiRequestLogMetadata(
        metadata: metadata,
        prompt: effectivePrompt,
        taskType: taskType,
      ),
    );
    final result = await settingsStore.requestAiCompletion(
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content: continueMode
              ? '你是中文小说续写助手。只输出需要追加的新内容，不要解释，不要重复原文，不要使用 Markdown、标题、编号或引号。'
              : '你是中文小说改写助手。只输出最终改写结果，不要解释，不要使用 Markdown、标题、编号或引号。',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务类型：$taskType',
            '作者意图：$effectivePrompt',
            '请求配置：${metadata.providerSummary}',
            '接口：${metadata.endpointLabel}',
            '风格约束：${metadata.styleSummary}',
            '场景上下文：${metadata.sceneSummary}',
            metadata.characterSummary,
            metadata.worldSummary,
            '模拟摘要：${metadata.simulationSummary}',
            '上一段：$previousText',
            '原文：\n$originalText',
            '下一段：$nextText',
          ].join('\n\n'),
        ),
      ],
    );
    if (result.succeeded) {
      final text = result.text!.trim();
      await _logWorkbenchEvent(
        category: AppEventLogCategory.ai,
        action: 'ai.chat.request.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'AI chat request succeeded.',
        correlationId: correlationId,
        metadata: {
          ..._aiRequestLogMetadata(
            metadata: metadata,
            prompt: effectivePrompt,
            taskType: taskType,
            response: text,
          ),
          if (result.latencyMs != null) 'latencyMs': result.latencyMs,
        },
      );
      return text;
    }
    await _logWorkbenchEvent(
      category: AppEventLogCategory.ai,
      action: 'ai.chat.request.failed',
      status: AppEventLogStatus.failed,
      message: 'AI chat request failed.',
      correlationId: correlationId,
      level: AppEventLogLevel.error,
      errorCode: result.failureKind?.name,
      errorDetail: result.detail,
      metadata: _aiRequestLogMetadata(
        metadata: metadata,
        prompt: effectivePrompt,
        taskType: taskType,
      ),
    );
    throw _aiRequestException(result);
  }

  _AiRequestException _aiRequestException(AppLlmChatResult result) {
    return switch (result.failureKind) {
      AppLlmFailureKind.unauthorized => const _AiRequestException(
        title: 'AI 请求失败：鉴权失败',
        message: '401 / 403：请检查 API Key、账号权限或服务端授权状态。',
      ),
      AppLlmFailureKind.timeout => const _AiRequestException(
        title: 'AI 请求失败：连接超时',
        message: '模型服务在超时时间内未返回结果，请稍后重试或调大 timeout_ms。',
      ),
      AppLlmFailureKind.modelNotFound => _AiRequestException(
        title: 'AI 请求失败：模型不存在',
        message: result.detail?.trim().isNotEmpty == true
            ? result.detail!
            : '当前模型不可用，请检查 model 配置。',
      ),
      AppLlmFailureKind.network => _AiRequestException(
        title: 'AI 请求失败：网络错误',
        message: result.detail?.trim().isNotEmpty == true
            ? result.detail!
            : '无法连接到模型服务，请检查网络环境与 base_url。',
      ),
      AppLlmFailureKind.rateLimited => _AiRequestException(
        title: 'AI 请求失败：请求受限',
        message: result.detail?.trim().isNotEmpty == true
            ? result.detail!
            : '模型服务暂时限制请求，请稍后重试或降低请求频率。',
      ),
      AppLlmFailureKind.invalidResponse ||
      AppLlmFailureKind.server ||
      AppLlmFailureKind.unsupportedPlatform ||
      null => _AiRequestException(
        title: 'AI 请求失败：服务异常',
        message: result.detail?.trim().isNotEmpty == true
            ? result.detail!
            : '模型服务返回了无法解析的响应。',
      ),
    };
  }

  String _contextWindow(
    String text, {
    int? start,
    int? end,
    bool backwards = false,
  }) {
    if (text.isEmpty) {
      return '无可预览上下文';
    }
    if (backwards) {
      final safeEnd = (end ?? 0).clamp(0, text.length).toInt();
      final safeStart = (safeEnd - 24).clamp(0, safeEnd).toInt();
      final snippet = text.substring(safeStart, safeEnd).trim();
      return snippet.isEmpty ? '无上一段预览' : snippet;
    }
    final safeStart = (start ?? text.length).clamp(0, text.length).toInt();
    final safeEnd = (safeStart + 24).clamp(safeStart, text.length).toInt();
    final snippet = text.substring(safeStart, safeEnd).trim();
    return snippet.isEmpty ? '无下一段预览' : snippet;
  }

  String _acceptedTextForBlocks(
    String original,
    List<_AiReviewBlock> blocks,
    List<bool> included, {
    required bool continueMode,
  }) {
    final keptBlocks = <_AiReviewBlock>[
      for (var index = 0; index < blocks.length; index += 1)
        if (included[index]) blocks[index],
    ];
    if (keptBlocks.isEmpty) {
      return original;
    }
    final selectionBlocks = keptBlocks
        .where((block) => block.selection != null)
        .toList();
    if (selectionBlocks.isEmpty) {
      if (continueMode) {
        return [
          original,
          for (final block in keptBlocks) block.suggestionText,
        ].join('\n\n');
      }
      return keptBlocks.last.suggestionText;
    }
    final replacements = List<_AiReviewBlock>.from(selectionBlocks)
      ..sort(
        (left, right) =>
            right.selection!.start.compareTo(left.selection!.start),
      );
    var nextText = original;
    for (final block in replacements) {
      final selection = block.selection!;
      nextText = nextText.replaceRange(
        selection.start,
        selection.end,
        continueMode
            ? '${block.originalText}\n\n${block.suggestionText}'
            : block.suggestionText,
      );
    }
    return nextText;
  }

  Future<void> _openAiReviewDialog({
    required String reviewTitle,
    required String historyPrompt,
    required List<_AiReviewBlock> blocks,
    required _AiRequestMetadata metadata,
    required bool continueMode,
    required bool clearSelectionsOnAccept,
    String? correlationId,
  }) async {
    AppAiHistoryScope.of(
      context,
    ).addEntry(mode: continueMode ? '续写' : '改写', prompt: historyPrompt);
    final original = AppDraftScope.of(context).snapshot.text;
    await _logWorkbenchEvent(
      category: AppEventLogCategory.ui,
      action: 'ui.ai.review_opened.succeeded',
      status: AppEventLogStatus.succeeded,
      message: 'Opened AI review dialog.',
      correlationId: correlationId,
      metadata: {
        'reviewTitle': reviewTitle,
        'blockCount': blocks.length,
        'continueMode': continueMode,
        'historyPromptPreview': _previewText(historyPrompt, 160),
      },
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final included = List<bool>.filled(blocks.length, true);
        var isSaving = false;
        String? saveErrorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final keptCount = included.where((isIncluded) => isIncluded).length;
            final hasIncluded = keptCount > 0;
            final uniquePrompts = {
              for (final block in blocks) block.authorPrompt,
            };
            final acceptedText = _acceptedTextForBlocks(
              original,
              blocks,
              included,
              continueMode: continueMode,
            );
            return AlertDialog(
              title: Text(reviewTitle),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uniquePrompts.length == 1) ...[
                      Text('修改意图：${uniquePrompts.first}'),
                      const SizedBox(height: 12),
                    ],
                    Text('请求配置：${metadata.providerSummary}'),
                    const SizedBox(height: 4),
                    Text('接口：${metadata.endpointLabel}'),
                    const SizedBox(height: 4),
                    Text('风格约束：${metadata.styleSummary}'),
                    const SizedBox(height: 4),
                    Text('场景上下文：${metadata.sceneSummary}'),
                    const SizedBox(height: 4),
                    Text(metadata.characterSummary),
                    const SizedBox(height: 4),
                    Text(metadata.worldSummary),
                    const SizedBox(height: 4),
                    Text('模拟摘要：${metadata.simulationSummary}'),
                    const SizedBox(height: 12),
                    Text('已保留 $keptCount / ${blocks.length} 个修改块'),
                    const SizedBox(height: 16),
                    const Text('原始正文'),
                    const SizedBox(height: 8),
                    Text(original),
                    const SizedBox(height: 16),
                    for (var index = 0; index < blocks.length; index += 1) ...[
                      Text(blocks[index].blockLabel),
                      const SizedBox(height: 8),
                      const Text('上一段'),
                      const SizedBox(height: 4),
                      Text(blocks[index].previousText),
                      const SizedBox(height: 8),
                      const Text('当前被修改段'),
                      const SizedBox(height: 4),
                      Text(blocks[index].originalText),
                      const SizedBox(height: 8),
                      const Text('下一段'),
                      const SizedBox(height: 4),
                      Text(blocks[index].nextText),
                      const SizedBox(height: 8),
                      const Text('作者该段修改意见'),
                      const SizedBox(height: 4),
                      Text(blocks[index].authorPrompt),
                      const SizedBox(height: 8),
                      Text(blocks[index].suggestionText),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            included[index] = !included[index];
                          });
                        },
                        child: Text(
                          included[index]
                              ? '排除修改块 ${index + 1}'
                              : '恢复修改块 ${index + 1}',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!hasIncluded) const Text('至少保留 1 个修改块'),
                    if (hasIncluded && acceptedText != original) ...[
                      const SizedBox(height: 4),
                      const Text('接受后的正文预览'),
                      const SizedBox(height: 8),
                      Text(acceptedText),
                    ],
                    if (saveErrorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        saveErrorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: appDangerColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          _recordAiReviewDecision(
                            status: AuthorFeedbackStatus.rejected,
                            historyPrompt: historyPrompt,
                            correlationId: correlationId,
                          );
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('拒绝变更'),
                ),
                FilledButton(
                  onPressed: hasIncluded && !isSaving
                      ? () async {
                          setDialogState(() {
                            isSaving = true;
                            saveErrorMessage = null;
                          });
                          final draftStore = AppDraftScope.of(context);
                          final versionStore = AppVersionScope.of(context);
                          final navigator = Navigator.of(dialogContext);
                          try {
                            await draftStore.updateTextAndPersist(acceptedText);
                            try {
                              await versionStore.captureSnapshotAndPersist(
                                label: continueMode ? 'AI 接受变更（续写）' : 'AI 接受变更',
                                content: acceptedText,
                              );
                            } catch (_) {
                              try {
                                await draftStore.updateTextAndPersist(original);
                                throw _AiRequestException(
                                  title: 'AI 接受失败：本地保存失败',
                                  message: '版本保存失败，正文已回滚。请稍后重试。',
                                );
                              } catch (_) {
                                throw _AiRequestException(
                                  title: 'AI 接受失败：本地保存失败',
                                  message:
                                      '版本保存失败，且正文回滚也失败。当前正文可能已部分更新，请手动确认后重试。',
                                );
                              }
                            }
                          } on _AiRequestException catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSaving = false;
                                saveErrorMessage = error.message;
                              });
                            }
                            return;
                          } catch (_) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                isSaving = false;
                                saveErrorMessage = '本地保存失败，请稍后重试。';
                              });
                            }
                            return;
                          }
                          if (!mounted) {
                            return;
                          }
                          _recordAiReviewDecision(
                            status: AuthorFeedbackStatus.accepted,
                            historyPrompt: historyPrompt,
                            correlationId: correlationId,
                          );
                          if (clearSelectionsOnAccept) {
                            setState(() {
                              _aiSelections.clear();
                            });
                          }
                          navigator.pop();
                          _draftFocusNode.requestFocus();
                        }
                      : null,
                  child: Text(isSaving ? '正在保存…' : '接受变更'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateAiSuggestion() async {
    final original = AppDraftScope.of(context).snapshot.text;
    final prompt = _aiPromptController.text.trim();
    final settingsStore = AppSettingsScope.of(context);
    if (!settingsStore.hasReadyConfiguration ||
        settingsStore.hasPersistenceIssue) {
      await _showMessageDialog(
        title: 'AI 功能暂不可用',
        message: '请先补全可用的 Provider 配置并处理配置异常，然后再发起 AI 操作。',
      );
      return;
    }
    final metadata = _currentAiRequestMetadata();
    final correlationId = _eventLog.newCorrelationId('ai-generate');
    if (_aiToolMode == AiToolMode.rewrite &&
        _aiSelections.isNotEmpty &&
        _hasOverlappingSelections(_aiSelections)) {
      await _showOverlappingSelectionsDialog();
      return;
    }

    await _logWorkbenchEvent(
      category: AppEventLogCategory.ui,
      action: 'ui.ai.generate.started',
      status: AppEventLogStatus.started,
      message: 'Started AI generate flow.',
      correlationId: correlationId,
      metadata: {
        'mode': _aiToolMode.name,
        'selectionCount': _aiSelections.length,
        'promptLength': prompt.length,
        'promptPreview': _previewText(
          prompt.isEmpty
              ? _defaultAiIntent(
                  continueMode: _aiToolMode == AiToolMode.continueWriting,
                )
              : prompt,
          160,
        ),
      },
    );
    setState(() {
      _isGeneratingAi = true;
    });
    try {
      if (_aiToolMode == AiToolMode.rewrite && _aiSelections.isNotEmpty) {
        await _openAiReviewDialog(
          reviewTitle: 'AI 修改确认',
          historyPrompt: '多选区改写（${_aiSelections.length}段）',
          blocks: await _requestSelectionReviewBlocks(
            original,
            _aiSelections,
            metadata,
            correlationId,
          ),
          metadata: metadata,
          continueMode: false,
          clearSelectionsOnAccept: true,
          correlationId: correlationId,
        );
        return;
      }
      await _openAiReviewDialog(
        reviewTitle: _aiToolMode == AiToolMode.rewrite ? 'AI 修改确认' : 'AI 续写确认',
        historyPrompt: prompt.isEmpty
            ? _defaultAiIntent(
                continueMode: _aiToolMode == AiToolMode.continueWriting,
              )
            : prompt,
        blocks: await _requestFallbackReviewBlocks(
          original: original,
          prompt: prompt,
          continueMode: _aiToolMode == AiToolMode.continueWriting,
          metadata: metadata,
          correlationId: correlationId,
        ),
        metadata: metadata,
        continueMode: _aiToolMode == AiToolMode.continueWriting,
        clearSelectionsOnAccept: false,
        correlationId: correlationId,
      );
    } on _AiRequestException catch (error) {
      await _showMessageDialog(title: error.title, message: error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
      }
    }
  }

  void _recordAiReviewDecision({
    required AuthorFeedbackStatus status,
    required String historyPrompt,
    String? correlationId,
  }) {
    final workspace = AppWorkspaceScope.of(context);
    final runSnapshot = ServiceScope.of(
      context,
    ).resolve<StoryGenerationRunStore>().snapshot;
    final promptText = historyPrompt.trim().isEmpty
        ? _defaultAiIntent(continueMode: false)
        : historyPrompt;
    final promptPreview = _previewText(promptText, 120);
    AuthorFeedbackScope.of(context).createFeedback(
      chapterId: workspace.currentScene.chapterLabel,
      sceneId: workspace.currentScene.id,
      sceneLabel: workspace.currentScene.displayLocation,
      note: status == AuthorFeedbackStatus.accepted
          ? '已采纳 AI 建议：$promptPreview'
          : '未采纳 AI 建议：$promptPreview',
      priority: AuthorFeedbackPriority.normal,
      status: status,
      sourceRunId: _sourceRunId(workspace.currentProject.id, runSnapshot),
      sourceRunLabel: _sourceRunLabel(runSnapshot),
      sourceReviewId: correlationId,
    );
  }

  void _mapReviewSnapshotToTasks(StoryGenerationRunSnapshot snapshot) {
    final reviewMessages = _reviewIssueMessages(snapshot);
    if (reviewMessages.isEmpty) {
      return;
    }
    final workspace = AppWorkspaceScope.of(context);
    final sourceRunId = _sourceRunId(workspace.currentProject.id, snapshot);
    final tasks = const ReviewTaskMapper().fromReviewMessages(
      messages: [
        for (final message in reviewMessages)
          ReviewMessageInput(
            title: message.title,
            body: message.body,
            reference: ReviewTaskReference(
              projectId: workspace.currentProject.id,
              chapterId: workspace.currentScene.chapterLabel,
              chapterTitle: workspace.currentScene.chapterLabel,
              sceneId: workspace.currentScene.id,
              sceneTitle: workspace.currentScene.title,
            ),
            source: ReviewTaskSource(
              kind: 'story_generation_run',
              runId: sourceRunId ?? snapshot.sceneId,
              passName: message.title,
              metadata: {
                'runStatus': snapshot.status.name,
                'messageKind': message.kind.name,
                'sceneLabel': snapshot.sceneLabel,
              },
            ),
          ),
      ],
      sourceKind: 'story_generation_run',
    );
    if (tasks.isEmpty) {
      return;
    }
    ReviewTaskScope.of(context).upsertAll(tasks);
    setState(() {
      _activeToolPanel = WorkbenchToolPanel.reviewTasks;
    });
  }

  Future<void> _replayAiHistory(AiHistoryEntry entry) async {
    _aiPromptController.text = entry.prompt;
    _aiPromptController.selection = TextSelection.collapsed(
      offset: entry.prompt.length,
    );
    final original = AppDraftScope.of(context).snapshot.text;
    final continueMode = entry.mode == '续写';
    final metadata = _currentAiRequestMetadata();
    final correlationId = _eventLog.newCorrelationId('ai-replay');
    await _logWorkbenchEvent(
      category: AppEventLogCategory.ui,
      action: 'ui.ai.replay.started',
      status: AppEventLogStatus.started,
      message: 'Started AI history replay.',
      correlationId: correlationId,
      metadata: {
        'mode': entry.mode,
        'promptLength': entry.prompt.length,
        'promptPreview': _previewText(entry.prompt, 160),
      },
    );
    setState(() {
      _isGeneratingAi = true;
    });
    try {
      await _openAiReviewDialog(
        reviewTitle: continueMode ? 'AI 续写确认' : 'AI 修改确认',
        historyPrompt: entry.prompt,
        blocks: await _requestFallbackReviewBlocks(
          original: original,
          prompt: entry.prompt,
          continueMode: continueMode,
          metadata: metadata,
          correlationId: correlationId,
        ),
        metadata: metadata,
        continueMode: continueMode,
        clearSelectionsOnAccept: false,
        correlationId: correlationId,
      );
    } on _AiRequestException catch (error) {
      await _showMessageDialog(title: error.title, message: error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAi = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final workspace = AppWorkspaceScope.of(context);
    final draft = AppDraftScope.of(context).snapshot;
    final draftStore = AppDraftScope.of(context);
    if (_activeDraftScopeId != draftStore.activeProjectId) {
      _activeDraftScopeId = draftStore.activeProjectId;
      _aiSelections.clear();
      _lastDraftText = draft.text;
      _lastEditorSelection = TextSelection.collapsed(offset: draft.text.length);
      if (_pendingReturnAnchor != null &&
          _pendingReturnAnchor!.sceneId != workspace.currentProject.sceneId) {
        _pendingReturnAnchor = null;
      }
      if (_draftController != null &&
          _pendingReturnAnchor == null &&
          _draftController!.text == draft.text) {
        _draftController!.selection = _clampSelection(
          _lastEditorSelection,
          _draftController!.text.length,
        );
      }
    }
    final selectionToRestore =
        _pendingReturnAnchor?.selection ?? _lastEditorSelection;
    if (_draftController != null && _draftController!.text != draft.text) {
      _draftController!.value = TextEditingValue(
        text: draft.text,
        selection: _clampSelection(selectionToRestore, draft.text.length),
      );
      _lastDraftText = draft.text;
    }
    _maybeApplyPendingReturnAnchor();
    final currentSelectionPreview = _selectionPreview(
      draft.text,
      _normalizedEditorSelection(draft.text),
    );
    final simulation = AppSimulationScope.of(context).snapshot;
    final storyRunStore = ServiceScope.of(
      context,
    ).resolve<StoryGenerationRunStore>();
    final authorFeedbackStore = AuthorFeedbackScope.of(context);
    final reviewTaskStore = ReviewTaskScope.of(context);
    final effectiveSimulationStatus = _effectiveSimulationStatus(
      simulation.status,
    );
    final sceneContext = AppSceneContextScope.of(context).snapshot;
    final settingsStore = AppSettingsScope.of(context);
    final settings = settingsStore.snapshot;
    final settingsFeedback = settingsStore.feedback;
    final settingsHasPersistenceIssue = settingsStore.hasPersistenceIssue;
    final diagnosticReport = settingsStore.diagnosticReport;
    final canGenerateAi =
        settingsStore.hasReadyConfiguration && !settingsHasPersistenceIssue;
    final linkedCharacters = [
      for (final character in workspace.characters)
        if (character.linkedSceneIds.contains(workspace.currentScene.id))
          character,
    ];
    final linkedWorldNodes = [
      for (final node in workspace.worldNodes)
        if (node.linkedSceneIds.contains(workspace.currentScene.id)) node,
    ];
    final canRunSimulation =
        linkedCharacters.isNotEmpty && linkedWorldNodes.isNotEmpty;
    final statusBanner = _buildStatusBanner(
      theme,
      simulation,
      showContextSynced: _showContextSyncedBanner,
      hasSceneCharacterBinding: linkedCharacters.isNotEmpty,
      hasSceneWorldReference: linkedWorldNodes.isNotEmpty,
    );

    return DesktopShellFrame(
      header: DesktopBreadcrumbBar(
        barKey: WorkbenchShellPage.breadcrumbKey,
        breadcrumb: workspace.currentProjectBreadcrumb,
        trailingText: '自动保存 · Markdown',
      ),
      body: LayoutBuilder(
        builder: (context, layoutConstraints) {
          final spacing = panelSpacingFor(layoutConstraints.maxWidth);
          final compact =
              layoutConstraints.maxWidth <
              DesktopLayoutTokens.compactPageBreakpoint;
          final showToolRail =
              layoutConstraints.maxWidth >=
              DesktopLayoutTokens.narrowBreakpoint;

          final editorPane = Expanded(
            child: Container(
              key: WorkbenchShellPage.editorPaneKey,
              padding: EdgeInsets.all(compact ? 8 : 16),
              decoration: appPanelDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (statusBanner != null) ...[
                    statusBanner,
                    const SizedBox(height: 12),
                  ],
                  if (_isInteractiveDefault) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final secondaryActions = Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              key: WorkbenchShellPage.saveVersionButtonKey,
                              onPressed: () {
                                AppVersionScope.of(context).captureSnapshot(
                                  label: '手动保存',
                                  content: draft.text,
                                );
                              },
                              child: const Text('保存版本'),
                            ),
                            TextButton(
                              key: WorkbenchShellPage.openVersionsButtonKey,
                              onPressed: () {
                                AppNavigator.push(context, AppRoutes.versions);
                              },
                              child: const Text('查看版本'),
                            ),
                          ],
                        );
                        final runPanel = _StoryGenerationRunPanel(
                          store: storyRunStore,
                          canRun: canRunSimulation,
                          onRun: () {
                            AppSimulationScope.of(
                              context,
                            ).startSuccessfulRun(eventLog: _eventLog);
                            storyRunStore.runCurrentScene();
                          },
                          onForceFailure: () {
                            AppSimulationScope.of(
                              context,
                            ).startFailureRun(eventLog: _eventLog);
                            storyRunStore.runCurrentScene(forceFailure: true);
                          },
                          onCancel: () {
                            storyRunStore.cancelCurrentRun();
                            AppSimulationScope.of(
                              context,
                            ).reset(eventLog: _eventLog);
                          },
                          onMapReviewTasks: _mapReviewSnapshotToTasks,
                        );

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: appPanelDecoration(
                            context,
                            color: palette.surface,
                          ),
                          child: constraints.maxWidth < 420
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '正文优先显示，快速操作保持低干扰。',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 8),
                                    runPanel,
                                    const SizedBox(height: 8),
                                    secondaryActions,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: runPanel),
                                    const SizedBox(width: 12),
                                    Flexible(child: secondaryActions),
                                  ],
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.elevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border),
                      ),
                      child: LayoutBuilder(
                        builder: (context, editorConstraints) {
                          final showEditorHeader =
                              editorConstraints.maxHeight >= 120;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showEditorHeader)
                                Container(
                                  key:
                                      WorkbenchShellPage.editorSurfaceHeaderKey,
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: palette.border),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workspace.currentProjectBreadcrumb,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '自动保存 · Markdown',
                                        key: WorkbenchShellPage
                                            .editorSurfaceMetaKey,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: TextField(
                                  key: WorkbenchShellPage.editorTextFieldKey,
                                  controller: _draftController,
                                  focusNode: _draftFocusNode,
                                  scrollController: _editorScrollController,
                                  maxLines: null,
                                  expands: true,
                                  style: theme.textTheme.bodyMedium,
                                  decoration: const InputDecoration(
                                    hintText: '开始书写当前场景正文…',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          final toolWindow = _activeToolPanel != null
              ? Container(
                  key: WorkbenchShellPage.toolWindowKey,
                  width: DesktopLayoutTokens.workbenchToolWindowWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: appPanelDecoration(context),
                  child: _ToolWindowPanel(
                    activePanel: _activeToolPanel!,
                    authorFeedbackStore: authorFeedbackStore,
                    reviewTaskStore: reviewTaskStore,
                    scenes: workspace.scenes,
                    currentSceneId: workspace.currentProject.sceneId,
                    currentChapterId: workspace.currentScene.chapterLabel,
                    currentSceneLabel: workspace.currentScene.displayLocation,
                    sourceRunId: _sourceRunId(
                      workspace.currentProject.id,
                      storyRunStore.snapshot,
                    ),
                    sourceRunLabel: _sourceRunLabel(storyRunStore.snapshot),
                    sceneContext: sceneContext,
                    uiState: widget.uiState,
                    settings: settings,
                    settingsFeedback: settingsFeedback,
                    settingsHasPersistenceIssue: settingsHasPersistenceIssue,
                    canGenerateAi: canGenerateAi,
                    isGeneratingAi: _isGeneratingAi,
                    diagnosticReport: diagnosticReport,
                    aiToolMode: _aiToolMode,
                    historyEntries: AppAiHistoryScope.of(context).entries,
                    aiPromptController: _aiPromptController,
                    onRetrySecureStore: settingsStore.retrySecureStoreAccess,
                    draftText: draft.text,
                    currentSelectionPreview: currentSelectionPreview,
                    selectionDrafts: List<_AiSelectionDraft>.unmodifiable(
                      _aiSelections,
                    ),
                    onSelectAiMode: (mode) {
                      setState(() {
                        _aiToolMode = mode;
                      });
                    },
                    onGenerateAiSuggestion: _generateAiSuggestion,
                    onReplayAiHistory: _replayAiHistory,
                    onDeleteAiHistoryEntry: (entry) {
                      AppAiHistoryScope.of(context).removeEntry(entry.sequence);
                    },
                    onClearAiHistory: () {
                      AppAiHistoryScope.of(context).clear();
                    },
                    onSyncContext: () {
                      AppSceneContextScope.of(context).syncContext();
                      setState(() {
                        _showContextSyncedBanner = true;
                      });
                    },
                    onSelectScene: (scene) {
                      workspace.updateCurrentScene(
                        sceneId: scene.id,
                        recentLocation: scene.displayLocation,
                      );
                    },
                    onCreateScene: () => _showSceneDialog(
                      context,
                      title: '新建场景',
                      initialValue: '',
                      onConfirm: workspace.createScene,
                    ),
                    onRenameScene: () => _showSceneDialog(
                      context,
                      title: '重命名场景',
                      initialValue: workspace.currentScene.title,
                      onConfirm: workspace.renameCurrentScene,
                    ),
                    onDeleteScene: () => _confirmDeleteScene(
                      context,
                      workspace.deleteCurrentScene,
                    ),
                    canDeleteScene: workspace.canDeleteCurrentScene,
                    onOpenSettings: () =>
                        _openSettingsAndRestoreAnchor(closeToolPanel: true),
                    onAddCurrentSelection: _addCurrentSelectionFromEditor,
                    onEditSelectionPrompt: _editSelectionPrompt,
                    onRemoveSelection: _removeSelection,
                  ),
                )
              : null;

          final toolRail = Container(
            key: WorkbenchShellPage.toolRailKey,
            width: DesktopLayoutTokens.workbenchRailWidth,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: appPanelDecoration(context),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RailButton(
                    buttonKey: WorkbenchShellPage.resourcesToolButtonKey,
                    icon: Icons.menu_book_outlined,
                    label: '资料',
                    isSelected:
                        _activeToolPanel == WorkbenchToolPanel.resources,
                    onTap: () => _toggleToolPanel(WorkbenchToolPanel.resources),
                  ),
                  const SizedBox(height: 12),
                  _RailButton(
                    buttonKey: WorkbenchShellPage.aiToolButtonKey,
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI',
                    isSelected: _activeToolPanel == WorkbenchToolPanel.ai,
                    onTap: () => _toggleToolPanel(WorkbenchToolPanel.ai),
                  ),
                  const SizedBox(height: 12),
                  _RailButton(
                    buttonKey: WorkbenchShellPage.feedbackToolButtonKey,
                    icon: Icons.rate_review_outlined,
                    label: '反馈',
                    isSelected: _activeToolPanel == WorkbenchToolPanel.feedback,
                    onTap: () => _toggleToolPanel(WorkbenchToolPanel.feedback),
                  ),
                  const SizedBox(height: 12),
                  _RailButton(
                    buttonKey: WorkbenchShellPage.reviewTasksToolButtonKey,
                    icon: Icons.task_alt_outlined,
                    label: '任务',
                    isSelected:
                        _activeToolPanel == WorkbenchToolPanel.reviewTasks,
                    onTap: () =>
                        _toggleToolPanel(WorkbenchToolPanel.reviewTasks),
                  ),
                  const SizedBox(height: 12),
                  _RailButton(
                    buttonKey: WorkbenchShellPage.settingsToolButtonKey,
                    icon: Icons.settings_outlined,
                    label: '设置',
                    isSelected: _activeToolPanel == WorkbenchToolPanel.settings,
                    onTap: () => _toggleToolPanel(WorkbenchToolPanel.settings),
                  ),
                  const SizedBox(height: 12),
                  _RailButton(
                    buttonKey: WorkbenchShellPage.readingToolButtonKey,
                    icon: Icons.chrome_reader_mode_outlined,
                    label: '阅读',
                    onTap: _openReadingMode,
                  ),
                ],
              ),
            ),
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopMenuDrawerRegion(
                  handleKey: WorkbenchShellPage.menuDrawerHandleKey,
                  drawerKey: WorkbenchShellPage.menuDrawerPanelKey,
                  title: '菜单',
                  isOpen: _isDrawerOpen,
                  onHandleTap: _isInteractiveDefault
                      ? () {
                          setState(() {
                            _isDrawerOpen = !_isDrawerOpen;
                          });
                        }
                      : null,
                  items: _menuItems(context),
                ),
                SizedBox(width: spacing),
                if (toolWindow != null) ...[
                  SizedBox(
                    width: DesktopLayoutTokens.workbenchToolWindowWidth,
                    child: toolWindow,
                  ),
                  SizedBox(width: spacing),
                ],
                editorPane,
                if (showToolRail) ...[SizedBox(width: spacing), toolRail],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopMenuDrawerRegion(
                handleKey: WorkbenchShellPage.menuDrawerHandleKey,
                drawerKey: WorkbenchShellPage.menuDrawerPanelKey,
                title: '菜单',
                isOpen: _isDrawerOpen,
                onHandleTap: _isInteractiveDefault
                    ? () {
                        setState(() {
                          _isDrawerOpen = !_isDrawerOpen;
                        });
                      }
                    : null,
                items: _menuItems(context),
              ),
              SizedBox(width: spacing),
              editorPane,
              if (toolWindow != null) ...[SizedBox(width: spacing), toolWindow],
              SizedBox(width: spacing),
              if (showToolRail) toolRail,
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        stripKey: WorkbenchShellPage.statusBarKey,
        leftText: _statusLabel(effectiveSimulationStatus),
        rightText: _statusMetaLabel(draft.text),
      ),
    );
  }

  void _toggleToolPanel(WorkbenchToolPanel panel) {
    setState(() {
      if (_activeToolPanel == panel) {
        _activeToolPanel = null;
      } else {
        _activeToolPanel = panel;
      }
    });
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return [
      DesktopMenuItemData(
        label: '书架',
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
      DesktopMenuItemData(
        label: '编辑工作台',
        isSelected: true,
        onTap: () {
          setState(() {
            _isDrawerOpen = false;
          });
        },
      ),
      DesktopMenuItemData(
        label: '生产看板',
        onTap: () {
          AppNavigator.push(context, AppRoutes.productionBoard);
        },
      ),
      DesktopMenuItemData(
        label: '审查任务',
        onTap: () {
          AppNavigator.push(context, AppRoutes.reviewTasks);
        },
      ),
      DesktopMenuItemData(label: '设置', onTap: _openSettingsAndRestoreAnchor),
    ];
  }

  String _statusLabel(SimulationStatus status) {
    switch (status) {
      case SimulationStatus.none:
        return '暂无模拟记录';
      case SimulationStatus.running:
        return '模拟进行中';
      case SimulationStatus.completed:
        return '模拟已完成';
      case SimulationStatus.failed:
        return '模拟失败';
    }
  }

  String _statusMetaLabel(String draftText) {
    final panelLabel = switch (_activeToolPanel) {
      WorkbenchToolPanel.resources => '资料窗口',
      WorkbenchToolPanel.ai => 'AI 工具',
      WorkbenchToolPanel.feedback => '作者反馈',
      WorkbenchToolPanel.reviewTasks => '审查任务',
      WorkbenchToolPanel.settings => '设置快捷面板',
      null => '写作模式',
    };
    return '$panelLabel · 阅读模式可切换 · ${_formatDraftUnitCount(draftText)} 字';
  }

  String _formatDraftUnitCount(String draftText) {
    final compact = draftText.replaceAll(RegExp(r'\s+'), '');
    final countText = compact.length.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < countText.length; index += 1) {
      final remaining = countText.length - index;
      buffer.write(countText[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String? _sourceRunId(String projectId, StoryGenerationRunSnapshot snapshot) {
    if (!snapshot.hasRun) {
      return null;
    }
    return '$projectId::${snapshot.sceneId}::${snapshot.status.name}';
  }

  String? _sourceRunLabel(StoryGenerationRunSnapshot snapshot) {
    if (!snapshot.hasRun) {
      return null;
    }
    final stage = snapshot.stageSummary.trim();
    if (stage.isEmpty) {
      return snapshot.headline;
    }
    return '${snapshot.headline} · $stage';
  }

  SimulationStatus _effectiveSimulationStatus(SimulationStatus status) {
    if (status != SimulationStatus.none) {
      return status;
    }
    return switch (widget.uiState) {
      WorkbenchUiState.simulationCompleted => SimulationStatus.completed,
      WorkbenchUiState.simulationFailedSummary => SimulationStatus.failed,
      _ => status,
    };
  }

  void _openSandboxMonitor({
    required SimulationStatus fallbackStatus,
    bool failureMode = false,
  }) {
    final simulationStore = AppSimulationScope.of(context);
    final liveStatus = simulationStore.snapshot.status;
    final hasLiveRun = liveStatus != SimulationStatus.none;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 1080,
          height: 640,
          child: SandboxMonitorPage(
            failureMode: failureMode,
            previewStatus: hasLiveRun ? null : fallbackStatus,
          ),
        ),
      ),
    );
  }

  Widget? _buildStatusBanner(
    ThemeData theme,
    AppSimulationSnapshot simulation, {
    required bool showContextSynced,
    required bool hasSceneCharacterBinding,
    required bool hasSceneWorldReference,
  }) {
    final simulationStatus = _effectiveSimulationStatus(simulation.status);
    switch (widget.uiState) {
      case WorkbenchUiState.defaultHidden:
      case WorkbenchUiState.simulationCompleted:
      case WorkbenchUiState.simulationFailedSummary:
      case WorkbenchUiState.noSimulationYet:
        if (showContextSynced) {
          return _StatusBanner(
            title: '资料已同步到当前工作台。',
            message: '角色、世界观与上下文摘要已经刷新，正文位置保持不变。',
            accentColor: const Color(0xFF5B7A5A),
          );
        }
        if (!hasSceneCharacterBinding) {
          return _StatusBanner(
            title: '模拟不可用：当前场景还没有绑定参与角色。',
            message: '正文仍可继续编辑，但运行模拟前需要补充角色绑定。',
            accentColor: const Color(0xFFB6813B),
          );
        }
        if (!hasSceneWorldReference) {
          return _StatusBanner(
            title: '世界观引用已失效，地点与规则约束需要重新绑定。',
            message: '正文可继续编辑，但场景约束与模拟条件当前不可用。',
            accentColor: const Color(0xFFB6813B),
          );
        }
        switch (simulationStatus) {
          case SimulationStatus.none:
            return widget.uiState == WorkbenchUiState.noSimulationYet
                ? _StatusBanner(
                    title: '暂无可查看的模拟记录。',
                    message: '你仍然可以继续编辑正文，或先发起一次新的模拟。',
                    accentColor: const Color(0xFF5C6E85),
                  )
                : null;
          case SimulationStatus.running:
            return _StatusBanner(
              title: '模拟进行中',
              message: '${simulation.summary} · ${simulation.stageSummary}',
              actionLabel: '查看模拟过程',
              onActionTap: () {
                _openSandboxMonitor(fallbackStatus: SimulationStatus.running);
              },
              accentColor: const Color(0xFF5C6E85),
            );
          case SimulationStatus.completed:
            return _StatusBanner(
              title: '模拟已完成',
              message: '${simulation.summary} · ${simulation.sceneLabel}',
              actionLabel: '查看模拟过程',
              onActionTap: () {
                _openSandboxMonitor(fallbackStatus: SimulationStatus.completed);
              },
              accentColor: const Color(0xFF5B7A5A),
            );
          case SimulationStatus.failed:
            return _StatusBanner(
              title: '模拟未完成，正文保持原样。',
              message: '${simulation.summary} · ${simulation.turnSummary}',
              actionLabel: '查看失败详情',
              onActionTap: () {
                _openSandboxMonitor(
                  fallbackStatus: SimulationStatus.failed,
                  failureMode: true,
                );
              },
              accentColor: const Color(0xFF9A5444),
            );
        }
      case WorkbenchUiState.menuDrawerOpen:
        return null;
      case WorkbenchUiState.apiKeyMissing:
        return _StatusBanner(
          title: 'AI 功能暂不可用',
          message: '请先补全 Provider 配置与 API Key，然后再发起 AI 操作。',
          actionLabel: '前往设置',
          onActionTap: _openSettingsAndRestoreAnchor,
          accentColor: const Color(0xFF9A5444),
        );
      case WorkbenchUiState.missingCharacterBinding:
        return _StatusBanner(
          title: '模拟不可用：当前场景还没有绑定参与角色。',
          message: '正文仍可继续编辑，但运行模拟前需要补充角色绑定。',
          accentColor: const Color(0xFFB6813B),
        );
      case WorkbenchUiState.missingCharacterReference:
        return _StatusBanner(
          title: '角色引用已失效，正文仍可继续编辑。',
          message: '重新绑定角色后，人物摘要与模拟入口会恢复。',
          accentColor: const Color(0xFFB6813B),
        );
      case WorkbenchUiState.missingWorldReference:
        return _StatusBanner(
          title: '世界观引用已失效，地点与规则约束需要重新绑定。',
          message: '正文可继续编辑，但场景约束与模拟条件当前不可用。',
          accentColor: const Color(0xFFB6813B),
        );
      case WorkbenchUiState.contextSynced:
        return _StatusBanner(
          title: '资料已同步到当前工作台。',
          message: '角色、世界观与上下文摘要已经刷新，正文位置保持不变。',
          accentColor: const Color(0xFF5B7A5A),
        );
    }
  }
}

List<StoryGenerationRunMessage> _reviewIssueMessages(
  StoryGenerationRunSnapshot snapshot,
) {
  if (!snapshot.hasRun) {
    return const [];
  }
  return [
    for (final message in snapshot.messages)
      if (_isActionableReviewMessage(message)) message,
  ];
}

bool _isActionableReviewMessage(StoryGenerationRunMessage message) {
  if (message.kind != StoryGenerationRunMessageKind.review) {
    return false;
  }
  final body = message.body.trim();
  if (body.isEmpty) {
    return false;
  }
  final normalized = body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const passingBodies = {
    'pass',
    'passed',
    'scene passed review.',
    '审查通过',
    '通过',
  };
  if (passingBodies.contains(normalized)) {
    return false;
  }
  return true;
}
