# nix-build ./examples/setup-users
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };

  shadow = flake.lib.shadow;

  users = shadow.defaultUsers // {
    mark.uid = 1000;
    game.uid = 2000;
  };

  groups = shadow.defaultGroups // {
    game.gid = 2000;
  };
in
pkgs.runCommandNoCC "shadow" ({ } // shadow.setupUsers { inherit users groups; }) ''
  ${shadow.setupUsersScript { }}
''
