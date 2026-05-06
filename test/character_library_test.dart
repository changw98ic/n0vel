import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/main.dart';

void main() {
  setUp(() {
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
  });

  testWidgets('shows character library ready state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );

    expect(find.text('角色库'), findsOneWidget);
    expect(find.text('维护人物信息、心理参数与引用场景'), findsOneWidget);
    expect(find.text('新建角色'), findsOneWidget);
    expect(find.text('人物资料已保存'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(uiState: CharacterLibraryUiState.empty),
      ),
    );

    expect(find.text('当前项目无角色'), findsOneWidget);
    expect(find.text('创建第一个角色'), findsOneWidget);
    expect(
      find.textContaining('先建立主要人物'),
      findsOneWidget,
    );
  });

  testWidgets('shows search no results state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.searchNoResults,
        ),
      ),
    );

    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('没有找到匹配角色'), findsOneWidget);
    expect(find.text('清空搜索'), findsOneWidget);
    expect(find.text('未选中角色'), findsOneWidget);
  });

  testWidgets('shows missing required fields state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.missingRequiredFields,
        ),
      ),
    );

    expect(find.text('缺少必填字段'), findsOneWidget);
    expect(
      find.textContaining('当前人物还没有名字'),
      findsOneWidget,
    );
    expect(
      find.textContaining('缺少姓名时，系统不会生成角色摘要'),
      findsOneWidget,
    );
  });

  testWidgets('shows delete referenced confirm overlay', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.deleteReferencedConfirm,
        ),
      ),
    );

    expect(find.text('删除被引用角色？'), findsOneWidget);
    expect(find.textContaining('仍被'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('查看引用后再删'), findsOneWidget);
  });

  testWidgets('ready state shows character list with default characters', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.byKey(CharacterLibraryPage.searchFieldKey), findsOneWidget);
    expect(find.text('柳溪'), findsWidgets);
    expect(find.text('岳人'), findsWidgets);
    expect(find.text('傅行舟'), findsWidgets);
  });

  testWidgets('ready state shows editable fields for selected character', (
    tester,
  ) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.text('角色详情'), findsOneWidget);
    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('身份'), findsOneWidget);
    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('核心需求'), findsOneWidget);
    expect(find.text('人物摘要'), findsWidgets);
  });

  testWidgets('ready state shows summary panel', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    expect(find.text('引用摘要'), findsOneWidget);
    expect(find.text('引用场景'), findsWidgets);
  });

  // ---------------------------------------------------------------------------
  // PRD-04 Interactive Tests
  // ---------------------------------------------------------------------------

  testWidgets('creates a new character with all fields', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    // Tap the "新建角色" button to create a new character.
    await tester.tap(find.byKey(CharacterLibraryPage.newCharacterButtonKey));
    await tester.pump();

    // The new character is inserted at index 0. Get its dynamic ID.
    final newCharacterId = workspaceStore.characters.first.id;

    // Enter text in each editable field.
    await tester.enterText(
      find.byKey(
        ValueKey<String>(
          '${CharacterLibraryPage.nameFieldKey.value}-$newCharacterId',
        ),
      ),
      '柳溪',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(
        ValueKey<String>(
          '${CharacterLibraryPage.roleFieldKey.value}-$newCharacterId',
        ),
      ),
      '调查记者',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(
        ValueKey<String>(
          '${CharacterLibraryPage.noteFieldKey.value}-$newCharacterId',
        ),
      ),
      '性格果断',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(
        ValueKey<String>(
          '${CharacterLibraryPage.needFieldKey.value}-$newCharacterId',
        ),
      ),
      '追查真相',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(
        ValueKey<String>(
          '${CharacterLibraryPage.summaryFieldKey.value}-$newCharacterId',
        ),
      ),
      '柳溪是一名调查记者',
    );
    await tester.pump();

    // Verify the name and role appear in the widget tree (list button + detail).
    expect(find.text('柳溪'), findsWidgets);
    expect(find.text('调查记者'), findsWidgets);
  });

  testWidgets('edits an existing character name', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    // Default project has 柳溪 (id: character-liuxi) at some index.
    // Find and tap 柳溪 in the list to select it.
    // The list shows character names as buttons.
    final liuXiButtons = find.text('柳溪');
    expect(liuXiButtons, findsWidgets);

    // Tap the first 柳溪 text (the list button) to ensure it is selected.
    await tester.tap(liuXiButtons.first);
    await tester.pump();

    // Now clear the name field and enter a new name.
    // The default project created by createProject clones default characters,
    // so the ID is not the stable 'character-liuxi'. Find it from the store.
    final liuXi = workspaceStore.characters.firstWhere(
      (c) => c.name == '柳溪',
    );
    final nameFieldKey = ValueKey<String>(
      '${CharacterLibraryPage.nameFieldKey.value}-${liuXi.id}',
    );

    await tester.enterText(find.byKey(nameFieldKey), '林晓');
    await tester.pump();

    // Verify the updated name appears in the widget tree.
    expect(find.text('林晓'), findsWidgets);
    // The old name should no longer appear as a list button label.
    expect(find.text('柳溪'), findsNothing);
  });

  testWidgets('filters characters by search query', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(home: CharacterLibraryPage()),
    );
    final workspaceStore = AppWorkspaceScope.of(
      tester.element(find.byType(CharacterLibraryPage)),
    );
    workspaceStore.createProject();
    await tester.pump();

    // Default project has 柳溪, 岳人, 傅行舟.
    expect(find.text('柳溪'), findsWidgets);
    expect(find.text('岳人'), findsWidgets);
    expect(find.text('傅行舟'), findsWidgets);

    // Enter a search query that only matches 柳溪.
    await tester.enterText(
      find.byKey(CharacterLibraryPage.searchFieldKey),
      '柳',
    );
    await tester.pump();

    // 柳溪 should still be visible, but 岳人 and 傅行舟 should be filtered out
    // from the list panel. The detail panel may still show the selected character.
    expect(find.text('柳溪'), findsWidgets);
    expect(find.text('岳人'), findsNothing);
    expect(find.text('傅行舟'), findsNothing);

    // Clear the search to restore all characters.
    await tester.enterText(
      find.byKey(CharacterLibraryPage.searchFieldKey),
      '',
    );
    await tester.pump();

    expect(find.text('柳溪'), findsWidgets);
    expect(find.text('岳人'), findsWidgets);
    expect(find.text('傅行舟'), findsWidgets);
  });

  // Note: Character deletion is skipped because the production code does not
  // expose a deleteCharacter() method or a delete button on CharacterLibraryPage.
  // The delete-referenced-confirm overlay exists but is triggered by UI state
  // enum only; there is no interactive delete flow to test end-to-end.

  testWidgets('shows warning when required fields are empty', (tester) async {
    // The missing-required-fields state is a UI state that shows a warning
    // card when the character has no name. This is set via the uiState enum
    // rather than reactive form validation, so we test the overlay directly.
    await tester.pumpWidget(
      const NovelWriterApp(
        home: CharacterLibraryPage(
          uiState: CharacterLibraryUiState.missingRequiredFields,
        ),
      ),
    );

    // Verify the warning card appears with expected messages.
    expect(find.text('缺少必填字段'), findsOneWidget);
    expect(
      find.textContaining('当前人物还没有名字'),
      findsOneWidget,
    );
    expect(
      find.textContaining('缺少姓名时，系统不会生成角色摘要'),
      findsOneWidget,
    );

    // The detail panel should still show editable fields when a character
    // is present, but with the warning card above them.
    expect(find.text('角色详情'), findsOneWidget);
    expect(find.text('姓名'), findsOneWidget);
  });
}
