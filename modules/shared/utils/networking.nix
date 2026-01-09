{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    curl # Command line HTTP client
    dig # DNS lookup utility
    gping # Better ping
    ipfetch # Neofetch for IP addresses
    wget # Web file downloader
    xh # A better curl
    resterm # Terminal-based REST client
  ];
}
