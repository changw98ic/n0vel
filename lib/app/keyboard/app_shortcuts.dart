import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// Intents
// ─────────────────────────────────────────────

class SaveVersionIntent extends Intent {
  const SaveVersionIntent();
}

class ToggleMenuDrawerIntent extends Intent {
  const ToggleMenuDrawerIntent();
}

class ToggleResourcesPanelIntent extends Intent {
  const ToggleResourcesPanelIntent();
}

class ToggleAiPanelIntent extends Intent {
  const ToggleAiPanelIntent();
}

class ToggleSettingsPanelIntent extends Intent {
  const ToggleSettingsPanelIntent();
}

class OpenReadingModeIntent extends Intent {
  const OpenReadingModeIntent();
}

class CreateSceneIntent extends Intent {
  const CreateSceneIntent();
}

class CloseActivePanelIntent extends Intent {
  const CloseActivePanelIntent();
}

class SelectPreviousSceneIntent extends Intent {
  const SelectPreviousSceneIntent();
}

class SelectNextSceneIntent extends Intent {
  const SelectNextSceneIntent();
}

// ─────────────────────────────────────────────
// Shortcut maps
// ─────────────────────────────────────────────

final Map<ShortcutActivator, Intent> workbenchShortcutMap =
    <ShortcutActivator, Intent>{
      // Save version: Ctrl+S / Cmd+S
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
          const SaveVersionIntent(),
      const SingleActivator(LogicalKeyboardKey.keyS, control: true):
          const SaveVersionIntent(),

      // Toggle menu drawer: Ctrl+M / Cmd+M
      const SingleActivator(LogicalKeyboardKey.keyM, meta: true):
          const ToggleMenuDrawerIntent(),
      const SingleActivator(LogicalKeyboardKey.keyM, control: true):
          const ToggleMenuDrawerIntent(),

      // Toggle resources panel: Ctrl+Shift+P / Cmd+Shift+P
      const SingleActivator(
        LogicalKeyboardKey.keyP,
        meta: true,
        shift: true,
      ): const ToggleResourcesPanelIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyP,
        control: true,
        shift: true,
      ): const ToggleResourcesPanelIntent(),

      // Toggle AI panel: Ctrl+Shift+A / Cmd+Shift+A
      const SingleActivator(
        LogicalKeyboardKey.keyA,
        meta: true,
        shift: true,
      ): const ToggleAiPanelIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyA,
        control: true,
        shift: true,
      ): const ToggleAiPanelIntent(),

      // Toggle settings panel: Ctrl+Shift+Comma / Cmd+Shift+Comma
      const SingleActivator(
        LogicalKeyboardKey.comma,
        meta: true,
        shift: true,
      ): const ToggleSettingsPanelIntent(),
      const SingleActivator(
        LogicalKeyboardKey.comma,
        control: true,
        shift: true,
      ): const ToggleSettingsPanelIntent(),

      // Open reading mode: Ctrl+Shift+R / Cmd+Shift+R
      const SingleActivator(
        LogicalKeyboardKey.keyR,
        meta: true,
        shift: true,
      ): const OpenReadingModeIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyR,
        control: true,
        shift: true,
      ): const OpenReadingModeIntent(),

      // Create scene: Ctrl+N / Cmd+N
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const CreateSceneIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const CreateSceneIntent(),

      // Close active panel: Escape
      const SingleActivator(LogicalKeyboardKey.escape):
          const CloseActivePanelIntent(),

      // Previous scene: Ctrl+Shift+Up / Cmd+Shift+Up
      const SingleActivator(
        LogicalKeyboardKey.arrowUp,
        meta: true,
        shift: true,
      ): const SelectPreviousSceneIntent(),
      const SingleActivator(
        LogicalKeyboardKey.arrowUp,
        control: true,
        shift: true,
      ): const SelectPreviousSceneIntent(),

      // Next scene: Ctrl+Shift+Down / Cmd+Shift+Down
      const SingleActivator(
        LogicalKeyboardKey.arrowDown,
        meta: true,
        shift: true,
      ): const SelectNextSceneIntent(),
      const SingleActivator(
        LogicalKeyboardKey.arrowDown,
        control: true,
        shift: true,
      ): const SelectNextSceneIntent(),
    };

// ─────────────────────────────────────────────
// Action definitions
// ─────────────────────────────────────────────

typedef WorkbenchShortcutCallback = void Function();

class WorkbenchShortcutActions extends StatelessWidget {
  const WorkbenchShortcutActions({
    super.key,
    required this.child,
    required this.onSaveVersion,
    required this.onToggleMenuDrawer,
    required this.onToggleResourcesPanel,
    required this.onToggleAiPanel,
    required this.onToggleSettingsPanel,
    required this.onOpenReadingMode,
    required this.onCreateScene,
    required this.onCloseActivePanel,
    required this.onSelectPreviousScene,
    required this.onSelectNextScene,
  });

  final Widget child;
  final WorkbenchShortcutCallback onSaveVersion;
  final WorkbenchShortcutCallback onToggleMenuDrawer;
  final WorkbenchShortcutCallback onToggleResourcesPanel;
  final WorkbenchShortcutCallback onToggleAiPanel;
  final WorkbenchShortcutCallback onToggleSettingsPanel;
  final WorkbenchShortcutCallback onOpenReadingMode;
  final WorkbenchShortcutCallback onCreateScene;
  final WorkbenchShortcutCallback onCloseActivePanel;
  final WorkbenchShortcutCallback onSelectPreviousScene;
  final WorkbenchShortcutCallback onSelectNextScene;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        SaveVersionIntent: CallbackAction<SaveVersionIntent>(
          onInvoke: (_) {
            onSaveVersion();
            return null;
          },
        ),
        ToggleMenuDrawerIntent: CallbackAction<ToggleMenuDrawerIntent>(
          onInvoke: (_) {
            onToggleMenuDrawer();
            return null;
          },
        ),
        ToggleResourcesPanelIntent: CallbackAction<ToggleResourcesPanelIntent>(
          onInvoke: (_) {
            onToggleResourcesPanel();
            return null;
          },
        ),
        ToggleAiPanelIntent: CallbackAction<ToggleAiPanelIntent>(
          onInvoke: (_) {
            onToggleAiPanel();
            return null;
          },
        ),
        ToggleSettingsPanelIntent: CallbackAction<ToggleSettingsPanelIntent>(
          onInvoke: (_) {
            onToggleSettingsPanel();
            return null;
          },
        ),
        OpenReadingModeIntent: CallbackAction<OpenReadingModeIntent>(
          onInvoke: (_) {
            onOpenReadingMode();
            return null;
          },
        ),
        CreateSceneIntent: CallbackAction<CreateSceneIntent>(
          onInvoke: (_) {
            onCreateScene();
            return null;
          },
        ),
        CloseActivePanelIntent: CallbackAction<CloseActivePanelIntent>(
          onInvoke: (_) {
            onCloseActivePanel();
            return null;
          },
        ),
        SelectPreviousSceneIntent: CallbackAction<SelectPreviousSceneIntent>(
          onInvoke: (_) {
            onSelectPreviousScene();
            return null;
          },
        ),
        SelectNextSceneIntent: CallbackAction<SelectNextSceneIntent>(
          onInvoke: (_) {
            onSelectNextScene();
            return null;
          },
        ),
      },
      child: Shortcuts(
        shortcuts: workbenchShortcutMap,
        child: child,
      ),
    );
  }
}
