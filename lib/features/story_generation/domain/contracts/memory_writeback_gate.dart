import 'memory_policy.dart';

/// A proposed memory write pending gate validation.
class ProposedWrite {
  const ProposedWrite({
    required this.tier,
    required this.content,
    this.sourceRefs = const [],
    this.producer = '',
  });

  final MemoryTier tier;
  final String content;
  final List<String> sourceRefs;
  final String producer;
}

/// Result of validating a batch of proposed writes.
class WritebackResult {
  const WritebackResult({required this.accepted, required this.rejected});

  /// Writes that passed the gate.
  final List<ProposedWrite> accepted;

  /// Writes that were rejected, with reasons.
  final List<RejectedWrite> rejected;

  bool get allAccepted => rejected.isEmpty;
}

/// A write rejected by the gate, with the reason.
class RejectedWrite {
  const RejectedWrite({required this.write, required this.reasons});

  final ProposedWrite write;
  final List<String> reasons;
}

/// Validates proposed memory writes before they are persisted.
///
/// Enforces tier hierarchy, soul contract rules, and canon consistency.
/// This is an interface — concrete implementations will be provided by
/// later phases with real soul validation and canon checking.
abstract class MemoryWritebackGate {
  const MemoryWritebackGate();

  /// Validate a batch of proposed writes.
  ///
  /// Returns a [WritebackResult] with accepted and rejected writes.
  /// Rejected writes include reasons for rejection.
  Future<WritebackResult> validate(List<ProposedWrite> writes);

  /// Check whether a write to [targetTier] is allowed given the source.
  ///
  /// Draft-to-canon writes are always rejected (tier escalation forbidden).
  /// Canon writes require soul validation.
  bool isTierTransitionAllowed(MemoryTier sourceTier, MemoryTier targetTier);
}

/// Basic in-memory writeback gate for testing and bootstrapping.
///
/// Enforces tier hierarchy rules but delegates soul/canon validation
/// to optional callbacks.
class BasicMemoryWritebackGate extends MemoryWritebackGate {
  const BasicMemoryWritebackGate({this.soulValidator, this.canonKeeper});

  /// Optional soul contract validator. If null, soul validation is skipped.
  final SoulContractValidator? soulValidator;

  /// Optional canon consistency checker. If null, canon checks are skipped.
  final CanonKeeper? canonKeeper;

  @override
  Future<WritebackResult> validate(List<ProposedWrite> writes) async {
    final accepted = <ProposedWrite>[];
    final rejected = <RejectedWrite>[];

    for (final write in writes) {
      final reasons = <String>[];

      // Rule 1: Draft cannot be promoted to canon or character directly.
      if (write.tier == MemoryTier.canon ||
          write.tier == MemoryTier.character) {
        if (soulValidator != null) {
          final violations = soulValidator!(write.content);
          if (violations.isNotEmpty) {
            reasons.add(
              'Soul violation: ${violations.map((v) => v.rule).join(", ")}',
            );
          }
        }
      }

      // Rule 2: Canon writes must pass canon consistency.
      if (write.tier == MemoryTier.canon && canonKeeper != null) {
        final contradictions = canonKeeper!(write);
        if (contradictions.isNotEmpty) {
          reasons.add('Canon contradiction: ${contradictions.join("; ")}');
        }
      }

      if (reasons.isEmpty) {
        accepted.add(write);
      } else {
        rejected.add(RejectedWrite(write: write, reasons: reasons));
      }
    }

    return WritebackResult(accepted: accepted, rejected: rejected);
  }

  @override
  bool isTierTransitionAllowed(MemoryTier sourceTier, MemoryTier targetTier) {
    final sourceIndex = MemoryPolicy.tierOrder.indexOf(sourceTier);
    final targetIndex = MemoryPolicy.tierOrder.indexOf(targetTier);
    // Tier escalation (less authoritative -> more authoritative) is forbidden.
    // Higher index = less authoritative, so target must be >= source.
    return targetIndex >= sourceIndex;
  }
}

/// Callback type for soul contract validation.
typedef SoulContractValidator = List<SoulViolationRef> Function(String content);

/// Callback type for canon consistency checking.
typedef CanonKeeper = List<String> Function(ProposedWrite write);

/// Minimal violation reference for the gate interface.
class SoulViolationRef {
  const SoulViolationRef({required this.rule, this.description = ''});
  final String rule;
  final String description;
}
