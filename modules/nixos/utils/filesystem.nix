{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    rar # RAR archives

  ];
}
