{
  description = "Flake for nix-darwin configuration";
  
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
  };
}