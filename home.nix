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
  ];

  home.username = "thom";
  home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/thom" else "/home/thom";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
