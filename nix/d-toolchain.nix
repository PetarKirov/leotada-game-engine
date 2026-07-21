# The project's D toolchain, as a flake-parts module.
#
# For each system it:
#
#   1. Applies a nixpkgs overlay that replaces `dmd` and `dub` with the
#      project-pinned variants from dlang-nix (`_module.args.pkgs`), so every
#      consumer resolves the same toolchain.
#
#   2. Exports dev-shell metadata under `legacyPackages.d-toolchain` for the
#      shell module to consume.
{ inputs, ... }:
{
  perSystem =
    {
      system,
      inputs',
      pkgs,
      ...
    }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            # Prefer dlang-nix pins for dmd/dub so the shell tracks upstream
            # D releases independently of nixpkgs lag.
            dmd = inputs'.dlang-nix.packages.dmd-2_112_1;
            dub = inputs'.dlang-nix.packages.dub;
          })
        ];
      };

      legacyPackages.d-toolchain =
        let
          inherit (pkgs) lib;
          inherit (pkgs.stdenv) isx86_64;
        in
        {
          packages = [
            pkgs.ldc
            pkgs.dub
            pkgs.dtools
          ]
          ++ lib.optionals isx86_64 [
            # Official DMD reference compiler (x86_64 only in dlang-nix binaries).
            pkgs.dmd
          ];

          env = { };
        };
    };
}
