import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/chapter_concurrent_runner.dart';

void main() {
  const gate = ChapterCrossSceneClicheGate();

  test('blocks repeated fragments and preserves scene evidence', () {
    expect(
      () => gate.enforce(const <String, String>{
        'chapter-01/scene-01': '潮湿的风从破窗灌进来，把桌上的旧报纸一页页掀起。门外有人敲门。',
        'chapter-01/scene-02': '潮湿的风，从破窗灌进来；把桌上的旧报纸一页页掀起！她没有回头。',
      }),
      throwsA(
        isA<ChapterCrossSceneClicheGateFailure>().having(
          (failure) => failure.toString(),
          'evidence',
          allOf(
            contains('chapter-01/scene-01'),
            contains('chapter-01/scene-02'),
          ),
        ),
      ),
    );
  });

  test('allows distinct scene prose', () {
    expect(
      () => gate.enforce(const <String, String>{
        'chapter-01/scene-01': '柳溪推开档案室的门，警报骤然响起。',
        'chapter-01/scene-02': '沈渡沿排水管爬上天台，远处传来枪声。',
      }),
      returnsNormally,
    );
  });
}
