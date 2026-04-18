import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/writer_guidance_index.dart';

void main() {
  group('WriterGuidanceIndex', () {
    late WriterGuidanceIndex index;

    setUpAll(() {
      final yamlText = File('.writer/memory/index.yaml').readAsStringSync();
      index = WriterGuidanceIndex.parse(yamlText);
    });

    test('parses charter and global assets', () {
      expect(index.charterAssetPath, 'writer.md');
      expect(index.globalAssets, contains('.writer/memory/global.md'));
    });

    test('module entries match expected writing prompts', () {
      final editorEntry = index.modules.firstWhere(
        (entry) => entry.id == 'editor-chat',
      );

      expect(editorEntry.matchesPrompt('请帮我续写第一章并优化对白'), isTrue);
      expect(editorEntry.matchesPrompt('workflow checkpoint restore'), isFalse);
    });

    test('path entries match expected runtime paths', () {
      final workflowEntry = index.paths.firstWhere(
        (entry) => entry.id == 'workflow',
      );

      expect(
        workflowEntry.matchesPaths(['lib/features/workflow/data/']),
        isTrue,
      );
      expect(workflowEntry.matchesPaths(['lib/modules/editor/view/']), isFalse);
    });

    test('agent, team and hook entries can be resolved by id', () {
      expect(index.findAgent('writer-agent')?.assetPath, isNotEmpty);
      expect(index.findTeam('longform-book-team')?.assetPath, isNotEmpty);
      expect(index.findHook('pre-request-validate')?.assetPath, isNotEmpty);
    });

    test('all referenced asset files exist on disk', () {
      final allAssetPaths = <String>[
        index.charterAssetPath,
        ...index.globalAssets,
        ...index.modules.map((e) => e.assetPath),
        ...index.paths.map((e) => e.assetPath),
        ...index.skills.map((e) => e.assetPath),
        ...index.agents.map((e) => e.assetPath),
        ...index.teams.map((e) => e.assetPath),
        ...index.hooks.map((e) => e.assetPath),
      ];

      final missing = <String>[];
      for (final path in allAssetPaths) {
        if (!File(path).existsSync()) {
          missing.add(path);
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Missing asset files: ${missing.join(", ")}',
      );
    });
  });
}
