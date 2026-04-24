{
  inputs,
  user,
  ...
}: {
  imports = [
    ../../modules/shared
    ../../modules/darwin
  ];

  dotfiles.profiles = {
    devenv.enable = true;
    apps.enable = true;
    work.enable = true;
    essentials.promptEngine = "starship";
  };

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
