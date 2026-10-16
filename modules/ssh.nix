# ssh. The old ~/.ssh/config was age-encrypted as a whole. The generic part
# is native here; host blocks that identify machines (addresses, ports,
# users) stay in secrets/ssh_config_private.age, decrypted to
# ~/.ssh/config.private by secrets.nix and pulled in with Include. This repo
# is public and the store is world-readable, so keep it that way.
#
# Rendered order: global options, `Include config.private` (its Host blocks
# set nothing the blocks below do), then the blocks below in this order.
# ssh takes the first value it sees, so order matters.
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
      # Not the "*" attribute: Home Manager always writes that one last, which
      # would let the blocks below override it. The old config had it first.
      all = lib.hm.dag.entryAnywhere {
        header = "Host *";
        AddKeysToAgent = "yes";
        ControlMaster = "auto";
        ControlPersist = "yes";
        ControlPath = "~/.ssh/sockets/%C";
        TCPKeepAlive = "yes";
        ServerAliveInterval = 20;
      };

      # As in the old config this comes after `Host *`, so both values are
      # already set by then and this block has no effect.
      "github.com" = lib.hm.dag.entryAfter [ "all" ] {
        ControlPersist = "no";
        ControlMaster = "no";
      };

      # Ephemeral VMs reuse names with different host keys; network is the
      # trust boundary.
      ephemeral = lib.hm.dag.entryAfter [ "github.com" ] {
        header = "Host *.ide-nessie.ts.net *.incus";
        StrictHostKeyChecking = "no";
        UserKnownHostsFile = "/dev/null";
        LogLevel = "ERROR";
      };
    };
  };

  # ControlPath directory; must be a real 0700 dir.
  home.activation.sshSocketsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.ssh/sockets"
    run chmod 700 "$HOME/.ssh" "$HOME/.ssh/sockets"
  '';
}
