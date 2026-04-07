{dataPath ? ../../data, ...}: let
  dataPathUsers = dataPath + "/users";
  dataPathUserExtras = dataPathUsers + "/extras";
  dataPathUserPreferences = dataPathUsers + "/preferences";
  dataPathHosts = dataPath + "/hosts/hosts.nix";

  # Import user data
  userData =
    if builtins.pathExists (dataPathUsers + "/users.nix")
    then import (dataPathUsers + "/users.nix")
    else {users = {};};

  # Import user preferences (apps/profiles/etc.)
  userPreferences =
    if builtins.pathExists dataPathUserPreferences
    then import dataPathUserPreferences
    else {};

  # Import and pack all user extras data
  userExtras = {
    path = dataPathUserExtras;

    bookmarksData =
      if builtins.pathExists (dataPathUserExtras + "/bookmarks.nix")
      then import (dataPathUserExtras + "/bookmarks.nix")
      else {};

    profilesData =
      if builtins.pathExists (dataPathUserExtras + "/profiles.nix")
      then import (dataPathUserExtras + "/profiles.nix")
      else {};

    appsData =
      if builtins.pathExists (dataPathUserExtras + "/apps.nix")
      then import (dataPathUserExtras + "/apps.nix")
      else {};
  };

  # Import host data
  hostData =
    if builtins.pathExists dataPathHosts
    then import dataPathHosts
    else {hosts = {};};
in {
  inherit
    hostData
    userData
    userPreferences
    userExtras
    ;
}
