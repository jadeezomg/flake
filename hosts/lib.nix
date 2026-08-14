let
  userData = import ../data/users/users.nix;

  sharedNixOSUser = userData.users.jadee;
  darwinUser = userData.users.caya-jonas;
  nixosExtraUsers = [ userData.users.angelie ];

  sharedNixOSHost = {
    inherit (sharedNixOSUser) username;
    system = "x86_64-linux";
    homeDirectory = "/home/${sharedNixOSUser.username}";
    stateVersion = "26.05";
    hostClass = "workstation";
    extraUsers = nixosExtraUsers;
    # Used for nix.settings.cores and half-sized CARGO_BUILD_JOBS.
    buildCores = 6;
  };
in
{
  inherit
    userData
    sharedNixOSUser
    darwinUser
    nixosExtraUsers
    sharedNixOSHost
    ;
}
