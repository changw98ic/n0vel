import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/keyboard/app_shortcuts.dart';

void main() {
  group('WorkbenchShortcutActions', () {
    late List<String> actions;

    setUp(() {
      actions = <String>[];
    });

    Widget buildSubject() {
      return MaterialApp(
        home: WorkbenchShortcutActions(
          onSaveVersion: () => actions.add('saveVersion'),
          onToggleMenuDrawer: () => actions.add('toggleMenuDrawer'),
          onToggleResourcesPanel: () => actions.add('toggleResourcesPanel'),
          onToggleAiPanel: () => actions.add('toggleAiPanel'),
          onToggleSettingsPanel: () => actions.add('toggleSettingsPanel'),
          onOpenReadingMode: () => actions.add('openReadingMode'),
          onCreateScene: () => actions.add('createScene'),
          onCloseActivePanel: () => actions.add('closeActivePanel'),
          onSelectPreviousScene: () => actions.add('selectPreviousScene'),
          onSelectNextScene: () => actions.add('selectNextScene'),
          child: const Focus(
            autofocus: true,
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
    }

    Future<void> sendShortcut(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool meta = false,
      bool control = false,
      bool shift = false,
    }) async {
      if (meta) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      }
      if (control) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      }
      if (shift) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyUpEvent(key);
      if (shift) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      if (control) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }
      if (meta) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      }
      await tester.pump();
    }

    testWidgets('triggers saveVersion on meta+S', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(tester, LogicalKeyboardKey.keyS, meta: true);
      expect(actions, contains('saveVersion'));
    });

    testWidgets('triggers saveVersion on control+S', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(tester, LogicalKeyboardKey.keyS, control: true);
      expect(actions, contains('saveVersion'));
    });

    testWidgets('triggers toggleMenuDrawer on meta+M', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(tester, LogicalKeyboardKey.keyM, meta: true);
      expect(actions, contains('toggleMenuDrawer'));
    });

    testWidgets('triggers toggleResourcesPanel on meta+shift+P', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(
        tester,
        LogicalKeyboardKey.keyP,
        meta: true,
        shift: true,
      );
      expect(actions, contains('toggleResourcesPanel'));
    });

    testWidgets('triggers toggleAiPanel on meta+shift+A', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(
        tester,
        LogicalKeyboardKey.keyA,
        meta: true,
        shift: true,
      );
      expect(actions, contains('toggleAiPanel'));
    });

    testWidgets('triggers toggleSettingsPanel on meta+shift+Comma', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(
        tester,
        LogicalKeyboardKey.comma,
        meta: true,
        shift: true,
      );
      expect(actions, contains('toggleSettingsPanel'));
    });

    testWidgets('triggers openReadingMode on meta+shift+R', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(
        tester,
        LogicalKeyboardKey.keyR,
        meta: true,
        shift: true,
      );
      expect(actions, contains('openReadingMode'));
    });

    testWidgets('triggers createScene on meta+N', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(tester, LogicalKeyboardKey.keyN, meta: true);
      expect(actions, contains('createScene'));
    });

    testWidgets('triggers closeActivePanel on Escape', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(actions, contains('closeActivePanel'));
    });

    testWidgets('triggers selectPreviousScene on meta+shift+Up', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(
        tester,
        LogicalKeyboardKey.arrowUp,
        meta: true,
        shift: true,
      );
      expect(actions, contains('selectPreviousScene'));
    });

    testWidgets('triggers selectNextScene on meta+shift+Down', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await sendShortcut(
        tester,
        LogicalKeyboardKey.arrowDown,
        meta: true,
        shift: true,
      );
      expect(actions, contains('selectNextScene'));
    });

    testWidgets(
      'workbenchShortcutMap contains all expected shortcut entries',
      (tester) async {
        expect(workbenchShortcutMap, isNotEmpty);
        final intents = workbenchShortcutMap.values.toList();
        expect(intents.whereType<SaveVersionIntent>(), hasLength(2));
        expect(intents.whereType<ToggleMenuDrawerIntent>(), hasLength(2));
        expect(intents.whereType<ToggleResourcesPanelIntent>(), hasLength(2));
        expect(intents.whereType<ToggleAiPanelIntent>(), hasLength(2));
        expect(intents.whereType<ToggleSettingsPanelIntent>(), hasLength(2));
        expect(intents.whereType<OpenReadingModeIntent>(), hasLength(2));
        expect(intents.whereType<CreateSceneIntent>(), hasLength(2));
        expect(intents.whereType<CloseActivePanelIntent>(), hasLength(1));
        expect(intents.whereType<SelectPreviousSceneIntent>(), hasLength(2));
        expect(intents.whereType<SelectNextSceneIntent>(), hasLength(2));
      },
    );
  });
}
