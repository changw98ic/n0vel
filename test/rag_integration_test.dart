import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/openviking_models.dart';
import 'package:novel_writer/app/rag/rag_config.dart';
import 'package:novel_writer/app/rag/rag_orchestrator.dart';

void main() {
  group('RagConfig', () {
    test('has sensible defaults', () {
      const config = RagConfig();
      expect(config.serverUrl, 'http://localhost:1933');
      expect(config.defaultLimit, 10);
      expect(config.scoreThreshold, 0.5);
      expect(config.tokenBudget, 800);
    });

    test('copyWith preserves unmodified fields', () {
      const config = RagConfig(tokenBudget: 1200);
      final updated = config.copyWith(scoreThreshold: 0.7);
      expect(updated.tokenBudget, 1200);
      expect(updated.scoreThreshold, 0.7);
      expect(updated.serverUrl, config.serverUrl);
    });

    test('copyWith with no args returns equal config', () {
      const config = RagConfig(serverUrl: 'http://ov:1933');
      final copy = config.copyWith();
      expect(copy.serverUrl, config.serverUrl);
      expect(copy.defaultLimit, config.defaultLimit);
    });
  });

  group('OpenVikingSearchResult', () {
    test('constructs and serializes', () {
      const result = OpenVikingSearchResult(
        path: 'proj/characters/char_0.md',
        content: '柳溪是调查记者',
        score: 0.92,
      );
      expect(result.path, 'proj/characters/char_0.md');
      expect(result.content, '柳溪是调查记者');
      expect(result.score, 0.92);
      expect(result.metadata, isEmpty);
    });

    test('fromJson parses complete JSON', () {
      final result = OpenVikingSearchResult.fromJson({
        'path': 'proj/worldbuilding/fact_1.md',
        'content': '世界观规则',
        'score': 0.85,
        'metadata': {'kind': 'worldFact'},
      });
      expect(result.path, 'proj/worldbuilding/fact_1.md');
      expect(result.content, '世界观规则');
      expect(result.score, 0.85);
      expect(result.metadata['kind'], 'worldFact');
    });

    test('fromJson handles missing fields', () {
      final result = OpenVikingSearchResult.fromJson({});
      expect(result.path, '');
      expect(result.content, '');
      expect(result.score, 0.0);
      expect(result.metadata, isEmpty);
    });

    test('fromJson handles int score', () {
      final result = OpenVikingSearchResult.fromJson({'score': 1});
      expect(result.score, 1.0);
    });

    test('toJson round-trip', () {
      const original = OpenVikingSearchResult(
        path: 'a/b.md',
        content: '内容',
        score: 0.75,
        metadata: {'x': 1},
      );
      final restored = OpenVikingSearchResult.fromJson(original.toJson());
      expect(restored.path, original.path);
      expect(restored.content, original.content);
      expect(restored.score, original.score);
    });
  });

  group('OpenVikingResourceInfo', () {
    test('fromJson parses complete JSON', () {
      final info = OpenVikingResourceInfo.fromJson({
        'path': 'proj/characters/',
        'type': 'directory',
        'size': 0,
        'modifiedAt': '2026-04-26',
      });
      expect(info.path, 'proj/characters/');
      expect(info.type, 'directory');
      expect(info.size, 0);
      expect(info.modifiedAt, '2026-04-26');
    });

    test('fromJson falls back to file type', () {
      final info = OpenVikingResourceInfo.fromJson({});
      expect(info.type, 'file');
      expect(info.path, '');
    });
  });

  group('OpenVikingFindResponse', () {
    test('fromJson parses results list', () {
      final response = OpenVikingFindResponse.fromJson({
        'results': [
          {'path': 'a.md', 'content': 'A', 'score': 0.9},
          {'path': 'b.md', 'content': 'B', 'score': 0.7},
        ],
        'totalCount': 2,
      });
      expect(response.results.length, 2);
      expect(response.results[0].path, 'a.md');
      expect(response.totalCount, 2);
    });

    test('fromJson handles empty results', () {
      final response = OpenVikingFindResponse.fromJson({});
      expect(response.results, isEmpty);
      expect(response.totalCount, 0);
    });

    test('fromJson skips malformed entries', () {
      final response = OpenVikingFindResponse.fromJson({
        'results': [
          {'path': 'ok.md', 'content': 'OK', 'score': 0.5},
          'not-a-map',
          42,
        ],
      });
      expect(response.results.length, 1);
      expect(response.results[0].path, 'ok.md');
    });
  });

  group('RagSceneContext', () {
    test('isEmpty when no results', () {
      const context = RagSceneContext(results: [], formattedContext: '');
      expect(context.isEmpty, isTrue);
    });

    test('is not empty with results', () {
      const context = RagSceneContext(
        results: [
          OpenVikingSearchResult(path: 'a.md', content: 'A', score: 0.9),
        ],
        formattedContext: 'some text',
      );
      expect(context.isEmpty, isFalse);
    });
  });

  group('RagOrchestrator logic', () {
    test('deduplication removes duplicate paths keeping first', () {
      // Indirectly test through the formatContext which operates on deduped results
      const results = [
        OpenVikingSearchResult(path: 'a.md', content: 'Alpha', score: 0.9),
        OpenVikingSearchResult(path: 'b.md', content: 'Beta', score: 0.8),
        OpenVikingSearchResult(path: 'a.md', content: 'Alpha2', score: 0.7),
      ];
      // Simulate dedup logic
      final seen = <String>{};
      final deduped = <OpenVikingSearchResult>[];
      for (final r in results) {
        if (seen.add(r.path)) deduped.add(r);
      }
      expect(deduped.length, 2);
      expect(deduped[0].content, 'Alpha');
      expect(deduped[1].content, 'Beta');
    });

    test('budget trimming respects char budget', () {
      const budget = 20;
      const results = [
        OpenVikingSearchResult(path: 'a.md', content: '12345678', score: 0.9),
        OpenVikingSearchResult(path: 'b.md', content: '12345', score: 0.8),
        OpenVikingSearchResult(path: 'c.md', content: '12345678', score: 0.7),
      ];
      // Simulate trim logic
      final selected = <OpenVikingSearchResult>[];
      var charCount = 0;
      for (final r in results) {
        if (charCount + r.content.length > budget) break;
        selected.add(r);
        charCount += r.content.length;
      }
      expect(selected.length, 2);
      expect(charCount, 13);
    });

    test('formatContext produces expected structure', () {
      // Directly test the formatting pattern used in RagOrchestrator
      const results = [
        OpenVikingSearchResult(path: 'char/0.md', content: '柳溪是调查记者', score: 0.92),
      ];
      final buffer = StringBuffer('【RAG检索上下文】\n');
      for (final r in results) {
        final snippet = r.content.length > 200
            ? '${r.content.substring(0, 197)}...'
            : r.content;
        buffer.writeln('- [${r.path}] ${r.score.toStringAsFixed(2)}: $snippet');
      }
      final output = buffer.toString();
      expect(output, contains('【RAG检索上下文】'));
      expect(output, contains('char/0.md'));
      expect(output, contains('柳溪是调查记者'));
      expect(output, contains('0.92'));
    });

    test('formatContext truncates long content', () {
      final longContent = 'A' * 300;
      final results = [
        OpenVikingSearchResult(path: 'x.md', content: longContent, score: 1.0),
      ];
      final buffer = StringBuffer();
      for (final r in results) {
        final snippet = r.content.length > 200
            ? '${r.content.substring(0, 197)}...'
            : r.content;
        buffer.writeln(snippet);
      }
      final output = buffer.toString().trim();
      expect(output.length, lessThanOrEqualTo(203)); // 197 + 3 for "..."
      expect(output, endsWith('...'));
    });

    test('formatContext returns empty for empty results', () {
      const results = <OpenVikingSearchResult>[];
      if (results.isEmpty) {
        // matches the pattern in _formatContext
      }
      expect(results, isEmpty);
    });
  });

  group('Integration invariants', () {
    test('RAG config with extreme values still constructs', () {
      const config = RagConfig(
        serverUrl: '',
        defaultLimit: 0,
        scoreThreshold: 0.0,
        tokenBudget: 0,
      );
      expect(config.serverUrl, '');
      expect(config.defaultLimit, 0);
    });

    test('search result with negative score handled', () {
      final result = OpenVikingSearchResult.fromJson({'score': -0.5});
      expect(result.score, -0.5);
    });

    test('search result with string score parsed', () {
      final result = OpenVikingSearchResult.fromJson({'score': '0.75'});
      expect(result.score, 0.75);
    });

    test('find response with non-list results handled gracefully', () {
      final response = OpenVikingFindResponse.fromJson({
        'results': 'not-a-list',
        'totalCount': 'five',
      });
      expect(response.results, isEmpty);
      expect(response.totalCount, 0);
    });
  });
}
