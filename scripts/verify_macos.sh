#!/usr/bin/env bash

set -euo pipefail

skip_flutter_analyze=false
skip_flutter_tests=false

usage() {
  printf '%s\n' \
    'Usage: scripts/verify_macos.sh [--skip-flutter-analyze] [--skip-flutter-tests]' \
    '' \
    '  --skip-flutter-analyze  Skip analysis when another CI job owns it.' \
    '  --skip-flutter-tests  Skip the full Flutter suite when another CI job owns it.'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-flutter-analyze)
      skip_flutter_analyze=true
      ;;
    --skip-flutter-tests)
      skip_flutter_tests=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

resolve_flutter_bin() {
  if [[ -n "${FLUTTER_BIN:-}" ]]; then
    echo "$FLUTTER_BIN"
    return
  fi

  local package_config=".dart_tool/package_config.json"
  if [[ -f "$package_config" ]]; then
    local flutter_root
    flutter_root="$(
      python3 - "$package_config" <<'PY'
import json
import sys
import urllib.parse

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        data = json.load(handle)
    root = data.get("flutterRoot")
    if isinstance(root, str):
        if root.startswith("file://"):
            print(urllib.parse.unquote(urllib.parse.urlparse(root).path))
        else:
            print(root)
except Exception:
    pass
PY
    )"

    if [[ -n "$flutter_root" && -x "$flutter_root/bin/flutter" ]]; then
      echo "$flutter_root/bin/flutter"
      return
    fi
  fi

  command -v flutter
}

flutter_cmd="$(resolve_flutter_bin)"
echo "Using Flutter: $flutter_cmd"

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
"$flutter_cmd" pub get >"$pub_log" 2>&1
pub_status=$?
set -e

if [[ $pub_status -ne 0 ]]; then
  cat "$pub_log"
  rm -f "$pub_log"
  exit "$pub_status"
fi

echo "Dependencies resolved."
rm -f "$pub_log"

if [[ "$skip_flutter_analyze" == true ]]; then
  echo "== flutter analyze skipped; owned by Flutter Analyze and Test workflow =="
else
  echo "== flutter analyze =="
  "$flutter_cmd" analyze --no-pub
fi

if [[ "$skip_flutter_tests" == true ]]; then
  echo "== flutter test skipped; owned by Flutter Analyze and Test workflow =="
else
  echo "== flutter test =="
  "$flutter_cmd" test --no-pub -r compact
fi

echo "== verify xcodebuild log filter =="
python3 scripts/test_filter_xcodebuild_test_output.py

echo "== clean release artifacts for xcodebuild test =="
rm -rf build/macos/Build/Products/Release

echo "== generate macOS Flutter project config =="
"$flutter_cmd" build macos --debug --config-only --no-pub

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
"$flutter_cmd" build macos --no-pub >"$build_log" 2>&1
build_status=$?
set -e

python3 scripts/filter_xcodebuild_test_output.py "$build_log"

rm -f "$build_log"

if [[ $build_status -ne 0 ]]; then
  exit "$build_status"
fi
