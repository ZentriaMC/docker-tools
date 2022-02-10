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
  };
in
pkgs.runCommandNoCC "fhs-linked" { } ''
  mkdir -p $out && cd $out
  ${fhsSetupScript}
''
