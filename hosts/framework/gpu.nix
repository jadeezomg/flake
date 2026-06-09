{pkgs, ...}: {
  services = {
    xserver.videoDrivers = ["amdgpu"];
    lact.enable = true;
  };
  environment.systemPackages = with pkgs; [nvtopPackages.amd];
}
