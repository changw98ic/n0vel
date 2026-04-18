import 'package:flutter/material.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/review/domain/review_report.dart';

class ReviewIssueDetailDialog extends StatelessWidget {
  final ReviewIssue issue;

  const ReviewIssueDetailDialog({super.key, required this.issue});

  static Future<void> show(BuildContext context, ReviewIssue issue) {
    return showDialog<void>(
      context: context,
      builder: (context) => ReviewIssueDetailDialog(issue: issue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;

    return AlertDialog(
      title: Text(issue.dimension.label),
      content: SingleChildScrollView(
        child: Text([
          issue.description,
          if (issue.originalText != null) '\n閸樼喐鏋冮敍?{issue.originalText!}',
          if (issue.location != null) '\n娴ｅ秶鐤嗛敍?{issue.location!}',
          if (issue.suggestion != null) '\n瀵ら缚顔呴敍?{issue.suggestion!}',
        ].join('\n')),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.editor_close),
        ),
      ],
    );
  }
}
