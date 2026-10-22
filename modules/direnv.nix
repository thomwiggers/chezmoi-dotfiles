# direnv with nix-direnv (cached `use flake`).
_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # thom-container mounts every project at /project.
    config.whitelist.prefix = [ "/project" ];
  };
}
