# Dev shell for the game engine: D toolchain + SDL3 + wgpu-native.
#
# Goal: `nix develop -c dub build` works without host-installed D/SDL/wgpu.
# Box3D and per-config packages are layered on in later commits.
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

      envExports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") d-toolchain.env
      );

      sharedLibs = [
        pkgs.sdl3
        pkgs.wgpu-native
      ];
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.pkg-config
          pkgs.stdenv.cc
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

          export LD_LIBRARY_PATH=${lib.makeLibraryPath sharedLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

          if [ -z "''${VK_ICD_FILENAMES:-}" ] && [ -d ${pkgs.mesa}/share/vulkan/icd.d ]; then
            export VK_ICD_FILENAMES=$(echo ${pkgs.mesa}/share/vulkan/icd.d/*.json | tr ' ' ':')
          fi
        '';
      };
    };
}
