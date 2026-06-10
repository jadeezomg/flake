{
  lib,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
  homeDir = host.homeDirectory or "/Users/${user}";

  xdgVars = {
    XDG_CONFIG_HOME = "${homeDir}/.config";
    XDG_CACHE_HOME = "${homeDir}/.cache";
    XDG_DATA_HOME = "${homeDir}/.local/share";
    XDG_STATE_HOME = "${homeDir}/.local/state";
    XDG_BIN_HOME = "${homeDir}/.local/bin";
  };

  setenvCommands =
    lib.concatStringsSep " && "
    (lib.mapAttrsToList (k: v: "launchctl setenv ${k} ${lib.escapeShellArg v}") xdgVars);
in {
  nix.enable = false;
  system.primaryUser = user;
  users.users.${user} = {
    name = user;
    home = homeDir;
    shell = pkgs.nushell;
  };

  # home/darwin/default.nix sets xdg.enable = true so home-manager places
  # configs under ~/.config. macOS/launchd doesn't export XDG_* by default,
  # so shells launched outside a zsh chain (nushell as login shell, bash/fish
  # spawned from a terminal app) miss their config dir entirely — nu falls
  # back to ~/Library/Application Support/nushell and runs with stock defaults.
  #
  # `launchd.user.envVariables` only fires `launchctl setenv` from the
  # activation script (lost on reboot). A LaunchAgent with RunAtLoad re-runs
  # the setenv at every user login so the vars survive reboot.
  launchd.user.envVariables = xdgVars;

  launchd.user.agents.xdg-env = {
    serviceConfig = {
      Label = "org.nix-community.xdg-env";
      ProgramArguments = ["/bin/sh" "-c" setenvCommands];
      RunAtLoad = true;
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;
  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
    Defaults env_keep += "TERMINFO TERMINFO_DIRS"
    Defaults env_keep += "LANG LANGUAGE LC_*"
    Defaults timestamp_timeout=15
  '';

  services.tailscale.enable = true;

  # Homebrew (work profile) lives in modules/profiles/work/darwin.nix.
}
