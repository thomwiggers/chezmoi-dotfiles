# ssh. The old ~/.ssh/config was age-encrypted as a whole. Anything in
# programs.ssh ends up in the world-readable Nix store, so host blocks stay
# in the encrypted file (decrypted to ~/.ssh/config.private by secrets.nix)
# and are pulled in with Include. Non-sensitive blocks can move into
# matchBlocks over time.
{ lib, ... }:
{
  programs.ssh = {
    enable = true;
    # Use the system ssh (keeps macOS keychain/SK provider support).
    package = null;
    enableDefaultConfig = false;
    includes = [ "config.private" ];
  };

  # ControlPath directory used by the private config; must be a real 0700 dir.
  home.activation.sshSocketsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.ssh/sockets"
    run chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets"
  '';
}
