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

      mkHome =
        role:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${role.system};
          extraSpecialArgs = { inherit inputs; };
          modules = [
            ./home.nix
            role.module
          ];
        };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      homeConfigurations = nixpkgs.lib.mapAttrs' (
        name: role: nixpkgs.lib.nameValuePair "thom@${name}" (mkHome role)
      ) roles;

      # `nix flake check` builds every role native to the checking machine.
      checks = forAllSystems (
        system:
        nixpkgs.lib.mapAttrs' (name: role: nixpkgs.lib.nameValuePair "home-${name}" (mkHome role).activationPackage) (
          nixpkgs.lib.filterAttrs (_: role: role.system == system) roles
        )
      );

      # Pinned Home Manager CLI, used by bootstrap.sh.
      packages = forAllSystems (system: {
        home-manager = home-manager.packages.${system}.home-manager;
        default = home-manager.packages.${system}.home-manager;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
