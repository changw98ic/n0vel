import 'workflow_service.dart';
import 'ai/models/model_tier.dart';

class WorkflowTemplateBatchHelpers {
  WorkflowTemplateBatchHelpers._();

  static final RegExp _unsafeKeyPattern = RegExp(
    r'[^a-zA-Z0-9_\u4e00-\u9fff]',
  );

  static List<WorkflowNode> buildBatchReviewBranches(
    Map<String, String> chapterContents,
  ) {
    final branches = <WorkflowNode>[];
    var branchIdx = 0;

    for (final entry in chapterContents.entries) {
      branches.add(
        _buildBatchReviewBranch(
          chapterKey: entry.key,
          content: entry.value,
          index: branchIdx,
        ),
      );
      branchIdx++;
    }

    return branches;
  }

  static String buildBatchResultSection(Iterable<String> chapterKeys) {
    return chapterKeys.map((chapterKey) {
      final safeKey = _safeKey(chapterKey);
      return '--- $chapterKey ---\n{batch_result_$safeKey}\n';
    }).join('\n');
  }

  static AINode _buildBatchReviewBranch({
    required String chapterKey,
    required String content,
    required int index,
  }) {
    final safeKey = _safeKey(chapterKey);

    return AINode(
      id: 'batch_review_${safeKey}_$index',
      name: '瀹℃牎锛?chapterKey',
      index: index,
      promptTemplate: '璇峰浠ヤ笅绔犺妭杩涜鍏ㄩ潰瀹℃牎锛屽寘鎷細\n\n'
          '1. **璁惧畾涓€鑷存€?*锛氭鏌ヤ笘鐣岃銆佹椂闂寸嚎銆佸姏閲忎綋绯绘槸鍚﹁嚜娲絓n'
          '2. **瑙掕壊琛ㄧ幇**锛氳鑹茶█琛屾槸鍚︿笌璁惧畾涓€鑷达紝鏈夋棤OOC\n'
          '3. **鏂囬璐ㄩ噺**锛氭槸鍚︽湁AI鍐欎綔鐥曡抗锛屾枃绗旀槸鍚﹁嚜鐒禱n'
          '4. **鎯呰妭閫昏緫**锛氭儏鑺傛帹杩涙槸鍚﹀悎鐞嗭紝鏈夋棤閫昏緫婕忔礊\n'
          '5. **璇昏€呬綋楠?*锛氬彊浜嬭妭濂忋€佹偓蹇佃缃€佹儏鎰熷叡楦n\n'
          '璇峰姣忎釜缁村害缁欏嚭璇勫垎锛?-5锛夊拰闂璇存槑锛屾渶鍚庣粰鍑虹珷鑺傛€讳綋璇勪环銆俓n\n'
          '--- $chapterKey ---\n$content\n--- 绔犺妭缁撴潫 ---',
      outputVariable: 'batch_result_$safeKey',
      modelTier: 'middle',
      function: AIFunction.review,
    );
  }

  static String _safeKey(String value) {
    return value.replaceAll(_unsafeKeyPattern, '_');
  }
}
