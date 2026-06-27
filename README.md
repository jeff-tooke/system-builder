# system-builder

Cross-platform machine provisioning for macOS, Arch, Debian and Fedora.

This repo handles **system setup** — installing packages, system settings
(nix-darwin on macOS), desktop session plumbing (greetd/Hyprland on Linux),
release-binary CLIs, fonts and wallpapers. It then hands off to
[chezmoi](https://chezmoi.io) to lay down the **dotfiles**, which live in a
separate repo: [`jeff-tooke/dotfiles`](https://github.com/jeff-tooke/dotfiles).

You only need to clone this repo. `setup.sh` runs `chezmoi init --apply
jeff-tooke`, which clones the dotfiles into `~/.local/share/chezmoi` and applies
them — no manual dotfiles checkout required.

## Usage

```bash
git clone https://github.com/jeff-tooke/system-builder.git ~/dev/system-builder
~/dev/system-builder/setup.sh
```

Run as the target user (NOT root); the script sudos when needed. Read the
per-platform prerequisites first — `macos/README.md` (Xcode CLT bootstrap) and
`linux/README.md` (sudo + git, per-distro notes).

## Tested on

All testing to date has been on **ARM (arm64) architecture only** and inside
**virtual machines**, never on physical hardware. Other architectures and
bare-metal installs may work but are unverified.

| OS / Distro | Version              | Architecture     | Environment     |
| ----------- | -------------------- | ---------------- | --------------- |
| Arch Linux  | Rolling (archinstall)| arm64            | Virtual Machine |
| Fedora      | 44                   | arm64            | Virtual Machine |
| Debian      | 13 (Trixie)          | arm64            | Virtual Machine |
| macOS       | Tahoe (26)           | Apple Silicon    | Virtual Machine |

## Layout

```
setup.sh                          OS detection + dispatch entry point
setup/lib/common.sh               shared helpers (logging, sudo, chezmoi, release binaries)
setup/os/{macos,linux,nixos}.sh   per-OS provisioning modules
setup/packages/*.txt              per-distro package manifests (Linux)
setup/package-management/Brewfile macOS packages
setup/system-settings/            nix-darwin flake (macOS system settings)
wallpaper/                        wallpapers copied to ~/.local/share/wallpaper (Linux) / ~/Pictures/wallpaper (macOS)
linux/nixos/                      NixOS configuration.nix reference
```

## chezmoi source modes

`setup.sh` defaults to **remote** — it clones the dotfiles from
`github.com/jeff-tooke/dotfiles`. To test local dotfile changes before pushing:

```bash
CHEZMOI_SOURCE_MODE=local CHEZMOI_LOCAL_SOURCE=~/dotfiles ~/dev/system-builder/setup.sh
```

## Status

This is a personal convenience tool, shared in case it's useful to others.
It's provided **as-is** under the [MIT License](LICENSE) — clone or fork freely.
I'm not actively seeking contributions and may not respond to pull requests,
but issue reports are welcome.
