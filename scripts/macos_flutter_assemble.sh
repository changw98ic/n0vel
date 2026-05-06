#!/usr/bin/env bash

set -euo pipefail

unset CC CXX CPP CPLUSPLUS OBJCPLUSPLUS OBJCC
unset DRIVERKIT_DEPLOYMENT_TARGET
unset IPHONEOS_DEPLOYMENT_TARGET
unset TVOS_DEPLOYMENT_TARGET
unset WATCHOS_DEPLOYMENT_TARGET
unset XROS_DEPLOYMENT_TARGET

exec "$FLUTTER_ROOT"/packages/flutter_tools/bin/macos_assemble.sh "$@"
