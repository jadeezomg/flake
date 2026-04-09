{pkgs, ...}: {
  services.xserver.videoDrivers = ["amdgpu"];
  environment.systemPackages = with pkgs; [nvtopPackages.amd];
}
