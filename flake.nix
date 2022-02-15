{
  description = "Docker tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    lib = {
      shadow = import ./shadow.nix { inherit (nixpkgs) lib; };

      # Helper for setting up the base files for managing users and
      # groups, only if such files don't exist already. It is suitable for
      # being used in extraCommands.
      # This is based on dockerTools.shadowSetup, except it does not require
      # runAsRoot
      shadowSetup = { runtimeShell ? "/bin/sh", targetDir ? "." }: ''
        mkdir -p ${targetDir}/etc/pam.d
        if [[ ! -f ${targetDir}/etc/passwd ]]; then
          echo "root:x:0:0::/root:${runtimeShell}" > ${targetDir}/etc/passwd
          echo "root:!x:::::::" > ${targetDir}/etc/shadow
        fi
        if [[ ! -f ${targetDir}/etc/group ]]; then
          echo "root:x:0:" > ${targetDir}/etc/group
          echo "root:x::" > ${targetDir}/etc/gshadow
        fi
        if [[ ! -f ${targetDir}/etc/pam.d/other ]]; then
          cat > ${targetDir}/etc/pam.d/other <<EOF
        account sufficient pam_unix.so
        auth sufficient pam_rootok.so
        password requisite pam_unix.so nullok sha512
        session required pam_unix.so
        EOF
        fi
        if [[ ! -f ${targetDir}/etc/login.defs ]]; then
          touch ${targetDir}/etc/login.defs
        fi

        chmod 640 ${targetDir}/etc/gshadow
        chmod 640 ${targetDir}/etc/shadow
        chmod 644 ${targetDir}/etc/passwd
        chmod 644 ${targetDir}/etc/group
      '';

      # Symlinks CA certs into place for HTTPS etc. via curl, java and other
      # programs to work.
      symlinkCACerts = { cacert, targetDir ? "." }: ''
        mkdir -p ${targetDir}/etc/ssl/certs ${targetDir}/etc/pki/tls/certs
        ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt ${targetDir}/etc/ssl/certs/ca-bundle.crt
        ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt ${targetDir}/etc/ssl/certs/ca-certificates.crt
        ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt ${targetDir}/etc/pki/tls/certs/ca-bundle.crt
        ln -s ${cacert.p11kit}/etc/ssl/trust-source ${targetDir}/etc/ssl/trust-source
      '';

      # Builds environment. output is output name of derivation, pkgs is instance of imported nixpkgs, pkgsList is a list of derivations.
      createEnv = { output, pkgs, pkgsList }: pkgs.buildEnv {
        name = "fhs-${output}";
        extraOutputsToInstall = [ output ];
        pathsToLink = [ "/${output}" ];
        ignoreCollisions = true;
        paths = map (p: nixpkgs.lib.getOutput output p) pkgsList;
      };

      # Builds multiple environments by their output name. pkgs is instance of imported nixpkgs.
      setupFHS = { pkgs, paths ? { "bin" = [ ]; "lib" = [ ]; } }:
        builtins.mapAttrs
          (output: pkgsList: self.lib.createEnv { inherit output pkgs pkgsList; })
          paths;

      # Creates a FHS environment symlink script.
      setupFHSScript = { pkgs, paths, targetDir ? "." }@args:
        let
          fhsPaths = self.lib.setupFHS args;
        in
        toString (nixpkgs.lib.mapAttrsToList (name: env: "ln -s ${env}/${name} ${targetDir}/${name};") fhsPaths);

      dockerConfig = {
        # Turns { TZ = "UTC"; LANG = "C"; } into [ "TZ=UTC", "LANG=C" ]
        env = envvars: nixpkgs.lib.mapAttrsToList (k: v: "${k}=${toString v}") envvars;

        # Turns [ "/var/run/zentria" ] into { "/var/lib/zentria" = { }; }
        volumes = paths: nixpkgs.lib.listToAttrs (map (p: { name = p; value = { }; }) paths);
      };
    };
  };
}
