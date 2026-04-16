{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [fprintd];

  services.fprintd.enable = true;

  security.pam.services = {
    login.fprintAuth = lib.mkForce true;
    sudo.fprintAuth = true;
    dms-greeter = {
      fprintAuth = true;
      rules.auth.fprintd.order = config.security.pam.services.dms-greeter.rules.auth.unix.order + 10;
    };
    gdm-password.fprintAuth = lib.mkForce true;
    gdm-fingerprint.fprintAuth = lib.mkForce true;
  };
}
