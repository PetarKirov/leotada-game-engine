# Shared builder for game-engine dub configurations.
#
# Wraps nixpkgs `buildDubPackage` with the project plumbing every demo needs:
# in-tree source fileset, empty `nix/dub-lock.json` (no registry deps),
# pkg-config + C libs for ImportC (dub#3085), writable build tree, binary
# install + runtime wrap for shared SDL3/wgpu-native, and a Phobos store-path
# scrub. Callers set `dubConfig` / `binaryName` and optional feature flags.
#
# Exposed as `legacyPackages.buildGameEngineDemo` (same pattern as
# sparkles' `buildSparklesApp`).
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      fs = lib.fileset;
      root = ../..;
      fromRoot = lib.path.append root;

      # Engine sources + tools (lint) + manifests. Headers for Box3D come from
      # packages.box3d via pkg-config, not vendor/.
      src = fs.toSource {
        inherit root;
        fileset = fs.unions [
          (fromRoot "dub.json")
          (fromRoot "dub.selections.json")
          (fs.fileFilter (file: file.hasExt "d" || file.hasExt "c" || file.hasExt "h") (fromRoot "source"))
          (fs.fileFilter (file: file.hasExt "d") (fromRoot "tools"))
        ];
      };

      assets = fs.toSource {
        inherit root;
        fileset = fs.maybeMissing (fromRoot "assets");
      };
    in
    {
      legacyPackages.buildGameEngineDemo = lib.extendMkDerivation {
        constructDrv = pkgs.buildDubPackage;

        # Synthetic args consumed here, not passed to mkDerivation.
        excludeDrvArgNames = [
          "dubConfig"
          "binaryName"
          "withGraphics"
          "withAssets"
        ];

        extendDrvArgs =
          finalAttrs: args:
          let
            dubConfig = args.dubConfig or finalAttrs.pname;
            binaryName = args.binaryName or finalAttrs.pname;
            # Runtime wrap only (SDL/wgpu load). Build always has graphics
            # libs available: some configs set `libs: ["box3d"]` intending to
            # drop SDL/wgpu, but dub still merges package-level `libs`, so the
            # linker may request -lSDL3/-lwgpu_native anyway.
            withGraphics = args.withGraphics or true;
            withAssets = args.withAssets or false;

            compiler = args.compiler or pkgs.ldc;

            # Always provide Box3D (ImportC headers + optional link via .pc)
            # and the graphics stack (see withGraphics note above).
            cLibs = [
              config.packages.box3d
              pkgs.sdl3
              pkgs.wgpu-native
            ];

            runtimeLibPath = lib.makeLibraryPath (
              lib.optionals withGraphics (
                [
                  pkgs.sdl3
                  pkgs.wgpu-native
                  pkgs.vulkan-loader
                ]
                ++ lib.optionals pkgs.stdenv.isLinux [
                  pkgs.wayland
                  pkgs.libx11
                ]
              )
            );

            defaultDisallowed = [
              compiler
            ]
            ++ lib.optionals (compiler ? include) [ compiler.include ]
            ++ [
              pkgs.curl.out
              pkgs.tzdata
            ];
            disallowed = lib.subtractLists (args.buildInputs or [ ]) (
              args.disallowedReferences or defaultDisallowed
            );
            scrubFlags = lib.concatMapStringsSep " " (r: "-t ${r}") disallowed;
          in
          {
            inherit src;
            version = args.version or "0.1.0";

            # No registry dependencies; keep the shared empty lock next to the
            # other nix metadata (matches sparkles' single-lock approach).
            dubLock = args.dubLock or (fromRoot "nix/dub-lock.json");
            compiler = compiler;

            nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [
              pkgs.pkg-config
              pkgs.makeWrapper
            ];

            buildInputs = (args.buildInputs or [ ]) ++ cLibs;

            # Select the dub configuration; release is the buildDubPackage default.
            dubBuildFlags = (args.dubBuildFlags or [ ]) ++ [
              "--config=${dubConfig}"
            ];

            # Unpacked fileset is read-only; dub writes objects into the tree.
            preBuild = args.preBuild or ''chmod -R u+w "$NIX_BUILD_TOP"'';

            installPhase =
              args.installPhase or (
                ''
                  runHook preInstall
                  install -Dm755 ${lib.escapeShellArg binaryName} \
                    $out/bin/${lib.escapeShellArg binaryName}
                ''
                + lib.optionalString withAssets ''
                  mkdir -p $out/share/game-engine
                  cp -a ${assets}/assets $out/share/game-engine/
                ''
                + ''
                  runHook postInstall
                ''
              );

            disallowedReferences = disallowed;

            postFixup =
              (lib.optionalString (disallowed != [ ]) ''
                find "$out" -type f -exec remove-references-to ${scrubFlags} '{}' +
              '')
              + ''
                wrapProgram $out/bin/${lib.escapeShellArg binaryName} \
                  ${lib.optionalString (runtimeLibPath != "") "--prefix LD_LIBRARY_PATH : ${runtimeLibPath}"} \
                  ${lib.optionalString withAssets "--chdir $out/share/game-engine"}
              ''
              + (args.postFixup or "");

            meta = {
              description = args.meta.description or "game-engine dub config '${dubConfig}'";
              mainProgram = binaryName;
              license = lib.licenses.mit;
            }
            // (builtins.removeAttrs (args.meta or { }) [
              "description"
              "mainProgram"
              "license"
            ]);
          };
      };
    };
}
