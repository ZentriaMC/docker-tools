{ lib }:

{
  # Turns { TZ = "UTC"; LANG = "C"; } into [ "TZ=UTC", "LANG=C" ]
  env = lib.mapAttrsToList (k: v: "${k}=${toString v}");

  # Turns [ "/var/run/zentria" ] into { "/var/lib/zentria" = { }; }
  volumes = paths: lib.listToAttrs (map (p: { name = p; value = { }; }) paths);
}
