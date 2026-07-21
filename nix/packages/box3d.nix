# PIC static Box3D + headers + pkg-config for ImportC (dub#3085).
#
# Source is fetched at the same commit as `vendor/box3d` (see .gitmodules) so
# `nix build .#box3d` does not require a submodule checkout.
#
# Pattern matches sparkles' C-library integration: one `libs "box3d"` line in
# dub.json resolves both `-lbox3d` and ImportC's `-P-I…` via `box3d.pc`.
# See sparkles/docs/guidelines/importc-c-libraries.md.
{
  perSystem =
    { pkgs, ... }:
    {
      packages.box3d = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "box3d";
        version = "0.1.0-8441b4a";

        src = pkgs.fetchFromGitHub {
          owner = "erincatto";
          repo = "box3d";
          rev = "8441b4a06d6d09dcfb0b0f704df4d847d1437b92";
          hash = "sha256-Bns1GblF+940azkOSfZwJLvt0CeVwR5jG8SsmWGe30g=";
        };

        nativeBuildInputs = [
          pkgs.cmake
          pkgs.ninja
        ];

        cmakeBuildType = "Release";

        cmakeFlags = [
          "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
          "-DBOX3D_SAMPLES=OFF"
          "-DBOX3D_UNIT_TESTS=OFF"
          "-DBOX3D_BENCHMARKS=OFF"
          "-DBOX3D_DOCS=OFF"
        ];

        # Static archive only — PIE-safe for LDC/DMD under Nix.
        dontDisableStatic = true;

        postInstall = ''
                    mkdir -p $out/lib/pkgconfig
                    cat > $out/lib/pkgconfig/box3d.pc <<EOF
          Name: box3d
          Description: Box3D 3D physics engine (static, PIC)
          Version: ${finalAttrs.version}
          Cflags: -I$out/include
          Libs: -L$out/lib -lbox3d -lm
          EOF
        '';

        meta = with pkgs.lib; {
          description = "Box3D physics engine (static PIC + pkg-config for ImportC)";
          homepage = "https://github.com/erincatto/box3d";
          license = licenses.mit;
          platforms = platforms.unix;
        };
      });
    };
}
