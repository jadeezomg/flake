{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./tailscale-client.nix
  ];
}
