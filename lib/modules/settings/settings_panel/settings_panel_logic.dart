import 'package:get/get.dart';

import '../../../shared/data/base_business/base_controller.dart';
import 'settings_panel_state.dart';

/// SettingsPanel 业务逻辑
class SettingsPanelLogic extends BaseController {
  final SettingsPanelState state = SettingsPanelState();

  String get workId => Get.parameters['id']!;
}
