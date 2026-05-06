{
  config,
  hostData,
  hostKey,
  lib,
  pkgs,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
  extras = host.extraUsers or [];
  username = config.home.username;
  extraUser =
    lib.findFirst (u: (u.username or "") == username) null extras;
  shouldPromptPasswordChange =
    extraUser
    != null
    && (extraUser.promptPasswordChange or false)
    && (extraUser.initialPassword or null) != null;

  stateDir = "${config.xdg.stateHome}/guest-password-reminder";
  markerFile = "${stateDir}/password-changed";

  passwordPromptScript = pkgs.writeShellScript "guest-password-change-prompt" ''
    set +e
    mkdir -p "${stateDir}"

    echo
    echo "Please change your temporary password now."
    echo "Run: passwd"
    echo
    passwd
    rc=$?

    if [ "$rc" -eq 0 ]; then
      touch "${markerFile}"
      echo
      echo "Password changed successfully."
    else
      echo
      echo "Password was not changed. You will be reminded again next login."
    fi

    echo
    printf "Press Enter to close..."
    read -r _
  '';

  launchReminderScript = pkgs.writeShellScript "guest-password-reminder-launcher" ''
    set -eu

    if [ -e "${markerFile}" ]; then
      exit 0
    fi

    if command -v kgx >/dev/null 2>&1; then
      exec kgx --title "Change password" -- "${pkgs.bashInteractive}/bin/bash" -lc "${passwordPromptScript}"
    fi

    if command -v gnome-terminal >/dev/null 2>&1; then
      exec gnome-terminal --title="Change password" -- "${pkgs.bashInteractive}/bin/bash" -lc "${passwordPromptScript}"
    fi

    if command -v xterm >/dev/null 2>&1; then
      exec xterm -T "Change password" -e "${pkgs.bashInteractive}/bin/bash" -lc "${passwordPromptScript}"
    fi
  '';
in
  lib.mkIf shouldPromptPasswordChange {
    systemd.user.services.guest-password-reminder = {
      Unit = {
        Description = "Prompt guest user to change temporary password";
        After = ["graphical-session.target"];
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${launchReminderScript}";
      };
    };
  }
