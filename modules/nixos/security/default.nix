{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./auth.nix
    ./keyrings.nix
    ./secureboot.nix
    ./ssh.nix
    ./sudo.nix
  ];
}
