# x86_64 Linux without root: Nix runs inside nix-user-chroot with ~/.nix
# bind-mounted on /nix. See bootstrap.sh for how the shell enters it.
{ ... }:
{
  imports = [ ../modules/linux.nix ];
  thom.container = false;
}
