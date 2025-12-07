{ pkgs, ... }:

{
  # Networking utilities can be added here
  environment.systemPackages = with pkgs; [
    gping # Better ping
    xh # Better curl
  ];
}
