{
  inputs,
  hostData,
  userPreferences,
  userExtras,
  userData,
  homeModules,
  getPkgs,
  getPkgsStable,
  ...
}: let
  homeManagerConfig = {
    user,
    hostKey,
    isDarwin,
    inputs,
    ...
  }: let
    system =
      if isDarwin
      then "aarch64-darwin"
      else "x86_64-linux";
  in {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit
        inputs
        hostData
        user
        hostKey
        userPreferences
        userExtras
        userData
        isDarwin
        ;
      pkgs = getPkgs system;
      pkgs-stable = getPkgsStable system;
    };
    users.${user} = {
      imports = homeModules isDarwin;
      home = {
        username = user;
        homeDirectory = hostData.hosts.${hostKey}.homeDirectory;
        stateVersion = hostData.hosts.${hostKey}.stateVersion;
      };
    };
  };
in {
  inherit homeManagerConfig;
}
