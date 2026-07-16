import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/quality_repair_policy.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  test('turning-point weakness becomes a concrete causal repair contract', () {
    const score = SceneQualityScore(
      overall: 91,
      prose: 93,
      coherence: 95,
      character: 92,
      completeness: 90,
      summary: '人物转折缺少把他推过临界点的对白，目标落地偏软。',
    );

    final feedback = QualityRepairPolicy.feedbackFor(score);

    expect(feedback, contains(QualityRepairPolicy.releaseId));
    expect(feedback, contains('planner.missing_required_beat'));
    expect(feedback, contains('repairPlanHash='));
    expect(feedback, contains('必须重验='));
    expect(feedback, contains('明确触发点'));
    expect(feedback, contains('不可逆的选择或行动'));
    expect(feedback, contains('实际交出、说出、打开、带路或拒绝'));
    expect(feedback, contains(score.summary));
    expect(feedback, isNot(contains('必须整体重写')));
  });
}
