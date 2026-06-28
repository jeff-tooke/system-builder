# ============================================================================
# NixOS system module — the declarative equivalent of setup/os/linux.sh.
#
# Scope is the SYSTEM layer only: packages, services, the greetd + Hyprland
# desktop, and fonts — the same environment Arch/Debian/Fedora get from the
# imperative script. User dotfiles are NOT managed here; chezmoi lays them down
# after the rebuild (setup/os/nixos.sh), exactly like every other platform. Do
# not add home-manager — chezmoi is the single dotfiles toolchain.
#
# Design rule: tools whose CONFIG comes from the chezmoi dotfiles are installed
# as plain packages (not programs.*), so NixOS doesn't write competing system
# config and the result matches the other distros. programs.*/services.* are
# reserved for genuine system-level wiring (login shell, compositor, PAM,
# display manager, portals).
#
# The package set is kept in step with setup/packages/common.txt + the per-distro
# manifests + the release-binary CLIs (opencode/claude/starship/chezmoi) — but
# those CLIs come from nixpkgs here, because the FHS binaries
# install_release_binary fetches do not run on NixOS.
# ============================================================================
{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Flakes are the source of truth; enable them for subsequent rebuilds. (The
  # FIRST switch is run with --extra-experimental-features by setup/os/nixos.sh,
  # since this only takes effect after it is applied.)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # claude-code and bitwarden are unfree.
  nixpkgs.config.allowUnfree = true;

  # --- Boot ------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- Networking / locale ---------------------------------------------------
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";

  # --- User ------------------------------------------------------------------
  users.users.jeff = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  # --- Packages --------------------------------------------------------------
  # Plain packages: shell integration + config (starship/zoxide/fzf/bat/git/
  # nvim/tmux/foot/waybar/...) all come from the chezmoi dotfiles, matching the
  # other distros — so no programs.*-with-init here, to avoid double config.
  environment.systemPackages = with pkgs; [
    # CLI baseline (common.txt + per-distro)
    bat
    btop
    chezmoi
    curl
    eza
    fastfetch
    fd
    foot
    fzf
    git
    gnupg
    jq
    k9s
    kitty
    lazydocker
    lazygit
    neovim
    ripgrep
    starship
    tmux
    unzip
    waybar
    wget
    zoxide
    # AI CLIs (release-binary installs on other distros -> nixpkgs here)
    claude-code
    # Build tooling
    cmake
    gcc
    gnumake
    nodejs
    pkg-config
    podman-compose
    python3
    # Wayland / Hyprland desktop bits
    dunst
    grim
    hypridle
    hyprpaper
    slurp
    wl-clipboard
    wofi
    # Cursor theme. NixOS has no default, so Hyprland shows its fallback logo
    # cursor; the other distros get Adwaita implicitly via the GTK/desktop stack.
    # The hypr dotfiles only set the cursor SIZE, so the theme must come from here.
    adwaita-icon-theme
    # No GUI apps installed by default. A browser (zen) and bitwarden are
    # user-scope flatpaks on the other distros; neither has a clean nixpkgs
    # path here (bitwarden's bundled Electron is currently flagged insecure),
    # so they're left for a community flake later. To add bitwarden:
    #   nixpkgs.config.permittedInsecurePackages = [ "electron-<ver>" ];
    # then add `bitwarden-desktop` to this list.
  ]
  # opencode isn't reliably in nixpkgs — include it only if present, otherwise
  # skip cleanly (add via a community flake later if wanted).
  ++ lib.optional (pkgs ? opencode) pkgs.opencode;

  # --- System-level program/service wiring -----------------------------------
  # zsh as a system shell (required for users.users.jeff.shell = pkgs.zsh) plus
  # the plugins — enabled at the NixOS level rather than sourced from a hard-coded
  # distro path in the dotfiles (which wouldn't exist under /nix/store). The
  # dotfiles should not double-source these on NixOS.
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # File manager (pulls in gvfs/tumbler for mounting + thumbnails).
  programs.thunar.enable = true;

  # Hyprland compositor + hyprlock PAM wiring. withUWSM enables uwsm (Universal
  # Wayland Session Manager); greetd launches Hyprland through it via
  # `uwsm start hyprland.desktop` below, matching the other distros and removing
  # Hyprland's "launched without a session manager" warning. (Enabling uwsm also
  # switches dbus to dbus-broker, uwsm's recommended default.)
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  programs.hyprlock.enable = true;
  security.polkit.enable = true;
  xdg.portal.enable = true; # portal-hyprland comes via programs.hyprland

  # Default cursor theme for the Wayland session (pairs with adwaita-icon-theme
  # above). The hypr dotfiles set only XCURSOR_SIZE; without a theme NixOS falls
  # back to Hyprland's logo cursor.
  environment.variables.XCURSOR_THEME = "Adwaita";

  # --- Fonts -----------------------------------------------------------------
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg
    nerd-fonts.symbols-only
    noto-fonts
  ];

  # --- Services --------------------------------------------------------------
  virtualisation.podman.enable = true;
  services.openssh.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd 'uwsm start hyprland.desktop'";
      user = "greeter";
    };
  };

  system.stateVersion = "26.05";
}
