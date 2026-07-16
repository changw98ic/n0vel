import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/step_review_io.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_models.dart';

void main() {
  test('checkpoint review DTO excludes raw provider response text', () {
    const rawProviderText = 'provider-only response: do not persist';
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '结构通过',
      rawText: rawProviderText,
    );
    const output = ReviewOutput(
      review: SceneReviewResult(
        judge: pass,
        consistency: pass,
        decision: SceneReviewDecision.pass,
      ),
      wasLengthRetry: false,
      action: SceneReviewDecision.pass,
    );

    final dto = output.toJson();

    expect(dto.toString(), isNot(contains(rawProviderText)));
    expect((dto['judge'] as Map).containsKey('rawText'), isFalse);
    expect((dto['consistency'] as Map).containsKey('rawText'), isFalse);
  });
}
