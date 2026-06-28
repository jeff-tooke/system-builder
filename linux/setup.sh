#!/usr/bin/env bash
# ============================================================================
# Compatibility shim.
#
# Provisioning now lives in the repo-root setup.sh, which detects the
# OS/distro and dispatches to setup/os/linux.sh (shared helpers in
# setup/lib/common.sh, package lists in setup/packages/*.txt). This shim is
# kept so existing bootstrap instructions (linux/setup.sh) keep working — it
# just execs the real entry point.
#
# Per-distro prerequisites: see linux/README.md.
# ============================================================================
exec "$(cd "$(dirname "$0")/.." && pwd)/setup.sh" "$@"
