# tmux. Ported from dot_tmux.conf. The module always writes its own option
# block, so every value it emits is pinned to tmux's built-in default (what the
# old config got by not setting it). All plugins were commented out; none are
# installed.
{ config, ... }:
{
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    historyLimit = 10000;

    # Pinned tmux built-in defaults.
    baseIndex = 0;
    clock24 = true;
    escapeTime = 10;
    # tmux picks vi keys when $EDITOR contains "vi" (EDITOR=nvim).
    keyMode = "vi";
    mouse = false;
    focusEvents = false;
    aggressiveResize = false;
    # Don't move the socket to $XDG_RUNTIME_DIR via TMUX_TMPDIR.
    secureSocket = false;

    extraConfig = ''
      # Lets run-shell and friends find Nix-installed tools.
      # Doesn't appear to affect shell PATH.
      set-environment -g PATH "$HOME/.local/bin:${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/bin:/usr/bin"

      set -g history-file ~/.tmux/tmux_history

      # resize to smallest _active_ window
      # incompatible with iterm2
      #setw -g aggressive-resize on

      set-option -g allow-passthrough on
      set-option -g set-titles on
      set-option -g set-titles-string '#T'
    '';
  };
}
