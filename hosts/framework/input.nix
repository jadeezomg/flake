{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ fprintd ];

  services.fprintd.enable = true;

  security.pam.services = {
    login.fprintAuth = lib.mkForce true;
    sudo.fprintAuth = true;
    dms-greeter = {
      fprintAuth = true;
      rules.auth.fprintd.order = config.security.pam.services.dms-greeter.rules.auth.unix.order + 10;
    };
    # greetd authenticates the actual login (DMS greeter via greetd IPC). fprintAuth
    # defaults to services.fprintd.enable (true), and its default rule order puts fprintd
    # BEFORE unix — so password-alone parks on the fingerprint prompt. Move it after unix
    # so password-alone succeeds and fingerprint stays a fallback.
    greetd.rules.auth.fprintd.order = config.security.pam.services.greetd.rules.auth.unix.order + 10;
    gdm-password.fprintAuth = lib.mkForce true;
    gdm-fingerprint.fprintAuth = lib.mkForce true;
  };
}
