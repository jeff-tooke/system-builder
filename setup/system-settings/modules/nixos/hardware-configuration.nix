# ============================================================================
# PLACEHOLDER hardware-configuration.nix — NOT for any real machine.
#
# This file is overwritten by setup/os/nixos.sh at provision time with the
# target's actual /etc/nixos/hardware-configuration.nix (disk UUIDs, kernel
# modules, filesystems, host platform — all machine-specific). It is committed
# only so the flake's `imports = [ ./hardware-configuration.nix ]` resolves and
# the file is git-tracked: flakes ignore untracked files, but a *modified*
# tracked file in a dirty working tree IS picked up, which is how nixos.sh's
# overwrite takes effect without a commit.
#
# Do NOT commit a machine's real hardware config back over this placeholder.
# ============================================================================
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Dummy values so the module evaluates if someone inspects the flake before
  # provisioning. mkDefault lets the real config (and ./default.nix) win.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
