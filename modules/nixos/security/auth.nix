{
  pkgs,
  pkgsStable,
  ...
}: {
  # Authentication configuration
  # PAM configuration, etc.

  # Password managers
  environment.systemPackages = with pkgs; [
    proton-pass
  ];
}
