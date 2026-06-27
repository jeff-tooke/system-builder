{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";

  users.users.jeff = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "changeme";
    shell = pkgs.zsh;
  };

  environment.pathsToLink = [ "share/foot" ];
  environment.systemPackages = with pkgs; [
    chezmoi
    cmake
    curl
    dunst
    eza
    fastfetch
    gcc
    gnumake
    greetd
    grim
    hyprpaper
    nodejs
    pkg-config
    python3
    ripgrep
    slurp
    starship
    tuigreet
    unzip
    wget
    wl-clipboard
    wofi
    ];

  programs.bat.enable = true;
  programs.firefox.enable = true;
  programs.foot = {
     enable = true;
     theme = "catppuccin-macchiato";
     settings = {
        main = {
	    font = "JetBrainsMono Nerd Font:size=11, monospace=size=11";
	};

	colors = {
	    alpha = "0.80";
	    };
    };
  };
  programs.fzf.enable = true;
  programs.git.enable = true;
  programs.hyprland.enable = true;
  programs.hyprlock.enable = true;
  programs.lazygit.enable = true;
  programs.neovim.enable = true;
  programs.tmux.enable = true;
  programs.waybar.enable = true;
  programs.yazi.enable = true;
  programs.zoxide.enable = true;
  programs.zsh.enable = true;

  fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
  ];

  services.greetd.enable = true;
  services.greetd.settings.default_session = {
     command = "tuigreet --time --remember --cmd start-hyprland";
     user = "jeff";
  };

  system.copySystemConfiguration = true;
  system.stateVersion = "26.05";
}

