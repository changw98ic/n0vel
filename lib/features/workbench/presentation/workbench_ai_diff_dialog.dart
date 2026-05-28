import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'workbench_ai_revision_helpers.dart';

class WorkbenchAiDiffDialog extends StatelessWidget {
  const WorkbenchAiDiffDialog({
    required this.blocks,
    super.key,
  });

  final List<WorkbenchAiReviewBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dmp = DiffMatchPatch();

    return DesktopModalDialog(
      title: '版本对比',
      width: 760,
      body: SizedBox(
        height: 480,
        child: blocks.isEmpty
            ? const Center(
                child: Text('暂无已生成的 AI 建议进行比对。'),
              )
            : ListView.separated(
                itemCount: blocks.length,
                separatorBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0x1F243226)),
                ),
                itemBuilder: (context, index) {
                  final block = blocks[index];
                  final diffs = dmp.diff(block.originalText, block.suggestionText);
                  dmp.diffCleanupSemantic(diffs);

                  final spans = <TextSpan>[];
                  for (final diff in diffs) {
                    if (diff.operation == DIFF_EQUAL) {
                      spans.add(TextSpan(
                        text: diff.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF243226),
                        ),
                      ));
                    } else if (diff.operation == DIFF_INSERT) {
                      spans.add(TextSpan(
                        text: diff.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2E7D32),
                          backgroundColor: const Color(0xFFE8F5E9),
                          fontWeight: FontWeight.w600,
                        ),
                      ));
                    } else if (diff.operation == DIFF_DELETE) {
                      spans.add(TextSpan(
                        text: diff.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFC62828),
                          backgroundColor: const Color(0xFFFFEBEE),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ));
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.blockLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF243226),
                        ),
                      ),
                      if (block.authorPrompt.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '修改意图: ${block.authorPrompt}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF77736A),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBFAF6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE8E2D6)),
                        ),
                        child: RichText(
                          text: TextSpan(children: spans),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
      ],
    );
  }
}

Future<void> showAiDiffDialog({
  required BuildContext context,
  required List<WorkbenchAiReviewBlock> blocks,
}) async {
  await showDialog<void>(
    context: context,
    barrierLabel: '关闭',
    builder: (dialogContext) => WorkbenchAiDiffDialog(blocks: blocks),
  );
}
