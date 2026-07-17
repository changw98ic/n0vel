import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linux owns shared checks while desktop runners own native builds', () {
    final makefile = File('Makefile').readAsStringSync();
    final macosScript = File('scripts/verify_macos.sh').readAsStringSync();
    final macosWorkflow = File(
      '.github/workflows/verify-macos.yml',
    ).readAsStringSync();
    final linuxWorkflow = File(
      '.github/workflows/flutter-analyze-test.yml',
    ).readAsStringSync();
    final windowsWorkflow = File(
      '.github/workflows/verify-windows.yml',
    ).readAsStringSync();

    expect(linuxWorkflow, contains('flutter analyze --no-pub'));
    expect(linuxWorkflow, contains('flutter test --no-pub -r compact'));
    expect(linuxWorkflow, contains('flutter build linux --release --no-pub'));
    final macosPaths = <String>[
      '".github/workflows/verify-macos.yml"',
      '"Makefile"',
      '"assets/**"',
      '"lib/**"',
      '"macos/**"',
      '"scripts/**"',
      '"pubspec.yaml"',
      '"pubspec.lock"',
    ];
    final windowsPaths = <String>[
      '".github/workflows/verify-windows.yml"',
      '"assets/**"',
      '"lib/**"',
      '"pubspec.yaml"',
      '"pubspec.lock"',
      '"windows/**"',
    ];
    for (final path in macosPaths) {
      expect(macosWorkflow, contains(path));
    }
    for (final path in windowsPaths) {
      expect(windowsWorkflow, contains(path));
    }
    for (final path in <String>{
      ...macosPaths,
      ...windowsPaths,
      '"analysis_options.yaml"',
      '"linux/**"',
      '"test/**"',
    }) {
      expect(
        path.allMatches(linuxWorkflow),
        hasLength(2),
        reason: '$path must trigger Linux on push and pull requests.',
      );
    }

    expect(makefile, contains('verify-macos-ci:'));
    expect(makefile, contains('verify-macos:\n\tbash scripts/verify_macos.sh'));
    expect(
      makefile,
      contains(
        'bash scripts/verify_macos.sh --skip-flutter-analyze --skip-flutter-tests',
      ),
    );
    expect(macosWorkflow, contains('workflow_dispatch:'));
    expect(
      macosWorkflow,
      contains("if: github.event_name != 'workflow_dispatch'"),
    );
    expect(macosWorkflow, contains('run: make verify-macos-ci'));
    expect(
      macosWorkflow,
      contains(
        "if: github.event_name == 'workflow_dispatch'\n        run: make verify-macos",
      ),
    );
    expect(macosScript, contains('--skip-flutter-analyze'));
    expect(macosScript, contains('--skip-flutter-tests'));
    expect(
      macosScript,
      contains(r'if [[ "$skip_flutter_analyze" == true ]]; then'),
    );
    expect(
      macosScript,
      contains(r'if [[ "$skip_flutter_tests" == true ]]; then'),
    );
    expect(macosScript, contains('xcodebuild test'));
    expect(macosScript, contains(r'"$flutter_cmd" build macos --no-pub'));

    expect(windowsWorkflow, contains('workflow_dispatch:'));
    expect(windowsWorkflow, contains('runs-on: windows-latest'));
    expect(
      windowsWorkflow,
      contains('flutter build windows --release --no-pub'),
    );
    expect(windowsWorkflow, isNot(contains('flutter analyze')));
    expect(windowsWorkflow, isNot(contains('flutter test')));
  });

  test('CI mode removes only duplicated Flutter checks', () {
    if (Platform.isWindows) {
      return;
    }

    final temporaryDirectory = Directory.systemTemp.createTempSync(
      'verify_macos_contract_',
    );
    addTearDown(() => temporaryDirectory.deleteSync(recursive: true));

    final binDirectory = Directory(
      '${temporaryDirectory.path}${Platform.pathSeparator}bin',
    )..createSync();
    final logFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}commands.log',
    );
    final fakeFlutter = File(
      '${binDirectory.path}${Platform.pathSeparator}flutter',
    );
    final fakeRm = File('${binDirectory.path}${Platform.pathSeparator}rm');
    final fakeUname = File(
      '${binDirectory.path}${Platform.pathSeparator}uname',
    );
    final fakeXcodebuild = File(
      '${binDirectory.path}${Platform.pathSeparator}xcodebuild',
    );

    fakeFlutter.writeAsStringSync(r'''#!/bin/sh
printf 'flutter %s\n' "$*" >> "$VERIFY_MACOS_LOG"
''');
    fakeRm.writeAsStringSync(r'''#!/bin/sh
for argument in "$@"; do
  if [ "$argument" = 'build/macos/Build/Products/Release' ]; then
    exit 0
  fi
done
exec /bin/rm "$@"
''');
    fakeUname.writeAsStringSync(r'''#!/bin/sh
echo arm64
''');
    fakeXcodebuild.writeAsStringSync(r'''#!/bin/sh
printf 'xcodebuild %s\n' "$*" >> "$VERIFY_MACOS_LOG"
''');
    for (final executable in <File>[
      fakeFlutter,
      fakeRm,
      fakeUname,
      fakeXcodebuild,
    ]) {
      final chmod = Process.runSync('chmod', <String>['+x', executable.path]);
      expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
    }

    String runVerification({required bool ciMode}) {
      logFile.writeAsStringSync('');
      final result = Process.runSync(
        'bash',
        <String>[
          'scripts/verify_macos.sh',
          if (ciMode) '--skip-flutter-analyze',
          if (ciMode) '--skip-flutter-tests',
        ],
        environment: <String, String>{
          ...Platform.environment,
          'FLUTTER_BIN': fakeFlutter.path,
          'PATH': '${binDirectory.path}:${Platform.environment['PATH'] ?? ''}',
          'VERIFY_MACOS_LOG': logFile.path,
        },
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      return logFile.readAsStringSync();
    }

    final defaultCommands = runVerification(ciMode: false);
    expect(defaultCommands, contains('flutter pub get'));
    expect(defaultCommands, contains('flutter analyze --no-pub'));
    expect(defaultCommands, contains('flutter test --no-pub -r compact'));
    expect(
      defaultCommands,
      contains('flutter build macos --debug --config-only --no-pub'),
    );
    expect(defaultCommands, contains('xcodebuild test'));
    expect(defaultCommands, contains('flutter build macos --no-pub'));

    final ciCommands = runVerification(ciMode: true);
    expect(ciCommands, contains('flutter pub get'));
    expect(ciCommands, isNot(contains('flutter analyze --no-pub')));
    expect(ciCommands, isNot(contains('flutter test --no-pub -r compact')));
    expect(
      ciCommands,
      contains('flutter build macos --debug --config-only --no-pub'),
    );
    expect(ciCommands, contains('xcodebuild test'));
    expect(ciCommands, contains('flutter build macos --no-pub'));
  });
}
