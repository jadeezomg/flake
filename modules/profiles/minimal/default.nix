# minimal — system core + the user baseline HM halves (shells, ssh, sops
# plumbing, nix client settings). Always on, including the server.
{
  dotfilesLib,
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.minimal;
  minimalPackages = dotfilesLib.minimalPackages pkgs;
in {
  config = lib.mkIf cfg.enable {
    home-manager.sharedModules =
      [
        ./shells
        ./network
        ./nix-client.nix
        ./security.nix
      ]
      ++ lib.optionals (!isDarwin) [./linux]
      ++ lib.optionals isDarwin [./darwin];

    environment.systemPackages = minimalPackages;
  };
}
