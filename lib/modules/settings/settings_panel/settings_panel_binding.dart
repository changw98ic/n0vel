import 'package:get/get.dart';

import 'settings_panel_logic.dart';

/// SettingsPanel 依赖注入
class SettingsPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SettingsPanelLogic>(() => SettingsPanelLogic());
  }
}
