{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./auth.nix
    ./encryption
    ./ssh.nix
    ./sudo.nix
  ];
}
