# age-encrypted files, decrypted into $HOME at activation.
#
# Not sops-nix/agenix: the identity is a post-quantum (mlkem768x25519) age
# key, which needs age >= 1.3, and agenix's Home Manager module relies on a
# systemd user service that nix-user-chroot and containers don't have. The
# ciphertext lands in the Nix store; plaintext only ever exists in $HOME.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.thom.age;
  home = config.home.homeDirectory;

  decryptOne = name: secret: ''
    thomDecrypt ${lib.escapeShellArg "${home}/${secret.target}"} ${secret.mode} ${secret.file}
  '';
in
{
  options.thom.age = {
    identity = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/age/keys.txt";
      description = "age identity used to decrypt secrets (created by bootstrap.sh).";
    };

    secrets = lib.mkOption {
      default = { };
      description = "Encrypted files to decrypt into the home directory.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            file = lib.mkOption {
              type = lib.types.path;
              description = "The .age file in this repository.";
            };
            target = lib.mkOption {
              type = lib.types.str;
              description = "Destination, relative to the home directory.";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0600";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf (cfg.secrets != { }) {
    home.activation.decryptSecrets = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      thomDecrypt() {
        local target="$1" mode="$2" src="$3" tmp
        if [[ -v DRY_RUN ]]; then
          echo "would decrypt $src -> $target"
          return
        fi
        (umask 077 && mkdir -p "$(dirname "$target")")
        tmp=$(umask 077 && mktemp "$target.XXXXXX")
        if ${lib.getExe pkgs.age} --decrypt --identity ${lib.escapeShellArg cfg.identity} --output "$tmp" "$src"; then
          chmod "$mode" "$tmp"
          mv -f "$tmp" "$target"
        else
          rm -f "$tmp"
          errorEcho "Failed to decrypt $src"
        fi
      }

      if [[ ! -r ${lib.escapeShellArg cfg.identity} ]]; then
        warnEcho "age identity ${cfg.identity} not found; skipping secrets (run bootstrap.sh)"
      else
      ${lib.concatStrings (lib.mapAttrsToList decryptOne cfg.secrets)}
      fi
      unset -f thomDecrypt
    '';
  };
}
