{ config, pkgs, ... }:

{
  #   environment.systemPackages = with pkgs; [
  #     polkit_gnome # Polkit GUI for authentication
  #     cmd-polkit # Polkit CLI for authentication
  #   ];

  #   security.polkit.enable = true;
}
