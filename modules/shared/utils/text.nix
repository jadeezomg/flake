{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Text utilities
    bat # Better cat
    ripgrep # Fast text search
    sd # Better sed
  ];
}

