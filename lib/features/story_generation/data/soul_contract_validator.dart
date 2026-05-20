import '../domain/contracts/memory_writeback_gate.dart' as gate;
import '../domain/contracts/soul_contract.dart';

class SoulContractValidator {
  const SoulContractValidator(this._contract);

  final SoulContract _contract;

  List<SoulViolation> validate(
    String proposedAction, {
    Map<String, Object?> context = const {},
  }) {
    return _contract.validate(proposedAction, context: context);
  }

  gate.SoulContractValidator asWritebackValidator() {
    return (String content) {
      final violations = _contract.validate(content);
      return [
        for (final v in violations)
          gate.SoulViolationRef(rule: v.rule, description: v.description),
      ];
    };
  }
}
