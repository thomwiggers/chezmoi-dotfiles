# Which encrypted files go where (previously chezmoi encrypted_* sources).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  thom.age.secrets = {
    # Host blocks included from the generated ~/.ssh/config (see ssh.nix).
    ssh-config = {
      file = ../secrets/ssh_config_private.age;
      target = ".ssh/config.private";
    };
    halloy-config = {
      file = ../secrets/halloy_config.toml.age;
      target = ".config/halloy/config.toml";
    };
    halloy-theme = {
      file = ../secrets/halloy_theme_catppucin_light.toml.age;
      target = ".config/halloy/themes/catppucin light.toml";
    };
    senpai = {
      file = ../secrets/senpai.scfg.age;
      target = ".config/senpai/senpai.scfg";
    };
    runitor-hc-key = {
      file = ../secrets/runitor_hc_key.age;
      target = ".config/runitor/hc_key";
    };
  };

  # senpai on macOS looks in ~/Library/Application Support.
  home.file."Library/Application Support/senpai/senpai.scfg" =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
      {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/senpai/senpai.scfg";
      };
}
