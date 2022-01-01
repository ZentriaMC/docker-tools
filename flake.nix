{
  description = "Docker tools";

  outputs = { self }: {
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
    };
  };
}
