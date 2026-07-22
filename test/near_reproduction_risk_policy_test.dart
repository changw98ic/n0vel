import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/near_reproduction_risk_policy.dart';

void main() {
  group('NearReproductionRiskPolicy', () {
    late NearReproductionRiskPolicy policy;

    setUp(() {
      policy = const NearReproductionRiskPolicy();
    });

    test('blocks forty or more contiguous identical CJK characters', () {
      const shared = '青石桥边微雨未停少年把旧灯收进袖中回头看见远处城门缓缓合上山影贴着长街慢慢暗下灯火忽然';

      final result = policy.evaluate(
        candidateText: '开场铺垫。$shared。后续转入项目自己的剧情。',
        references: [
          const NearReproductionReference(
            sourceId: 'src-third-party',
            sourceHash: 'hash-third-party',
            text: '无关前文。$shared。无关后文。',
          ),
        ],
      );

      expect(result.disposition, NearReproductionDisposition.blocked);
      expect(
        result.reasonCodes,
        contains(NearReproductionReasonCode.longestCjkMatchBlocker),
      );
      expect(result.toJson().values.join(), isNot(contains(shared)));
    });

    test(
      'manual-reviews twenty-four to thirty-nine contiguous CJK characters',
      () {
        const shared = '旧灯落在桥边水声压住脚步后半夜城门外风停无人应答';

        final result = policy.evaluate(
          candidateText: '新的角色关系。$shared。随后改变计划。',
          references: [
            const NearReproductionReference(
              sourceId: 'src-third-party',
              sourceHash: 'hash-third-party',
              text: '不同场景。$shared。',
            ),
          ],
        );

        expect(result.disposition, NearReproductionDisposition.manualReview);
        expect(
          result.reasonCodes,
          contains(NearReproductionReasonCode.longestCjkMatchReview),
        );
      },
    );

    test('manual-reviews high normalized eight-gram containment', () {
      const reference = '雨夜桥边收起旧灯乙城门背后无人回头';
      const candidate = '雨夜桥边收起旧灯甲城门背后无人回头';

      final result = policy.evaluate(
        candidateText: candidate,
        references: const [
          NearReproductionReference(
            sourceId: 'src-third-party',
            sourceHash: 'hash-third-party',
            text: reference,
          ),
        ],
      );

      expect(result.disposition, NearReproductionDisposition.manualReview);
      expect(
        result.reasonCodes,
        contains(
          NearReproductionReasonCode.normalizedEightGramContainmentReview,
        ),
      );
      expect(
        result.metrics.single.normalizedEightGramContainment,
        greaterThanOrEqualTo(0.20),
      );
    });

    test('allows common short phrases through the allowlist', () {
      final result = policy.evaluate(
        candidateText: '他深吸一口气，然后推门出去。',
        references: [
          const NearReproductionReference(
            sourceId: 'src-third-party',
            sourceHash: 'hash-third-party',
            text: '她深吸一口气，没有继续争辩。',
          ),
        ],
      );

      expect(result.disposition, NearReproductionDisposition.allowed);
      expect(result.reasonCodes, isEmpty);
    });

    test(
      'allows user-owned references within authorized full-context scope',
      () {
        const shared = '项目主人公在档案室里划掉旧目标把新的誓言写进页脚作为下一章的承诺';

        final result = policy.evaluate(
          candidateText: '承接自有样稿。$shared。',
          references: [
            const NearReproductionReference(
              sourceId: 'src-own-draft',
              sourceHash: 'hash-own-draft',
              text: '自有样稿。$shared。',
              ownership: ReferenceOwnershipKind.userOwned,
            ),
          ],
        );

        expect(result.disposition, NearReproductionDisposition.allowed);
        expect(
          result.reasonCodes,
          contains(NearReproductionReasonCode.noThirdPartyReferences),
        );
      },
    );
  });
}
