import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/context/context_manager.dart';

class MockAIService extends Mock implements AIService {}

void main() {
  group('ContextManager', () {
    test('uses 256k window for qwen-like local models', () {
      final manager = ContextManager(aiService: MockAIService());
      expect(manager.getContextWindow('qwen-opus-27b-v3'), 256000);
      expect(
        manager.getContextWindow(
          'qwen3.5-27b-claude-4.6-opus-reasoning-distilled',
        ),
        256000,
      );
    });
  });
}
