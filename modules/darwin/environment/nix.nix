{
  config,
  pkgs,
  ...
}: {
  # Disable nix-darwin's Nix management since Determinate manages it
  nix.enable = false;
}
