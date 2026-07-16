import 'dart:io';

import 'agent_evaluation_release_coordinator_preflight.dart';

void main(List<String> arguments) {
  try {
    if (arguments.length == 1 &&
        arguments.single == '--print-source-tree-hash') {
      stdout.write(
        computeAgentEvaluationReleaseSourceTreeHash(Directory.current),
      );
      return;
    }
    if (arguments.length == 2 &&
        arguments.first == '--print-build-artifact-hash') {
      stdout.write(
        computeAgentEvaluationMacAppBundleHash(Directory(arguments[1])),
      );
      return;
    }
    if (arguments.isNotEmpty) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    validateAgentEvaluationCoordinatorDeployment(Platform.environment);
  } on AgentEvaluationCoordinatorPreflightFailure {
    stderr.writeln('agent evaluation release coordinator preflight failed');
    exitCode = 64;
  }
}
