# macOS provisioning

A best-effort, scripted bootstrap for a fresh macOS user account. The macOS flow
now lives in `setup/os/macos.sh` and is driven by the unified, cross-platform
entry point at the repo root (`setup.sh`), which detects the OS and dispatches.
Shared helpers live in `setup/lib/common.sh`; the package list is
`setup/package-management/Brewfile`. `macos/setup.sh` is a thin compatibility
shim that execs the root `setup.sh`.

## Prerequisites

- A fresh / clean macOS **user account**.
- Working internet connection.
- This repo cloned to `~/dev/system-builder`:
  ```bash
  git clone https://github.com/<user>/system-builder ~/dev/system-builder
  ```
- Run **as the target user** (not root); the script `sudo`s where needed.

Dotfiles are pulled separately by chezmoi from `github.com/<user>/dotfiles`
during the run — no manual dotfiles checkout needed.

## Run

```bash
~/dev/system-builder/setup.sh
```

(`~/dev/system-builder/macos/setup.sh` still works — it's a shim that execs the above.)

The full run is logged to `~/system-setup-<timestamp>.log`.

## What it does

1. **sudo keep-alive** — primes `sudo -v` and refreshes the timestamp in the
   background so a multi-minute run isn't interrupted by repeated password
   prompts. The background refresher is killed on exit via a trap.
2. **Xcode Command Line Tools** — `xcode-select --install`, then waits.
3. **Homebrew** — non-interactive install (`NONINTERACTIVE=1`) + `shellenv` in
   `~/.zprofile`.
4. **Nix** — official `nixos.org` installer, driven with `--daemon --yes`.
5. **nix-darwin** — `nix run nix-darwin -- switch --flake .` from
   `setup/system-settings`.
6. **Homebrew packages** — `brew bundle` against `setup/package-management/Brewfile`.
7. **chezmoi** — `init --source` (first run) then `apply --source` from the repo.
8. **Tool init** — `bat cache --build`, start the `borders` service, install
   tmux plugins via TPM.

Every step is idempotent: re-running skips anything already installed.

## Known interactive challenges (why it isn't 100% hands-off)

macOS resists full unattended provisioning. Expect to babysit these:

- **Xcode CLI tools dialog** — `xcode-select --install` pops a GUI dialog that
  must be clicked. The script then polls until the tools appear; it cannot click
  the dialog for you.
- **First sudo password prompt** — unavoidable. The keep-alive loop only
  *maintains* the timestamp after you've entered the password once.
- **Nix installer** — interactive by default; `--daemon --yes` makes it
  non-interactive. NOTE: the top-level `README.md` still says "answer **no** to
  Determinate Nix" — that note is **stale** under the `nixos.org` installer
  (which never asks that). Flag for cleanup when the top-level README is next
  touched.
- **nix-darwin first switch** — slow (builds the system closure) and needs
  `sudo`. If it fails, re-run just that step.
- **Cask TCC / Gatekeeper approvals** — apps installed via `brew bundle`
  (Hammerspoon, Karabiner-Elements, Raycast, `corelocationcli`, aerospace) need
  manual approval in **System Settings → Privacy & Security**
  (Accessibility, Input Monitoring, Location Services). Not scriptable.

## Manual post-install steps

These mirror the top-level `README.md` and **must be done by hand**:

- Start **aerospace** from Applications and confirm it's added to Login Items.
- Add **Raycast** and **Hammerspoon** to Login Items.
- Allow the **`corelocationcli`** app in Privacy & Security.
- Enable **Location Services** in System Settings and grant `corelocationcli`
  access.

## Structure note

The macOS body (`setup/os/macos.sh`) is sourced by the root `setup.sh` and
relies on the shared helpers in `setup/lib/common.sh` (`log/warn/err/section`,
`start_sudo_keepalive`, `apply_chezmoi`, `bootstrap_tpm`, `post_install_bat`).
NixOS is the remaining platform not yet folded into the dispatcher — it has a
placeholder module at `setup/os/nixos.sh`.
