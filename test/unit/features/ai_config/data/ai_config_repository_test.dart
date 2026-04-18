import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AIConfigRepository defaults', () {
    late AIConfigRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = AIConfigRepository();
    });

    test('returns tier-specific default max tokens', () async {
      final fast = await repository.getModelConfig(ModelTier.fast);
      final middle = await repository.getModelConfig(ModelTier.middle);
      final thinking = await repository.getModelConfig(ModelTier.thinking);

      expect(fast, isNotNull);
      expect(middle, isNotNull);
      expect(thinking, isNotNull);
      expect(fast!.maxOutputTokens, 4096);
      expect(middle!.maxOutputTokens, 8192);
      expect(thinking!.maxOutputTokens, 16384);
    });
  });
}
