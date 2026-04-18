import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/ai/tools/update_chapter_content_tool.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late UpdateChapterContentTool tool;

  setUp(() {
    registerFallbackValue('');
  });

  test('returns failure when update callback throws', () async {
    tool = UpdateChapterContentTool(
      updateFn: (chapterId, content, wordCount) async {
        throw StateError('Chapter not found: $chapterId');
      },
    );

    final result = await tool.execute({
      'chapter_id': 'missing-chapter',
      'content':
          'new chapter content starting from the ferry dock under night, lanterns swaying, tide rising, characters making pivotal decisions that change the course of their fate. River wind carrying moisture, he finally took that step between hesitation and resolve, giving the narrative complete scenes, actions, and psychological progression, no longer any form of placeholder draft.',
    });

    expect(result.success, isFalse);
    expect(result.error, contains('Chapter not found'));
  });
}
