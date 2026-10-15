{ lib, ... }:
{
  options.thom = {
    container = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this host runs inside an unprivileged container (LXC/Incus,
        Docker, Podman, Apple container). Bubblewrap can't mount a fresh /proc
        there, so Claude Code's sandbox needs enableWeakerNestedSandbox.
      '';
    };
    claude.defaultMode = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Claude Code permissions.defaultMode.";
    };
  };
}
