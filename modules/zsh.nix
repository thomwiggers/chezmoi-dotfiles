# zsh + starship. Ported from dot_zshenv.tmpl, dot_zprofile.tmpl and
# dot_zshrc.tmpl. Home Manager emits its own blocks at fixed mkOrder slots
# (510 typeset/fpath, 570 completionInit, 910 history, 950 setOptions,
# 1100 aliases); our fragments are slotted around them so the startup
# sequence matches the old .zshrc.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  home.sessionVariables = {
    EDITOR = "nvim";

    DOCKER_BUILDKIT = "1";
    COMPOSE_DOCKER_CLI_BUILD = "1";

    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";

    XZ_DEFAULTS = "-T0";
    ZSTD_CLEVEL = "6";
    ZSTD_NBTHREADS = "0";

    CLICOLOR = "1";
    LSCOLORS = "ExGxBxDxCxEgEdxbxgxcxd";
  }
  // lib.optionalAttrs isDarwin {
    SSH_SK_PROVIDER = "/usr/lib/ssh-keychain.dylib";
    RIP_GRAVEYARD = "$HOME/.Trash";

    HOMEBREW_NO_ENV_HINTS = "true";
    HOMEBREW_BAT = "true";
  };

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh = {
    enable = true;
    # Pin the legacy location (~) instead of the future XDG default.
    dotDir = config.home.homeDirectory;

    envExtra = ''
      typeset -U PATH path
      typeset -U fpath
    ''
    + lib.optionalString isDarwin ''

      # Completions and functions of Homebrew-installed tools, after Nix's.
      fpath=($fpath /opt/homebrew/share/zsh/site-functions(N/))
    ''
    + lib.optionalString (!isDarwin) ''

      # devbox (thom-container): Claude Code token from `devbox
      # --register-claude-token`, for shells the entrypoint didn't start (attach,
      # ssh). Claude Code reads it from the descriptor; the token itself is never
      # in the environment.
      if [[ -r /run/user/$UID/claude-oauth-token ]]; then
          exec 9</run/user/$UID/claude-oauth-token
          export CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR=9
      fi
    '';

    profileExtra = ''
      typeset -U PATH path
    ''
    + lib.optionalString isDarwin ''
      # Changing the PATH variable in .zshenv on MacOS leads to MacOS messing with the order
      path=(
          "/Applications/Docker.app/Contents/Resources/bin"
          $path
      )

      # Homebrew stays usable but isn't managed here. shellenv sets
      # HOMEBREW_PREFIX/CELLAR/REPOSITORY, MANPATH and INFOPATH; it prepends
      # to PATH, so move Homebrew behind everything else for Nix's tools to
      # win (/etc/zshrc's nix-daemon.sh prepends the Nix profile later anyway).
      if [[ -z "$HOMEBREW_PREFIX" && -x /opt/homebrew/bin/brew ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv zsh)"
      fi
      if [[ -n "$HOMEBREW_PREFIX" ]]; then
          path=(''${path:#$HOMEBREW_PREFIX/(bin|sbin)} $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin)
      fi
    ''
    + ''

      if [ -e "$HOME/.cargo/env" ]; then
          source "$HOME/.cargo/env"
      fi

      export PATH
    '';

    autocd = true;
    setOptions = [
      "AUTO_PUSHD" # make cd push to directory stack
      "EXTENDED_GLOB" # enable extended globbing patterns (e.g. ^foo, **/, #)
      "NO_BG_NICE" # don't lower priority of background jobs
      "NO_HUP" # don't kill background jobs when the shell exits
      "NO_LIST_BEEP" # don't beep on ambiguous completions
      "NO_HIST_BEEP" # don't beep when navigating past history bounds
      "NO_BEEP" # disable all beeping globally
      "LOCAL_OPTIONS" # options set inside a function are restored on return
      "LOCAL_TRAPS" # traps set inside a function are restored on return
      "HIST_VERIFY" # show history expansion before executing (don't run immediately)
      "PROMPT_SUBST" # enable parameter/command substitution in prompt strings
      "CORRECT" # suggest corrections for mistyped commands
      "COMPLETE_IN_WORD" # allow tab completion from anywhere within a word, not just the end
      "HIST_REDUCE_BLANKS" # strip superfluous whitespace from history entries
      "MULTIBYTE" # enable multibyte character support (e.g. UTF-8)
      "COMBINING_CHARS" # treat combining characters (e.g. diacritics) as part of the base character
      "COMPLETE_ALIASES" # treat aliases as distinct commands for completion purposes
    ];

    history = {
      size = 10000; # number of commands kept in memory for the current session
      save = 10000; # number of commands written to the history file on disk
      path = "${config.home.homeDirectory}/.zsh_history";
      append = true; # append to the history file instead of overwriting it on exit
      share = true; # share history across all active shell sessions in real time
      ignoreAllDups = true; # remove all older duplicates when a command is added to history
      # Module defaults that the old .zshrc did not enable.
      ignoreDups = false;
      ignoreSpace = false;
    };

    shellAliases = {
      ls = "${if isDarwin then "gls" else "ls"} -h --color=auto";
      ll = "ls -l";
      la = "ls -a";
      l = "ls";
      sl = "ls";

      gdb = "gdb -q"; # don't show version information
      gp = "gp -q"; # quiet on startup
      grep = "grep --color=auto";
      diff = "diff --color=auto";

      # Remapped tools
      cat = "bat";
    };

    # The module's completionInit slot (mkOrder 570) is too early:
    # key-bindings.zsh runs `bindkey -e`, which would drop the widgets
    # compinit binds. As in the old .zshrc, compinit runs last (mkOrder 1450).
    enableCompletion = true;
    completionInit = "";

    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        fpath=(
            "${pkgs.zsh-defer}/share/zsh-defer"
            "$HOME/.zsh/completions"
            $fpath
        )
        autoload -Uz zsh-defer

        source "$HOME/.zsh/functions.sh"

        autoload -Uz compinit
        zstyle ':completion:*' menu select
      '')

      (lib.mkOrder 1000 ''
        if $(type python3 > /dev/null); then
            alias vim=nvim
        fi

        source ~/.zsh/key-bindings.zsh

        zsh-defer source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        if [ -n "$GHOSTTY_RESOURCES_DIR" ]; then
            source "''${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
        fi
      '')

      # Full compinit (with the compaudit security scan) when the dump is
      # missing or over a day old; otherwise skip the scan with -C. The
      # anonymous function's arguments are globbed with bare qualifiers (no
      # EXTENDED_GLOB needed).
      (lib.mkOrder 1450 ''
        # Initialize completion
        () {
            if (( $# )) || [[ ! -e ''${ZDOTDIR:-$HOME}/.zcompdump ]]; then
                # compinit leaves an unchanged dump alone; bump its mtime so
                # the full check runs once a day, not on every start.
                compinit && touch ''${ZDOTDIR:-$HOME}/.zcompdump
            else
                compinit -C
            fi
        } ''${ZDOTDIR:-$HOME}/.zcompdump(N.mh+24)
      '')

      (lib.mkOrder 1500 ''
        [[ -f ~/.cache/ls_colors ]] && export LS_COLORS="$(< ~/.cache/ls_colors)"
      '')
    ];
  };

  # `eval "$(starship init zsh)"` is emitted by the module (mkOrder 1000).
  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      # Inserts a blank line between shell prompts
      add_newline = true;

      format = lib.concatStrings [
        "$username"
        "$hostname"
        "\${env_var.THOM_CONTAINER_PROFILE}"
        "$localip"
        "$shlvl"
        "$directory"
        "$vcsh"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_metrics"
        "$git_status"
        "$docker_context"
        "$package"
        "$python"
        "$rust"
        "$memory_usage"
        "$aws"
        "$direnv"
        "$env_var"
        "$sudo"
        "$cmd_duration"
        "$line_break"
        "$jobs"
        "$battery"
        "$time"
        "$status"
        "$container"
        "$netns"
        "$os"
        "$shell"
        "$character"
      ];

      nodejs.disabled = true;

      direnv.disabled = false;

      # Devbox (thom-container) profile, shown next to the hostname like SSH is
      env_var.THOM_CONTAINER_PROFILE = {
        format = "[📦 $env_value]($style) in ";
        style = "bold blue";
      };
    };
  };

  home.packages = [
    pkgs.zsh-completions
  ]
  ++ lib.optional isDarwin pkgs.coreutils-prefixed;
}
