# nix-build ./examples/build-fhs.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };

  fhsSetupScript = (flake.mkLib { inherit pkgs; }).setupFHSScript {
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
  };
in
pkgs.runCommandNoCC "fhs-linked" { } ''
  mkdir -p $out && cd $out
  ${fhsSetupScript}
''
