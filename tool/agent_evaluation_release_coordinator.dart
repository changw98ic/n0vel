import 'dart:io';

const _runtimeExecutable =
    'build/macos/Build/Products/Release/'
    'novel_writer.app/Contents/MacOS/novel_writer';
const _supervisorMarker =
    '--novel-writer-agent-evaluation-release-supervisor-v1';

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty) {
    stderr.writeln('invalid release coordinator arguments');
    exitCode = 64;
    return;
  }
  final executable = File(_runtimeExecutable).absolute;
  if (FileSystemEntity.typeSync(executable.path, followLinks: false) !=
      FileSystemEntityType.file) {
    stderr.writeln('release coordinator build is missing');
    exitCode = 66;
    return;
  }
  final process = await Process.start(
    executable.path,
    const <String>[_supervisorMarker],
    workingDirectory: Directory.current.path,
    environment: Platform.environment,
    includeParentEnvironment: false,
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
