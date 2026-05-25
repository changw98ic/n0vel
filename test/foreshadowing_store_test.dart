import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/bible/data/foreshadowing_store.dart';

void main() {
  test('creates foreshadowing threads and filters active reminders', () {
    var now = DateTime.fromMillisecondsSinceEpoch(1000);
    final store = ForeshadowingStore(now: () => now);
    var notifications = 0;
    store.addListener(() {
      notifications += 1;
    });
    addTearDown(store.dispose);

    final thread = store.createForeshadowing(
      title: '  码头门禁异常  ',
      description: '  门禁记录与真实通行不一致  ',
      relatedChapterLabel: ' 第 3 章 / 场景 05 ',
    );

    expect(thread.title, '码头门禁异常');
    expect(thread.description, '门禁记录与真实通行不一致');
    expect(thread.relatedChapterLabel, '第 3 章 / 场景 05');
    expect(thread.status, ForeshadowingStatus.undeveloped);
    expect(thread.status.label, '未展开');
    expect(store.threads, hasLength(1));
    expect(store.reminders, hasLength(1));
    expect(store.remindersForChapter('第 3 章 / 场景 05'), [thread]);
    expect(notifications, 1);

    now = DateTime.fromMillisecondsSinceEpoch(2000);
    expect(
      store.updateStatus(thread.id, ForeshadowingStatus.developed),
      isTrue,
    );
    expect(store.threadById(thread.id)!.status.label, '已展开');
    expect(store.threadById(thread.id)!.updatedAtMs, 2000);
    expect(store.reminders, hasLength(1));
    expect(notifications, 2);

    expect(
      store.updateStatus('missing', ForeshadowingStatus.abandoned),
      isFalse,
    );
    expect(notifications, 2);

    now = DateTime.fromMillisecondsSinceEpoch(3000);
    expect(
      store.updateStatus(thread.id, ForeshadowingStatus.abandoned),
      isTrue,
    );
    expect(store.threadById(thread.id)!.status.label, '已废弃');
    expect(store.reminders, isEmpty);
    expect(store.remindersForChapter('第 3 章 / 场景 05'), isEmpty);
    expect(notifications, 3);
  });

  test('rejects empty titles', () {
    final store = ForeshadowingStore();
    addTearDown(store.dispose);

    expect(
      () => store.createForeshadowing(
        title: '   ',
        description: 'desc',
        relatedChapterLabel: '第 1 章',
      ),
      throwsArgumentError,
    );
  });
}
