import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/navigation/reading_route_data.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_run_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../author_feedback/data/author_feedback_store.dart';
import '../../author_feedback/domain/author_feedback_models.dart';
import '../../review_tasks/data/review_task_store.dart';

import 'workbench_ai_revision_helpers.dart';
import 'workbench_editor_helpers.dart';
import 'workbench_tool_window_panel.dart';
import 'workbench_types.dart';
import 'workbench_ai_controller.dart';
import 'workbench_ai_review_dialog.dart';
import 'workbench_editor_pane.dart';
import 'workbench_orchestrator.dart';

export 'workbench_types.dart';

part 'workbench_shell_actions.dart';
part 'workbench_shell_builders.dart';
part 'workbench_shell_components.dart';

class WorkbenchShellPage extends ConsumerStatefulWidget {
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
  static const chapterListToggleKey = ValueKey<String>(
    'workbench-chapter-list-toggle',
  );
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
  static const runRecoveryPromptKey = ValueKey<String>(
    'workbench-run-recovery-prompt',
  );
  static const runRecoveryRetryButtonKey = ValueKey<String>(
    'workbench-run-recovery-retry-button',
  );
  static const runRecoveryDiscardButtonKey = ValueKey<String>(
    'workbench-run-recovery-discard-button',
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
  static const sceneTitleFieldKey = ValueKey<String>(
    'workbench-scene-title-field',
  );
  static const aiToolButtonKey = ValueKey<String>('workbench-tool-button-ai');
  static const settingsToolButtonKey = ValueKey<String>(
    'workbench-tool-button-settings',
  );
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
  ConsumerState<WorkbenchShellPage> createState() => _WorkbenchShellPageState();
}

class _WorkbenchShellPageState extends ConsumerState<WorkbenchShellPage> {
  WorkbenchOrchestrator? _orchestrator;
  final TextEditingController _aiPromptController = TextEditingController();
  final FocusNode _draftFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  TextEditingController? _draftController;
  AppDraftStore? _draftStore;
  TextSelection _lastEditorSelection = const TextSelection.collapsed(offset: 0);
  String _lastDraftText = '';
  String? _activeDraftScopeId;
  String? _activeSceneId;
  WorkbenchEditorReturnAnchor? _pendingReturnAnchor;

  // Three-pane layout widths
  static const double _minPaneWidth = 200.0;
  static const double _defaultLeftPaneWidth = 400.0;
  static const double _defaultRightPaneWidth = 300.0;
  static const double _dividerWidth = 1.0;

  double _leftPaneWidth = _defaultLeftPaneWidth;
  double _rightPaneWidth = _defaultRightPaneWidth;

  // Calculate total minimum width needed for three-pane layout
  static double _calculateTotalMinWidth() =>
      (_minPaneWidth * 3) + (_dividerWidth * 2);

  WorkbenchOrchestrator get _orb => _orchestrator!;

  bool get _isEditorDirty {
    final controller = _draftController;
    final store = _draftStore;
    if (controller == null || store == null) return false;
    return controller.text != store.snapshot.text;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orchestrator == null) {
      _orchestrator = WorkbenchOrchestrator(
        draftStore: ref.read(appDraftStoreProvider),
        versionStore: ref.read(appVersionStoreProvider),
        settingsStore: ref.read(appSettingsStoreProvider),
        workspaceStore: ref.read(appWorkspaceStoreProvider),
        historyStore: ref.read(appAiHistoryStoreProvider),
        sceneContextStore: ref.read(appSceneContextStoreProvider),
        simulationStore: ref.read(appSimulationStoreProvider),
        authorFeedbackStore: ref.read(authorFeedbackStoreProvider),
        reviewTaskStore: ref.read(reviewTaskStoreProvider),
        storyRunStore: ref.read(storyGenerationRunStoreProvider),
        eventLog: ref.read(appEventLogProvider),
      );
      _orchestrator!.addListener(_onOrchestratorChanged);
    }
    final draftStore = ref.read(appDraftStoreProvider);
    final workspace = ref.read(appWorkspaceStoreProvider);
    final sceneId = workspace.currentProjectOrNull?.sceneId;

    if (_draftController == null) {
      _draftStore = draftStore;
      _draftController = TextEditingController(
        text: _draftStore!.snapshot.text,
      );
      _lastDraftText = _draftStore!.snapshot.text;
      _activeDraftScopeId = _draftStore!.activeProjectId;
      _activeSceneId = sceneId;
      _draftController!.addListener(() => _draftControllerListener(this));
      _lastEditorSelection = _draftController!.selection;
    } else if (sceneId != _activeSceneId) {
      _activeSceneId = sceneId;
      _draftStore = draftStore;
      final newText = draftStore.snapshot.text;
      _draftController!.text = newText;
      _lastDraftText = newText;
    }
  }

  void _onOrchestratorChanged() {
    if (mounted) setState(() {});
  }

  // Three-pane drag handlers
  void _handleLeftDividerDragStart() => setState(() {});

  void _handleLeftDividerDragUpdate(double deltaX, double totalWidth) {
    if (totalWidth < _calculateTotalMinWidth()) return;
    setState(() {
      final newWidth = _leftPaneWidth + deltaX;
      final maxCenterWidth = totalWidth - _rightPaneWidth - (2 * _dividerWidth);
      final maxWidth = maxCenterWidth - _minPaneWidth;
      _leftPaneWidth = newWidth.clamp(_minPaneWidth, maxWidth);
    });
  }

  void _handleLeftDividerDragEnd() => setState(() {});

  void _handleRightDividerDragStart() => setState(() {});

  void _handleRightDividerDragUpdate(double deltaX, double totalWidth) {
    if (totalWidth < _calculateTotalMinWidth()) return;
    setState(() {
      final newWidth = _rightPaneWidth - deltaX;
      final maxCenterWidth = totalWidth - _leftPaneWidth - (2 * _dividerWidth);
      final maxWidth = maxCenterWidth - _minPaneWidth;
      _rightPaneWidth = newWidth.clamp(_minPaneWidth, maxWidth);
    });
  }

  void _handleRightDividerDragEnd() => setState(() {});

  @override
  void didUpdateWidget(covariant WorkbenchShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _orchestrator?.removeListener(_onOrchestratorChanged);
    _orchestrator?.dispose();
    _aiPromptController.dispose();
    _draftFocusNode.dispose();
    _editorScrollController.dispose();
    _draftController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildShellBody(this, context);
}
