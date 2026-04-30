import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'real_chain_probe.dart' as probe;

class _RealHttpTestWidgetsFlutterBinding
    extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _RealHttpTestWidgetsFlutterBinding();

  test('runs real one-chapter probe', () async {
    exitCode = 0;

    await probe.main();

    if (exitCode != 0) {
      fail('real_chain_probe exited with code $exitCode');
    }
  }, timeout: const Timeout(Duration(hours: 2)));
}
