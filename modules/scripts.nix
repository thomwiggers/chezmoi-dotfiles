# Replacements for chezmoi's run_ scripts and .chezmoiexternal.toml.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  # run_after_generate-ls-colors.sh: rendered at build time, read by .zshrc.
  home.file.".cache/ls_colors".source = pkgs.runCommand "ls_colors" { } ''
    ${lib.getExe pkgs.vivid} generate molokai > $out
  '';

  # devbox launcher for https://github.com/thomwiggers/thom-container (macOS
  # only). Updated with `nix flake update thom-container`.
  home.file.".local/bin/devbox" = lib.mkIf isDarwin {
    source = "${inputs.thom-container}/bin/devbox";
    executable = true;
  };

  # zsh completions for Apple's container
  # (docs/shell-completions.md); ~/.zsh/completions is already on fpath.
  home.file.".zsh/completions/_container" = lib.mkIf isDarwin {
    source = pkgs.runCommand "_container" { } ''
      ${lib.getExe' pkgs.container "container"} --generate-completion-script zsh > $out
    '';
  };

  home.activation = {
    # run_after_nvim_sync.sh: sync lazy.nvim plugins quietly; show the
    # output only if something went wrong.
    # Needs init.lua linked and git/neovim in the profile.
    nvimLazySync =
      lib.hm.dag.entryAfter
        [
          "linkGeneration"
          "installPackages"
        ]
        ''
          if [[ ! -v DRY_RUN ]]; then
            log="${config.xdg.cacheHome}/nvim-lazy-sync.log"
            mkdir -p "$(dirname "$log")"
            # Skip checkout lines: their commit subjects can mention "error".
            if ! PATH="${config.home.profileDirectory}/bin:$PATH" \
                ${lib.getExe pkgs.neovim} --headless "+Lazy! sync" +qa >"$log" 2>&1 ||
              grep -v 'HEAD is now at' "$log" | grep -qiE 'error|failed'; then
              cat "$log" >&2
              warnEcho "nvim plugin sync had problems; log in $log"
            fi
          fi
        '';

    # Files chezmoi used to write where Home Manager now writes elsewhere.
    # Left in place they would shadow (~/.tmux.conf) or duplicate
    # (~/.gitconfig, config.ghostty) the new config.
    retireChezmoiFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for f in "$HOME/.gitconfig" "$HOME/.tmux.conf" "${config.xdg.configHome}/ghostty/config.ghostty"; do
        if [[ -f "$f" && ! -L "$f" ]]; then
          run mv $VERBOSE_ARG "$f" "$f.hm-bak"
        fi
      done
    '';
  }
  // lib.optionalAttrs isDarwin {
    # run_onchange_after_setup-thom-container.sh: start Apple's container
    # system service for devbox. Explicit kernel flag so it doesn't prompt.
    containerSystem = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      container=${lib.getExe' pkgs.container "container"}
      if ! $container system status >/dev/null 2>&1; then
        run $container system start --enable-kernel-install
      fi
    '';
  };
}
