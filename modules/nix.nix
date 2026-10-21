# User-level nix.conf. Nix itself is installed outside Home Manager (daemon
# install or nix-user-chroot), so write the file directly instead of via
# the `nix` module, which would require and install a Nix package.
{
  xdg.configFile."nix/nix.conf".text = ''
    experimental-features = nix-command flakes
  '';
}
