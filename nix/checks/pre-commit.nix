# Prek (Rust pre-commit) configuration via git-hooks.nix.
# Modelled on sparkles/nix/checks/pre-commit.nix, without hooks that need the
# sparkles `ci` binary or project-specific generators.
{ lib, ... }:
let
  generatedJsonFiles = [
    # Nix Flake lock file
    "flake.lock"

    # Dub lock files
    "dub.selections.json"
    "nix/dub-lock.json"
  ];

  # Hand-authored / engine-owned data we do not want pretty-format-json or
  # prettier to reorder/expand (stable authoring + no asset thrash).
  handFormattedJson = [
    "dub.json"
  ];

  # Scene / model assets — keep engine-authored layout; glTF is JSON-shaped.
  assetDataRegex = "^assets/";

  filesToExcludeRegex =
    files: lib.concatMapStringsSep "|" (entry: "(${lib.escapeRegex entry})") files;
in
{
  perSystem =
    { config, pkgs, ... }:
    {
      # Lightweight shell that only installs hooks (no C/GPU toolchain).
      devShells.pre-commit =
        let
          inherit (config.pre-commit.settings) enabledPackages package configFile;
        in
        pkgs.mkShellNoCC {
          packages = enabledPackages ++ [ package ];
          shellHook = ''
            ln -fvs ${configFile} .pre-commit-config.yaml
            echo "Running Pre-commit checks"
            echo "========================="
          '';
        };

      # `nix fmt` runs prek formatters only (not pure linters).
      formatter =
        let
          inherit (config.pre-commit.settings) package configFile;
          formattingHooks = [
            "nixfmt"
            "prettier"
            "trailing-whitespace"
            "end-of-file-fixer"
            "file-contents-sorter"
            "fix-byte-order-marker"
            "pretty-format-json"
            "mixed-line-ending"
          ];
        in
        pkgs.writeShellApplication {
          name = "game-engine-fmt";
          runtimeInputs = [
            package
            pkgs.gitMinimal
          ];
          text = ''
            hooks=(${lib.concatStringsSep " " formattingHooks})
            if [ "$#" -eq 0 ]; then
              exec prek run --config ${configFile} --all-files "''${hooks[@]}"
            else
              exec prek run --config ${configFile} "''${hooks[@]}" --files "$@"
            fi
          '';
        };

      # impl: https://github.com/cachix/git-hooks.nix
      pre-commit = {
        # Keep `nix flake check` light — hooks run via direnv / `prek run`.
        check.enable = false;

        settings = {
          # https://github.com/j178/prek — https://prek.j178.dev/
          package = pkgs.prek;

          excludes = [ "^.*\\.age$" ];

          hooks = {
            editorconfig-checker.enable = true;

            nixfmt.enable = true;

            prettier = {
              enable = true;
              args = [
                "--check"
                "--list-different=false"
                "--log-level=warn"
                "--ignore-unknown"
                "--write"
              ];
              excludes = builtins.map lib.escapeRegex (generatedJsonFiles ++ handFormattedJson);
            };
          };

          # Prek built-ins: https://prek.j178.dev/builtin/#supported-hooks_1
          rawConfig.repos = [
            {
              repo = "builtin";
              hooks = [
                { id = "trailing-whitespace"; }
                {
                  id = "check-added-large-files";
                  # Prebuilt static archives and screenshots live in-tree.
                  exclude = "^(libs/.*\\.a$|assets/screenshots/)";
                }
                { id = "check-case-conflict"; }
                { id = "check-illegal-windows-names"; }
                { id = "end-of-file-fixer"; }
                { id = "file-contents-sorter"; }
                { id = "fix-byte-order-marker"; }
                { id = "check-json"; }
                { id = "check-json5"; }
                {
                  id = "pretty-format-json";
                  exclude =
                    "(" + filesToExcludeRegex (generatedJsonFiles ++ handFormattedJson) + ")|(${assetDataRegex})";
                }
                { id = "check-toml"; }
                { id = "check-vcs-permalinks"; }
                { id = "check-yaml"; }
                { id = "check-xml"; }
                {
                  id = "mixed-line-ending";
                  args = [ "--fix=lf" ];
                }
                { id = "check-symlinks"; }
                { id = "destroyed-symlinks"; }
                { id = "check-merge-conflict"; }
                { id = "detect-private-key"; }
                { id = "no-commit-to-branch"; }
                { id = "check-shebang-scripts-are-executable"; }
                { id = "check-executables-have-shebangs"; }
              ];
            }
          ];
        };
      };
    };
}
