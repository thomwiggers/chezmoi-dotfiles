# Files deployed verbatim (no Home Manager module covers them).
{
  config,
  lib,
  pkgs,
  ...
}:
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

  # Apple's container: resolve <name>.devbox for devbox containers. The app
  # rewrites this file, so seed it once instead of linking a read-only store
  # path. Runs before containerSystem, whose `container system start` rewrites
  # the file; a leftover store symlink from the old setup is replaced.
  home.activation.seedContainerConfig = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryBetween [ "containerSystem" ] [ "writeBoundary" ] ''
      f="${config.xdg.configHome}/container/config.toml"
      if [ -L "$f" ] || [ ! -e "$f" ]; then
        run rm -f "$f"
        run mkdir -p "$(dirname "$f")"
        run cp ${pkgs.writeText "container-config.toml" ''
          [dns]
          domain = "devbox"
        ''} "$f"
        run chmod u+w "$f"
      fi
    ''
  );
}
