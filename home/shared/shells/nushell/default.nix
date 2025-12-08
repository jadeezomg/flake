{ ... }:

{
  imports = [
    ./base.nix
    ./env.nix
    ./theme.nix
    ./aliases.nix
  ];

  programs.nushell = {
    enable = true;
  };

}
