{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    ../../modules/shared
    ../../modules/nixos
    ../../modules/profiles
    ./input.nix
    ./power.nix
    ./profiles.nix
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";

  environment.systemPackages = with pkgs; [
    framework-tool
  ];
}
