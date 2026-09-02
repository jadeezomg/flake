{
  host,
  lib,
  pkgs,
  ...
}:
let
  extras = host.extraUsers or [ ];
  tempPasswordUsers = builtins.filter (u: (u.initialPassword or null) != null) extras;
  tempPasswordPairs = map (u: "${u.username}:${u.initialPassword}") tempPasswordUsers;
  mkUser =
    u:
    lib.nameValuePair u.username {
      isNormalUser = true;
      description = u.description or u.fullName or u.username;
      extraGroups = u.extraGroups or [ ];
      shell = u.shell or pkgs.bashInteractive;
      packages = with pkgs; u.packages or [ ];
      # Applies when account is first created.
      initialPassword = u.initialPassword or null;
    };
in
{
  users.users = lib.listToAttrs (map mkUser extras);
}
// lib.optionalAttrs (tempPasswordPairs != [ ]) {
  # Ensure temp passwords are also applied once for already-existing guest users.
  # Marker files prevent resetting password on every boot.
  systemd.services.bootstrap-extra-user-temp-passwords = {
    description = "Bootstrap temporary passwords for extra users";
    wantedBy = [ "multi-user.target" ];
    before = [
      "display-manager.service"
      "greetd.service"
    ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [
      coreutils
      shadow
    ];
    script = ''
      set -eu

      state_dir="/var/lib/bootstrap-extra-user-temp-passwords"
      install -d -m 700 "$state_dir"

      for pair in ${lib.escapeShellArgs tempPasswordPairs}; do
        username="''${pair%%:*}"
        marker="$state_dir/$username.done"
        if [ -e "$marker" ]; then
          continue
        fi

        if ! id "$username" >/dev/null 2>&1; then
          continue
        fi

        echo "$pair" | chpasswd
        touch "$marker"
        chmod 600 "$marker"
      done
    '';
  };
}
