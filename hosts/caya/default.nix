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
    # devenv.llm.hosting auto-disables on darwin via the profile's mkIf
    # (vllm/lmstudio aren't usable here), so leaving the meta-flag on is fine.
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
