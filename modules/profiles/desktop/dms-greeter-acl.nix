{
  config,
  host,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  useDmsGreeter = cfg.loginManager == "dms-greeter";
  home = host.homeDirectory;
  flakeRoot = "${home}/.dotfiles/flake";
  dmsConfigDir = "${flakeRoot}/modules/profiles/desktop/dms/config";
  cacheDir = "/var/lib/dms-greeter";
  cacheOwner = {
    user = "greeter";
    group = "greeter";
    mode = "2770";
  };
  runtimeDirs = [
    ".cache"
    ".local"
    ".local/state"
    ".local/share"
    "users"
  ];
  mkCacheTmpfiles = suffix: {
    name = "${cacheDir}/${suffix}";
    value = {
      d = cacheOwner;
      z = cacheOwner;
    };
  };
in
{
  config = lib.mkIf (cfg.enable && useDmsGreeter) {
    # Greeter runs as a separate user; grant read access to the user's DMS config.
    # Equivalent of `dms greeter sync`, which is unavailable on NixOS.
    users.users.${user}.extraGroups = [ "greeter" ];

    # dank-greeter's Nix module only declares the cache root. The greeter binary
    # extracts its embedded quickshell UI under $cacheDir/.cache/... and expects
    # the runtime tree that `dms-greeter sync` normally creates (mode 2770).
    systemd.tmpfiles.settings."11-dms-greeter-runtime" = {
      ${cacheDir}.z = cacheOwner;
    }
    // lib.listToAttrs (map mkCacheTmpfiles runtimeDirs);

    systemd.services.dms-greeter-acl = {
      description = "Prepare DMS greeter home ACLs and cache runtime directories";
      before = [ "greetd.service" ];
      wantedBy = [ "graphical.target" ];
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.acl
        pkgs.coreutils
      ];
      script = ''
        cache=${cacheDir}
        install -d -o greeter -g greeter -m 2770 "$cache"
        for dir in ${lib.concatStringsSep " " runtimeDirs}; do
          install -d -o greeter -g greeter -m 2770 "$cache/$dir"
        done
        chown -R greeter:greeter "$cache/.cache" "$cache/.local" "$cache/users" 2>/dev/null || true

        setfacl -m g:greeter:rx ${home}
        setfacl -m g:greeter:rx ${home}/.config
        setfacl -R -m g:greeter:rX ${home}/.config/DankMaterialShell
        # Live symlinks under DankMaterialShell point into the flake checkout.
        setfacl -m g:greeter:rx ${home}/.dotfiles
        setfacl -m g:greeter:rx ${flakeRoot}
        setfacl -R -m g:greeter:rX ${dmsConfigDir}
      '';
    };

    # greetd's preStart copies config as root; repair runtime ownership again
    # immediately before the greeter session starts.
    systemd.services.greetd.preStart = lib.mkAfter ''
      install -d -o greeter -g greeter -m 2770 \
        ${cacheDir}/.cache \
        ${cacheDir}/.local/state \
        ${cacheDir}/.local/share \
        ${cacheDir}/users
      chown -R greeter:greeter ${cacheDir}/.cache ${cacheDir}/.local ${cacheDir}/users 2>/dev/null || true
    '';
  };
}
