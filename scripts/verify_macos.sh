#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

arch_name="$(uname -m)"
case "$arch_name" in
  arm64|x86_64)
    ;;
  *)
    echo "Unsupported macOS architecture: $arch_name" >&2
    exit 1
    ;;
esac

echo "== flutter pub get =="
pub_log="$(mktemp)"
set +e
flutter pub get >"$pub_log" 2>&1
pub_status=$?
set -e

if [[ $pub_status -ne 0 ]]; then
  cat "$pub_log"
  rm -f "$pub_log"
  exit "$pub_status"
fi

echo "Dependencies resolved."
rm -f "$pub_log"

echo "== flutter analyze =="
flutter analyze --no-pub

echo "== flutter test =="
flutter test --no-pub -r compact

echo "== verify xcodebuild log filter =="
python3 scripts/test_filter_xcodebuild_test_output.py

echo "== clean release artifacts for xcodebuild test =="
rm -rf build/macos/Build/Products/Release

echo "== generate macOS Flutter project config =="
flutter build macos --debug --config-only --no-pub

echo "== xcodebuild test (platform=macOS,arch=$arch_name) =="
xcode_log="$(mktemp)"
set +e
xcodebuild test \
  -quiet \
  -workspace macos/Runner.xcworkspace \
  -scheme Runner \
  -destination "platform=macOS,arch=$arch_name" \
  >"$xcode_log" 2>&1
xcode_status=$?
set -e

python3 scripts/filter_xcodebuild_test_output.py "$xcode_log"

rm -f "$xcode_log"

if [[ $xcode_status -ne 0 ]]; then
  exit "$xcode_status"
fi

echo "== flutter build macos =="
build_log="$(mktemp)"
set +e
flutter build macos --no-pub >"$build_log" 2>&1
build_status=$?
set -e

python3 scripts/filter_xcodebuild_test_output.py "$build_log"

rm -f "$build_log"

if [[ $build_status -ne 0 ]]; then
  exit "$build_status"
fi
