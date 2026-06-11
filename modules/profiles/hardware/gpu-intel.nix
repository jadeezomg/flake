# Intel GPU trait (dotfiles.hardware.gpu = "intel") — iGPU and/or Arc dGPU.
{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf (config.dotfiles.hardware.gpu == "intel") {
    hardware.graphics.enable = true;

    environment.systemPackages = with pkgs; [
      intel-gpu-tools
      nvtopPackages.intel
    ];
  };
}
