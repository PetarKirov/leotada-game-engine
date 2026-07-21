{
  nixConfig = {
    extra-substituters = [
      "https://dlang-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "dlang-community.cachix.org-1:eAX1RqX4PjTDPCAp/TvcZP+DYBco2nJBackkAJ2BsDQ="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    dlang-nix = {
      # Keep dlang-nix on its own nixpkgs pin. Following this flake's
      # nixpkgs-unstable breaks binary DMD builds that still need older gcc.
      url = "github:PetarKirov/dlang.nix";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/d-toolchain.nix
        ./nix/packages/box3d.nix
        ./nix/shells/default.nix
      ];
      systems = import inputs.systems;
    };
}
