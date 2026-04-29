import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String architectureDoc;

  setUpAll(() {
    final file = File('docs/mvp/mvp-architecture.md');
    architectureDoc = file.readAsStringSync();
  });

  /// Each required MVP UI surface with canonical identifiers used in
  /// the architecture doc's mermaid diagrams and surface catalog table.
  const requiredSurfaces = <String, List<String>>{
    'Project List': ['ProjectPage', '项目列表', 'nXod8'],
    'Writing Workbench': ['WorkbenchPage', '写作工作台', '47nGt'],
    'Sandbox Monitor': ['SandboxPage', 'Sandbox Monitor', 'YTrUo'],
    'Character Library': ['CharacterPage', '角色库', '4KVQe'],
    'Worldbuilding': ['WorldPage', '世界观', 'dH2Mr'],
    'Style Panel': ['StylePage', '风格面板', 'ff8vo'],
    'Audit Center': ['AuditPage', '审计中心', 'p8Lkt'],
    'Chapter Versions': ['VersionPage', '章节版本', 'Ym6ea'],
    'Project Import Export': ['ImportExportPage', '工程导入导出', 'z0mJ1'],
    'Settings & BYOK': ['SettingsPage', '设置与 BYOK', 'DnwrZ'],
    'Reading Mode': ['ReadingPage', '纯净阅读', 'GD63C'],
  };

  group('Architecture Surface Coverage', () {
    for (final entry in requiredSurfaces.entries) {
      final surfaceName = entry.key;
      final identifiers = entry.value;

      test('$surfaceName is present in architecture doc', () {
        final found = identifiers.any(
          (id) => architectureDoc.contains(id),
        );
        expect(
          found,
          isTrue,
          reason:
              '$surfaceName: none of ${identifiers.join(", ")} found in mvp-architecture.md',
        );
      });
    }

    test('all 11 required surfaces are accounted for', () {
      expect(requiredSurfaces.length, 11);
    });

    test(
        'workbench-adjacent relationship for Sandbox Monitor is explicit',
        () {
      expect(
        architectureDoc.contains('工作台模态') ||
            architectureDoc.contains('模态观察面'),
        isTrue,
        reason:
            'Sandbox Monitor must be explicitly described as workbench-modal',
      );
    });

    test('workbench-adjacent relationship for Chapter Versions is explicit',
        () {
      expect(
        architectureDoc.contains('工作台邻接'),
        isTrue,
        reason:
            'Chapter Versions must be explicitly described as workbench-adjacent',
      );
    });

    test('workbench-adjacent relationship for Reading Mode is explicit', () {
      expect(
        architectureDoc.contains('工作台邻接视图'),
        isTrue,
        reason:
            'Reading Mode must be explicitly described as workbench-adjacent',
      );
    });

    test('MVP UI Surface Catalog section exists', () {
      expect(
        architectureDoc.contains('MVP UI Surface Catalog'),
        isTrue,
        reason: 'Architecture doc must contain an explicit surface catalog',
      );
    });

    test('surface catalog lists Core Pages', () {
      expect(
        architectureDoc.contains('Core Pages'),
        isTrue,
        reason: 'Surface catalog must enumerate Core Pages',
      );
    });

    test('surface catalog lists Adjacent Views', () {
      expect(
        architectureDoc.contains('Adjacent Views'),
        isTrue,
        reason: 'Surface catalog must enumerate Adjacent Views',
      );
    });
  });
}
