import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';

void main() {
  test(
    'runs the production-path archive inside the Flutter host',
    () async {
      const encodedOutput = String.fromEnvironment('AGENT_ADVERSARIAL_OUTPUT');
      const encodedWork = String.fromEnvironment('AGENT_ADVERSARIAL_WORK');
      if (encodedOutput.isEmpty || encodedWork.isEmpty) {
        fail('host requires output and work directory dart-defines');
      }
      final output = File(Uri.decodeComponent(encodedOutput)).absolute.path;
      final work = Directory(Uri.decodeComponent(encodedWork)).absolute.path;
      final archive = await AgentAdversarialProductionPathRunner()
          .runAndArchive(workDirectory: Directory(work), outputPath: output);
      expect(archive.evidence, hasLength(50));
      expect(
        AgentAdversarialProductionEvidenceArchive.verifyDiagnosticJsonText(
          File(output).readAsStringSync(),
          authorityDirectory: Directory(work),
        ),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
