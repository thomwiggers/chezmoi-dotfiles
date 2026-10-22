# direnv with nix-direnv (cached `use flake`).
_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
