#!/usr/bin/env bash

set -euo pipefail

real_clang="${REAL_CLANG:-$(xcrun --find clang)}"

if [[ $# -gt 0 && ( "${1##*/}" == "clang" || "${1##*/}" == "clang++" ) && -x "$1" ]]; then
  real_clang="$1"
  shift
fi

if [[ ! -x "$real_clang" ]]; then
  echo "Unable to find Xcode clang at $real_clang" >&2
  exit 127
fi

has_verbose=0
has_preprocess=0
has_dump_macros=0
has_c_language=0
has_dev_null=0

for arg in "$@"; do
  case "$arg" in
    -v)
      has_verbose=1
      ;;
    -E)
      has_preprocess=1
      ;;
    -dM)
      has_dump_macros=1
      ;;
    c)
      has_c_language=1
      ;;
    /dev/null)
      has_dev_null=1
      ;;
  esac
done

if [[ $has_verbose -eq 1 &&
      $has_preprocess -eq 1 &&
      $has_dump_macros -eq 1 &&
      $has_c_language -eq 1 &&
      $has_dev_null -eq 1 ]]; then
  args=()
  for arg in "$@"; do
    [[ "$arg" == "-v" ]] && continue
    args+=("$arg")
  done
  exec "$real_clang" "${args[@]}"
fi

exec "$real_clang" "$@"
