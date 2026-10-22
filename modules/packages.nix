# CLI tools, formerly .chezmoidata.toml's Homebrew lists. git, tmux, zsh,
# starship, gh and gpg come from their programs.* modules.
{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;

  # Homebrew's gnu-sed only provided `gsed`; keep BSD sed as `sed` on macOS.
  gsed = pkgs.runCommand "gsed" { } ''
    mkdir -p $out/bin
    ln -s ${lib.getExe pkgs.gnused} $out/bin/gsed
  '';
in
{
  home.packages =
    with pkgs;
    [
      age
      bat
      curl
      dust
      jq
      neovim
      # LazyVim's lang.nix extra: language server and formatter.
      nil
      nixfmt
      python3
      ripgrep
      sops
      uv
      vivid
      wget
      xz
      zstd
    ]
    ++ lib.optionals isDarwin [
      container
      gsed
      # Shadows BSD tar, as Homebrew's gnu-tar libexec/bin on PATH did.
      gnutar
    ]
    ++ lib.optionals isLinux [
      # Claude Code's sandbox; were sudo-installed distro packages.
      bubblewrap
      socat
      # nvim-treesitter compiles parsers; macOS has cc from the Xcode CLT.
      gcc
    ];
}
