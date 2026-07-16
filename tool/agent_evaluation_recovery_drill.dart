import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_migration_recovery_drill.dart';

void main(List<String> args) {
  final root = Directory(
    args.isEmpty ? '.omx/evidence/evaluation-recovery-drill' : args.single,
  );
  final report = AgentEvaluationMigrationRecoveryDrill.run(
    workingDirectory: root,
  );
  final output = <String, Object?>{
    ...report.toJson(),
    'reportHash': report.reportHash,
  };
  final encoded = AgentEvaluationHashes.canonicalJson(output);
  root.createSync(recursive: true);
  File('${root.path}/report.json').writeAsStringSync(encoded, flush: true);
  stdout.writeln(encoded);
  if (!report.passed) exitCode = 1;
}
