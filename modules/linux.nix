# Shared by every non-NixOS Linux role.
{ ... }:
{
  targets.genericLinux = {
    enable = true;
    # All Linux hosts are headless; skip the Mesa/GPU driver shim.
    gpu.enable = false;
  };
}
