{ pkgs }:

rec {
  inherit (pkgs) lib;

  dockerConfig = import ./docker-config.nix { inherit lib; };
  shadow = import ./shadow.nix { inherit lib; };

  # Helper for setting up the base files for managing users and
  # groups, only if such files don't exist already. It is suitable for
  # being used in extraCommands.
  # This is based on dockerTools.shadowSetup, except it does not require
  # runAsRoot
  shadowSetup =
    { runtimeShell ? "/bin/sh"
    , writeText ? null
    , users ? shadow.defaultUsers
    , groups ? shadow.defaultGroups
    , targetDir ? "."
    }:
    let
      script = shadow.setupUsersScriptExtraCommands {
        inherit writeText targetDir groups;

        # Adjust root user shell
        users =
          if (users ? root) then
            let
              users' = users // {
                root = users.root // {
                  shell = runtimeShell;
                };
              };
            in
            users'
          else users;
      };
    in
    ''
      ${script}
      ${pamSetup { inherit targetDir; }}
    '';

  # Sets up stub PAM files
  pamSetup = { targetDir ? "." }: ''
    mkdir -p ${targetDir}/etc/pam.d

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
  '';

  # Symlinks CA certs into place for HTTPS etc. via curl, java and other
  # programs to work.
  symlinkCACerts = { targetDir ? "." }:
    let
      inherit (pkgs) cacert;
    in
    ''
      mkdir -p ${targetDir}/etc/ssl/certs ${targetDir}/etc/pki/tls/certs
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt ${targetDir}/etc/ssl/certs/ca-bundle.crt
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt ${targetDir}/etc/ssl/certs/ca-certificates.crt
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt ${targetDir}/etc/pki/tls/certs/ca-bundle.crt
      ln -s ${cacert.p11kit}/etc/ssl/trust-source ${targetDir}/etc/ssl/trust-source
    '';

  # Builds environment. output is output name of derivation, pkgs is instance of imported nixpkgs, pkgsList is a list of derivations.
  createEnv = { output, pkgsList }: pkgs.buildEnv {
    name = "fhs-${output}";
    extraOutputsToInstall = [ output ];
    pathsToLink = [ "/${output}" ];
    ignoreCollisions = true;
    paths = map (p: lib.getOutput output p) pkgsList;
  };

  # Builds multiple environments by their output name. pkgs is instance of imported nixpkgs.
  setupFHS = { paths ? { "bin" = [ ]; "lib" = [ ]; } }:
    builtins.mapAttrs
      (output: pkgsList: createEnv { inherit output pkgsList; })
      paths;

  # Creates a FHS environment symlink script.
  setupFHSScript = { targetDir ? ".", ... }@args:
    let
      fhsPaths = setupFHS {
        inherit (args) paths;
      };
    in
    toString ([ "mkdir -p \"${targetDir}\";" ] ++ (lib.mapAttrsToList (name: env: "ln -s ${env}/${name} ${targetDir}/${name};") fhsPaths));

}
