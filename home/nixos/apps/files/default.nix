{ pkgs, ... }:
{
  home.packages = with pkgs; [
    filezilla # FTP client
    celeste # File sync client supporting ProtonDrive
    nautilus # File manager
  ];
}
