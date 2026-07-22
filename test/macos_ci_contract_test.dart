import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary CI keeps only core smoke and one release build per desktop', () {
    final makefile = File('Makefile').readAsStringSync();
    final macosScript = File('scripts/verify_macos.sh').readAsStringSync();
    final linuxWorkflow = File(
      '.github/workflows/flutter-analyze-test.yml',
    ).readAsStringSync();
    final macosWorkflow = File(
      '.github/workflows/verify-macos.yml',
    ).readAsStringSync();
    final windowsWorkflow = File(
      '.github/workflows/verify-windows.yml',
    ).readAsStringSync();

    expect(makefile, contains('test:\n\tflutter test'));
    expect(makefile, contains('ci-smoke:'));
    for (final testFile in <String>[
      'test/main_test.dart',
      'test/app_initialization_integration_test.dart',
      'test/db_integrity_test.dart',
      'test/macos_ci_contract_test.dart',
    ]) {
      expect(makefile, contains(testFile));
    }
    expect(makefile, isNot(contains('verify-macos-ci:')));
    expect(macosScript, contains(r'"$flutter_cmd" analyze --no-pub'));
    expect(macosScript, contains(r'"$flutter_cmd" test --no-pub -r compact'));

    expect(linuxWorkflow, contains('name: Flutter Smoke Check'));
    expect(linuxWorkflow, contains('flutter analyze --no-pub'));
    expect(linuxWorkflow, contains('run: make ci-smoke'));
    expect(linuxWorkflow, isNot(contains('flutter build linux')));
    expect(linuxWorkflow, isNot(contains('apt-get')));
    for (final path in <String>[
      '".github/workflows/flutter-analyze-test.yml"',
      '".github/workflows/verify-macos.yml"',
      '".github/workflows/verify-windows.yml"',
      '"Makefile"',
      '"analysis_options.yaml"',
      '"assets/**"',
      '"lib/**"',
      '"test/**"',
      '"pubspec.yaml"',
      '"pubspec.lock"',
    ]) {
      expect(
        path.allMatches(linuxWorkflow),
        hasLength(2),
        reason:
            '$path must trigger the Linux smoke gate for push and pull requests.',
      );
    }

    expect(macosWorkflow, contains('workflow_dispatch:'));
    expect(macosWorkflow, contains('flutter pub get'));
    expect(macosWorkflow, contains('flutter build macos --release --no-pub'));
    expect(macosWorkflow, isNot(contains('xcodebuild test')));
    expect(macosWorkflow, isNot(contains('make verify-macos')));
    expect(macosWorkflow, isNot(contains('flutter precache')));
    for (final path in <String>[
      '".github/workflows/verify-macos.yml"',
      '"assets/**"',
      '"lib/**"',
      '"macos/**"',
      '"pubspec.yaml"',
      '"pubspec.lock"',
    ]) {
      expect(path.allMatches(macosWorkflow), hasLength(2));
    }

    expect(windowsWorkflow, contains('workflow_dispatch:'));
    expect(windowsWorkflow, contains('flutter pub get'));
    expect(
      windowsWorkflow,
      contains('flutter build windows --release --no-pub'),
    );
    expect(windowsWorkflow, isNot(contains('flutter analyze')));
    expect(windowsWorkflow, isNot(contains('flutter test')));
    expect(windowsWorkflow, isNot(contains('flutter precache')));
    for (final path in <String>[
      '".github/workflows/verify-windows.yml"',
      '"assets/**"',
      '"lib/**"',
      '"pubspec.yaml"',
      '"pubspec.lock"',
      '"windows/**"',
    ]) {
      expect(path.allMatches(windowsWorkflow), hasLength(2));
    }
  });
}
