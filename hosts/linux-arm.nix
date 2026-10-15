# aarch64 Linux, e.g. devbox (thom-container) under Apple's container on
# Apple Silicon.
{ ... }:
{
  imports = [ ../modules/linux.nix ];
  thom.container = true;
}
