# Dev shell for the game engine: D toolchain + SDL3 + wgpu-native + Box3D.
#
# Goal: `nix develop -c dub build` works without host-installed D/SDL/wgpu.
#
# C libraries follow the sparkles ImportC pattern (dub#3085):
#   packages = [ pkg-config  <lib>  … ]
# dub's `libs "…"` resolves both link flags and ImportC `-P-I…` from `.pc`
# files — no hardcoded include paths or DFLAGS for that purpose.
# See sparkles/docs/guidelines/importc-c-libraries.md.
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (pkgs) lib;
      inherit (config.legacyPackages) d-toolchain;
      box3d = config.packages.box3d;

      envExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") d-toolchain.env
      );

      # Shared libraries that demos load at runtime (wgpu-native has no .pc in
      # nixpkgs; SDL3 does — both still need LD_LIBRARY_PATH for the loader).
      sharedLibs = [
        pkgs.sdl3
        pkgs.wgpu-native
      ];
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.pkg-config
          # C toolchain for DMD/LDC ImportC (`box3d_import.c`).
          pkgs.stdenv.cc
          # Box3D: static .a + headers + box3d.pc (link + ImportC via pkg-config).
          box3d
          # Optional runtime deps for demos that present.
          pkgs.vulkan-loader
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          pkgs.wayland
          pkgs.libx11
        ]
        ++ sharedLibs
        ++ d-toolchain.packages;

        shellHook = ''
          ${envExports}

          # Shared-lib resolution for running demos (wgpu-native / SDL3).
          export LD_LIBRARY_PATH=${lib.makeLibraryPath sharedLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          # Vulkan ICD discovery for pure nix shells. Prefer a host/session
          # list when already set (e.g. NixOS).
          if [ -z "''${VK_ICD_FILENAMES:-}" ] && [ -d ${pkgs.mesa}/share/vulkan/icd.d ]; then
            export VK_ICD_FILENAMES=$(echo ${pkgs.mesa}/share/vulkan/icd.d/*.json | tr ' ' ':')
          fi
        '';
      };
    };
}
