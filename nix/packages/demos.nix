# One Nix package per executable dub configuration.
#
# Built via `legacyPackages.buildGameEngineDemo` (buildDubPackage wrapper).
# Graphics demos link SDL3 + wgpu-native + box3d; headless/unit configs drop
# what they do not need. Asset-using demos ship `assets/` and chdir there.
{ lib, ... }:
{
  perSystem =
    { config, ... }:
    let
      inherit (config.legacyPackages) buildGameEngineDemo;

      # (attr name) → builder args
      demos = {
        demo = {
          pname = "game-engine-demo";
          dubConfig = "demo";
          binaryName = "game-engine-demo";
          meta.description = "Clear-screen demo (SDL3 + WGPU)";
        };

        benchmark = {
          pname = "game-engine-benchmark";
          dubConfig = "benchmark";
          binaryName = "game-engine-benchmark";
          meta.description = "3D benchmark — instanced cubes + Box3D";
        };

        benchmark2 = {
          pname = "game-engine-benchmark2";
          dubConfig = "benchmark2";
          binaryName = "game-engine-benchmark2";
          meta.description = "Secondary 3D benchmark configuration";
        };

        game = {
          pname = "crystal-collector";
          dubConfig = "game";
          binaryName = "crystal-collector";
          meta.description = "Crystal Collector gameplay demo";
        };

        showcase = {
          pname = "game-engine-showcase";
          dubConfig = "showcase";
          binaryName = "game-engine-showcase";
          meta.description = "Solar-system showcase (scene graph + materials)";
        };

        editor = {
          pname = "game-engine-editor";
          dubConfig = "editor";
          binaryName = "game-engine-editor";
          withAssets = true;
          meta.description = "Scene editor (gizmos, hierarchy, scene I/O)";
        };

        pbr = {
          pname = "game-engine-pbr";
          dubConfig = "pbr";
          binaryName = "game-engine-pbr";
          withAssets = true;
          meta.description = "PBR + IBL + multi-light shadows demo";
        };

        "marble-run" = {
          pname = "marble-run";
          dubConfig = "marble-run";
          binaryName = "marble-run";
          meta.description = "Marble Run physics demo";
        };

        pong3d = {
          pname = "pong3d";
          dubConfig = "pong3d";
          binaryName = "pong3d";
          meta.description = "Pong 3D physics gameplay demo";
        };

        "test-physics" = {
          pname = "game-engine-test-physics";
          dubConfig = "test-physics";
          binaryName = "game-engine-test-physics";
          withGraphics = false;
          meta.description = "Headless Box3D physics smoke test";
        };

        "test-physics-box3d" = {
          pname = "game-engine-test-physics-box3d";
          dubConfig = "test-physics-box3d";
          binaryName = "game-engine-test-physics-box3d";
          withGraphics = false;
          meta.description = "Headless Box3D API smoke test";
        };

        "gc-benchmark" = {
          pname = "game-engine-gc-benchmark";
          dubConfig = "gc-benchmark";
          binaryName = "game-engine-gc-benchmark";
          withGraphics = false;
          meta.description = "GC pause benchmark (no SDL/WGPU)";
        };

        lint = {
          pname = "game-engine-lint";
          dubConfig = "lint";
          binaryName = "game-engine-lint";
          withGraphics = false;
          meta.description = "Source linter for the game engine";
        };

        "test-scene" = {
          pname = "game-engine-test-scene";
          dubConfig = "test-scene";
          binaryName = "game-engine-test-scene";
          withGraphics = false;
          withAssets = true;
          meta.description = "Scene file load unit test";
        };

        "test-asset" = {
          pname = "game-engine-test-asset";
          dubConfig = "test-asset";
          binaryName = "game-engine-test-asset";
          withGraphics = false;
          withAssets = true;
          meta.description = "Asset file load unit test";
        };
      };
      demoPackages = lib.mapAttrs (_: args: buildGameEngineDemo args) demos;
    in
    {
      packages = demoPackages // {
        # Default flake package: the minimal clear-screen demo.
        default = demoPackages.demo;
      };

      apps = lib.mapAttrs (name: _: {
        type = "app";
        program = lib.getExe demoPackages.${name};
      }) demos;
    };
}
