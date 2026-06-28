# Prerequisites (must be true BEFORE running this script)

Provisioning is driven by the unified, cross-platform entry point at the repo
root: **`~/dev/system-builder/setup.sh`**. It detects the distro and dispatches
to `setup/os/linux.sh` (shared helpers in `setup/lib/common.sh`; package lists
in `setup/packages/*.txt`). The `linux/setup.sh` path still works — it's a shim
that execs the root script. Dotfiles are pulled separately by chezmoi from
`github.com/jeff-tooke/dotfiles`.

---

## Arch:

A working install booted, with a non-root user that has sudo privileges

Working internet connection

1.  Switch to the root account (use the root password set in archinstall)

```bash
su -
```

2.  Install the packages needed to run this script

```
pacman -Sy --needed sudo git
```

3.  Add existing user to the wheel group

```bash
 usermod -aG wheel <user>
```

4.  Allow members of the wheel group to use sudo.

```bash
   #    Uncomment the line:  %wheel ALL=(ALL:ALL) ALL
   EDITOR=nano visudo
```

5.  Drop back to user, clone system-builder, run the script.

```bash
   exit
   su - <user>             #
   git clone https://github.com/<github-user>/system-builder.git
   ~/system-builder/setup.sh
```

## Debian Trixie:

A working install booted, with a non-root user that has sudo privileges

Working internet connection

1.  Switch to the root account

```bash
su -
```

2.  Install the packages needed to run this script

```
apt update -y && apt install -y sudo git
```

3.  Add existing user to the sudo group

```bash
 usermod -aG sudo <user>
```

4.  Drop back to user, clone system-builder, run the script.

````bash
   exit
   su - <user>             #
   git clone https://github.com/<github-user>/system-builder.git
   ~/system-builder/setup.sh

## Fedora 44:

A working install booted, with a non-root user account; sudo is

Working internet connection

These packages installed via dnf: git

```bash
sudo dnf update -y && sudo dns install git -y
git clone https://github.com/<github-user>/system-builder
~/system-builder/setup.sh
````

## NixOS (26.05):

NixOS is handled declaratively by a flake (`setup/system-settings/`,
`nixosConfigurations`) rather than the imperative apt/pacman/dnf path. The flow
still starts from a normal install so the machine's hardware is detected.

A working install booted, with the normal user created during install (the flake
expects user **`jeff`** — adjust `setup/system-settings/modules/nixos/default.nix`
if yours differs), and a working internet connection.

1.  Confirm the installer generated the hardware config (it normally does):

```bash
ls /etc/nixos/hardware-configuration.nix
```

2.  Clone system-builder and run it. A base NixOS has no `git`, so pull it into
    a temporary `nix-shell` just for the clone:

```bash
nix-shell -p git --run 'git clone https://github.com/<github-user>/system-builder.git ~/dev/system-builder'
~/dev/system-builder/setup.sh
```

`setup.sh` detects NixOS, copies your `hardware-configuration.nix` into the
flake, runs `nixos-rebuild switch --flake setup/system-settings#nixos`, then
applies the chezmoi dotfiles. (One flake config serves both arm64 and x86_64 —
the architecture comes from your hardware config.) Reboot to land on greetd →
Hyprland. `git` is in the package set, so it's installed from then on.

Notes:
- The committed `modules/nixos/hardware-configuration.nix` is a **placeholder**
  that `setup.sh` overwrites with your machine's real one. Don't commit a real
  machine's hardware config back over it.
- Dotfiles stay with chezmoi (no home-manager); the flake is system-only.

# - Run as the target user (NOT root); the script will sudo when needed

# macOS: a fresh user account; Xcode CLI tools + Homebrew will be installed.

# ============================================================================
