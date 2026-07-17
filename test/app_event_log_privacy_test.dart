import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/logging/app_event_log_privacy.dart';

void main() {
  test('redacts text while preserving diagnostic length', () {
    final metadata = AppEventLogPrivacy.textMetadata(
      field: 'prompt',
      value: '一段不应写入日志的正文',
    );

    expect(metadata['promptLength'], 11);
    expect(metadata['promptPreview'], '[redacted]');
    expect(metadata.values, isNot(contains('一段不应写入日志的正文')));
  });

  test('rejects invalid metadata field names', () {
    expect(
      () =>
          AppEventLogPrivacy.textMetadata(field: 'prompt-preview', value: 'x'),
      throwsArgumentError,
    );
  });

  test('sanitizes credential-shaped error details and bounds length', () {
    final detail = AppEventLogPrivacy.sanitizeErrorDetail(
      'Authorization: Bearer secret-token apiKey=sk-1234567890\n'
      '${List<String>.filled(2100, 'x').join()}',
    );

    expect(detail, isNot(contains('secret-token')));
    expect(detail, isNot(contains('sk-1234567890')));
    expect(detail!.length, lessThanOrEqualTo(2000));
  });
}
