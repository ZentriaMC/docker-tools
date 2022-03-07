# nix-build ./examples/shadow-setup.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };
  lib = flake.mkLib { inherit pkgs; };

  fhsSetupScript = lib.setupFHSScript {
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

  shadowSetupScript = lib.shadowSetup {
    inherit (pkgs) writeText;
    targetDir = "$out";
  };
in
pkgs.runCommandNoCC "shadow-setup-fhs" { } ''
  ${fhsSetupScript}
  ${shadowSetupScript}
''
