import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  late AppVersionStore store;
  late AppWorkspaceStore workspaceStore;

  setUp(() {
    workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    store = AppVersionStore(
      storage: InMemoryAppVersionStorage(),
      workspaceStore: workspaceStore,
    );
  });

  tearDown(() {
    store.dispose();
    workspaceStore.dispose();
  });

  // ===========================================================================
  // VersionEntry model
  // ===========================================================================

  group('VersionEntry', () {
    test('toJson/fromJson round-trip preserves label and content', () {
      const entry = VersionEntry(label: 'chapter-1-draft', content: 'Hello');
      final json = entry.toJson();
      final restored = VersionEntry.fromJson(json);

      expect(restored.label, 'chapter-1-draft');
      expect(restored.content, 'Hello');
    });

    test('fromJson with empty label defaults to 自动保存版本', () {
      final restored = VersionEntry.fromJson({
        'label': '',
        'content': 'some text',
      });

      expect(restored.label, '自动保存版本');
      expect(restored.content, 'some text');
    });

    test('fromJson with whitespace-only label defaults to 自动保存版本', () {
      final restored = VersionEntry.fromJson({
        'label': '   ',
        'content': 'text',
      });

      expect(restored.label, '自动保存版本');
    });

    test('fromJson with null values uses defaults', () {
      final restored = VersionEntry.fromJson({});

      expect(restored.label, '自动保存版本');
      expect(restored.content, '');
    });
  });

  // ===========================================================================
  // captureSnapshot
  // ===========================================================================

  group('captureSnapshot', () {
    test('prepends new entry to front', () {
      store.captureSnapshot(label: 'first', content: 'AAA');
      store.captureSnapshot(label: 'second', content: 'BBB');

      expect(store.entries.first.label, 'second');
      expect(store.entries.first.content, 'BBB');
      expect(store.entries[1].label, 'first');
      expect(store.entries[1].content, 'AAA');
    });

    test('enforces maximum of 5 entries', () {
      for (var i = 0; i < 7; i++) {
        store.captureSnapshot(label: 'v$i', content: 'content-$i');
      }

      expect(store.entries, hasLength(5));
      // Most recent at front: v6, v5, v4, v3, v2
      expect(store.entries.first.label, 'v6');
      expect(store.entries.last.label, 'v2');
    });

    test('updates listeners after capture', () {
      var notifyCount = 0;
      store.addListener(() => notifyCount++);

      store.captureSnapshot(label: 'snap', content: 'text');

      expect(notifyCount, 1);
    });
  });

  // ===========================================================================
  // restoreEntry
  // ===========================================================================

  group('restoreEntry', () {
    test('creates entry with label 恢复版本 and the restored content', () {
      store.captureSnapshot(label: 'draft', content: 'original');
      final target = store.entries.first;

      store.restoreEntry(target);

      expect(store.entries.first.label, '恢复版本');
      expect(store.entries.first.content, 'original');
    });

    test('prepends restored entry to front', () {
      store.captureSnapshot(label: 'old', content: 'old-text');
      store.captureSnapshot(label: 'new', content: 'new-text');
      final oldEntry = store.entries[1];

      store.restoreEntry(oldEntry);

      expect(store.entries.first.label, '恢复版本');
      expect(store.entries.first.content, 'old-text');
      expect(store.entries[1].label, 'new');
    });
  });

  // ===========================================================================
  // export/import round-trip
  // ===========================================================================

  group('export/import round-trip', () {
    test('exportJson and importJson preserve all entries', () {
      store.captureSnapshot(label: 'alpha', content: 'aaa');
      store.captureSnapshot(label: 'beta', content: 'bbb');

      final exported = store.exportJson();

      final restored = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: workspaceStore,
      );
      addTearDown(restored.dispose);
      restored.importJson(exported);

      expect(restored.entries, hasLength(3)); // 2 captured + 1 default
      expect(restored.entries.first.label, 'beta');
      expect(restored.entries[1].label, 'alpha');
    });

    test('importJson with empty entries list reverts to defaults', () {
      store.captureSnapshot(label: 'extra', content: 'text');
      expect(store.entries.length, greaterThan(1));

      store.importJson({'entries': []});

      // Empty decoded list triggers default entries
      expect(store.entries, hasLength(1));
      expect(store.entries.first.label, '初始版本');
    });

    test('importJson with no entries key is a no-op', () {
      store.captureSnapshot(label: 'kept', content: 'data');

      store.importJson({'other': 'stuff'});

      expect(store.entries.any((e) => e.label == 'kept'), isTrue);
    });
  });

  // ===========================================================================
  // project scope change
  // ===========================================================================

  group('project scope change', () {
    test('onProjectScopeChanged resets to default entries', () {
      store.captureSnapshot(label: 'custom', content: 'custom-content');
      expect(store.entries.any((e) => e.label == 'custom'), isTrue);

      // Creating a new project changes currentProjectId, which triggers
      // onProjectScopeChanged on all scoped stores.
      workspaceStore.createProject();

      expect(store.entries, hasLength(1));
      expect(store.entries.first.label, '初始版本');
    });
  });
}
