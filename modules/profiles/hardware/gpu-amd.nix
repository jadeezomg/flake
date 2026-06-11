# AMD GPU trait (dotfiles.hardware.gpu = "amd").
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.dotfiles.hardware.gpu == "amd") {
    services = {
      xserver.videoDrivers = ["amdgpu"];
      lact.enable = true;
    };
    environment.systemPackages = with pkgs; [nvtopPackages.amd];
  };
}
