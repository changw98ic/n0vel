import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:writing_assistant/app/app.dart';
import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/shared/data/base_business/base_controller.dart';

const _settle = Duration(seconds: 1);
const _longSettle = Duration(seconds: 2);
const _editorReturnDelay = Duration(seconds: 2);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Directory? tempDir;

  setUp(() {
    Get.reset();
    BaseController.suppressSnackbars = true;
    tempDir = Directory.systemTemp.createTempSync('wa_integration_');
    AppDatabase.debugOverridePath =
        '${tempDir!.path}${Platform.pathSeparator}writing_assistant_test.db';
  });

  tearDown(() async {
    AppDatabase.debugOverridePath = null;
    BaseController.suppressSnackbars = false;
    Get.reset();

    final dir = tempDir;
    tempDir = null;
    if (dir != null && dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Desktop integration tests may still hold the sqlite file briefly.
      }
    }
  });

  testWidgets('作品流：从作品库创建作品', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(tester, title: '测试小说：星辰大海', description: '一部关于星际冒险的科幻小说');

    expect(find.text('测试小说：星辰大海'), findsOneWidget);
    await _finishScenario(tester);
  });

  testWidgets('章节流：创建首章时自动创建首卷', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(
      tester,
      title: '章节测试作品',
      description: '用于验证章节和卷自动创建的测试作品',
    );
    await _openWorkDetail(tester, '章节测试作品');
    await _createFirstChapter(tester, '第一章：启程');

    expect(find.textContaining('第一章：启程'), findsOneWidget);
    expect(find.text('第 1 卷'), findsOneWidget);
    await _finishScenario(tester);
  });

  testWidgets('章节编辑流：重命名章节后返回详情页可见', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(
      tester,
      title: '章节编辑测试作品',
      description: '用于验证章节重命名链路的测试作品',
    );
    await _openWorkDetail(tester, '章节编辑测试作品');
    await _createFirstChapter(tester, '第一章：旧标题', returnToDetail: false);
    await _renameChapterInEditor(tester, '第一章：风暴前夜');
    await _returnFromEditorToDetail(tester);

    expect(find.textContaining('第一章：风暴前夜'), findsOneWidget);
    await _finishScenario(tester);
  });

  testWidgets('章节正文编辑流：保存后重开仍保留', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(
      tester,
      title: '章节正文测试作品',
      description: '用于验证章节正文保存持久化的测试作品',
    );
    await _openWorkDetail(tester, '章节正文测试作品');
    await _createFirstChapter(tester, '第一章：正文测试');
    await _openChapterFromDetail(tester, '第一章：正文测试');

    const content =
        '夜雨刚停，长街尽头还残着水光。巡夜人提灯穿过石桥，听见桥洞里传来极轻的脚步声，'
        '像是有人故意躲着火光。他屏住呼吸，贴着石栏慢慢前行，忽然在桥洞阴影里看见一只'
        '染血的木匣，匣面刻着早已废弃的旧王朝徽记。';
    await _replaceChapterContent(tester, content);
    await _saveChapterContent(tester);
    await _returnFromEditorToDetail(tester);

    await _openChapterFromDetail(tester, '第一章：正文测试');

    final textField = tester.widget<TextField>(
      find.byKey(const Key('chapter_editor_content_field')),
    );
    expect(textField.controller?.text, content);
    await _finishScenario(tester);
  });

  testWidgets('角色流：从设定页创建角色', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(tester, title: '角色测试作品', description: '用于验证角色创建链路的测试作品');
    await _openWorkDetail(tester, '角色测试作品');
    await _openWorldPanel(tester);
    await _openCharacterList(tester);
    await _createCharacter(tester, '林星辰');

    expect(find.byKey(const ValueKey('character_card_林星辰')), findsOneWidget);
    await _finishScenario(tester);
  });

  testWidgets('角色档案流：填写 Profile 后返回详情页可见核心价值观', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(
      tester,
      title: '角色档案测试作品',
      description: '用于验证角色深度档案编辑的测试作品',
    );
    await _openWorkDetail(tester, '角色档案测试作品');
    await _openWorldPanel(tester);
    await _openCharacterList(tester);
    await _createCharacter(tester, '赵衡', tier: 'protagonist');

    await _openCharacterDetail(tester, '赵衡');
    final startProfile = find.byKey(
      const Key('character_detail_start_profile_button'),
    );
    expect(startProfile, findsOneWidget);
    await tester.tap(startProfile);
    await tester.pump(_longSettle);
    await _fillCharacterProfile(
      tester,
      coreValues: '守护同伴',
      fears: '失去家人',
      desires: '重建家园',
      moralBaseline: '绝不背叛并肩作战的人',
    );

    expect(find.text('守护同伴'), findsOneWidget);
    await _finishScenario(tester);
  });

  testWidgets('角色编辑归档流：编辑名称并归档后默认列表隐藏且状态落库', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(
      tester,
      title: '角色编辑测试作品',
      description: '用于验证角色编辑和归档的测试作品',
    );
    await _openWorkDetail(tester, '角色编辑测试作品');
    await _openWorldPanel(tester);
    await _openCharacterList(tester);
    await _createCharacter(tester, '林星辰');

    await _openCharacterOptions(tester, '林星辰');
    await tester.tap(find.byKey(const Key('character_option_edit')));
    await tester.pump(_longSettle);
    await _renameCharacter(tester, '林月');

    expect(find.byKey(const ValueKey('character_card_林月')), findsOneWidget);
    expect(find.text('林星辰'), findsNothing);

    await _openCharacterOptions(tester, '林月');
    await tester.tap(find.byKey(const Key('character_option_archive')));
    await tester.pump(_longSettle);
    await tester.pump(const Duration(seconds: 8));

    expect(find.text('林月'), findsNothing);
    final db = Get.find<AppDatabase>();
    final archivedRows = await (db.select(
      db.characters,
    )..where((t) => t.name.equals('林月'))).get();
    expect(archivedRows, hasLength(1));
    expect(archivedRows.single.isArchived, isTrue);
    await _finishScenario(tester);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
      builder: (context, child) => const WritingAssistantApp(),
    ),
  );
  await tester.pump(_settle);
}

Future<void> _openWorksTab(WidgetTester tester) async {
  final target = find.text('作品');
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pump(_settle);
}

Future<void> _createWork(
  WidgetTester tester, {
  required String title,
  required String description,
}) async {
  final newWorkBtn = find.byKey(const Key('work_list_new_work_button'));
  expect(newWorkBtn, findsOneWidget);
  await tester.tap(newWorkBtn);
  await tester.pump(_settle);

  final nameField = find.byKey(const Key('work_form_name_field'));
  final descField = find.byKey(const Key('work_form_description_field'));
  expect(nameField, findsOneWidget);
  expect(descField, findsOneWidget);

  await tester.enterText(nameField, title);
  await tester.enterText(descField, description);

  final submitBtn = find.byKey(const Key('work_form_submit_button'));
  expect(submitBtn, findsOneWidget);
  await tester.tap(submitBtn);
  await tester.pump(_longSettle);
  await tester.pump(const Duration(seconds: 4));
}

Future<void> _openWorkDetail(WidgetTester tester, String workTitle) async {
  final workCard = find.text(workTitle);
  expect(workCard, findsOneWidget);
  await tester.tap(workCard.first);
  await tester.pump(_longSettle);
}

Future<void> _createFirstChapter(
  WidgetTester tester,
  String chapterTitle, {
  bool returnToDetail = true,
}) async {
  final chapterButton = find.byKey(const Key('work_detail_new_chapter_button'));
  expect(chapterButton, findsOneWidget);
  await tester.tap(chapterButton);
  await tester.pump(_settle);

  final titleField = find.byKey(const Key('create_chapter_title_field'));
  expect(titleField, findsOneWidget);
  await tester.enterText(titleField, chapterTitle);

  final confirmButton = find.byKey(const Key('create_chapter_confirm_button'));
  expect(confirmButton, findsOneWidget);
  await tester.tap(confirmButton);
  await tester.pump(_longSettle);
  await tester.pump(_editorReturnDelay);

  if (!returnToDetail) {
    return;
  }

  await _returnFromEditorToDetail(tester);
}

Future<void> _returnFromEditorToDetail(WidgetTester tester) async {
  expect(Get.currentRoute, isNotEmpty);
  Get.back();
  await tester.pump(_longSettle);
  await tester.pump(const Duration(seconds: 4));
}

Future<void> _renameChapterInEditor(
  WidgetTester tester,
  String newTitle,
) async {
  final renameButton = find.byKey(const Key('chapter_editor_rename_button'));
  expect(renameButton, findsOneWidget);
  await tester.tap(renameButton);
  await tester.pump(_settle);

  final renameField = find.byKey(const Key('chapter_editor_rename_field'));
  expect(renameField, findsOneWidget);
  await tester.enterText(renameField, newTitle);

  final saveButton = find.byKey(const Key('chapter_editor_rename_save_button'));
  expect(saveButton, findsOneWidget);
  await tester.tap(saveButton);
  await tester.pump(_longSettle);
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _openWorldPanel(WidgetTester tester) async {
  final worldTab = find.byKey(const Key('work_detail_world_tab'));
  expect(worldTab, findsOneWidget);
  await tester.ensureVisible(worldTab);
  await tester.tap(worldTab);
  await tester.pump(_settle);
}

Future<void> _openCharacterList(WidgetTester tester) async {
  final characterAction = find.byKey(
    const Key('work_detail_characters_action'),
  );
  expect(characterAction, findsOneWidget);
  await tester.tap(characterAction);
  await tester.pump(_longSettle);
}

Future<void> _createCharacter(
  WidgetTester tester,
  String name, {
  String? tier,
}) async {
  final addButton = find.byKey(const Key('character_list_new_character_fab'));
  expect(addButton, findsOneWidget);
  await tester.tap(addButton);
  await tester.pump(_settle);

  if (tier != null) {
    final tierChip = find.byKey(Key('character_form_tier_$tier'));
    expect(tierChip, findsOneWidget);
    await tester.tap(tierChip);
    await tester.pump(const Duration(milliseconds: 300));
  }

  final nameField = find.byKey(const Key('character_form_name_field'));
  expect(nameField, findsOneWidget);
  await tester.enterText(nameField, name);

  final saveButton = find.byKey(const Key('character_form_save_button'));
  expect(saveButton, findsOneWidget);
  await tester.tap(saveButton);
  await tester.pump(_longSettle);
  await _waitForCharacterCard(tester, name);
}

Future<void> _openCharacterOptions(WidgetTester tester, String name) async {
  final card = await _waitForCharacterCard(tester, name);
  await tester.longPress(card);
  await tester.pump(_settle);
}

Future<void> _renameCharacter(WidgetTester tester, String newName) async {
  final nameField = find.byKey(const Key('character_form_name_field'));
  expect(nameField, findsOneWidget);
  await tester.enterText(nameField, newName);

  final saveButton = find.byKey(const Key('character_form_save_button'));
  expect(saveButton, findsOneWidget);
  await tester.tap(saveButton);
  await tester.pump(_longSettle);
  await _waitForCharacterCard(tester, newName);
}

Future<void> _openChapterFromDetail(
  WidgetTester tester,
  String chapterTitle,
) async {
  final row = await _waitForChapterRow(tester, chapterTitle);
  await tester.tap(row);
  await tester.pump(_longSettle);
}

Future<void> _replaceChapterContent(WidgetTester tester, String content) async {
  final field = find.byKey(const Key('chapter_editor_content_field'));
  expect(field, findsOneWidget);
  await tester.enterText(field, content);
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _saveChapterContent(WidgetTester tester) async {
  final saveButton = find.byKey(const Key('chapter_editor_save_button'));
  expect(saveButton, findsOneWidget);
  await tester.tap(saveButton);
  await tester.pump(_longSettle);
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _openCharacterDetail(WidgetTester tester, String name) async {
  final card = await _waitForCharacterCard(tester, name);
  await tester.tap(card);
  await tester.pump(_longSettle);
}

Future<void> _fillCharacterProfile(
  WidgetTester tester, {
  required String coreValues,
  required String fears,
  required String desires,
  required String moralBaseline,
}) async {
  final mbtiChip = find.byKey(const Key('character_profile_mbti_INTJ'));
  expect(mbtiChip, findsOneWidget);
  await tester.tap(mbtiChip);
  await tester.pump(const Duration(milliseconds: 300));

  await tester.enterText(
    find.byKey(const Key('character_profile_core_values_field')),
    coreValues,
  );
  await tester.enterText(
    find.byKey(const Key('character_profile_fears_field')),
    fears,
  );
  await tester.enterText(
    find.byKey(const Key('character_profile_desires_field')),
    desires,
  );
  await tester.enterText(
    find.byKey(const Key('character_profile_moral_baseline_field')),
    moralBaseline,
  );

  final saveButton = find.byKey(const Key('character_profile_save_button'));
  expect(saveButton, findsOneWidget);
  await tester.tap(saveButton);
  await tester.pump(_longSettle);
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _finishScenario(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<Finder> _waitForCharacterCard(WidgetTester tester, String name) async {
  final finder = find.byKey(ValueKey('character_card_$name'));
  for (var i = 0; i < 16; i++) {
    if (finder.evaluate().isNotEmpty) {
      return finder;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(finder, findsOneWidget);
  return finder;
}

Future<Finder> _waitForChapterRow(
  WidgetTester tester,
  String chapterTitle,
) async {
  final finder = find.byKey(ValueKey('chapter_row_$chapterTitle'));
  for (var i = 0; i < 16; i++) {
    if (finder.evaluate().isNotEmpty) {
      return finder;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(finder, findsOneWidget);
  return finder;
}
