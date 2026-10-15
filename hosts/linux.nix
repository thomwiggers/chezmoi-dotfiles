# x86_64 Linux with a system-wide (daemon) Nix install, e.g. the
# `development` Incus/LXC container.
{ ... }:
{
  imports = [ ../modules/linux.nix ];
  thom.container = true;
}
