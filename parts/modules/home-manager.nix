{
  inputs,
  hostData,
  userPreferences,
  userExtras,
  userData,
  homeModules,
  getPkgsUnstable,
  ...
}: let
  homeManagerConfig = {
    user,
    hostKey,
    isDarwin,
    inputs,
    ...
  }: {
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
        ;
      pkgs-unstable = getPkgsUnstable (
        if isDarwin
        then "aarch64-darwin"
        else "x86_64-linux"
      );
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
