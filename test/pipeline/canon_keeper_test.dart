import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/canon_keeper.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart'
    as gate;
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

void main() {
  const keeper = CanonKeeper();

  StoryMemoryChunk canonFact(String content) => StoryMemoryChunk(
    id: 'c1',
    projectId: 'p',
    scopeId: 's',
    kind: MemorySourceKind.worldFact,
    content: content,
    tier: MemoryTier.canon,
  );

  gate.ProposedWrite proposedWrite(String content) =>
      gate.ProposedWrite(tier: MemoryTier.canon, content: content);

  test('consistent write returns empty contradictions', () {
    final facts = [canonFact('The sky is blue')];
    final issues = keeper.checkConsistency(
      proposedWrite('The sky is blue'),
      facts,
    );
    expect(issues, isEmpty);
  });

  test('exact English negation is detected', () {
    final facts = [canonFact('The door is open')];
    final issues = keeper.checkConsistency(
      proposedWrite('The door is not open'),
      facts,
    );
    expect(issues, isNotEmpty);
    expect(issues.any((e) => e.contains('Negation conflict')), isTrue);
  });

  test('Chinese negation is detected', () {
    final facts = [canonFact('门是开着的')];
    final issues = keeper.checkConsistency(proposedWrite('门不是开着的'), facts);
    expect(issues, hasLength(1));
    expect(issues.first, contains('Negation conflict'));
  });

  test('subject-predicate conflict is detected', () {
    final facts = [canonFact('Alice is a knight')];
    final issues = keeper.checkConsistency(
      proposedWrite('Alice is a wizard'),
      facts,
    );
    expect(issues, hasLength(1));
    expect(issues.first, contains('Predicate conflict'));
  });

  test('numerical conflict is detected', () {
    final facts = [canonFact('The army has 300 soldiers')];
    final issues = keeper.checkConsistency(
      proposedWrite('The army has 500 soldiers'),
      facts,
    );
    expect(issues, hasLength(1));
    expect(issues.first, contains('Numeric conflict'));
  });

  test('non-canon facts are ignored', () {
    final facts = [
      const StoryMemoryChunk(
        id: 's1',
        projectId: 'p',
        scopeId: 's',
        kind: MemorySourceKind.sceneSummary,
        content: 'The door is not open',
        tier: MemoryTier.scene,
      ),
    ];
    final issues = keeper.checkConsistency(
      proposedWrite('The door is open'),
      facts,
    );
    expect(issues, isEmpty);
  });

  test(
    'asWritebackCanonKeeper adapter works with BasicMemoryWritebackGate',
    () async {
      final canonFacts = [canonFact('The king is alive')];
      final g = gate.BasicMemoryWritebackGate(
        canonKeeper: keeper.asWritebackCanonKeeper(canonFacts),
      );

      final result = await g.validate([
        const gate.ProposedWrite(
          tier: MemoryTier.canon,
          content: 'The king is not alive',
        ),
      ]);

      expect(result.accepted, isEmpty);
      expect(result.rejected, hasLength(1));
      expect(
        result.rejected.first.reasons.first,
        contains('Canon contradiction'),
      );
    },
  );
}
