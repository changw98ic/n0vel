import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readPrd(String name) {
  final file = File('docs/mvp/prd/$name');
  if (!file.existsSync()) {
    throw StateError('PRD file not found: ${file.path}');
  }
  return file.readAsStringSync();
}

String _readUiStandards() {
  final file = File('docs/mvp/ui-design-standards.md');
  if (!file.existsSync()) {
    throw StateError('ui-design-standards.md not found');
  }
  return file.readAsStringSync();
}

void main() {
  group('PRD Shell Rule Spot Checks', () {
    late String workbench;
    late String sandbox;
    late String stylePanel;
    late String versionHistory;
    late String settings;
    late String uiStandards;

    setUpAll(() {
      workbench = _readPrd('prd-02-writing-workbench.md');
      sandbox = _readPrd('prd-03-sandbox-monitor.md');
      stylePanel = _readPrd('prd-06-style-panel.md');
      versionHistory = _readPrd('prd-08-version-history.md');
      settings = _readPrd('prd-10-settings-byok.md');
      uiStandards = _readUiStandards();
    });

    group('Workbench (prd-02)', () {
      test('body pane is visual primary, AI is secondary', () {
        expect(
          workbench,
          contains('正文编辑区必须保持最高视觉权重'),
        );
        expect(
          workbench,
          contains('AI 操作区可见但不能压过正文主区'),
        );
      });

      test('bottom status bar is stable and low-distraction', () {
        expect(
          workbench,
          contains(
            '底部状态与模拟反馈区必须稳定、低干扰、易扫读，不得退化成持续滚动的日志墙',
          ),
        );
      });

      test('references ui-design-standards section 9.1', () {
        expect(workbench, contains('§9.1'));
        expect(workbench, contains('正文编辑区是视觉主角'));
      });

      test('simulation summary uses lightweight bar, not forced navigation',
          () {
        expect(
          workbench,
          contains(
            '把结果回传为轻摘要条，而不是强制跳出到独立页面',
          ),
        );
      });
    });

    group('Sandbox Monitor (prd-03)', () {
      test('distinguishes speech, intent, and adjudication', () {
        expect(sandbox, contains('发言'));
        expect(sandbox, contains('意图'));
        expect(sandbox, contains('裁决'));
        expect(
          sandbox,
          contains('作者在 `5` 秒内必须能区分发言、意图与裁决三类信息'),
        );
      });

      test('avoids terminal/log-wall framing', () {
        expect(
          sandbox,
          contains('监视器不得做成终端风或纯日志墙'),
        );
        expect(
          sandbox,
          contains('主视图区应保留结构化卡片层级'),
        );
      });

      test('references ui-design-standards section 9.2', () {
        expect(sandbox, contains('§9.2'));
        expect(sandbox, contains('不得做成终端风或日志墙'));
      });

      test('status snapshot area is quiet and secondary', () {
        expect(
          sandbox,
          contains('右侧摘要区与状态快照区必须保持次级视觉权重'),
        );
      });
    });

    group('Style Panel (prd-06)', () {
      test('questionnaire and JSON entry points at same hierarchy', () {
        expect(
          stylePanel,
          contains('问卷入口与 JSON 导入入口必须保持同级'),
        );
        expect(
          stylePanel,
          contains('不得把其中一项折叠为次级入口'),
        );
      });

      test('center summary framed as style card, not validator console', () {
        expect(
          stylePanel,
          contains('已定风格卡'),
        );
        expect(
          stylePanel,
          contains('不能退化成只显示字段校验结果的检查器面板'),
        );
      });

      test('JSON mode does not degrade center summary', () {
        expect(
          stylePanel,
          contains('摘要区不得退化为代码检查器式视图'),
        );
      });

      test('references ui-design-standards section 9.3', () {
        expect(stylePanel, contains('§9.3'));
        expect(
          stylePanel,
          contains('中间摘要区像"已定风格卡"，不是代码检查器'),
        );
      });
    });

    group('Version History (prd-08)', () {
      test('uses shared app-shell pattern for non-reader pages', () {
        expect(
          versionHistory,
          contains('版本页沿用统一应用壳层'),
        );
        expect(
          versionHistory,
          contains('不单独发明新壳层'),
        );
      });

      test('has same shell structure as other non-reader pages', () {
        expect(
          versionHistory,
          contains('左侧隐藏 handle'),
        );
        expect(
          versionHistory,
          contains('顶部轻页眉'),
        );
        expect(
          versionHistory,
          contains('底部状态栏'),
        );
      });

      test('references ui-design-standards section 9.4', () {
        expect(versionHistory, contains('§9.4'));
        expect(
          versionHistory,
          contains('共用项目列表、角色库、世界观页等同一套壳层'),
        );
      });
    });

    group('Settings & BYOK (prd-10)', () {
      test('uses shared shell and top-structure guidance', () {
        expect(
          settings,
          contains('设置页沿用其他非阅读页的一致壳层与顶部结构'),
        );
        expect(
          settings,
          contains('不单独发明一套视觉语言'),
        );
      });

      test('has same shell structure as other shell pages', () {
        expect(
          settings,
          contains('自动隐藏 `menu drawer` 把手'),
        );
        expect(
          settings,
          contains('顶部轻页眉'),
        );
      });

      test('references ui-design-standards section 9.4', () {
        expect(settings, contains('§9.4'));
        expect(
          settings,
          contains('设置页共用项目列表、角色库、世界观页等同一套壳层'),
        );
      });
    });

    group('UI Design Standards cross-reference', () {
      test('ui-design-standards.md defines all referenced sections', () {
        expect(uiStandards, contains('### 9.1 写作工作台'));
        expect(uiStandards, contains('### 9.2 沙盒监视器'));
        expect(uiStandards, contains('### 9.3 风格面板'));
        expect(uiStandards, contains('### 9.4 其他页面'));
      });

      test('§9.1 matches workbench requirements', () {
        expect(uiStandards, contains('正文编辑区是视觉主角'));
        expect(uiStandards, contains('AI 操作区位于右侧次级区'));
        expect(uiStandards, contains('底部模拟日志区必须稳定、低干扰、易扫读'));
      });

      test('§9.2 matches sandbox requirements', () {
        expect(uiStandards, contains('必须视觉区分三类信息'));
        expect(uiStandards, contains('发言'));
        expect(uiStandards, contains('意图'));
        expect(uiStandards, contains('裁决'));
        expect(uiStandards, contains('不得做成终端风或日志墙'));
      });

      test('§9.3 matches style panel requirements', () {
        expect(uiStandards, contains('问卷入口与 JSON 导入入口必须同级出现'));
        expect(uiStandards, contains('已定风格卡'));
        expect(uiStandards, contains('不是代码检查器'));
      });

      test('§9.4 matches version history and settings requirements', () {
        expect(
          uiStandards,
          contains('项目列表、角色库、世界观页、版本历史、审计中心、设置页共用同一套壳层'),
        );
      });
    });
  });
}
