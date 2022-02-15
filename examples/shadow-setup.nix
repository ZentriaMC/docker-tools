# nix-build ./examples/build-fhs.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };

  fhsSetupScript = flake.lib.setupFHSScript {
    inherit pkgs;
    paths = {
      "bin" = with pkgs; [
        bash
        coreutils
        htop
      ];
      "lib" = with pkgs; [
        ncurses
      ];
    };
    targetDir = "$out";
  };

  shadowSetupScript = flake.lib.shadowSetup {
    inherit (pkgs) writeText;
    targetDir = "$out";
  };
in
pkgs.runCommandNoCC "shadow-setup-fhs" { } ''
  ${fhsSetupScript}
  ${shadowSetupScript}
''
