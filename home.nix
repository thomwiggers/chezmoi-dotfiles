{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./modules/options.nix
    ./modules/nix.nix
    ./modules/files.nix
    ./modules/zsh.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/direnv.nix
    ./modules/secrets.nix
    ./modules/secret-files.nix
    ./modules/ssh.nix
    ./modules/claude.nix
    ./modules/packages.nix
    ./modules/ghostty.nix
    ./modules/scripts.nix
  ];

  # home.username / home.homeDirectory are set per configuration in flake.nix.
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
