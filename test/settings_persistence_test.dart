import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
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
import 'package:novel_writer/app/widgets/app_loading_state.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';
import 'package:novel_writer/main.dart';
import 'test_support/app_settings_fake_storages.dart';
import 'test_support/clipboard_spy.dart';
import 'test_support/fake_app_llm_client.dart';

void main() {
  setUp(() {
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSettingsStore.debugLlmClientOverride = FakeAppLlmClient();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSettingsStore.debugLlmClientOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
  });

  testWidgets('shows pencil-aligned settings header copy', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    expect(find.text('设置与模型密钥'), findsOneWidget);
    expect(find.text('连接你自己的模型服务，其余写作流程保持本地运行'), findsOneWidget);
    expect(find.text('配置保存在本地 · 导出包不包含 API 密钥'), findsOneWidget);
  });

  testWidgets('reopening settings hydrates the saved values from store', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsShellPage.baseUrlFieldKey),
      'https://api.openai.local/v1',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.modelFieldKey),
      'gpt-5.4',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-saved-key',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.maxConcurrentRequestsFieldKey),
      '2',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    final baseUrlField = tester.widget<TextField>(
      find.byKey(SettingsShellPage.baseUrlFieldKey),
    );
    final modelField = tester.widget<TextField>(
      find.byKey(SettingsShellPage.modelFieldKey),
    );
    final apiKeyField = tester.widget<TextField>(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
    );
    final maxConcurrentRequestsField = tester.widget<TextField>(
      find.byKey(SettingsShellPage.maxConcurrentRequestsFieldKey),
    );

    expect(baseUrlField.controller?.text, 'https://api.openai.local/v1');
    expect(modelField.controller?.text, 'gpt-5.4');
    expect(apiKeyField.controller?.text, 'sk-saved-key');
    expect(maxConcurrentRequestsField.controller?.text, '2');
  });

  testWidgets('reopening settings preserves the latest feedback status', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-feedback-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pump();
    expect(find.text('保存成功'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    expect(find.text('保存成功'), findsWidgets);
    expect(find.text('新配置会从下一次 AI 请求开始生效。'), findsWidgets);
  });

  testWidgets('switching to dark theme updates and persists app theme mode', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: WorkbenchShellPage()));

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SettingsShellPage.themeDarkButtonKey));
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WorkbenchShellPage.settingsToolButtonKey));
    await tester.pump();
    await tester.tap(find.text('打开完整设置'));
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('settings surface secure storage write failures to the user', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = FailingSecureSettingsStorage();

    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-warning-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('设置保存失败'), findsWidgets);
    expect(find.textContaining('未能持久化到 settings.json'), findsWidgets);
    expect(find.textContaining('诊断：settings.json write denied'), findsWidgets);
  });

  testWidgets(
    'global shell warning can retry secure store access after a write failure',
    (tester) async {
      AppSettingsStore.debugStorageOverride = RecoveringWriteStorage();

      await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-warning-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DesktopShellFrame.retrySecureStoreButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('配置已重新保存'), findsWidgets);
      expect(
        find.byKey(DesktopShellFrame.retrySecureStoreButtonKey),
        findsNothing,
      );
    },
  );

  testWidgets('settings surface legacy migration warnings after restore', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = LegacyMigrationWarningStorage();

    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));
    await tester.pumpAndSettle();

    expect(find.text('设置文件读取失败'), findsWidgets);
    expect(find.textContaining('无法读取 settings.json'), findsWidgets);
    expect(
      find.textContaining('诊断：settings.json contains invalid legacy data'),
      findsWidgets,
    );
  });

  testWidgets('settings surface secure store read failures after restore', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = ReadFailureWarningStorage();

    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));
    await tester.pumpAndSettle();

    expect(find.text('设置文件读取失败'), findsWidgets);
    expect(find.textContaining('无法读取 settings.json'), findsWidgets);
    expect(find.textContaining('诊断：settings.json is unreadable'), findsWidgets);
  });

  testWidgets('settings can retry secure store access after a read failure', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = RecoveringReadStorage();

    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(SettingsShellPage.retrySecureStoreButtonKey),
      findsOneWidget,
    );

    await tester.tap(find.byKey(SettingsShellPage.retrySecureStoreButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('配置已重新加载'), findsWidgets);
    expect(
      find.byKey(SettingsShellPage.retrySecureStoreButtonKey),
      findsNothing,
    );

    final apiKeyField = tester.widget<TextField>(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
    );
    expect(apiKeyField.controller?.text, 'sk-recovered-key');
  });

  testWidgets(
    'retrying secure store access preserves unsaved non-secret field edits',
    (tester) async {
      AppSettingsStore.debugStorageOverride = RecoveringReadStorage();

      await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SettingsShellPage.baseUrlFieldKey),
        'https://draft.local/v1',
      );

      await tester.tap(find.byKey(SettingsShellPage.retrySecureStoreButtonKey));
      await tester.pumpAndSettle();

      final baseUrlField = tester.widget<TextField>(
        find.byKey(SettingsShellPage.baseUrlFieldKey),
      );
      final apiKeyField = tester.widget<TextField>(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
      );

      expect(baseUrlField.controller?.text, 'https://draft.local/v1');
      expect(apiKeyField.controller?.text, 'sk-recovered-key');
    },
  );

  testWidgets('settings can retry secure store access after a write failure', (
    tester,
  ) async {
    AppSettingsStore.debugStorageOverride = RecoveringWriteStorage();

    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-warning-key',
    );
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(SettingsShellPage.retrySecureStoreButtonKey),
      findsOneWidget,
    );
    expect(find.text('设置保存失败'), findsWidgets);

    await tester.tap(find.byKey(SettingsShellPage.retrySecureStoreButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('配置已重新保存'), findsWidgets);
    expect(find.text('当前请求'), findsOneWidget);
    expect(find.text('不自动重试'), findsOneWidget);
    expect(
      find.byKey(SettingsShellPage.retrySecureStoreButtonKey),
      findsNothing,
    );
  });

  testWidgets(
    'retrying a write failure uses the latest edited settings values',
    (tester) async {
      AppSettingsStore.debugStorageOverride = RecoveringWriteStorage();

      await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-warning-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SettingsShellPage.baseUrlFieldKey),
        'https://override.local/v1',
      );
      await tester.enterText(
        find.byKey(SettingsShellPage.modelFieldKey),
        'gpt-5.4',
      );

      await tester.tap(find.byKey(SettingsShellPage.retrySecureStoreButtonKey));
      await tester.pumpAndSettle();

      final baseUrlField = tester.widget<TextField>(
        find.byKey(SettingsShellPage.baseUrlFieldKey),
      );
      final modelField = tester.widget<TextField>(
        find.byKey(SettingsShellPage.modelFieldKey),
      );

      expect(find.text('配置已重新保存'), findsWidgets);
      expect(baseUrlField.controller?.text, 'https://override.local/v1');
      expect(modelField.controller?.text, 'gpt-5.4');
    },
  );

  testWidgets(
    'settings can copy diagnostic details from a persistence warning',
    (tester) async {
      AppSettingsStore.debugStorageOverride = FailingSecureSettingsStorage();
      final clipboard = ClipboardSpy(tester)..attach();
      addTearDown(() {
        clipboard.detach();
      });

      await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-warning-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SettingsShellPage.copyDiagnosticButtonKey));
      await tester.pump();

      expect(clipboard.text, contains('类别：settings_file_write_failed'));
      expect(clipboard.text, contains('诊断：settings.json write denied'));
      expect(find.text('诊断已复制'), findsOneWidget);
    },
  );

  testWidgets(
    'global shell warning can copy diagnostic details after a write failure',
    (tester) async {
      AppSettingsStore.debugStorageOverride = FailingSecureSettingsStorage();
      final clipboard = ClipboardSpy(tester)..attach();
      addTearDown(() {
        clipboard.detach();
      });

      await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

      await tester.enterText(
        find.byKey(SettingsShellPage.apiKeyFieldKey),
        'sk-warning-key',
      );
      await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(DesktopShellFrame.copyDiagnosticButtonKey));
      await tester.pump();

      expect(clipboard.text, contains('类别：settings_file_write_failed'));
      expect(clipboard.text, contains('诊断：settings.json write denied'));
      expect(find.text('诊断已复制'), findsOneWidget);
    },
  );

  testWidgets('connection test surfaces unauthorized failures distinctly', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-unauthorized-key',
    );
    await tester.pump();
    await tester.tap(find.byKey(SettingsShellPage.testConnectionButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('连接测试失败：鉴权失败'), findsWidgets);
    expect(find.textContaining('401 / 403'), findsWidgets);
  });

  testWidgets('connection test surfaces model-not-found failures distinctly', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.modelFieldKey),
      'missing-model',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.pump();
    await tester.tap(find.byKey(SettingsShellPage.testConnectionButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('连接测试失败：模型不存在'), findsWidgets);
    expect(find.textContaining('missing-model'), findsWidgets);
  });

  testWidgets('connection test surfaces network failures distinctly', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.baseUrlFieldKey),
      'https://offline.example/v1',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.pump();
    await tester.tap(find.byKey(SettingsShellPage.testConnectionButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('连接测试失败：网络错误'), findsWidgets);
    expect(find.textContaining('offline.example'), findsWidgets);
  });

  testWidgets('unsupported model disables save and connection actions', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.modelFieldKey),
      'claude-3-opus',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.pump();

    final testButton = tester.widget<FilledButton>(
      find.byKey(SettingsShellPage.testConnectionButtonKey),
    );
    final saveButton = tester.widget<AppLoadingButton>(
      find.byKey(SettingsShellPage.saveButtonKey),
    );

    expect(testButton.onPressed, isNull);
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('saving kimi-2.6 normalizes to the live kimi-k2.6 model id', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.modelFieldKey),
      'kimi-2.6',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-kimi-test-key',
    );
    await tester.pump();
    await tester.tap(find.byKey(SettingsShellPage.saveButtonKey));
    await tester.pumpAndSettle();

    final modelField = tester.widget<TextField>(
      find.byKey(SettingsShellPage.modelFieldKey),
    );
    expect(modelField.controller?.text, 'kimi-k2.6');
  });

  testWidgets('connection test surfaces timeout failures distinctly', (
    tester,
  ) async {
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));

    await tester.enterText(
      find.byKey(SettingsShellPage.apiKeyFieldKey),
      'sk-test-key',
    );
    await tester.enterText(
      find.byKey(SettingsShellPage.receiveTimeoutFieldKey),
      '500',
    );
    await tester.pump();
    await tester.tap(find.byKey(SettingsShellPage.testConnectionButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('连接测试失败：连接超时'), findsWidgets);
    expect(find.textContaining('timeout'), findsWidgets);
  });

  test(
    'settings save and connection test emit structured events with redacted key metadata',
    () async {
      final eventStorage = _RecordingAppEventLogStorage();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(),
        eventLog: AppEventLog(storage: eventStorage, sessionId: 'session-1'),
      );

      await store.saveWithFeedback(
        providerName: 'OpenAI 兼容服务',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-test-secret-1234',
        timeout: const AppLlmTimeoutConfig.uniform(30000),
      );
      await pumpEventQueue();
      await store.testConnection(
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-test-secret-1234',
        timeout: const AppLlmTimeoutConfig.uniform(30000),
      );
      await pumpEventQueue();

      expect(
        _entriesForAction(eventStorage.entries, 'settings.save.started'),
        hasLength(1),
      );
      expect(
        _entriesForAction(eventStorage.entries, 'settings.save.succeeded'),
        hasLength(1),
      );
      expect(
        _entriesForAction(
          eventStorage.entries,
          'settings.connection_test.started',
        ),
        hasLength(1),
      );
      expect(
        _entriesForAction(
          eventStorage.entries,
          'settings.connection_test.succeeded',
        ),
        hasLength(1),
      );

      final saveStarted = _entriesForAction(
        eventStorage.entries,
        'settings.save.started',
      ).single;
      expect(
        saveStarted.metadata.containsValue('sk-test-secret-1234'),
        isFalse,
      );
      expect(saveStarted.metadata['apiKeyPreview'], startsWith('sk-'));
      expect(
        (saveStarted.metadata['apiKeyPreview'] as String).length,
        lessThan('sk-test-secret-1234'.length),
      );
    },
  );

  test('retry secure store access emits structured retry events', () async {
    final eventStorage = _RecordingAppEventLogStorage();
    final store = AppSettingsStore(
      storage: RecoveringWriteStorage(),
      llmClient: FakeAppLlmClient(),
      eventLog: AppEventLog(storage: eventStorage, sessionId: 'session-1'),
    );

    await store.saveWithFeedback(
      providerName: 'OpenAI 兼容服务',
      baseUrl: 'https://api.example.com/v1',
      model: 'gpt-5.4',
      apiKey: 'sk-warning-key',
      timeout: const AppLlmTimeoutConfig.uniform(30000),
    );
    await pumpEventQueue();
    await store.retrySecureStoreAccess();
    await pumpEventQueue();

    expect(
      _entriesForAction(eventStorage.entries, 'settings.save.warning'),
      hasLength(1),
    );
    expect(
      _entriesForAction(
        eventStorage.entries,
        'settings.secure_store_retry.started',
      ),
      hasLength(1),
    );
    expect(
      _entriesForAction(
        eventStorage.entries,
        'settings.secure_store_retry.succeeded',
      ),
      hasLength(1),
    );
  });
}

List<AppEventLogEntry> _entriesForAction(
  List<AppEventLogEntry> entries,
  String action,
) {
  return entries.where((entry) => entry.action == action).toList();
}

class _RecordingAppEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}
