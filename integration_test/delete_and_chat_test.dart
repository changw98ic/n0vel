import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:writing_assistant/app/app.dart';
import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart';
import 'package:writing_assistant/shared/data/base_business/base_controller.dart';

const _settle = Duration(seconds: 1);
const _longSettle = Duration(seconds: 2);

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
      } catch (_) {}
    }
  });

  testWidgets('删除流：从作品库删除作品并确认数据库已清除', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(tester, title: '删除测试作品', description: '用于验证作品删除的测试作品');

    final workCard = await _waitForWorkCard(tester, '删除测试作品');
    await tester.longPress(workCard);
    await tester.pump(_settle);

    final deleteOption = find.byKey(const Key('work_option_delete'));
    expect(deleteOption, findsOneWidget);
    await tester.ensureVisible(deleteOption);
    await tester.tap(deleteOption);
    await tester.pump(_settle);
    await tester.tap(find.byKey(const Key('work_delete_confirm_button')));
    await tester.pump(_longSettle);
    await tester.pump(const Duration(seconds: 4));

    expect(find.byKey(const ValueKey('work_card_删除测试作品')), findsNothing);

    final db = Get.find<AppDatabase>();
    final rows = await (db.select(
      db.works,
    )..where((t) => t.name.equals('删除测试作品'))).get();
    expect(rows, isEmpty);
    await _finishScenario(tester);
  });

  testWidgets('删除流：从作品详情删除章节并确认数据库已清除', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(tester, title: '章节删除测试作品', description: '用于验证章节删除的测试作品');
    await _openWorkDetail(tester, '章节删除测试作品');
    await _createFirstChapter(tester, '第一章：待删除');

    final chapterRow = await _waitForChapterRow(tester, '第一章：待删除');
    await tester.longPress(chapterRow);
    await tester.pump(_settle);

    await tester.tap(find.byKey(const Key('chapter_delete_confirm_button')));
    await tester.pump(_longSettle);
    await tester.pump(const Duration(seconds: 4));

    expect(find.byKey(const ValueKey('chapter_row_第一章：待删除')), findsNothing);

    final db = Get.find<AppDatabase>();
    final rows = await (db.select(
      db.chapters,
    )..where((t) => t.title.equals('第一章：待删除'))).get();
    expect(rows, isEmpty);
    await _finishScenario(tester);
  });

  testWidgets('删除流：删除卷时会级联清除其章节', (tester) async {
    await _pumpApp(tester);
    await _openWorksTab(tester);
    await _createWork(tester, title: '卷删除测试作品', description: '用于验证卷删除的测试作品');
    await _openWorkDetail(tester, '卷删除测试作品');
    await _createFirstChapter(tester, '第一章：卷内章节');

    final volumeDeleteButton = find.byKey(
      const ValueKey('volume_delete_button_第 1 卷'),
    );
    expect(volumeDeleteButton, findsOneWidget);
    await tester.tap(volumeDeleteButton);
    await tester.pump(_settle);

    await tester.tap(find.byKey(const Key('volume_delete_confirm_button')));
    await tester.pump(_longSettle);
    await tester.pump(const Duration(seconds: 4));

    final db = Get.find<AppDatabase>();
    final volumeRows = await (db.select(
      db.volumes,
    )..where((t) => t.name.equals('第 1 卷'))).get();
    final chapterRows = await (db.select(
      db.chapters,
    )..where((t) => t.title.equals('第一章：卷内章节'))).get();
    expect(volumeRows, isEmpty);
    expect(chapterRows, isEmpty);
    await _finishScenario(tester);
  });

  testWidgets('AI 聊天流：新建并删除会话时数据库同步更新', (tester) async {
    await _pumpApp(tester);
    await _openAiChatTab(tester);

    final newConversationButton = find.byKey(
      const Key('ai_chat_sidebar_new_conversation_button'),
    );
    expect(newConversationButton, findsOneWidget);
    await tester.tap(newConversationButton);
    await tester.pump(_longSettle);

    final conversationTile = find.byKey(
      const ValueKey('ai_chat_conversation_新对话'),
    );
    expect(conversationTile, findsOneWidget);
    await tester.tap(conversationTile);
    await tester.pump(_longSettle);

    final db = Get.find<AppDatabase>();
    final createdRows = await db.select(db.chatConversations).get();
    expect(createdRows, hasLength(1));
    final conversationId = createdRows.single.id;

    final deleteButton = await _waitForFinder(
      tester,
      find.byKey(const Key('ai_chat_delete_conversation_button')),
    );
    await tester.tap(deleteButton);
    await tester.pump(_longSettle);
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.byKey(const ValueKey('ai_chat_conversation_新对话')),
      findsNothing,
    );

    final deletedRows = await (db.select(
      db.chatConversations,
    )..where((t) => t.id.equals(conversationId))).get();
    expect(deletedRows, isEmpty);
    await _finishScenario(tester);
  });

  testWidgets('AI 聊天流：发送消息后用户消息会持久化到数据库', (tester) async {
    await _pumpApp(tester);
    await _configureFastFailAi();
    await _openAiChatTab(tester);

    await tester.enterText(
      find.byKey(const Key('ai_chat_input_field')),
      '请帮我记录这条测试消息',
    );
    await tester.tap(find.byKey(const Key('ai_chat_send_button')));
    await tester.pump(_longSettle);
    await tester.pump(const Duration(seconds: 2));

    final db = Get.find<AppDatabase>();
    final conversations = await db.select(db.chatConversations).get();
    expect(conversations, hasLength(1));

    final messages = await (db.select(
      db.chatMessages,
    )..where((t) => t.role.equals('user'))).get();
    expect(messages, hasLength(1));
    expect(messages.single.content, '请帮我记录这条测试消息');
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

Future<void> _openAiChatTab(WidgetTester tester) async {
  final target = find.text('AI 助手');
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pump(_settle);
}

Future<void> _configureFastFailAi() async {
  final repo = Get.find<AIConfigRepository>();
  for (final tier in ModelTier.values) {
    await repo.saveModelConfig(
      tier: tier,
      providerType: 'custom',
      modelName: 'integration-test',
      apiEndpoint: 'http://127.0.0.1:9/v1',
      apiKey: 'integration-test',
      temperature: 0.1,
      maxOutputTokens: 128,
    );
  }
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

  await tester.enterText(find.byKey(const Key('work_form_name_field')), title);
  await tester.enterText(
    find.byKey(const Key('work_form_description_field')),
    description,
  );

  await tester.tap(find.byKey(const Key('work_form_submit_button')));
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
  String chapterTitle,
) async {
  await tester.tap(find.byKey(const Key('work_detail_new_chapter_button')));
  await tester.pump(_settle);
  await tester.enterText(
    find.byKey(const Key('create_chapter_title_field')),
    chapterTitle,
  );
  await tester.tap(find.byKey(const Key('create_chapter_confirm_button')));
  await tester.pump(_longSettle);
  Get.back();
  await tester.pump(_longSettle);
  await tester.pump(const Duration(seconds: 6));
}

Future<Finder> _waitForWorkCard(WidgetTester tester, String workTitle) async {
  final finder = find.byKey(ValueKey('work_card_$workTitle'));
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

Future<void> _finishScenario(WidgetTester tester) async {
  Get.closeAllSnackbars();
  await tester.pump(const Duration(seconds: 3));
}

Future<Finder> _waitForFinder(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 16; i++) {
    if (finder.evaluate().isNotEmpty) {
      return finder;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(finder, findsOneWidget);
  return finder;
}
