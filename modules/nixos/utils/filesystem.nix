{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    rar # RAR archives
    nfs-utils # NFS client
    samba # Samba client
  ];
}
