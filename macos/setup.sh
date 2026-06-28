#!/usr/bin/env bash
# ============================================================================
# Compatibility shim.
#
# Provisioning now lives in the repo-root setup.sh, which detects the OS and
# dispatches to setup/os/macos.sh (shared helpers in setup/lib/common.sh).
# This shim is kept so existing bootstrap instructions (macos/setup.sh) keep
# working — it just execs the real entry point.
#
# Prerequisites + manual GUI / Privacy & Security steps: see macos/README.md.
# ============================================================================
exec "$(cd "$(dirname "$0")/.." && pwd)/setup.sh" "$@"
