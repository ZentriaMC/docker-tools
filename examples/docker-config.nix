# nix-build ./examples/docker-config.nix
let
  flake = builtins.getFlake (toString ./..);
  pkgs = import flake.inputs.nixpkgs { };

  dockerConfig = flake.lib.dockerConfig;
  config = {
    Env = dockerConfig.env {
      TZ = "UTC";
      LANG = "C";
    };

    Volumes = dockerConfig.volumes [
      "/data"
      "/var/lib/zentria"
    ];
  };
in
pkgs.writeText "docker-config.json" (builtins.toJSON config)
