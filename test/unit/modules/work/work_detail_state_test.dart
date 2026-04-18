import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/modules/work/work_detail/work_detail_state.dart';

void main() {
  group('workDetailPanelFromParameter', () {
    test('maps supported values to panels', () {
      expect(
        workDetailPanelFromParameter('chapters'),
        WorkDetailPanel.chapters,
      );
      expect(workDetailPanelFromParameter('world'), WorkDetailPanel.world);
      expect(workDetailPanelFromParameter('studio'), WorkDetailPanel.studio);
      expect(workDetailPanelFromParameter('insight'), WorkDetailPanel.insight);
    });

    test('returns null for unsupported values', () {
      expect(workDetailPanelFromParameter(null), isNull);
      expect(workDetailPanelFromParameter('settings'), isNull);
      expect(workDetailPanelFromParameter('unknown'), isNull);
    });
  });
}
