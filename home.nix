{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./modules/options.nix
    ./modules/files.nix
    ./modules/zsh.nix
    ./modules/git.nix
    ./modules/tmux.nix
  ];

  home.username = "thom";
  home.homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/thom" else "/home/thom";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
