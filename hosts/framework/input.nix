{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [fprintd];

  services.fprintd.enable = true;

  security.pam.services = {
    login.fprintAuth = lib.mkForce true;
    sudo.fprintAuth = true;
    gdm-password.fprintAuth = lib.mkForce true;
    gdm-fingerprint.fprintAuth = lib.mkForce true;
  };
}
