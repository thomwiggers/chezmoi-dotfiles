{
  description = "Thom's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # devbox launcher (darwin only); was a chezmoi external with refreshPeriod 1m
    thom-container = {
      url = "github:thomwiggers/thom-container";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      # One configuration per role. Hosts differ only by OS/arch and whether
      # they run inside a container; nothing in the old chezmoi setup keyed on
      # hostname.
      roles = {
        darwin = {
          system = "aarch64-darwin";
          module = ./hosts/darwin.nix;
        };
        linux = {
          system = "x86_64-linux";
          module = ./hosts/linux.nix;
        };
        linux-arm = {
          system = "aarch64-linux";
          module = ./hosts/linux-arm.nix;
        };
        chroot = {
          system = "x86_64-linux";
          module = ./hosts/chroot.nix;
        };
      };

      # Account names in use; every role is offered for each of them.
      users = [
        "thom"
        "thomwiggers"
      ];

      mkHome =
        user: role:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${role.system};
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./home.nix
            role.module
            (
              { pkgs, ... }:
              {
                home.username = user;
                home.homeDirectory =
                  if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${user}" else "/home/${user}";
              }
            )
          ];
        };

      # [ { name = "<user>@<role>"; value = { user; role; }; } ... ]
      configs = nixpkgs.lib.concatMap (
        user:
        nixpkgs.lib.mapAttrsToList (
          name: role: nixpkgs.lib.nameValuePair "${user}@${name}" { inherit user role; }
        ) roles
      ) users;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      homeConfigurations = nixpkgs.lib.mapAttrs (_: c: mkHome c.user c.role) (
        nixpkgs.lib.listToAttrs configs
      );

      # `nix flake check` builds every configuration native to the checking
      # machine.
      checks = forAllSystems (
        system:
        nixpkgs.lib.listToAttrs (
          map (c: {
            name = "home-" + nixpkgs.lib.replaceStrings [ "@" ] [ "-" ] c.name;
            value = (mkHome c.value.user c.value.role).activationPackage;
          }) (nixpkgs.lib.filter (c: c.value.role.system == system) configs)
        )
      );

      # Pinned Home Manager CLI, used by bootstrap.sh.
      packages = forAllSystems (system: {
        home-manager = home-manager.packages.${system}.home-manager;
        default = home-manager.packages.${system}.home-manager;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
