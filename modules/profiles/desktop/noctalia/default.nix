{
  host,
  inputs,
  pkgs,
  ...
}:
let
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hostConfigFile = host.noctaliaConfigFile or "config.toml";
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPkg;
    systemd.enable = false;
    validateConfig = true;
    # Path into the flake checkout; HM installs it to ~/.config/noctalia/config.toml
    # (rebuild after edits). GUI overrides still land in
    # ~/.local/state/noctalia/settings.toml.
    settings = ./config + "/${hostConfigFile}";
  };
}
