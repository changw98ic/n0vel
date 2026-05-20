import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_settings_store_validation.dart';

void main() {
  group('validateInputs timeout guardrails', () {
    AppSettingsFeedback? validateWithTimeout(AppLlmTimeoutConfig timeout) {
      return validateInputs(
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-test',
        timeout: timeout,
        maxConcurrentRequests: 1,
        forConnectionTest: false,
        isLocalCompatibleEndpoint: (_) => false,
        isSupportedModel: (_) => true,
      );
    }

    test('rejects receive timeout large enough to cause long idle waits', () {
      final feedback = validateWithTimeout(
        const AppLlmTimeoutConfig(
          connectTimeoutMs: 10000,
          sendTimeoutMs: 30000,
          receiveTimeoutMs: 3480000,
          idleTimeoutMs: 60000,
        ),
      );

      expect(feedback, isNotNull);
      expect(feedback!.tone, AppSettingsFeedbackTone.error);
      expect(feedback.title, contains('接收超时'));
      expect(feedback.message, contains('10 分钟'));
    });

    test('rejects each timeout field above the ten minute limit', () {
      final cases = [
        (
          label: '连接超时',
          timeout: const AppLlmTimeoutConfig(
            connectTimeoutMs: 600001,
            sendTimeoutMs: 30000,
            receiveTimeoutMs: 60000,
            idleTimeoutMs: 60000,
          ),
        ),
        (
          label: '发送超时',
          timeout: const AppLlmTimeoutConfig(
            connectTimeoutMs: 10000,
            sendTimeoutMs: 600001,
            receiveTimeoutMs: 60000,
            idleTimeoutMs: 60000,
          ),
        ),
        (
          label: '接收超时',
          timeout: const AppLlmTimeoutConfig(
            connectTimeoutMs: 10000,
            sendTimeoutMs: 30000,
            receiveTimeoutMs: 600001,
            idleTimeoutMs: 60000,
          ),
        ),
        (
          label: '空闲超时',
          timeout: const AppLlmTimeoutConfig(
            connectTimeoutMs: 10000,
            sendTimeoutMs: 30000,
            receiveTimeoutMs: 60000,
            idleTimeoutMs: 600001,
          ),
        ),
      ];

      for (final entry in cases) {
        final feedback = validateWithTimeout(entry.timeout);

        expect(feedback, isNotNull, reason: entry.label);
        expect(feedback!.tone, AppSettingsFeedbackTone.error);
        expect(feedback.title, contains(entry.label));
        expect(feedback.message, contains('10 分钟'));
      }
    });

    test('accepts timeout values at the ten minute boundary', () {
      final feedback = validateWithTimeout(
        const AppLlmTimeoutConfig(
          connectTimeoutMs: 600000,
          sendTimeoutMs: 600000,
          receiveTimeoutMs: 600000,
          idleTimeoutMs: 600000,
        ),
      );

      expect(feedback, isNull);
    });
  });
}
