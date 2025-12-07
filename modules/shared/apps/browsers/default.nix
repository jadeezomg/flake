{ pkgs, ... }:

{
  # Browser configuration is handled via Home Manager
  # System-level browser packages
  environment.systemPackages = with pkgs; [
    google-chrome
    # chromium  # Uncomment to use Chromium instead of Chrome
  ];
}
