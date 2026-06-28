#!/usr/bin/env bash
# ============================================================================
# NixOS provisioning module — sourced by ../../setup.sh. Not run directly.
#
# NixOS is provisioned declaratively: the system layer (packages, services,
# greetd + Hyprland desktop, fonts) lives in the flake at
# setup/system-settings (nixosConfigurations, alongside the macOS darwin
# config). This module's job is to:
#   1. stage the machine's hardware-configuration.nix into the flake,
#   2. run `nixos-rebuild switch --flake` to apply that system config, then
#   3. hand off to chezmoi for the dotfiles + tmux + wallpapers, exactly like
#      every other platform (no home-manager).
#
# It deliberately does NOT call install_release_binary / install_*_release:
# those fetch FHS binaries that don't run on NixOS, so opencode/claude/starship/
# chezmoi come from nixpkgs via the flake instead.
#
# Expects from the caller: SETUP_DIR, LOG_FILE, the log/warn/err/section helpers
# and apply_chezmoi / copy_wallpapers / bootstrap_tpm (common.sh). sudo was
# acquired + kept alive by setup.sh. Prerequisites: see linux/README.md.
# ============================================================================

section "Configuring for NixOS"

FLAKE_DIR="$SETUP_DIR/setup/system-settings"
HW_SRC="/etc/nixos/hardware-configuration.nix"
HW_DST="$FLAKE_DIR/modules/nixos/hardware-configuration.nix"

# One flake config serves both arm64 and x86_64 — the architecture comes from
# nixpkgs.hostPlatform in the machine's hardware-configuration.nix (staged below),
# so there's no per-arch attr to choose.
NIXOS_HOST="nixos"
log "Target flake config: $FLAKE_DIR#$NIXOS_HOST ($(uname -m))"

# --- 1. Stage hardware-configuration.nix -----------------------------------
# The committed copy is a placeholder; overwrite it with this machine's real
# hardware config so the flake (a dirty git tree) picks up the new content.
section "Staging hardware-configuration.nix"
if [ -f "$HW_SRC" ]; then
    cp "$HW_SRC" "$HW_DST" && log "Copied $HW_SRC -> $HW_DST"
else
    warn "$HW_SRC not found — regenerating via nixos-generate-config --show-hardware-config"
    if sudo nixos-generate-config --show-hardware-config | tee "$HW_DST" >/dev/null; then
        log "Wrote fresh hardware config to $HW_DST"
    else
        err "Could not obtain a hardware-configuration.nix — aborting NixOS rebuild"
    fi
fi

# --- 2. Apply the system configuration -------------------------------------
section "Applying NixOS configuration (nixos-rebuild switch --flake)"
# Enable flakes for THIS invocation via NIX_CONFIG (the flake's nix.settings
# only takes effect after the first successful switch). NIX_CONFIG is read by
# the nix evaluation nixos-rebuild runs and works regardless of nixos-rebuild
# variant — unlike `--extra-experimental-features`, which the classic
# nixos-rebuild wrapper does not accept. `sudo VAR=val cmd` sets it for the
# elevated process.
if sudo NIX_CONFIG="experimental-features = nix-command flakes" \
        nixos-rebuild switch --flake "$FLAKE_DIR#$NIXOS_HOST"; then
    log "nixos-rebuild switch complete"
    # /run/current-system/sw/bin is already on PATH; refresh the shell's command
    # cache so newly-installed tools (chezmoi etc.) are found below.
    hash -r 2>/dev/null || true
else
    warn "nixos-rebuild switch failed — inspect the log and re-run this step."
    warn "Continuing to the dotfiles step, but tools from the flake may be missing."
fi

# --- 3. Dotfiles + tmux plugins + wallpapers -------------------------------
# chezmoi is provided by the flake, so it is on PATH after the switch above.
apply_chezmoi
copy_wallpapers "$HOME/.local/share/wallpaper"
bootstrap_tpm

# --- DONE ------------------------------------------------------------------
echo ""
echo "======================================================================="
echo " NixOS provisioning complete!"
echo " Log: $LOG_FILE"
echo ""
echo " Reboot to land on greetd/tuigreet -> Hyprland. The login shell is zsh"
echo " and the dotfiles have been applied via chezmoi."
echo "======================================================================="
