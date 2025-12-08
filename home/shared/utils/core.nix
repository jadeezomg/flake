{ pkgs, ... }:

{
  programs.pay-respects = {
    enable = true;
    enableNushellIntegration = true;
    aiIntegration = false;
    alias = "fuck";
    packages = [ pkgs.pay-respects ];
  };
}
