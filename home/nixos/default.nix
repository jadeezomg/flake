{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./enviroment
  ];

  # Add home-manager command to PATH
  home.packages = [
    inputs.home-manager.packages.${system}.home-manager
  ];
}
