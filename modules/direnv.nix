# direnv with nix-direnv (cached `use flake`).
_: {
  # Silence direnv's log (errors too); starship's direnv module shows the
  # state instead.
  home.sessionVariables.DIRENV_LOG_FORMAT = "";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # thom-container mounts every project at /project.
    config.whitelist.prefix = [ "/project" ];
  };
}
