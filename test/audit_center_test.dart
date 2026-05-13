import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/main.dart';
import 'test_support/test_registry.dart';

void main() {
  setUp(() {
    NovelWriterApp.debugRegistryOverride = createTestRegistry();
  });

  tearDown(() {
    NovelWriterApp.debugRegistryOverride = null;
  });

  testWidgets('shows audit center ready state', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: AuditCenterPage()));

    expect(find.text('改稿 · 一致性检查'), findsOneWidget);
    expect(find.text('需要作者核对的线索与依据'), findsOneWidget);
    expect(find.text('改稿 · 核对线索已更新'), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.empty),
      ),
    );

    expect(find.text('当前项目暂无问题'), findsOneWidget);
    expect(find.text('暂无一致性问题'), findsOneWidget);
    expect(find.textContaining('当前作品没有发现角色、规则、道具或时间线冲突'), findsOneWidget);
  });

  testWidgets('shows filter no results state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.filterNoResults),
      ),
    );

    expect(find.text('0 个匹配'), findsOneWidget);
    expect(find.text('当前筛选没有命中问题'), findsOneWidget);
    expect(find.text('清空筛选'), findsOneWidget);
    expect(find.text('未选中问题'), findsOneWidget);
    expect(find.text('无可用动作'), findsOneWidget);
  });

  testWidgets('shows related draft missing state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.relatedDraftMissing),
      ),
    );

    expect(find.text('无法定位关联草稿'), findsOneWidget);
    expect(find.textContaining('原始场景草稿已被删除'), findsOneWidget);
    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('重新检查'), findsOneWidget);
  });

  testWidgets('shows jump failed state', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: AuditCenterPage(uiState: AuditCenterUiState.jumpFailed),
      ),
    );

    expect(find.text('跳转失败'), findsOneWidget);
    expect(find.textContaining('目标场景'), findsOneWidget);
    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('重新检查'), findsOneWidget);
  });
}
