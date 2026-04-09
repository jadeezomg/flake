{
  inputs,
  user,
  ...
}: {
  imports = [
    ../../modules/shared
    ../../modules/darwin
  ];

  nix-homebrew = {
    inherit user;
    enable = true;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
    mutableTaps = true;
    autoMigrate = true;
  };

  system.stateVersion = "25.11";
}
