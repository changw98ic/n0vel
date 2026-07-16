import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';

void main() {
  final environment = Platform.environment;
  final decision = AgentEvaluationRealProviderEntryGate.legacyDecision(
    entryPoint: 'tool/agent_evaluation_smoke_runner.dart',
    environment: environment,
  );
  stderr.writeln(decision.denialReason);
  exitCode = 64;
}
