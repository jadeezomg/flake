{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    btop # Better htop alternative
    hyperfine # Command-line benchmarking tool
  ];
}
