# ssh. The old ~/.ssh/config was age-encrypted as a whole. The generic part
# is native here; host blocks that identify machines (addresses, ports,
# users) stay in secrets/ssh_config_private.age, decrypted to
# ~/.ssh/config.private by secrets.nix and pulled in with Include. This repo
# is public and the store is world-readable, so keep it that way.
#
# Rendered order: global options, `Include config.private` (its Host blocks
# set nothing the blocks below do), the specific blocks, then `Host *` last
# (Home Manager always writes the "*" block last). ssh takes the first value
# it sees, so specific blocks must come before the defaults.
{ lib, ... }:
{
  programs.ssh = {
    enable = true;
    # Use the system ssh (keeps macOS keychain/SK provider support).
    package = null;
    enableDefaultConfig = false;
    includes = [ "config.private" ];

    # Written before any Host block.
    extraOptionOverrides = {
      CanonicalizeHostname = "yes";
      CanonicalDomains = "incus ide-nessie.ts.net";
      # For tab completion.
      HashKnownHosts = "no";
    };

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ControlMaster = "auto";
        ControlPersist = "yes";
        ControlPath = "~/.ssh/sockets/%C";
        TCPKeepAlive = "yes";
        ServerAliveInterval = 20;
      };

      # No connection sharing for GitHub.
      "github.com" = {
        ControlPersist = "no";
        ControlMaster = "no";
      };

      # Ephemeral VMs reuse names with different host keys; network is the
      # trust boundary.
      ephemeral = {
        header = "Host *.ide-nessie.ts.net *.incus";
        StrictHostKeyChecking = "no";
        UserKnownHostsFile = "/dev/null";
        LogLevel = "ERROR";
      };

      devbox = {
        header = "Host *.devbox";
        User = "thom";
        StrictHostKeyChecking = "accept-new";
      };
    };
  };

  # ControlPath directory; must be a real 0700 dir.
  home.activation.sshSocketsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.ssh/sockets"
    run chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets"
  '';
}
