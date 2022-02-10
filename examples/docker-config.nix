# nix-instantiate --eval --strict ./examples/docker-config.nix
let
  flake = builtins.getFlake (toString ./..);
  dockerConfig = flake.lib.dockerConfig;
in
{
  Env = dockerConfig.env {
    TZ = "UTC";
    LANG = "C";
  };

  Volumes = dockerConfig.volumes [
    "/data"
    "/var/lib/zentria"
  ];
}
