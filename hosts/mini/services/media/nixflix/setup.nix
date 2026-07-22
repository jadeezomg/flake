{
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./common.nix) mountDeps remoteDirs;
in
{
  systemd.tmpfiles.settings = {
    "10-nixflix" = lib.mkForce {
      "/srv/nixflix".d = {
        mode = "0755";
        user = "root";
        group = "root";
      };
    };
  };

  systemd.services = {
    nixflix-setup-remote-dirs = {
      description = "Create Nixflix directories on mounted Unraid storage";
      after = mountDeps;
      requires = mountDeps;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatMapStringsSep "\n" (
        dir: "${pkgs.coreutils}/bin/install -d -m 0775 -o unraid -g users ${lib.escapeShellArg dir}"
      ) remoteDirs;
    };
  };
}
