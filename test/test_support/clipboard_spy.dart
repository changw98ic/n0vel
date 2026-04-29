import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class ClipboardSpy {
  ClipboardSpy(this.tester);

  final WidgetTester tester;
  String? text;

  void attach() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          text = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
  }

  void detach() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }
}
