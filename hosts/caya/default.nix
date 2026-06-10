{
  inputs,
  user,
  ...
}: {
  imports = [
    ../../modules/shared
    ../../modules/darwin
    ../../modules/profiles
    ./profiles.nix
  ];

  nix-homebrew = {
    inherit user;
    enable = true;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
      "xykong/homebrew-tap" = inputs.homebrew-xykong-tap;
    };
    mutableTaps = true;
    autoMigrate = true;
  };

  system.stateVersion = "26.05";
}
