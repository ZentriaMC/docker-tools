{ lib }:

let
  shadowPermissions = {
    "passwd" = "644";
    "group" = "644";
    "shadow" = "600";
    "gshadow" = "600";
  };

  # Create a flat list of user/group mappings
  groupMemberMap =
    users:
    let
      mappings =
        builtins.foldl'
          (acc: user:
            let
              groups = users.${user}.groups or [ ];
            in
            acc ++ map
              (group: {
                inherit user group;
              })
              groups)
          [ ]
          (lib.attrNames users);
    in
    builtins.foldl'
      (acc: v: acc // {
        ${v.group} = acc.${v.group} or [ ] ++ [ v.user ];
      })
      { }
      mappings;

  # Creates a passwd entry from the user
  userToPasswdEntry =
    name:
    { uid ? 65534
    , gid ? uid
    , password ? "!"
    , home ? "/var/empty"
    , description ? ""
    , shell ? "/sbin/nologin"
    , groups ? [ ]
    }:
    "${name}:x:${toString uid}:${toString gid}:${description}:${home}:${shell}";

  # Creates a shadow entry from the user
  userToShadowEntry =
    name:
    { password ? "!"
    , ...
    }:
    "${name}:!:1::::::";

  # Creates a group entry from the group
  groupToGroupEntry =
    name:
    { gid ? 65534
    , members ? [ ]
    }:
    "${name}:x:${toString gid}:${lib.concatStringsSep "," members}";

  # Creates a gshadow entry from the group
  groupToGshadowEntry =
    name:
    { members ? [ ]
    , ...
    }:
    "${name}:!::${lib.concatStringsSep "," members}";

  attrsToLines = f: data: lib.concatStringsSep "\n"
    ((lib.attrValues (lib.mapAttrs f data)) ++ [ "" ]);
in
rec {
  defaultUsers = {
    root.uid = 0;
    nobody = { };
  };

  defaultGroups = {
    root.gid = 0;
    nogroup = { };
  };

  # Sets up /etc/{passwd,group,shadow} contents. Use with e.g `runCommandNoCC "base-system" ({ ... } // (setupUsers userDetails)) '' ... ''`
  setupUsers =
    { users ? defaultUsers
    , groups ? defaultGroups
    }:
    let
      collectedGroups = groupMemberMap users;
      addCollectedMembers =
        name: group:
        group // {
          members = (group.members or [ ]) ++ (collectedGroups.${name} or [ ]);
        };
      groups' = lib.mapAttrs addCollectedMembers groups;
    in
    {
      passwd = attrsToLines userToPasswdEntry users;
      shadow = attrsToLines userToShadowEntry users;
      group = attrsToLines groupToGroupEntry groups';
      gshadow = attrsToLines groupToGshadowEntry groups';

      passAsFile = [ "passwd" "shadow" "group" "gshadow" ];
      # `cat $passwdPath > $out/etc/passwd` etc.
    };

  # Puts /etc/{passwd,group,shadow} files in place. Useful inside runCommand* derivation with setupUsers
  setupUsersScript = { targetDir ? "$out" }:
    toString ([ "mkdir -p \"${targetDir}/etc\";" ] ++ (lib.mapAttrsToList
      (k: v:
        let
          path = "${targetDir}/etc/${k}";
        in
        "cat $" + k + "Path > \"${path}\"; chmod ${v} \"${path}\";")
      shadowPermissions));

  # Setup users inside buildImage extraCommands script.
  setupUsersScriptExtraCommands = { writeText, targetDir ? ".", ... }@args:
    let
      contents = setupUsers {
        inherit (args) users groups;
      };
      contents' = lib.listToAttrs (map (k: { name = k; value = writeText k contents.${k}; }) contents.passAsFile);
    in
    toString ([ "mkdir -p \"${targetDir}/etc\";" ] ++ (lib.mapAttrsToList
      (k: v:
        let
          path = "${targetDir}/etc/${k}";
          permission = shadowPermissions.${k} or "644";
        in
        "cat ${v} > \"${path}\"; chmod ${permission} \"${path}\";")
      contents'));
}
