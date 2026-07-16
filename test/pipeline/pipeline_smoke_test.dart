// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:test/test.dart';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';
import 'package:novel_writer/features/story_generation/data/canon_keeper.dart';
import 'package:novel_writer/features/story_generation/data/soul_contract_validator.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart'
    show ProposedWrite;
import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

void main() {
  final legacyRealProviderDecision =
      AgentEvaluationRealProviderEntryGate.legacyDecision(
        entryPoint: 'test/pipeline/pipeline_smoke_test.dart',
        environment: Platform.environment,
      );
  test(
    'real 3-scene smoke delegates to existing real validation suite',
    () async {
      if (!legacyRealProviderDecision.authorized) {
        markTestSkipped(legacyRealProviderDecision.denialReason);
        return;
      }

      final result = await Process.run('flutter', [
        'test',
        '--no-pub',
        'test/real_three_chapter_generation_test.dart',
        '--plain-name',
        'real three chapter generation leaves visible artifacts',
      ]);

      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
      );
    },
    timeout: Timeout.none,
  );

  test('canon violation is caught by CanonKeeper gate logic', () {
    final issues = const CanonKeeper().checkConsistency(
      const ProposedWrite(
        tier: MemoryTier.canon,
        content: 'warehouse door is blue',
        producer: 'pipeline-smoke',
      ),
      const [
        StoryMemoryChunk(
          id: 'canon-door-red',
          projectId: 'p-smoke',
          scopeId: 'world',
          kind: MemorySourceKind.worldFact,
          content: 'warehouse door is red',
          tier: MemoryTier.canon,
        ),
      ],
    );

    expect(issues, isNotEmpty);
    expect(issues.single, contains('Predicate conflict'));
  });

  test('soul violation marks content for automatic rewrite', () {
    const validator = SoulContractValidator(
      SoulContract(forbiddenActions: ['betray']),
    );

    final violations = validator.validate('Lin decides to betray the crew.');
    final shouldRewrite = violations.isNotEmpty;

    expect(shouldRewrite, isTrue);
    expect(violations.single.rule, 'forbidden:betray');
  });
}
