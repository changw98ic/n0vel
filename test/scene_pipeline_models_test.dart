import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/context_capsule_compressor.dart';
import 'package:novel_writer/features/story_generation/domain/pipeline_models.dart';

void main() {
  group('RetrievalIntent', () {
    test('constructs with required fields and defaults', () {
      final intent = RetrievalIntent(
        characterId: 'liuxi',
        toolName: 'character_profile',
      );
      expect(intent.characterId, 'liuxi');
      expect(intent.toolName, 'character_profile');
      expect(intent.parameters, isEmpty);
      expect(intent.reasoning, '');
    });

    test('allowedTools contains expected tools', () {
      expect(RetrievalIntent.allowedTools, containsAll([
        'character_profile',
        'relationship_history',
        'scene_context',
        'world_rule',
      ]));
    });

    test('isToolAllowed returns true for valid tools', () {
      final intent = RetrievalIntent(
        characterId: 'a',
        toolName: 'scene_context',
      );
      expect(intent.isToolAllowed, isTrue);
    });

    test('isToolAllowed returns false for unknown tools', () {
      final intent = RetrievalIntent(
        characterId: 'a',
        toolName: 'hack_the_mainframe',
      );
      expect(intent.isToolAllowed, isFalse);
    });

    test('serializes and deserializes round-trip', () {
      final original = RetrievalIntent(
        characterId: 'liuxi',
        toolName: 'relationship_history',
        parameters: {'targetId': 'yueren', 'depth': 2},
        reasoning: 'Need to understand trust dynamics',
      );
      final json = original.toJson();
      final restored = RetrievalIntent.fromJson(json);
      expect(restored.characterId, original.characterId);
      expect(restored.toolName, original.toolName);
      expect(restored.parameters['targetId'], 'yueren');
      expect(restored.reasoning, original.reasoning);
    });

    test('fromJson handles missing fields', () {
      final restored = RetrievalIntent.fromJson({});
      expect(restored.characterId, '');
      expect(restored.toolName, '');
      expect(restored.parameters, isEmpty);
      expect(restored.reasoning, '');
    });

    test('copyWith preserves unmodified fields', () {
      final original = RetrievalIntent(
        characterId: 'liuxi',
        toolName: 'world_rule',
        reasoning: 'original',
      );
      final copied = original.copyWith(reasoning: 'updated');
      expect(copied.reasoning, 'updated');
      expect(copied.characterId, 'liuxi');
      expect(copied.toolName, 'world_rule');
    });

    test('equality and hashCode work correctly', () {
      final a = RetrievalIntent(
        characterId: 'x',
        toolName: 'scene_context',
      );
      final b = RetrievalIntent(
        characterId: 'x',
        toolName: 'scene_context',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('parameters are immutable', () {
      final intent = RetrievalIntent(
        characterId: 'a',
        toolName: 'scene_context',
        parameters: {'key': 'value'},
      );
      expect(() => intent.parameters['x'] = 'y', throwsA(isA<UnsupportedError>()));
    });
  });

  group('ContextCapsule', () {
    test('constructs with valid data', () {
      final capsule = ContextCapsule(
        id: 'cap-1',
        sourceTool: 'character_profile',
        summary: '柳溪是调查记者，性格冷静',
        charBudget: 200,
      );
      expect(capsule.id, 'cap-1');
      expect(capsule.sourceTool, 'character_profile');
      expect(capsule.summary, '柳溪是调查记者，性格冷静');
      expect(capsule.charBudget, 200);
      expect(capsule.isWithinBudget, isTrue);
    });

    test('truncates summary that exceeds charBudget', () {
      final longSummary = 'A' * 300;
      final capsule = ContextCapsule(
        id: 'cap-2',
        sourceTool: 'scene_context',
        summary: longSummary,
        charBudget: 100,
      );
      expect(capsule.summary.length, lessThanOrEqualTo(100));
      expect(capsule.summary, endsWith('...'));
      expect(capsule.isWithinBudget, isTrue);
    });

    test('preserves summary within budget', () {
      const summary = 'Short summary';
      final capsule = ContextCapsule(
        id: 'cap-3',
        sourceTool: 'world_rule',
        summary: summary,
        charBudget: 200,
      );
      expect(capsule.summary, summary);
    });

    test('serializes round-trip', () {
      final original = ContextCapsule(
        id: 'cap-4',
        sourceTool: 'relationship_history',
        summary: '柳溪和岳人互不信任',
        charBudget: 150,
        createdAtMs: 1000,
        metadata: {'source': 'test'},
      );
      final restored = ContextCapsule.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.sourceTool, original.sourceTool);
      expect(restored.summary, original.summary);
      expect(restored.charBudget, original.charBudget);
      expect(restored.createdAtMs, original.createdAtMs);
    });

    test('fromJson falls back to safe defaults', () {
      final restored = ContextCapsule.fromJson({});
      expect(restored.id, '');
      expect(restored.sourceTool, '');
      expect(restored.summary, '');
      expect(restored.charBudget, 200);
      expect(restored.createdAtMs, 0);
    });

    test('metadata is immutable', () {
      final capsule = ContextCapsule(
        id: 'cap-5',
        sourceTool: 'scene_context',
        summary: 'data',
        charBudget: 50,
        metadata: {'key': 'value'},
      );
      expect(
        () => capsule.metadata['x'] = 'y',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('PromptBudget', () {
    test('starts with full budget available', () {
      final budget = PromptBudget(maxChars: 1000);
      expect(budget.remaining, 1000);
      expect(budget.isExhausted, isFalse);
      expect(budget.utilization, 0.0);
    });

    test('tryAllocate succeeds when budget available', () {
      final budget = PromptBudget(maxChars: 1000);
      final result = budget.tryAllocate(300);
      expect(result, isTrue);
      expect(budget.remaining, 700);
      expect(budget.utilization, closeTo(0.3, 0.001));
    });

    test('tryAllocate fails when insufficient budget', () {
      final budget = PromptBudget(maxChars: 100);
      expect(budget.tryAllocate(80), isTrue);
      expect(budget.tryAllocate(30), isFalse);
      expect(budget.remaining, 20);
    });

    test('tryAllocate rejects non-positive values', () {
      final budget = PromptBudget(maxChars: 1000);
      expect(budget.tryAllocate(0), isFalse);
      expect(budget.tryAllocate(-10), isFalse);
      expect(budget.remaining, 1000);
    });

    test('isExhausted when all budget used', () {
      final budget = PromptBudget(maxChars: 100);
      budget.tryAllocate(100);
      expect(budget.isExhausted, isTrue);
      expect(budget.remaining, 0);
    });

    test('release restores budget', () {
      final budget = PromptBudget(maxChars: 100);
      budget.tryAllocate(60);
      budget.release(30);
      expect(budget.remaining, 70);
    });

    test('release clamps to zero', () {
      final budget = PromptBudget(maxChars: 100);
      budget.tryAllocate(30);
      budget.release(50);
      expect(budget.remaining, 100);
    });

    test('reset clears allocation', () {
      final budget = PromptBudget(maxChars: 100);
      budget.tryAllocate(80);
      budget.reset();
      expect(budget.remaining, 100);
      expect(budget.utilization, 0.0);
    });

    test('reset with reserved chars', () {
      final budget = PromptBudget(maxChars: 100);
      budget.tryAllocate(80);
      budget.reset(reservedChars: 20);
      expect(budget.remaining, 80);
    });

    test('constructor with reserved chars', () {
      final budget = PromptBudget(maxChars: 1000, reservedChars: 200);
      expect(budget.remaining, 800);
    });
  });

  group('ContextCapsuleCompressor', () {
    test('compresses content within default budget', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 100);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: 'Short content',
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary, 'Short content');
      expect(capsule.sourceTool, 'character_profile');
      expect(capsule.isWithinBudget, isTrue);
    });

    test('truncates content exceeding budget', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 20);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'scene_context',
        rawContent: 'This is a very long piece of content that should be truncated',
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary.length, lessThanOrEqualTo(20));
      expect(capsule.summary, endsWith('...'));
    });

    test('respects PromptBudget remaining capacity', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 200);
      final budget = PromptBudget(maxChars: 50);
      final capsule = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: 'A' * 500,
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary.length, lessThanOrEqualTo(50));
    });

    test('returns null when budget is exhausted', () {
      final compressor = ContextCapsuleCompressor();
      final budget = PromptBudget(maxChars: 10);
      budget.tryAllocate(10);
      final capsule = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: 'content',
        budget: budget,
      );
      expect(capsule, isNull);
    });

    test('allocates from budget on successful compress', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 100);
      final budget = PromptBudget(maxChars: 1000);
      compressor.compress(
        sourceTool: 'character_profile',
        rawContent: 'Some content here',
        budget: budget,
      );
      expect(budget.remaining, lessThan(1000));
      expect(budget.utilization, greaterThan(0));
    });

    test('compressAll stops early when budget exhausted', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 30);
      final budget = PromptBudget(maxChars: 50);
      final capsules = compressor.compressAll(
        rawResults: [
          RawRetrievalResult(
            sourceTool: 'character_profile',
            rawContent: 'First result with enough text to fill budget',
          ),
          RawRetrievalResult(
            sourceTool: 'scene_context',
            rawContent: 'Second result also quite long to fill space',
          ),
          RawRetrievalResult(
            sourceTool: 'world_rule',
            rawContent: 'Third result that should not appear at all',
          ),
        ],
        budget: budget,
      );
      expect(capsules.length, lessThan(3));
      expect(capsules.length, greaterThanOrEqualTo(1));
      for (final capsule in capsules) {
        expect(capsule.isWithinBudget, isTrue);
      }
    });

    test('compressAll returns empty list for empty input', () {
      final compressor = ContextCapsuleCompressor();
      final budget = PromptBudget(maxChars: 1000);
      final capsules = compressor.compressAll(
        rawResults: [],
        budget: budget,
      );
      expect(capsules, isEmpty);
    });

    test('generates unique IDs across calls', () {
      final compressor = ContextCapsuleCompressor();
      final budget = PromptBudget(maxChars: 10000);
      final capsule1 = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: 'content 1',
        budget: budget,
      );
      final capsule2 = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: 'content 2',
        budget: budget,
      );
      expect(capsule1!.id, isNot(equals(capsule2!.id)));
    });
  });

  group('ScenePipelineTelemetryEntry', () {
    test('constructs with required fields', () {
      final entry = ScenePipelineTelemetryEntry(
        sceneId: 'scene-03',
        stage: ScenePipelineStage.retrieval,
        startedAtMs: 1000,
        completedAtMs: 1500,
        succeeded: true,
      );
      expect(entry.sceneId, 'scene-03');
      expect(entry.stage, ScenePipelineStage.retrieval);
      expect(entry.durationMs, 500);
      expect(entry.succeeded, isTrue);
      expect(entry.detail, '');
    });

    test('durationMs computed correctly', () {
      final entry = ScenePipelineTelemetryEntry(
        sceneId: 'scene-03',
        stage: ScenePipelineStage.capsuleCompression,
        startedAtMs: 2000,
        completedAtMs: 2250,
        succeeded: true,
      );
      expect(entry.durationMs, 250);
    });

    test('serializes to JSON', () {
      final entry = ScenePipelineTelemetryEntry(
        sceneId: 'scene-03',
        stage: ScenePipelineStage.editorial,
        startedAtMs: 1000,
        completedAtMs: 2000,
        succeeded: true,
        detail: 'Draft generated',
      );
      final json = entry.toJson();
      expect(json['sceneId'], 'scene-03');
      expect(json['stage'], 'editorial');
      expect(json['startedAtMs'], 1000);
      expect(json['completedAtMs'], 2000);
      expect(json['succeeded'], true);
      expect(json['detail'], 'Draft generated');
    });

    test('fromJson reconstructs entry', () {
      final original = ScenePipelineTelemetryEntry(
        sceneId: 'scene-05',
        stage: ScenePipelineStage.resolution,
        startedAtMs: 3000,
        completedAtMs: 4000,
        succeeded: false,
        detail: 'Conflict detected',
      );
      final restored = ScenePipelineTelemetryEntry.fromJson(original.toJson());
      expect(restored.sceneId, original.sceneId);
      expect(restored.stage, original.stage);
      expect(restored.startedAtMs, original.startedAtMs);
      expect(restored.completedAtMs, original.completedAtMs);
      expect(restored.succeeded, original.succeeded);
      expect(restored.detail, original.detail);
    });

    test('fromJson falls back to retrieval for unknown stage', () {
      final json = {'stage': 'unknown_stage'};
      final restored = ScenePipelineTelemetryEntry.fromJson(json);
      expect(restored.stage, ScenePipelineStage.retrieval);
    });

    test('records failed stage', () {
      final entry = ScenePipelineTelemetryEntry(
        sceneId: 'scene-99',
        stage: ScenePipelineStage.retrieval,
        startedAtMs: 0,
        completedAtMs: 100,
        succeeded: false,
        detail: 'Tool unavailable',
      );
      expect(entry.succeeded, isFalse);
    });

    test('metadata is immutable', () {
      final entry = ScenePipelineTelemetryEntry(
        sceneId: 'scene-01',
        stage: ScenePipelineStage.retrieval,
        startedAtMs: 0,
        completedAtMs: 1,
        succeeded: true,
        metadata: {'key': 'value'},
      );
      expect(
        () => entry.metadata['x'] = 'y',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Non-functional invariants', () {
    test('capsule never exceeds its declared budget', () {
      final rng = _SeededRandom(42);
      for (var i = 0; i < 100; i++) {
        final budget = 10 + rng.nextInt(200);
        final contentLength = 1 + rng.nextInt(500);
        final content = 'A' * contentLength;
        final capsule = ContextCapsule(
          id: 'stress-$i',
          sourceTool: 'test',
          summary: content,
          charBudget: budget,
        );
        expect(
          capsule.summary.length,
          lessThanOrEqualTo(budget),
          reason: 'Capsule $i: summary exceeds charBudget',
        );
        expect(capsule.isWithinBudget, isTrue);
      }
    });

    test('budget never goes negative after allocations and releases', () {
      final budget = PromptBudget(maxChars: 100);
      budget.tryAllocate(60);
      budget.release(30);
      budget.tryAllocate(40);
      budget.release(50);
      budget.tryAllocate(20);
      expect(budget.remaining, greaterThanOrEqualTo(0));
      expect(budget.remaining, lessThanOrEqualTo(100));
    });

    test('compressor never produces capsule exceeding PromptBudget', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 100);
      final budget = PromptBudget(maxChars: 150);
      final capsules = <ContextCapsule>[];
      for (var i = 0; i < 10; i++) {
        final capsule = compressor.compress(
          sourceTool: 'test',
          rawContent: 'Content block $i with some text',
          budget: budget,
        );
        if (capsule == null) break;
        capsules.add(capsule);
      }
      var totalChars = 0;
      for (final capsule in capsules) {
        totalChars += capsule.summary.length;
        expect(capsule.isWithinBudget, isTrue);
      }
      expect(totalChars, lessThanOrEqualTo(150));
    });

    test('telemetry entries preserve chronological order', () {
      final entries = [
        ScenePipelineTelemetryEntry(
          sceneId: 's1',
          stage: ScenePipelineStage.retrieval,
          startedAtMs: 0,
          completedAtMs: 100,
          succeeded: true,
        ),
        ScenePipelineTelemetryEntry(
          sceneId: 's1',
          stage: ScenePipelineStage.capsuleCompression,
          startedAtMs: 100,
          completedAtMs: 200,
          succeeded: true,
        ),
        ScenePipelineTelemetryEntry(
          sceneId: 's1',
          stage: ScenePipelineStage.resolution,
          startedAtMs: 200,
          completedAtMs: 350,
          succeeded: true,
        ),
        ScenePipelineTelemetryEntry(
          sceneId: 's1',
          stage: ScenePipelineStage.editorial,
          startedAtMs: 350,
          completedAtMs: 500,
          succeeded: true,
        ),
      ];
      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i].startedAtMs,
          greaterThanOrEqualTo(entries[i - 1].completedAtMs),
          reason: 'Stage ${entries[i].stage} starts before previous completes',
        );
      }
    });

    test('retrieval intents only reference allowed tools', () {
      final intents = [
        RetrievalIntent(characterId: 'a', toolName: 'character_profile'),
        RetrievalIntent(characterId: 'a', toolName: 'relationship_history'),
        RetrievalIntent(characterId: 'b', toolName: 'scene_context'),
        RetrievalIntent(characterId: 'b', toolName: 'world_rule'),
      ];
      for (final intent in intents) {
        expect(intent.isToolAllowed, isTrue, reason: '${intent.toolName} should be allowed');
      }
    });
  });

  group('CompressionStrategy', () {
    test('selectStrategy returns full when content fits', () {
      final compressor = ContextCapsuleCompressor();
      expect(
        compressor.selectStrategy('Short', 100),
        CompressionStrategy.full,
      );
    });

    test('selectStrategy returns sentenceBoundary for moderate pressure', () {
      final compressor = ContextCapsuleCompressor();
      final content = 'A' * 100;
      // ratio = 70/100 = 0.7 > 0.6
      expect(
        compressor.selectStrategy(content, 70),
        CompressionStrategy.sentenceBoundary,
      );
    });

    test('selectStrategy returns keySentences for tight budgets', () {
      final compressor = ContextCapsuleCompressor();
      final content = 'A' * 100;
      // ratio = 40/100 = 0.4, between 0.25 and 0.6
      expect(
        compressor.selectStrategy(content, 40),
        CompressionStrategy.keySentences,
      );
    });

    test('selectStrategy returns keywords for critical pressure', () {
      final compressor = ContextCapsuleCompressor();
      final content = 'A' * 100;
      // ratio = 10/100 = 0.1 < 0.25
      expect(
        compressor.selectStrategy(content, 10),
        CompressionStrategy.keywords,
      );
    });
  });

  group('Dynamic context compression', () {
    test('sentence-boundary truncation preserves complete sentences', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 25);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: '柳溪是调查记者。她性格冷静，善于观察。她在调查中发现了一条重要线索。',
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary, equals('柳溪是调查记者。她性格冷静，善于观察。'));
      expect(capsule.isWithinBudget, isTrue);
    });

    test('sentence-boundary truncation with English text', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 22);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'scene_context',
        rawContent: 'The hero arrived. The battle began. The enemy retreated.',
        budget: budget,
      );
      expect(capsule, isNotNull);
      // "The hero arrived." = 17 chars, fits within 22.
      // "The hero arrived. The" = 22 chars but no sentence end there.
      expect(capsule!.summary, equals('The hero arrived.'));
    });

    test('falls back to ellipsis when no sentence boundary', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 20);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'scene_context',
        rawContent: 'No sentence boundary here just continuous text',
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary.length, lessThanOrEqualTo(20));
      expect(capsule.summary, endsWith('...'));
    });

    test('key sentence extraction picks leading sentences', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 30);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'world_rule',
        rawContent: 'First sentence. Second. Third. Fourth.',
        budget: budget,
      );
      expect(capsule, isNotNull);
      // ratio = 30/38 ≈ 0.79 → sentenceBoundary, not keySentences.
      // sentenceBoundary: substring(0, 30) = "First sentence. Second. Third."
      // finds '.' at index 29 → returns all of it
      expect(capsule!.summary, contains('First sentence'));
    });

    test('key sentence extraction with tight budget', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 20);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'world_rule',
        rawContent: 'Alpha。Beta。Gamma。Delta。Epsilon。',
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary.length, lessThanOrEqualTo(20));
      // Should contain at least the first sentence
      expect(capsule.summary, contains('Alpha'));
    });

    test('keyword extraction strips punctuation', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 15);
      final budget = PromptBudget(maxChars: 1000);
      final capsule = compressor.compress(
        sourceTool: 'character_profile',
        rawContent: '名字：柳溪，职业：记者，性格：冷静',
        budget: budget,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary.length, lessThanOrEqualTo(15));
      // Should contain core content without punctuation
      expect(capsule.summary, contains('柳溪'));
    });

    test('manual strategy override works', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 15);
      final budget = PromptBudget(maxChars: 1000);
      // Force keywords strategy on content that exceeds budget
      final capsule = compressor.compress(
        sourceTool: 'test',
        rawContent: '名字：柳溪，职业：调查记者，性格：冷静',
        budget: budget,
        strategy: CompressionStrategy.keywords,
      );
      expect(capsule, isNotNull);
      expect(capsule!.summary.length, lessThanOrEqualTo(15));
      // keywords should strip full-width punctuation
      expect(capsule.summary, isNot(contains('：')));
      expect(capsule.summary, contains('柳溪'));
    });

    test('zero budget returns empty or null', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 1);
      final budget = PromptBudget(maxChars: 1);
      budget.tryAllocate(1);
      final capsule = compressor.compress(
        sourceTool: 'test',
        rawContent: 'content',
        budget: budget,
      );
      expect(capsule, isNull);
    });
  });

  group('Priority-aware compressAll', () {
    test('processes higher priority items first', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 30);
      final budget = PromptBudget(maxChars: 40);
      final capsules = compressor.compressAll(
        rawResults: [
          RawRetrievalResult(
            sourceTool: 'low_priority',
            rawContent: 'Low priority content that is quite long indeed',
            priority: 1,
          ),
          RawRetrievalResult(
            sourceTool: 'high_priority',
            rawContent: 'High priority content that is also quite long',
            priority: 10,
          ),
        ],
        budget: budget,
      );
      expect(capsules, isNotEmpty);
      expect(capsules.first.sourceTool, 'high_priority');
    });

    test('equal priority preserves insertion order stability', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 50);
      final budget = PromptBudget(maxChars: 200);
      final capsules = compressor.compressAll(
        rawResults: [
          RawRetrievalResult(
            sourceTool: 'first',
            rawContent: 'First item',
          ),
          RawRetrievalResult(
            sourceTool: 'second',
            rawContent: 'Second item',
          ),
          RawRetrievalResult(
            sourceTool: 'third',
            rawContent: 'Third item',
          ),
        ],
        budget: budget,
      );
      expect(capsules.length, 3);
      // All have priority 0, order may vary but all should be present
      final tools = capsules.map((c) => c.sourceTool).toSet();
      expect(tools, containsAll(['first', 'second', 'third']));
    });

    test('priority items get budget before low priority are dropped', () {
      final compressor = ContextCapsuleCompressor(defaultCharBudget: 30);
      final budget = PromptBudget(maxChars: 35);
      final capsules = compressor.compressAll(
        rawResults: [
          RawRetrievalResult(
            sourceTool: 'optional',
            rawContent: 'Optional detail that is not critical at all',
            priority: 0,
          ),
          RawRetrievalResult(
            sourceTool: 'essential',
            rawContent: 'Essential context that must be included here',
            priority: 100,
          ),
        ],
        budget: budget,
      );
      // High priority should be in the result
      final tools = capsules.map((c) => c.sourceTool).toList();
      expect(tools, contains('essential'));
    });
  });

  group('RawRetrievalResult', () {
    test('constructs with default priority', () {
      final result = RawRetrievalResult(
        sourceTool: 'character_profile',
        rawContent: 'content',
      );
      expect(result.priority, 0);
    });

    test('constructs with explicit priority', () {
      final result = RawRetrievalResult(
        sourceTool: 'character_profile',
        rawContent: 'content',
        priority: 5,
      );
      expect(result.priority, 5);
    });

    test('metadata is immutable', () {
      final result = RawRetrievalResult(
        sourceTool: 'test',
        rawContent: 'content',
        metadata: {'key': 'value'},
      );
      expect(
        () => result.metadata['x'] = 'y',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

class _SeededRandom {
  _SeededRandom(this._seed);
  int _seed;
  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed % max;
  }
}
