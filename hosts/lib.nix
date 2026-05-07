# Shared host fragments for NixOS machines. Per-host records live in
# `hosts/<name>/host.nix`; this file only holds common merges and user imports.
let
  userData = import ../data/users/users.nix;

  sharedNixOSUser = userData.users.jadee;
  darwinUser = userData.users.caya-jonas;
  nixosExtraUsers = [userData.users.angelie];

  sharedNixOSHost = {
    username = sharedNixOSUser.username;
    system = "x86_64-linux";
    homeDirectory = "/home/${sharedNixOSUser.username}";
    stateVersion = "26.05";
    extraUsers = nixosExtraUsers;
    /**
    `nix.settings.cores` + half for CARGO_BUILD_JOBS
    */
    buildCores = 6;
  };
in {
  inherit
    userData
    sharedNixOSUser
    darwinUser
    nixosExtraUsers
    sharedNixOSHost
    ;
}
