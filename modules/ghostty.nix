# Ghostty only runs on the Macs, installed outside Nix.
{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  programs.ghostty = {
    enable = true;
    package = null;
    # .zshrc sources the integration itself (from $GHOSTTY_RESOURCES_DIR).
    enableZshIntegration = false;
    settings = {
      # enable all features
      shell-integration-features = true;
      macos-option-as-alt = false;
    };
  };
}
