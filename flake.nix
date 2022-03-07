{
  description = "Docker tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      mkLib = import ./lib.nix;
    in
    {
      inherit mkLib;

      lib = forAllSystems (system: mkLib { pkgs = nixpkgs.legacyPackages.${system}; });
    };
}
