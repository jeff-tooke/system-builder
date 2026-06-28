{
  description = "Flake for nix-darwin (macOS) and NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, darwin, ... }:
  let
    configuration = { pkgs, ...}: {
      documentation.enable = false;
      nixpkgs.hostPlatform = "aarch64-darwin";
      nix.settings.experimental-features = "nix-command flakes";
      system.configurationRevision = self.rev or self.dirtyRev or null;
      # Required by current nix-darwin: user-scoped system.defaults (dock,
      # finder, NSGlobalDomain, trackpad in ./modules/darwin) must declare which
      # user owns them. This is the user that runs darwin-rebuild.
      system.primaryUser = "jeff";
      system.stateVersion = 6;
    };

  in
    {
    darwinConfigurations = {
      # System configuration for mac os
      jeffs-Virtual-Machine = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
        };
        modules = [
          configuration
          ./modules/darwin
        ];
      };
    };

    # NixOS system settings — the declarative equivalent of what setup/os/linux.sh
    # does imperatively on Arch/Debian/Fedora. Dotfiles stay with chezmoi (no
    # home-manager), exactly like the macOS flow.
    #
    # A single config serves both arm64 and x86_64: the architecture is taken
    # from `nixpkgs.hostPlatform`, which the machine's hardware-configuration.nix
    # always sets (setup/os/nixos.sh stages the real one in before the rebuild;
    # the committed copy is a placeholder so the import resolves and is tracked).
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      modules = [ ./modules/nixos ];
    };
  };
}