{
  description = "Docker tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {
    lib = {
      # Helper for setting up the base files for managing users and
      # groups, only if such files don't exist already. It is suitable for
      # being used in extraCommands.
      # This is based on dockerTools.shadowSetup, except it does not require
      # runAsRoot
      shadowSetup = { runtimeShell ? "/bin/sh" }: ''
        mkdir -p etc/pam.d
        if [[ ! -f etc/passwd ]]; then
          echo "root:x:0:0::/root:${runtimeShell}" > etc/passwd
          echo "root:!x:::::::" > etc/shadow
        fi
        if [[ ! -f etc/group ]]; then
          echo "root:x:0:" > etc/group
          echo "root:x::" > etc/gshadow
        fi
        if [[ ! -f etc/pam.d/other ]]; then
          cat > etc/pam.d/other <<EOF
        account sufficient pam_unix.so
        auth sufficient pam_rootok.so
        password requisite pam_unix.so nullok sha512
        session required pam_unix.so
        EOF
        fi
        if [[ ! -f etc/login.defs ]]; then
          touch etc/login.defs
        fi

        chmod 640 etc/gshadow
        chmod 640 etc/shadow
        chmod 644 etc/passwd
        chmod 644 etc/group
      '';

      # Symlinks CA certs into place for HTTPS etc. via curl, java and other
      # programs to work.
      symlinkCACerts = { cacert }: ''
        mkdir -p etc/ssl/certs etc/pki/tls/certs
        ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-bundle.crt
        ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
        ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt etc/pki/tls/certs/ca-bundle.crt
        ln -s ${cacert.p11kit}/etc/ssl/trust-source etc/ssl/trust-source
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
      setupFHSScript = { pkgs, paths }@args:
        let
          fhsPaths = self.lib.setupFHS args;
        in
        toString (nixpkgs.lib.mapAttrsToList (name: env: "ln -s ${env}/${name} ${name};") fhsPaths);
    };
  };
}
