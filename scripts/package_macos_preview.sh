#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

flutter_cmd="${FLUTTER_BIN:-flutter}"
arch_name="$(uname -m)"
case "$arch_name" in
  arm64|x86_64)
    ;;
  *)
    echo "Unsupported macOS architecture: $arch_name" >&2
    exit 1
    ;;
esac

echo "Using Flutter: $flutter_cmd"
echo "== flutter pub get =="
"$flutter_cmd" pub get

echo "== flutter build macos --release =="
"$flutter_cmd" build macos --release --no-pub --no-tree-shake-icons

app_path="build/macos/Build/Products/Release/novel_writer.app"
if [[ ! -d "$app_path" ]]; then
  echo "Expected app bundle not found: $app_path" >&2
  exit 1
fi

mkdir -p dist
archive="dist/NovelWriter-macos-${arch_name}-preview.zip"
rm -f "$archive" "$archive.sha256"

echo "== package $archive =="
ditto -c -k --keepParent "$app_path" "$archive"
shasum -a 256 "$archive" | tee "$archive.sha256"

echo "Packaged preview artifact:"
echo "  $archive"
echo "  $archive.sha256"
echo
echo "This archive is unsigned and not notarized. Keep that limitation in release notes."
