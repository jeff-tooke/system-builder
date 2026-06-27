#!/bin/bash
# ============================================================================
# macOS provisioning module — sourced by ../../setup.sh. Not run directly.
#
# Flow: Xcode CLT -> Homebrew -> Nix -> nix-darwin -> brew bundle (Brewfile)
#       -> chezmoi apply -> post-install (bat cache, borders, tmux plugins).
#
# Expects from the caller: SETUP_DIR, LOG_FILE, the log/warn/err/section
# helpers, and apply_chezmoi / bootstrap_tpm / post_install_bat (common.sh).
# sudo was already acquired + kept alive by setup.sh.
#
# Prereqs and the manual GUI / Privacy & Security steps that cannot be scripted
# are documented in macos/README.md.
# ============================================================================

# --- 1. Xcode Command Line Tools -------------------------------------------
# `xcode-select --install` opens a GUI dialog that must be clicked through; it
# cannot be fully scripted on a clean machine. Poll until the tools land.
section "Installing Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools already installed at $(xcode-select -p) — skipping"
else
    log "Triggering Xcode Command Line Tools install (a GUI dialog will appear)..."
    xcode-select --install || true
    log "Waiting for Command Line Tools to finish installing (click through the dialog)..."
    until xcode-select -p >/dev/null 2>&1; do
        sleep 10
    done
    log "Xcode Command Line Tools installed"
fi

# --- 2. Homebrew -----------------------------------------------------------
section "Installing Homebrew"
if command -v brew >/dev/null 2>&1; then
    warn "Homebrew already on PATH at $(command -v brew) — skipping install"
else
    log "Installing Homebrew (non-interactive)..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to the login shell env (guard against duplicate appends so this
    # stays idempotent across re-runs).
    if ! grep -q '/opt/homebrew/bin/brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
        {
            echo
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
        } >> "$HOME/.zprofile"
        log "Appended brew shellenv to ~/.zprofile"
    else
        warn "brew shellenv already present in ~/.zprofile — skipping append"
    fi
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# --- 3. Nix ----------------------------------------------------------------
# Use the official nixos.org installer (the Determinate installer is no longer
# used — see macos/README.md). `--daemon --yes` drives it non-interactively.
section "Installing Nix"
if command -v nix >/dev/null 2>&1 || [ -d /nix ]; then
    warn "Nix already present (nix on PATH or /nix exists) — skipping install"
else
    log "Installing Nix (multi-user daemon, non-interactive)..."
    curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
fi

# Make nix available in this shell for the nix-darwin step below.
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
    warn "nix-daemon.sh not found — nix may not be on PATH for the nix-darwin step"
fi

# --- 4. nix-darwin system settings -----------------------------------------
section "Applying nix-darwin system settings"
if [ -d "$SETUP_DIR/setup/system-settings" ]; then
    # nix-darwin refuses to activate if it would overwrite pre-existing files in
    # /etc that it doesn't manage (the stock macOS /etc/bashrc, /etc/zshrc, etc).
    # It expects them renamed with a .before-nix-darwin suffix; do that for the
    # files it touches so the first switch on a clean machine doesn't abort.
    for f in bashrc zshrc zprofile zshenv bash.bashrc; do
        if [ -e "/etc/$f" ] && [ ! -e "/etc/$f.before-nix-darwin" ]; then
            sudo mv "/etc/$f" "/etc/$f.before-nix-darwin" \
                && log "Renamed /etc/$f -> /etc/$f.before-nix-darwin"
        fi
    done
    (
        cd "$SETUP_DIR/setup/system-settings"
        sudo nix --extra-experimental-features "nix-command flakes" \
            run nix-darwin -- switch --flake .
    ) && log "nix-darwin switch complete" \
       || warn "nix-darwin switch failed — inspect the log and re-run this step"
else
    warn "No $SETUP_DIR/setup/system-settings — skipping nix-darwin switch"
fi

# --- 5. Homebrew packages --------------------------------------------------
section "Installing Homebrew packages (brew bundle)"
BREWFILE="$SETUP_DIR/setup/package-management/Brewfile"
if [ -f "$BREWFILE" ]; then
    brew trust nikitabobko/tap
    brew trust felixkratz/formulae
    brew bundle --file="$BREWFILE" \
        && log "brew bundle complete" \
        || warn "brew bundle reported failures — check the log for individual formulae/casks"
else
    warn "No Brewfile at $BREWFILE — skipping brew bundle"
fi

# --- 6. Apply dotfiles via chezmoi -----------------------------------------
# chezmoi is installed by brew bundle above, so it is on PATH here.
apply_chezmoi

# --- 6b. Wallpapers --------------------------------------------------------
copy_wallpapers "$HOME/Pictures/wallpaper"

# --- 7. Post-installation tool initialisation ------------------------------
section "Initialising tools (bat / borders / tmux plugins)"

# bat: build the cache so the bundled (catppuccin) theme is available.
post_install_bat

# borders: start the window-border service (felixkratz/borders).
if command -v borders >/dev/null 2>&1; then
    brew services start borders \
        && log "borders service started" \
        || warn "Failed to start borders service"
fi

# TPM (Tmux Plugin Manager) ships via the `tpm` brew formula.
bootstrap_tpm

# --- DONE ------------------------------------------------------------------
echo ""
echo "======================================================================="
echo " macOS provisioning complete!"
echo " Log: $LOG_FILE"
echo ""
echo " Manual steps remain (GUI / Privacy & Security) — see macos/README.md."
echo "======================================================================="
