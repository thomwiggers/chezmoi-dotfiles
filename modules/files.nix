# Files deployed verbatim (no Home Manager module covers them).
{ lib, pkgs, ... }:
{
  home.file = {
    ".zsh/functions.sh".source = ../files/zsh/functions.sh;
    ".zsh/key-bindings.zsh" = {
      source = ../files/zsh/key-bindings.zsh;
      executable = true;
    };
    ".zsh/completions/_package".source = ../files/zsh/completions/_package;

    ".latexmkrc".source = ../files/latexmkrc;

    ".claude/CLAUDE.md".source = ../files/claude/CLAUDE.md;
    ".claude/skills/using-ruff/SKILL.md".source = ../files/claude/skills/using-ruff/SKILL.md;
  };

  # lazy.nvim writes lazy-lock.json and lazyvim.json next to init.lua, so link
  # file by file and keep ~/.config/nvim a real, writable directory.
  xdg.configFile."nvim" = {
    source = ../files/nvim;
    recursive = true;
  };

  # Reference dump of Ghostty's defaults; Ghostty only runs on the Macs.
  xdg.configFile."ghostty/default.config" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = ../files/ghostty/default.config;
  };

  # Apple's container: resolve <name>.devbox for devbox containers.
  xdg.configFile."container/config.toml" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    text = ''
      [dns]
      domain = "devbox"
    '';
  };
}
