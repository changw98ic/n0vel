import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_writeback_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BasicMemoryWritebackGate', () {
    test('accepts valid scene-tier writes', () async {
      const gate = BasicMemoryWritebackGate();
      final result = await gate.validate([
        const ProposedWrite(
          tier: MemoryTier.scene,
          content: '角色进入了房间',
          producer: 'roleplay',
        ),
      ]);
      expect(result.allAccepted, isTrue);
      expect(result.accepted, hasLength(1));
    });

    test('rejects soul-violating canon writes when validator provided', () async {
      const gate = BasicMemoryWritebackGate(
        soulValidator: _rejectingValidator,
      );
      final result = await gate.validate([
        const ProposedWrite(
          tier: MemoryTier.canon,
          content: 'bad action',
        ),
      ]);
      expect(result.rejected, hasLength(1));
      expect(result.rejected[0].reasons, isNotEmpty);
    });

    test('accepts canon writes when validator passes', () async {
      const gate = BasicMemoryWritebackGate(
        soulValidator: _acceptingValidator,
      );
      final result = await gate.validate([
        const ProposedWrite(
          tier: MemoryTier.canon,
          content: 'good action',
        ),
      ]);
      expect(result.allAccepted, isTrue);
    });

    test('rejects canon-contradicting writes when keeper provided', () async {
      const gate = BasicMemoryWritebackGate(
        canonKeeper: _rejectingCanonKeeper,
      );
      final result = await gate.validate([
        const ProposedWrite(
          tier: MemoryTier.canon,
          content: '太阳从西边升起',
        ),
      ]);
      expect(result.rejected, hasLength(1));
      expect(
        result.rejected[0].reasons[0],
        contains('Canon contradiction'),
      );
    });

    test('tier transition: scene to draft is allowed', () {
      const gate = BasicMemoryWritebackGate();
      expect(
        gate.isTierTransitionAllowed(MemoryTier.scene, MemoryTier.draft),
        isTrue,
      );
    });

    test('tier transition: draft to canon is forbidden', () {
      const gate = BasicMemoryWritebackGate();
      expect(
        gate.isTierTransitionAllowed(MemoryTier.draft, MemoryTier.canon),
        isFalse,
      );
    });

    test('tier transition: same tier is allowed', () {
      const gate = BasicMemoryWritebackGate();
      for (final tier in MemoryTier.values) {
        expect(gate.isTierTransitionAllowed(tier, tier), isTrue);
      }
    });

    test('handles empty write list', () async {
      const gate = BasicMemoryWritebackGate();
      final result = await gate.validate([]);
      expect(result.accepted, isEmpty);
      expect(result.rejected, isEmpty);
      expect(result.allAccepted, isTrue);
    });

    test('mixes accepted and rejected writes', () async {
      const gate = BasicMemoryWritebackGate(
        soulValidator: _rejectingValidator,
      );
      final result = await gate.validate([
        const ProposedWrite(tier: MemoryTier.scene, content: 'ok'),
        const ProposedWrite(tier: MemoryTier.canon, content: 'bad'),
        const ProposedWrite(tier: MemoryTier.draft, content: 'also ok'),
      ]);
      expect(result.accepted, hasLength(2));
      expect(result.rejected, hasLength(1));
    });
  });
}

List<SoulViolationRef> _rejectingValidator(String content) {
  return const [SoulViolationRef(rule: 'test:forbidden')];
}

List<SoulViolationRef> _acceptingValidator(String content) {
  return const [];
}

List<String> _rejectingCanonKeeper(ProposedWrite write) {
  return ['contradicts established fact'];
}
