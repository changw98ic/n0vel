import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart';

/// 完整小说创作全流程测试（8个阶段）
/// 通过 flutter_driver + 自定义 VM service extensions 驱动 App

@Skip('Requires running app with flutter_driver')
void main() {
  group('完整 AI 小说创作全流程', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('健康检查', () async {
      final health = await driver.checkHealth();
      expect(health.status, HealthStatus.ok);
      print('✅ Driver 连接正常');
    });
  });
}
