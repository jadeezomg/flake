{pkgs, ...}: {
  services.udisks2 = {
    enable = true;
  };

  # NTFS support for shared Windows drives
  environment.systemPackages = with pkgs; [
    ntfs3g # NTFS filesystem driver
    ntfsprogs # NTFS utilities
  ];
}
