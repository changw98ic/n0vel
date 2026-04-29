import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client_types.dart';

void main() {
  group('AppLlmTimeoutConfig', () {
    test('defaults preset has expected values', () {
      const config = AppLlmTimeoutConfig.defaults;
      expect(config.connectTimeoutMs, 10000);
      expect(config.sendTimeoutMs, 30000);
      expect(config.receiveTimeoutMs, 60000);
      expect(config.idleTimeoutMs, 30000);
    });

    test('quickChat preset has shorter timeouts', () {
      const config = AppLlmTimeoutConfig.quickChat;
      expect(config.connectTimeoutMs, 5000);
      expect(config.sendTimeoutMs, 10000);
      expect(config.receiveTimeoutMs, 15000);
      expect(config.idleTimeoutMs, 5000);
    });

    test('longGeneration preset has longer receive and idle timeouts', () {
      const config = AppLlmTimeoutConfig.longGeneration;
      expect(config.connectTimeoutMs, 10000);
      expect(config.sendTimeoutMs, 30000);
      expect(config.receiveTimeoutMs, 180000);
      expect(config.idleTimeoutMs, 60000);
    });

    test(
      'effectiveIdleTimeoutMs returns idleTimeoutMs when set',
      () {
        const config = AppLlmTimeoutConfig(
          connectTimeoutMs: 1000,
          sendTimeoutMs: 2000,
          receiveTimeoutMs: 3000,
          idleTimeoutMs: 4000,
        );
        expect(config.effectiveIdleTimeoutMs, 4000);
      },
    );

    test(
      'effectiveIdleTimeoutMs falls back to receiveTimeoutMs when idle is null',
      () {
        const config = AppLlmTimeoutConfig(
          connectTimeoutMs: 1000,
          sendTimeoutMs: 2000,
          receiveTimeoutMs: 3000,
        );
        expect(config.idleTimeoutMs, isNull);
        expect(config.effectiveIdleTimeoutMs, 3000);
      },
    );

    test(
      'uniform constructor sets all timeouts to same value with null idle',
      () {
        const config = AppLlmTimeoutConfig.uniform(5000);
        expect(config.connectTimeoutMs, 5000);
        expect(config.sendTimeoutMs, 5000);
        expect(config.receiveTimeoutMs, 5000);
        expect(config.idleTimeoutMs, isNull);
        expect(config.effectiveIdleTimeoutMs, 5000);
      },
    );

    group('copyWith', () {
      test('overrides only specified fields', () {
        const original = AppLlmTimeoutConfig.defaults;
        final modified = original.copyWith(receiveTimeoutMs: 120000);
        expect(modified.connectTimeoutMs, 10000);
        expect(modified.sendTimeoutMs, 30000);
        expect(modified.receiveTimeoutMs, 120000);
        expect(modified.idleTimeoutMs, 30000);
      });

      test('preserves all fields when no arguments given', () {
        const original = AppLlmTimeoutConfig(
          connectTimeoutMs: 1000,
          sendTimeoutMs: 2000,
          receiveTimeoutMs: 3000,
          idleTimeoutMs: 4000,
        );
        final copy = original.copyWith();
        expect(copy.connectTimeoutMs, 1000);
        expect(copy.sendTimeoutMs, 2000);
        expect(copy.receiveTimeoutMs, 3000);
        expect(copy.idleTimeoutMs, 4000);
      });

      test('sets idleTimeoutMs to a new value', () {
        const original = AppLlmTimeoutConfig.defaults;
        final modified = original.copyWith(idleTimeoutMs: 99999);
        expect(modified.idleTimeoutMs, 99999);
      });

      test('clearIdleTimeout sets idle to null', () {
        const original = AppLlmTimeoutConfig.defaults;
        expect(original.idleTimeoutMs, isNotNull);
        final cleared = original.copyWith(clearIdleTimeout: true);
        expect(cleared.idleTimeoutMs, isNull);
        expect(
          cleared.effectiveIdleTimeoutMs,
          original.receiveTimeoutMs,
        );
      });
    });

    group('serialization', () {
      test('toJson includes idleTimeoutMs when present', () {
        const config = AppLlmTimeoutConfig(
          connectTimeoutMs: 1000,
          sendTimeoutMs: 2000,
          receiveTimeoutMs: 3000,
          idleTimeoutMs: 4000,
        );
        final json = config.toJson();
        expect(json['idleTimeoutMs'], 4000);
      });

      test('toJson omits idleTimeoutMs when null', () {
        const config = AppLlmTimeoutConfig(
          connectTimeoutMs: 1000,
          sendTimeoutMs: 2000,
          receiveTimeoutMs: 3000,
        );
        final json = config.toJson();
        expect(json.containsKey('idleTimeoutMs'), isFalse);
      });

      test('fromJson restores idleTimeoutMs', () {
        const config = AppLlmTimeoutConfig(
          connectTimeoutMs: 1000,
          sendTimeoutMs: 2000,
          receiveTimeoutMs: 3000,
          idleTimeoutMs: 4000,
        );
        final restored = AppLlmTimeoutConfig.fromJson(config.toJson());
        expect(restored.connectTimeoutMs, 1000);
        expect(restored.sendTimeoutMs, 2000);
        expect(restored.receiveTimeoutMs, 3000);
        expect(restored.idleTimeoutMs, 4000);
      });

      test('fromJson handles missing idleTimeoutMs as null', () {
        final restored = AppLlmTimeoutConfig.fromJson({
          'connectTimeoutMs': 1000,
          'sendTimeoutMs': 2000,
          'receiveTimeoutMs': 3000,
        });
        expect(restored.idleTimeoutMs, isNull);
      });

      test('fromJson handles legacy timeoutMs', () {
        final restored = AppLlmTimeoutConfig.fromJson({'timeoutMs': 5000});
        expect(restored.connectTimeoutMs, 5000);
        expect(restored.sendTimeoutMs, 5000);
        expect(restored.receiveTimeoutMs, 5000);
        expect(restored.idleTimeoutMs, isNull);
      });

      test('roundtrip preserves all fields', () {
        const config = AppLlmTimeoutConfig(
          connectTimeoutMs: 1111,
          sendTimeoutMs: 2222,
          receiveTimeoutMs: 3333,
          idleTimeoutMs: 4444,
        );
        final roundtripped = AppLlmTimeoutConfig.fromJson(config.toJson());
        expect(roundtripped.connectTimeoutMs, config.connectTimeoutMs);
        expect(roundtripped.sendTimeoutMs, config.sendTimeoutMs);
        expect(roundtripped.receiveTimeoutMs, config.receiveTimeoutMs);
        expect(roundtripped.idleTimeoutMs, config.idleTimeoutMs);
      });
    });
  });
}
