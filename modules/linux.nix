# Shared by every non-NixOS Linux role.
{ config, pkgs, ... }:
{
  targets.genericLinux = {
    enable = true;
    # All Linux hosts are headless; skip the Mesa/GPU driver shim.
    gpu.enable = false;
  };

  # Sessions come from Ghostty (TERM=xterm-ghostty), whose terminfo Linux
  # hosts don't ship; genericLinux's `export TERM="$TERM"` then fails with
  # "can't find terminal definition". The trailing empty entry keeps ncurses'
  # compiled-in search path (and ~/.terminfo is always searched first).
  home.packages = [ pkgs.ghostty.terminfo ];
  home.sessionVariables.TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:$TERMINFO_DIRS";
}
