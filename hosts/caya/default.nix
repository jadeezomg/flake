{
  inputs,
  lib,
  user,
  dotfilesLib,
  ...
}:
let
  # brew version nix-homebrew pins, read from its own lock the same way its
  # module derives `version`.
  upstreamBrew =
    (builtins.fromJSON (builtins.readFile "${inputs.nix-homebrew}/flake.lock"))
    .nodes.brew-src.original.ref;
in
{
  imports = [
    ../../modules/shared
    ../../modules/darwin
    ../../modules/profiles
    ./profiles.nix
  ];

  nix-homebrew = {
    inherit user;
    enable = true;

    # The homebrew-cask tap is tracked at HEAD, and casks now use the
    # `command_wrapper` artifact DSL that only exists in brew >= 6.0.13
    # (Homebrew/brew#23308). nix-homebrew still pins 6.0.12, so `brew bundle`
    # during activation dies with
    # "Cask 'firefox' definition is invalid: undefined method 'command_wrapper'".
    # Point it at a newer brew until nix-homebrew catches up.
    package =
      (dotfilesLib.expiry { inherit lib; } "hosts/caya/default.nix").expireWhen
        {
          fixed = lib.versionAtLeast upstreamBrew "6.0.13";
          reason = "nix-homebrew now pins brew ${upstreamBrew}, which understands the cask command_wrapper DSL.";
          # Nothing to define — nix-homebrew's own default is what we want back.
          fallback = lib.mkIf false null;
        }
        (
          inputs.brew-src
          // {
            name = "brew-6.0.14";
            version = "6.0.14";
          }
        );

    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
      "xykong/homebrew-tap" = inputs.homebrew-xykong-tap;
      "nkzw-tech/homebrew-tap" = inputs.homebrew-nkzw-tap;
    };
    mutableTaps = true;
    autoMigrate = true;
  };

  system.stateVersion = "26.05";
}
