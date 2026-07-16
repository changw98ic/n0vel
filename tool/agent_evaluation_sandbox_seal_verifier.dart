import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_sandbox_seal_verifier.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('usage: seal-verifier <sqlite-path>');
    exitCode = 64;
    return;
  }
  exitCode = runAgentEvaluationSealVerifierCommand(<String>[
    agentEvaluationSealVerifierArgument,
    arguments.single,
  ])!;
}
