#!/bin/bash
# ============================================================================
# Shared provisioning helpers — sourced by setup.sh and every setup/os/*.sh
# module. Not meant to be run directly. Expects LOG_FILE to be set by the
# caller (setup.sh) before sourcing so the log helpers can tee to it.
# ============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG_FILE"; }
err() { echo -e "${RED}[x]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }
section() { echo -e "\n${BLUE}--- $1 ---${NC}\n" | tee -a "$LOG_FILE"; }

# --- Architecture detection ------------------------------------------------
# Normalize uname output into release-artifact form (x64 / arm64). Used by any
# step that downloads architecture-specific binaries (opencode/claude/etc.).
# Empty $ARCH means "unsupported" — downstream steps should skip cleanly.
case "$(uname -m)" in
    x86_64|amd64)  ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)             ARCH="" ;;
esac
if [ -n "$ARCH" ]; then
    log "Detected architecture: $ARCH ($(uname -m))"
else
    warn "Unsupported architecture: $(uname -m) — arch-specific downloads will be skipped"
fi

# start_sudo_keepalive
# Prime the sudo timestamp and refresh it in the background until this script
# exits. Several steps (Homebrew, the Nix installer, nix-darwin, large package
# transactions) run for many minutes, so keep the timestamp warm to avoid a
# mid-run re-prompt. The background loop self-terminates when the parent dies.
start_sudo_keepalive() {
    sudo -v || err "sudo is required — aborting"
    while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

# install_release_binary <name> <url> <dst> [archive_type] [expected_sha256]
#
# Generic "download release artefact, optional sha256-verify, extract if
# archive, move to dst" helper shared by the chezmoi / opencode / claude /
# starship install steps. Per-tool variation (version resolution, checksum
# lookup, arch-string mapping) stays in the caller; this function only owns
# the common download → verify → extract → install pipeline.
#
#   archive_type    "tar.gz" (default) — extract first, find binary inside
#                   "binary"           — single executable, no extraction
#   expected_sha256 optional 64-char hex digest; verified before extract.
#                   Empty means "no checksum available" — the helper warns
#                   loudly so the unverified install is visible in the log.
#
# Returns 0 on success or no-op (binary already on PATH), non-zero on any
# real failure so the caller can decide whether to bail or continue.
install_release_binary() {
    local name="$1"
    local url="$2"
    local dst="$3"
    local archive_type="${4:-tar.gz}"
    local expected_sha256="${5:-}"

    if command -v "$name" >/dev/null 2>&1; then
        warn "$name already on PATH at $(command -v "$name") — skipping"
        return 0
    fi

    local tmp tmpdir bin got
    tmp=$(mktemp)
    log "Downloading $name from $url..."
    if ! curl -fsSL "$url" -o "$tmp"; then
        warn "Download failed: $url — skipping $name"
        rm -f "$tmp"
        return 1
    fi

    if [ -z "$expected_sha256" ]; then
        warn "$name installing without checksum verification (upstream publishes none)"
    else
        if [[ ! "$expected_sha256" =~ ^[a-f0-9]{64}$ ]]; then
            warn "Invalid expected sha256 for $name (got: '${expected_sha256:0:40}') — refusing install"
            rm -f "$tmp"
            return 1
        fi
        got=$(sha256sum "$tmp" | cut -d' ' -f1)
        if [ "$got" != "$expected_sha256" ]; then
            warn "$name checksum mismatch — expected $expected_sha256, got $got — refusing install"
            rm -f "$tmp"
            return 1
        fi
    fi

    mkdir -p "$(dirname "$dst")"

    case "$archive_type" in
        binary)
            chmod +x "$tmp"
            if mv "$tmp" "$dst"; then
                log "$name installed to $dst"
                return 0
            else
                warn "Failed to move $name binary to $dst"
                rm -f "$tmp"
                return 1
            fi
            ;;
        tar.gz)
            tmpdir=$(mktemp -d)
            if ! tar -xzf "$tmp" -C "$tmpdir"; then
                warn "Failed to extract $name archive"
                rm -rf "$tmp" "$tmpdir"
                return 1
            fi
            # Binary usually sits at the archive root, but some projects nest
            # it under a versioned dir — find by name to be safe.
            bin=$(find "$tmpdir" -type f -name "$name" | head -n1)
            if [ -z "$bin" ]; then
                warn "$name binary not found inside archive"
                rm -rf "$tmp" "$tmpdir"
                return 1
            fi
            chmod +x "$bin"
            if mv "$bin" "$dst"; then
                log "$name installed to $dst"
                rm -rf "$tmp" "$tmpdir"
                return 0
            else
                warn "Failed to move $name binary to $dst"
                rm -rf "$tmp" "$tmpdir"
                return 1
            fi
            ;;
        *)
            warn "install_release_binary: unknown archive_type '$archive_type' for $name"
            rm -f "$tmp"
            return 1
            ;;
    esac
}

# apply_chezmoi
# Initialise (if needed) and apply the dotfiles via chezmoi. Two source modes,
# selected by $CHEZMOI_SOURCE_MODE:
#
#   remote — clone + apply straight from GitHub: chezmoi init --apply
#            $GITHUB_USER into ~/.local/share/chezmoi (default). The dotfiles
#            live in their own repo; nothing else needs to be cloned.
#   local  — apply from a local checkout at $CHEZMOI_LOCAL_SOURCE. Useful for
#            testing dotfile changes before pushing them.
#
# Debian installs chezmoi to ~/.local/bin (not yet on PATH during provisioning,
# since the .zshenv that adds it is itself a dotfile chezmoi is about to lay
# down), so resolve the binary explicitly there.
apply_chezmoi() {
    section "Applying dotfiles via chezmoi"

    local cz_bin
    if [ "${IS_DEBIAN:-false}" = true ]; then
        cz_bin="$HOME/.local/bin/chezmoi"
    else
        cz_bin="$(command -v chezmoi || true)"
    fi

    if [ -z "$cz_bin" ] || [ ! -x "$cz_bin" ]; then
        warn "chezmoi not found (looked for: ${cz_bin:-<nothing on PATH>}) — skipping dotfiles apply"
        return 0
    fi

    case "${CHEZMOI_SOURCE_MODE:-remote}" in
        remote)
            log "chezmoi source mode: remote (GitHub: $GITHUB_USER)"
            if [ ! -d "$HOME/.local/share/chezmoi" ]; then
                "$cz_bin" init --apply "$GITHUB_USER"
            else
                log "chezmoi already initialised — running apply"
                "$cz_bin" apply
            fi
            ;;
        local|*)
            log "chezmoi source mode: local ($CHEZMOI_LOCAL_SOURCE)"
            if [ ! -d "$HOME/.local/share/chezmoi" ]; then
                "$cz_bin" init --source "$CHEZMOI_LOCAL_SOURCE"
            else
                log "chezmoi already initialised — skipping init"
            fi
            "$cz_bin" apply --source "$CHEZMOI_LOCAL_SOURCE"
            ;;
    esac
}

# bootstrap_tpm
# Install TPM (Tmux Plugin Manager) and run its plugin install. Prefers the
# brew `tpm` formula's bundled installer (macOS); falls back to git-cloning TPM
# into ~/.tmux/plugins/tpm (Linux). install_plugins is a no-op unless the tmux
# config (applied via chezmoi) actually lists plugins.
bootstrap_tpm() {
    section "Bootstrapping tmux plugins (TPM)"

    local brew_tpm="/opt/homebrew/opt/tpm/share/tpm/bin/install_plugins"
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    local tpm_install

    if [ -x "$brew_tpm" ]; then
        tpm_install="$brew_tpm"
    else
        if [ ! -d "$tpm_dir" ]; then
            git clone https://github.com/tmux-plugins/tpm "$tpm_dir" \
                && log "TPM installed" \
                || warn "Failed to clone TPM"
        else
            warn "TPM already exists at $tpm_dir"
        fi
        tpm_install="$tpm_dir/bin/install_plugins"
    fi

    if [ ! -x "$tpm_install" ]; then
        warn "TPM install_plugins not found at $tpm_install — skipping plugin install"
        return 0
    fi

    if [ -f "$HOME/.config/tmux/tmux.conf" ] || [ -f "$HOME/.tmux.conf" ]; then
        "$tpm_install" 2>>"$LOG_FILE" \
            && log "Tmux plugins installed" \
            || warn "TPM auto-install failed — open tmux and press prefix+I"
    else
        warn "No tmux.conf found — skipping plugin install. Re-run after chezmoi apply."
    fi
}

# copy_wallpapers <dst_dir>
# Copy the repo's top-level wallpaper/ folder contents into <dst_dir>.
# No-op (with a warning) if the source folder is missing. A failed copy warns
# and returns 0 so provisioning continues.
copy_wallpapers() {
    local dst="$1"
    local src="$SETUP_DIR/wallpaper"

    section "Configure wallpapers"
    if [ ! -d "$src" ]; then
        warn "Wallpaper source $src not found — skipping wallpaper copy"
        return 0
    fi
    log "Copying wallpapers from $src to $dst..."
    mkdir -p "$dst"
    if cp -R "$src"/. "$dst"/ 2>>"$LOG_FILE"; then
        log "Wallpapers copied successfully"
    else
        warn "Failed to copy wallpapers from $src — continuing"
    fi
}

# post_install_bat
# bat post-install fix-ups, each guarded so only the relevant one fires:
#   - macOS/repo bat: build the cache so the bundled (catppuccin) theme works.
#   - Debian: the package ships the binary as `batcat`; provide a `bat` symlink.
post_install_bat() {
    if command -v bat >/dev/null 2>&1; then
        bat cache --build && log "bat cache built" || warn "bat cache --build failed"
    elif command -v batcat >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        if [ ! -e "$HOME/.local/bin/bat" ]; then
            ln -s "$(command -v batcat)" "$HOME/.local/bin/bat" \
                && log "Created bat -> batcat symlink"
        else
            warn "bat symlink already present"
        fi
    fi
}
