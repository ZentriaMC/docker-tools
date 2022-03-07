# nix-build ./examples/setup-users.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };

  shadow = (flake.mkLib { inherit pkgs; }).shadow;

  users = shadow.defaultUsers // {
    mark.uid = 1000;
    game.uid = 2000;
    darwin = {
      uid = 3000;
      groups = [ "dummy" ];
    };
  };

  groups = shadow.defaultGroups // {
    game.gid = 2000;
    dummy.gid = 3000;
  };
in
pkgs.runCommandNoCC "shadow" ({ } // shadow.setupUsers { inherit users groups; }) ''
  ${shadow.setupUsersScript { }}
''
